#!/usr/bin/env bash
# 跨 job 续建：把「源码树 + out/」当成可搬运的状态存进 GitHub Release。
# 单个 hosted job 只有 6 小时，装不下一整轮 LineageOS 构建，靠它把进度接力下去。
#   probe      有可续建的 tree 存档吗（有 → exit 0）
#   get        流式拉回 tree/out（压缩包不落盘，边下边解）
#   save-tree  打包上传源码树（同步成功、还没开编时就存，编炸了也不用重新同步）
#   save-out   打包上传 out/ + 写回 state.json
# 依赖：gh（GITHUB_TOKEN 需 contents: write）、zstd、curl、GNU coreutils
# 峰值磁盘 = tree + out + 一个分片（分片边压边传边删，不累积）
set -uo pipefail

TAG="${HANDOFF_TAG:-ci-handoff}"
ROOT="${HANDOFF_ROOT:-$PWD}"
SPLIT="${HANDOFF_SPLIT:-3500m}"
EXCLUDES=(--exclude=./out --exclude=./ci --exclude=./artifacts --exclude=./state.json
          --exclude=./.ci-tmp --exclude=./rom.sha256 --exclude=./chain.log)
cd "$ROOT"
export TAG
# 工作区根目录不是 git 仓库（本仓 checkout 在 ci/），gh 需要显式的仓库上下文
export GH_REPO="${GH_REPO:-${GITHUB_REPOSITORY:-}}"
[ -n "$GH_REPO" ] || echo "警告：GH_REPO 与 GITHUB_REPOSITORY 都为空，gh 将依赖 git 上下文"

ghx() { GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" gh "$@"; }

release_ensure() {
  ghx release view "$TAG" >/dev/null 2>&1 && return 0
  # 工作区根目录不是 git 仓库（本仓被 checkout 到 ci/），必须显式给 gh 一个 target 分支
  ghx release create "$TAG" --target "${HANDOFF_TARGET:-main}" --prerelease \
      --title "CI 续建状态（勿删）" --notes "build.yml 跨 job 搬运 tree/out 用"
}

asset_url() {
  ghx release view "$TAG" --json assets \
     --jq ".assets[] | select(.name==\"$1\") | .url" 2>/dev/null | head -1
}

family_idx() {  # $1 = family
  ghx release view "$TAG" --json assets --jq '.assets[].name' 2>/dev/null |
    sed -n "s/^$1\.tar\.zst\.part\([0-9][0-9]\)$/\1/p" | sort -u
}

state_field() {  # $1 = key
  sed -n "s/.*\"$1\": *\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" state.json 2>/dev/null | head -1
}

# 依次取回 part00..NN 拼成一条流（split 切的是压缩流，可以直接串起来解）
stream_fetch() {  # $1 = family
  local fam="$1" n=0 i url
  for i in $(family_idx "$fam"); do
    url="$(asset_url "${fam}.tar.zst.part${i}")"
    [ -z "$url" ] && continue
    n=$((n+1)); printf '  <- %s.part%s\n' "$fam" "$i" >&2
    curl -sL ${CURL_EXTRA:-} --retry 5 --retry-delay 15 -o - "$url" || return 1
  done
  [ "$n" -gt 0 ]
}

# tar → zstd → 分片，每片交给 put-part.sh 上传后即删（不在本地攒压缩包）
pack() {  # $1 = family  $2.. = tar 的路径参数
  local fam="$1"; shift
  release_ensure
  tar --numeric-owner -C . -cf - "$@" | zstd -T3 -3 --long=27 2>/dev/null |
    split -b "$SPLIT" -d --numeric-suffixes=0 --suffix-length=2 \
          --filter="bash $ROOT/ci/infra/put-part.sh" - "$fam.tar.zst.part"
}

# 新分片覆盖同名旧分片之后，把多余的旧高序号删掉（不留没有存档的空窗）
prune_family() {  # $1 = family  $2 = 新分片数
  local fam="$1" keep="$2" i
  for i in $(family_idx "$fam"); do
    [ "$((10#$i))" -ge "$keep" ] || continue
    echo "  删除过期分片 ${fam}.part${i}"
    ghx release delete-asset "$TAG" "${fam}.tar.zst.part${i}" --yes >/dev/null 2>&1 || true
  done
}

write_state() {  # $1 = tree_parts  $2 = out_parts
  local tp="${1//[!0-9]/}" op="${2//[!0-9]/}"
  tp="${tp:-0}"; op="${op:-0}"
  cat > state.json <<JSON
{
  "cycle": ${CYCLE:-0},
  "done": ${DONE:-false},
  "branch": "${BRANCH:-}",
  "variant": "${VARIANT:-}",
  "tree_parts": $tp,
  "out_parts": $op,
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
    [ -n "$(asset_url tree.tar.zst.part00)" ] && { echo "已有 tree 存档，走续建"; exit 0; }
    echo "无 tree 存档，本轮全量同步"; exit 1
    ;;

  get)
    release_ensure
    [ -f state.json ] || ghx release download "$TAG" -p state.json --clobber
    [ -f state.json ] || { echo "state.json 不存在"; exit 1; }
    echo "== 续建自 cycle=$(state_field cycle) tree=$(state_field tree_parts) out=$(state_field out_parts)"
    echo "== 解包 tree"
    stream_fetch tree | zstd -dc 2>/dev/null | tar --numeric-owner -C "$ROOT" -xf - || { echo "tree 解包失败"; exit 1; }
    if [ "$(state_field out_parts)" != "0" ]; then
      echo "== 解包 out"
      stream_fetch out | zstd -dc 2>/dev/null | tar --numeric-owner -C "$ROOT" -xf - || { echo "out 解包失败"; exit 1; }
    fi
    test -f build/envsetup.sh && test -d device/oneplus/ovaltine || { echo "解包后关键路径缺失"; exit 1; }
    df -h / | tail -1
    echo "== 取回完成"
    ;;

  save-tree)
    echo "== 打包并上传源码树"
    pack tree "${EXCLUDES[@]}" .
    n="$(family_idx tree | wc -l | tr -d ' ')"
    prune_family tree "$n"
    write_state "$n" "${OUT_PARTS:-$(state_field out_parts)}"
    df -h / | tail -1
    ;;

  save-out)
    n=0
    # 只有本轮真的开编过才搬 out/（同步或取回失败时 out/ 可能是残缺/污染的）
    if [ "${BUILD_OUTCOME:-none}" = success ] && [ -d out ]; then
      echo "== 打包并上传 out/"
      pack out out
      n="$(family_idx out | wc -l | tr -d ' ')"
      prune_family out "$n"
    else
      echo "== 本轮不搬 out/（BUILD_OUTCOME=${BUILD_OUTCOME:-none}），只更新 state.json"
    fi
    tp="$(state_field tree_parts)"; [ -n "$tp" ] || tp=0
    write_state "$tp" "$n"
    df -h / | tail -1
    ;;

  show)
    ghx release view "$TAG" --json name,assets --jq '{name, assets: [.assets[] | {name, size}]}'
    ;;

  *) echo "用法: handoff.sh <probe|get|save-tree|save-out|show>"; exit 2 ;;
esac
