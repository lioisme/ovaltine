#!/usr/bin/env bash
# 在 LineageOS 源码根目录执行：bash ci/build.sh [userdebug|eng]
# Android 15/16 的 lunch 需要 release 字段；可刷 OTA 包只有 m dist 才产出。
set -uo pipefail
VARIANT="${1:-userdebug}"
DEV="${DEVICE:-ovaltine}"

export USE_CCACHE=0                      # out/ 整体被 handoff 搬运，ccache 只会多吃磁盘
export ANDROID_BUILD_SMP="${ANDROID_BUILD_SMP:-$(nproc)}"
export TMPDIR="$PWD/.ci-tmp"; mkdir -p "$TMPDIR"

# 构建期真正要用的包在这里自己补一遍（GKI 内核没有 bc/elfutils 会在最后几步才炸，
# 那时候已经烧掉几小时）。CI 的 apt 步骤装的是同步/打包用的，这里补齐编译用的。
SUDO=; [ "$(id -u)" != 0 ] && command -v sudo >/dev/null && SUDO=sudo
if command -v apt-get >/dev/null 2>&1; then
  $SUDO apt-get install -y --no-install-recommends bc bison flex libssl-dev libelf-dev \
      dwarves cpio kmod xz-utils m4 >/dev/null 2>&1 || echo "提示：部分编译依赖没装上（$?）"
fi
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
# droid = 默认目标（只做到分区镜像，不做 dist 的 target_files/otatools/symbols 打包）
[ "$TARGETS" = droid ] && TARGETS=""
# 边编边回收：symbols/nativetest 是纯副产物；更狠的一招是删「已经被链接吃掉的旧 .o/.a」。
# 在 ext4 上 unlink 正被读取的文件是安全的（inode 活到 close），所以删旧对象文件不会打断在跑的动作；
# 万一某个 .o 的链接还没跑，ninja 只会把那几个文件重编一遍 —— 慢，但不会错。
reaper() {
  while :; do
    sleep 300
    a=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
    [ "${a:-99}" -ge 20 ] && continue
    echo "REAP avail=${a}G → 清 symbols / nativetest"
    rm -rf out/target/product/*/symbols out/host/linux-x86/nativetest* out/host/linux-x86/test-suites 2>/dev/null
    if [ "${a:-99}" -lt 12 ]; then
      echo "REAP avail=${a}G → 清 45 分钟前的 .o/.a（缺的链接产物让 ninja 自己补编）"
      find out -type f \( -name '*.o' -o -name '*.a' \) -mmin +45 -delete 2>/dev/null
    fi
    df -h / | tail -1
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
