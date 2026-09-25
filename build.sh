#!/usr/bin/env bash
# 在 LineageOS 源码根目录执行：./build.sh [userdebug|eng]
set -euo pipefail
VARIANT="${1:-userdebug}"

export USE_CCACHE=1
export CCACHE_EXEC="$(command -v ccache)"
export ANDROID_BUILD_SMP=$(( $(nproc) > 6 ? 6 : $(nproc) ))   # runner 内存有限，压并行度
export TMPDIR="$PWD/.ci-tmp"; mkdir -p "$TMPDIR"

source build/envsetup.sh
brunch lineage_ovaltine "$VARIANT"

find out/target/product/ovaltine -maxdepth 1 \( -name 'lineage-*.zip' -o -name '*target_files*.zip' \) -printf '%p %s\n'
