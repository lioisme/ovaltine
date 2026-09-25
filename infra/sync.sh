#!/usr/bin/env bash
# 把 LineageOS + ovaltine 社区树同步到工作区，并压低磁盘峰值。
# 用法：bash infra/sync.sh
#   SYNC_SOFT_SECS  单发同步的单次时限（默认 4500s）——repo sync 可续，超时后接着来
#   SYNC_HARD_SECS  整个同步阶段的硬预算（默认 13200s），到点必须让位给编译
#   LOW_DISK_G      低于这个可用量就改走「分批 + 每批回收对象库」
# 磁盘峰值 = 工作树 + .repo 对象库；分批的意义就是让两者不同时占满。
set -uo pipefail

SYNC_JOBS="${SYNC_JOBS:-16}"
BATCHES="${BATCHES:-12}"
SOFT="${SYNC_SOFT_SECS:-4500}"
HARD="${SYNC_HARD_SECS:-13200}"
# 实测（run 36162392208）：单发同步 6 分钟就吃掉 72G（.repo 22G + 工作树 50G），
# 对象树与工作树同时存在 → hosted 的 ~108G 必然爆盘。所以默认走分批（LOW_DISK_G 设很大）。
LOW_DISK_G="${LOW_DISK_G:-999}"
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
  echo "分批同步：$(wc -l < /tmp/projects.txt) 个项目，$BATCHES 批"
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
