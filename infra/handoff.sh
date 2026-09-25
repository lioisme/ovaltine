#!/usr/bin/env bash
# 跨 job 续建：把「源码树 + out/」当成可搬运的状态存进 GitHub Release。
# 单个 hosted job 只有 6 小时，装不下一整轮 LineageOS 构建，靠它把进度接力下去。
#   probe      有可续建的 tree 存档吗（有 → exit 0）
#   get        流式拉回 tree/out（压缩包不落盘，边下边解）
#   save-tree  打包上传源码树（同步完、开编之前就存，编炸了也不用重新同步）
#   save-out   打包上传 out/ + 写回 state.json
# 分片族名带 run id（tree-<run>.tar.zst.part000）：被取消的 job 会留下还在往 Release
# 写分片的僵尸进程，共用族名会让「上传完清理旧分片」互相删掉对方的数据（实测踩过）。
# 依赖：gh（GITHUB_TOKEN 需 contents: write）、zstd、curl、GNU coreutils
# 峰值磁盘 = tree + out + 一个分片（分片边压边传边删，不累积）
set -uo pipefail

TAG="${HANDOFF_TAG:-ci-handoff}"
ROOT="${HANDOFF_ROOT:-$PWD}"
SPLIT="${HANDOFF_SPLIT:-1500m}"      # 单个 Release 资产有大小上限，切片保守取 1.5G
RUNKEY="${GITHUB_RUN_ID:-local}"
EXCLUDES=(--exclude=./out --exclude=./ci --exclude=./artifacts --exclude=./state.json
          --exclude=./.ci-tmp --exclude=./rom.sha256 --exclude=./chain.log
          --exclude=./.handoff-parts.* --exclude=./.handoff-assets.tsv)
cd "$ROOT"
export TAG HANDOFF_ROOT="$ROOT"
# 工作区根目录不是 git 仓库（本仓 checkout 在 ci/），gh 需要显式的仓库上下文
export GH_REPO="${GH_REPO:-${GITHUB_REPOSITORY:-}}"

