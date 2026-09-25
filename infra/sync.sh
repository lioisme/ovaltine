#!/usr/bin/env bash
# 把 LineageOS + ovaltine 社区树同步到工作区，并压低磁盘峰值。
# 用法：bash infra/sync.sh
#   SYNC_SOFT_SECS  单发同步的单次时限（默认 4500s）——repo sync 可续，超时后接着来
#   SYNC_HARD_SECS  整个同步阶段的硬预算（默认 13200s），到点必须让位给编译
#   LOW_DISK_G      低于这个可用量就改走「分批 + 每批回收对象库」
# 磁盘峰值 = 工作树 + .repo 对象库；分批的意义就是让两者不同时占满。
set -uo pipefail

SYNC_JOBS="${SYNC_JOBS:-16}"
BATCHES="${BATCHES:-16}"
SOFT="${SYNC_SOFT_SECS:-4500}"
HARD="${SYNC_HARD_SECS:-13200}"
# 实测（run 36162392208）：单发同步 6 分钟吃 72G（.repo 22G + 工作树 50G），对象库与工作树
# 同时存在 → hosted 的 ~108G 必爆。故 hosted 一律分批；磁盘宽裕（≥200G 的 self-hosted）才走单发。
LOW_DISK_G="${LOW_DISK_G:-200}"
LFS_TREES="vendor/oneplus/ovaltine vendor/oneplus/sm8450-common"

avail_g() { df --output=avail -BG / | tail -1 | tr -dc '0-9'; }
left_s() { echo $(( HARD - ( $(date +%s) - start ) )); }

start=$(date +%s)
PROG=""
for c in ci/infra/progress.sh infra/progress.sh; do [ -f "$c" ] && PROG="$c" && break; done
monitor() {
  # 心跳：耗时、可用磁盘、已登记项目数、.repo 体积 —— 用日志判读真实速率
  local tick=0 line
  while :; do
    sleep 180
    tick=$((tick + 1))
    line="+$(( $(date +%s) - start ))s avail=$(avail_g)G projects=$(wc -l < .repo/project.list 2>/dev/null || echo '?') .repo=$(du -sh .repo 2>/dev/null | cut -f1)"
    printf 'OBS %s\n' "$line"
    [ -n "$PROG" ] && [ $((tick % 2)) -eq 0 ] && bash "$PROG" "sync ${line}"
  done
}
monitor & MON=$!
trap 'kill $MON 2>/dev/null' EXIT

batched_sync() {  # 分批：每批结束立刻回收对象库
  repo list -p 2>/dev/null | sort > /tmp/projects.txt
  # 最肥的先拉：此刻磁盘最空。clang 一个仓就要「对象库 + 工作树」两份几十 G，
  # 等到最后再拉就撞在 avail 只剩十几 G 的时候（run 36169431905 实测 86 分钟时 avail=11G）。
  HEAVY="prebuilts/clang/host/linux-x86 prebuilts/build-tools prebuilts/jdk/jdk21 prebuilts/jdk/jdk25 prebuilts/go/linux-x86 prebuilts/misc"
  for h in $HEAVY; do grep -vx "$h" /tmp/projects.txt > /tmp/p2 && mv /tmp/p2 /tmp/projects.txt; done
  echo "分批同步：$(wc -l < /tmp/projects.txt) 个项目，$BATCHES 批（先单独拉 $(( $(echo $HEAVY | wc -w) )) 个肥的）"
  for h in $HEAVY; do
    [ "$(left_s)" -gt 300 ] || { echo "同步硬预算用尽"; return 1; }
    timeout -s INT -k 60 "$(left_s)" repo sync -c --no-tags -j4 --force-sync "$h" || {
      echo "$h 同步失败（avail=$(avail_g)G）"; return 1; }
    rm -rf .repo/project-objects/*
    for s in ci/infra/slim.sh infra/slim.sh; do [ -f "$s" ] && { bash "$s" | tail -3; break; }; done
    echo "  $h 落地，avail=$(avail_g)G"
  done
  rm -f /tmp/batch.*; split -n "l/$BATCHES" /tmp/projects.txt /tmp/batch.
  for b in /tmp/batch.*; do
    [ "$(left_s)" -gt 300 ] || { echo "同步硬预算用尽"; return 1; }
    ok=0
    for try in 1 2 3; do
      timeout -s INT -k 60 "$(left_s)" repo sync -c --no-tags -j"$SYNC_JOBS" --force-sync $(cat "$b") && { ok=1; break; }
      echo "$(basename "$b") 第 $try 次失败（avail=$(avail_g)G），回收对象库后重试"
      rm -rf .repo/project-objects/*
      sleep 20
    done
    [ "$ok" = 1 ] || { echo "批 $(basename "$b") 同步失败"; return 1; }
    rm -rf .repo/project-objects/*
    # clang 一落地就把没用到的版本删掉：它是单一最肥的目录（十几个 clang-rNNN）
    for s in ci/infra/slim.sh infra/slim.sh; do
      [ -f "$s" ] && { bash "$s" | tail -4; break; }
    done
    echo "$(basename "$b") 完成，avail=$(avail_g)G 已用=$(( $(date +%s) - start ))s"
  done
}

echo "=== 开始同步：可用 $(avail_g)G，软时限 ${SOFT}s，硬预算 ${HARD}s ==="
if [ "$(avail_g)" -lt "$LOW_DISK_G" ]; then
  echo "可用磁盘低于 ${LOW_DISK_G}G，直接走分批策略"
  batched_sync || exit 1
else
  while :; do
    rem=$(left_s)
    [ "$rem" -gt 300 ] || { echo "同步硬预算用尽"; exit 1; }
    t=$(( rem < SOFT ? rem : SOFT ))
    echo "--- repo sync -j$SYNC_JOBS（本轮最多 ${t}s，累计已用 $(( $(date +%s) - start ))s）---"
    timeout -s INT -k 60 "$t" repo sync -c --no-tags --force-sync -j"$SYNC_JOBS"
    rc=$?
    if [ "$rc" = 0 ]; then echo "同步成功"; break; fi
    echo "本轮结束 rc=$rc avail=$(avail_g)G（repo sync 可续，接着同步剩余部分）"
    [ "$rc" = 124 ] || { echo "非超时失败，改用分批策略收尾"; batched_sync || exit 1; break; }
  done
fi

# 只对承载固件镜像的 blob 树取 LFS 内容（约 360MB），其余仓库跳过 smudge
export GIT_LFS_SKIP_SMUDGE=0
for t in $LFS_TREES; do
  [ -d "$t" ] && { git -C "$t" lfs pull >/dev/null 2>&1 || echo "LFS 拉取失败: $t"; }
done

echo "=== 关键仓库自检 ==="
miss=0
for p in build/make build/soong device/oneplus/ovaltine device/oneplus/sm8450-common \
         hardware/oplus vendor/extra vendor/oneplus/ovaltine vendor/oneplus/sm8450-common \
         kernel/oneplus/sm8450 prebuilts/clang/host/linux-x86 prebuilts/build-tools; do
  if [ -d "$p" ]; then echo "  OK   $p"; else echo "  MISS $p"; miss=1; fi
done
[ "$miss" = 0 ] || { echo "关键仓库缺失"; exit 1; }

echo "=== 同步后磁盘画像（用时 $(( $(date +%s) - start ))s，avail=$(avail_g)G）==="
du -sh .repo 2>/dev/null
du -xsh .repo */ 2>/dev/null | sort -h | tail -15
