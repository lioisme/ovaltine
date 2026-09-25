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

m dist
rc=$?
echo "== m dist 退出码 $rc"

echo "== 产物 =="
find out -maxdepth 3 -type f \( -name 'lineage*.zip' -o -name '*ota*.zip' -o -name '*target_files*.zip' \) \
     -printf '%p %s\n' 2>/dev/null | sort
df -h / | tail -1
exit $rc
