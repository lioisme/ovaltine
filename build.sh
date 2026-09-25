#!/usr/bin/env bash
# 在 LineageOS 源码根目录执行：bash ci/build.sh [userdebug|eng]
# Android 15/16 的 lunch 需要 release 字段；可刷 OTA 包只有 m dist 才产出。
set -uo pipefail
VARIANT="${1:-userdebug}"
DEV="${DEVICE:-ovaltine}"

export USE_CCACHE=0                      # out/ 整体被 handoff 搬运，ccache 只会多吃磁盘
export ANDROID_BUILD_SMP="${ANDROID_BUILD_SMP:-$(nproc)}"
export TMPDIR="$PWD/.ci-tmp"; mkdir -p "$TMPDIR"
echo "== nproc=$(nproc) smp=$ANDROID_BUILD_SMP"; df -h / | tail -1

source build/envsetup.sh

lunch_ok=0
lunch "lineage_${DEV}-${VARIANT}" >/dev/null 2>&1 && lunch_ok=1
if [ "$lunch_ok" != 1 ]; then
  for rel in trunk_staging bp1a aps bp4a; do
    if lunch "lineage_${DEV}-${rel}-${VARIANT}" >/dev/null 2>&1; then lunch_ok=1; break; fi
  done
fi
[ "$lunch_ok" = 1 ] || { echo "lunch lineage_${DEV}…${VARIANT} 失败"; exit 1; }
echo "== lunch 目标: ${TARGET_PRODUCT:-?} / ${TARGET_RELEASE:-默认} / $VARIANT"

# 磁盘吃紧时只出「可刷镜像」而不是整包 dist：out/ 能少 10-20G（不产 target_files/otatools/symbols 包）
# 注意用 ${VAR-def}：workflow 传空串就是要走默认目标 droid，不能被当成「没设」
TARGETS="${BUILD_TARGETS-dist}"
# 边编边回收：symbols/nativetest 是纯副产物，刷机用不到；ninja 只在 dist 打包时才要它们
reaper() {
  while :; do
    sleep 300
    a=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
    if [ "${a:-99}" -lt 14 ]; then
      echo "REAP avail=${a}G → 清理 symbols / nativetest 副产物"
      du -xsh out/*/linux-x86/nativetest* out/target/product/*/symbols out/soong/.intermediates/*/symbols 2>/dev/null | tail -5
      rm -rf out/target/product/*/symbols out/host/linux-x86/nativetest* out/host/linux-x86/test-suites 2>/dev/null
      df -h / | tail -1
    fi
  done
}
reaper & REAP=$!
trap 'kill $REAP 2>/dev/null' EXIT

m $TARGETS
rc=$?
echo "== m $TARGETS 退出码 $rc"

echo "== 产物 =="
find out -maxdepth 3 -type f \( -name 'lineage*.zip' -o -name '*ota*.zip' -o -name '*target_files*.zip' \) \
     -printf '%p %s\n' 2>/dev/null | sort
df -h / | tail -1
exit $rc