ghx() { GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" gh "$@"; }
prog() { [ -f "$ROOT/ci/infra/progress.sh" ] && bash "$ROOT/ci/infra/progress.sh" "$1"; return 0; }

release_ensure() {
  ghx release view "$TAG" >/dev/null 2>&1 && return 0
  ghx release create "$TAG" --target "${HANDOFF_TARGET:-main}" --prerelease \
      --title "CI 续建状态（勿删）" --notes "build.yml 跨 job 搬运 tree/out 用" \
    || echo "!! gh release create $TAG 失败 rc=$?"
}

# release 对象里的 assets 数组只给前 30 条（API 截断），而一族就 36+ 片：
# 拿它列举会漏尾巴，进而把自家分片当「过期」删掉。一览一律走分页端点并缓存成 name→url 表。
MAP="$ROOT/.handoff-assets.tsv"
refresh_map() {
  # 注意：gh release view --json id 给的是 GraphQL 的 node id（RE_xxx），不是数字 id；
  # 拼 /releases/{id}/assets 会 404 → 列举为空。数字 id 要从 tags 端点取。
  local rid; rid="$(ghx api "repos/${GH_REPO}/releases/tags/${TAG}" --jq .id 2>/dev/null | head -1)"
  [ -n "$rid" ] || { : > "$MAP"; return; }
  ghx api "repos/${GH_REPO}/releases/$rid/assets?per_page=100" \
     --jq '.[] | "\(.name)\t\(.browser_download_url)"' > "$MAP" 2>/dev/null || : > "$MAP"
}
asset_url() { [ -s "$MAP" ] || refresh_map; awk -F'\t' -v n="$1" '$1==n{print $2; exit}' "$MAP"; }
family_idx() {  # $1 = family → 该族已有分片序号（2 或 3 位都认）
  [ -s "$MAP" ] || refresh_map
  cut -f1 "$MAP" | sed -En "s|^$1\.tar\.zst\.part([0-9]{2,3})\$|\1|p" | sort -u
}
# 本轮真正传上去的分片数：put-part.sh 逐条落在本地清单里，比远端列举更可靠
local_count() { wc -l < "$ROOT/.handoff-parts.$1" 2>/dev/null | tr -dc '0-9'; }

state_field() {  # $1 = key
  sed -n "s/.*\"$1\": *\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" state.json 2>/dev/null | head -1
}
fam_of() {  # $1 = state 里的族名字段  $2 = 老存档的回落族名
  local f; f="$(state_field "$1")"; [ -n "$f" ] && printf '%s\n' "$f" || printf '%s\n' "$2"
}

# 依次取回该族分片拼成一条流（split 切的是压缩流，可以直接串起来解）。
# 片数与 state.json 不符就拒绝解包：缺片会被悄悄跳过，拼出「能解但少文件」的坏档。
stream_fetch() {  # $1 = family
  local fam="$1" n=0 i url
  for i in $(family_idx "$fam"); do
    url="$(asset_url "${fam}.tar.zst.part${i}")"
    [ -z "$url" ] && continue
    n=$((n+1)); printf '  <- %s.part%s\n' "$fam" "$i" >&2
    prog "取回 ${fam} 第 $n 片"
    curl -sL ${CURL_EXTRA:-} --retry 5 --retry-delay 15 -o - "$url" || return 1
  done
  [ "$n" -gt 0 ] || { echo "!! $fam 一片都没有"; return 1; }
  local exp; exp="$(state_field "${fam%%-*}_parts")"
  if [ -n "${exp:-}" ] && [ "$n" -ne "$exp" ] 2>/dev/null; then
    echo "!! $fam 实到 $n 片，state 记 $exp 片 → 分片被删/漏传，拒绝解包"; return 1
  fi
}

# tar → zstd → 分片，每片交给 put-part.sh 上传后即删（不在本地攒压缩包）
pack() {  # $1 = family  $2.. = tar 的路径参数
  local fam="$1"; shift
  release_ensure
  rm -f "$ROOT/.handoff-parts.$fam"
  tar --numeric-owner -C . -cf - "$@" | zstd -T3 -3 --long=27 2>/dev/null |
    split -b "$SPLIT" -d --numeric-suffixes=0 --suffix-length=3 \
          --filter="bash $ROOT/ci/infra/put-part.sh" - "$fam.tar.zst.part"
}

# 同名覆盖之后，删掉本次没写到的旧高序号尾巴
prune_family() {  # $1 = family  $2 = 本次分片数
  local fam="$1" keep="$2" i
  # keep=0 只可能是打包/列举失败，绝不能据此把已有分片删光
  [ "${keep:-0}" -ge 1 ] || { echo "  keep=${keep:-0}，跳过清理（防误删）"; return 0; }
  rm -f "$MAP"
  for i in $(family_idx "$fam"); do
    [ "$((10#$i))" -ge "$keep" ] || continue
    echo "  删除过期分片 ${fam}.part${i}"
    ghx release delete-asset "$TAG" "${fam}.tar.zst.part${i}" --yes >/dev/null 2>&1 || true
  done
}

write_state() {  # $1=tree_parts $2=out_parts $3=tree_family $4=out_family
  local tp="${1//[!0-9]/}" op="${2//[!0-9]/}"
  tp="${tp:-0}"; op="${op:-0}"
  cat > state.json <<JSON
{
  "cycle": ${CYCLE:-0},
  "done": ${DONE:-false},
  "branch": "${BRANCH:-}",
  "variant": "${VARIANT:-}",
  "targets": "${TARGETS:-dist}",
  "tree_parts": $tp,
  "out_parts": $op,
  "tree_family": "${3:-$(fam_of tree_family tree)}",
  "out_family": "${4:-$(fam_of out_family out)}",
  "sync_secs": "${SYNC_SECS:-}",
  "build_secs": "${BUILD_SECS:-}",
  "note": "${NOTE:-}",
  "ts": "$(date -u +%FT%TZ)"
}
JSON
  release_ensure
  ghx release upload "$TAG" state.json --clobber
  echo "== state.json"; cat state.json
}

cmd="${1:-}"
case "$cmd" in
  probe)
    release_ensure
    ghx release download "$TAG" -p state.json --clobber >/dev/null 2>&1 || true
    [ -f state.json ] || { echo "无 state.json，本轮全量同步"; exit 1; }
    fam="$(fam_of tree_family tree)"
    [ -n "$(family_idx "$fam" | head -1)" ] && { echo "已有 tree 存档（$fam），走续建"; exit 0; }
    echo "tree 存档（$fam）不存在，本轮全量同步"; exit 1
    ;;

  get)
    release_ensure
    [ -f state.json ] || ghx release download "$TAG" -p state.json --clobber
    [ -f state.json ] || { echo "state.json 不存在"; exit 1; }
    tf="$(fam_of tree_family tree)"; of="$(fam_of out_family out)"
    echo "== 续建自 cycle=$(state_field cycle)：tree=$tf($(state_field tree_parts)片) out=$of($(state_field out_parts)片)"
    echo "== 解包 tree"
    stream_fetch "$tf" | zstd -dc 2>/dev/null | tar --numeric-owner -C "$ROOT" -xf - || { echo "tree 取回失败"; exit 1; }
    if [ "$(state_field out_parts)" != "0" ]; then
      echo "== 解包 out"
      stream_fetch "$of" | zstd -dc 2>/dev/null | tar --numeric-owner -C "$ROOT" -xf - || { echo "out 取回失败"; exit 1; }
    fi
    test -f build/envsetup.sh && test -d device/oneplus/ovaltine || { echo "解包后关键路径缺失"; exit 1; }
    df -h / | tail -1
    echo "== 取回完成"
    ;;

  save-tree)
    fam="tree-$RUNKEY"
    echo "== 打包并上传源码树（族 $fam）"
    pack "$fam" "${EXCLUDES[@]}" .
    n="$(local_count "$fam")"; [ "${n:-0}" -ge 1 ] || n="$(family_idx "$fam" | wc -l | tr -dc '0-9')"
    prune_family "$fam" "$n"
    write_state "$n" "$(state_field out_parts)" "$fam" "$(fam_of out_family out)"
    df -h / | tail -1
    ;;

  save-out)
    fam="out-$RUNKEY"; n=0
    # 只有本轮真的开编过才搬 out/（同步或取回失败时 out/ 可能残缺/被污染）
    if [ "${BUILD_OUTCOME:-none}" = success ] && [ -d out ]; then
      echo "== 打包并上传 out/（族 $fam）"
      pack "$fam" out
      n="$(local_count "$fam")"; [ "${n:-0}" -ge 1 ] || n="$(family_idx "$fam" | wc -l | tr -dc '0-9')"
      prune_family "$fam" "$n"
    else
      echo "== 本轮不搬 out/（BUILD_OUTCOME=${BUILD_OUTCOME:-none}）"
      fam="$(fam_of out_family out)"
    fi
    write_state "$(state_field tree_parts)" "$n" "$(fam_of tree_family tree)" "$fam"
    df -h / | tail -1
    ;;

  show)
    refresh_map
    echo "资产总数=$(wc -l < "$MAP")"
    cut -f1 "$MAP" | sed -E 's/\.tar\.zst\.part[0-9]+$//' | sort | uniq -c
    state_field cycle; state_field tree_family; state_field out_family
    ;;

  *) echo "用法: handoff.sh <probe|get|save-tree|save-out|show>"; exit 2 ;;
esac
