#!/usr/bin/env bash
# 在 LineageOS 源码根目录执行：bash ci/build.sh [userdebug|eng]
# Android 15/16 的 lunch 需要 release 字段；且可刷 OTA 包只有 m dist 才产出。
set -euo pipefail
VARIANT="${1:-userdebug}"
DEV=ovaltine

export USE_CCACHE=1
export CCACHE_EXEC="$(command -v ccache || true)"
export ANDROID_BUILD_SMP=$(( $(nproc) > 6 ? 6 : $(nproc) ))
export TMPDIR="$PWD/.ci-tmp"; mkdir -p "$TMPDIR"
df -h / | tail -1

if [ -f build.sh ]; then
  bash build.sh --env-only
  bash build.sh --brunch "lineage_${DEV}" --variant "$VARIANT"
else
  source build/envsetup.sh
  set +e
  lunch "lineage_${DEV}-${VARIANT}" >/dev/null 2>&1; ok=$?
  set -e
  if [ "$ok" != 0 ]; then
    # A15+ 需要 release 字段（trunk_staging / bp1a 等），逐个试
    for rel in trunk_staging bp1a aps bp4a; do
      if lunch "lineage_${DEV}-${rel}-${VARIANT}" >/dev/null 2>&1; then echo "lunch 使用 lineage_${DEV}-${rel}-${VARIANT}"; break; fi
    done
  fi
  printvar TARGET_PRODUCT TARGET_RELEASE 2>/dev/null || true
  m dist
fi

echo "== 产物 =="
find out -maxdepth 3 -type f \( -name 'lineage*.zip' -o -name '*ota*.zip' -o -name '*target_files*.zip' \) -printf '%p %s\n' 2>/dev/null | sort
ls -l "out/target/product/$DEV" 2>/dev/null | tail -15
df -h / | tail -1
