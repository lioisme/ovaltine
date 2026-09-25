#!/usr/bin/env bash
# 刷 PGP110 固件：21 个用国行 15.0 镜像，abl/xbl/xbl_config 强制用社区 pin 的 OOS13 版。
# 用法: ./flash-firmware.sh <CN镜像目录> <radio目录>   （在能跑 fastboot 的机器上执行）
#
# 为什么混用：设备树 proprietary-firmware.txt 把 abl/xbl/xbl_config 钉在 OOS 13.1.0.583，
# 提交记录写明 "newer ones killed EDL access" 与 "bootloader mode crashes with OOS 14 abl"。
# 实测 PGP110_15.0.0.1901 的三个哈希与 pin 不同，因此不可整包刷。
set -euo pipefail
CN=${1:?需要国行镜像目录}; RD=${2:?需要 radio 目录}

PINNED="abl xbl xbl_config"
declare -A PIN_SHA=( [abl]=b7a623c3136885fbfd26b19c8e76edc9740250f4 \
                     [xbl]=df04531acb9c7ac715f38ee9ec576521e309bfba \
                     [xbl_config]=dc1aee7ced14445e4cad9a0ddb2634029302a91f )
ALL="abl aop aop_config bluetooth cpucp devcfg dsp engineering_cdt featenabler hyp imagefv \
     keymaster modem oplus_sec oplusstanvbk qupfw shrm splash tz uefi uefisecapp xbl xbl_config xbl_ramdump"

for p in $PINNED; do
  got=$(sha1sum "$RD/$p.img" | cut -d' ' -f1)
  [ "$got" = "${PIN_SHA[$p]}" ] || { echo "中止：$RD/$p.img 哈希 $got != pin ${PIN_SHA[$p]}"; exit 1; }
done
for i in $ALL; do [ -f "$CN/$i.img" ] || { echo "中止：缺 $CN/$i.img"; exit 1; }; done
command -v fastboot >/dev/null || { echo "中止：没有 fastboot"; exit 1; }

for i in $ALL; do
  case " $PINNED " in *" $i "*) src="$RD/$i.img"; tag=PIN ;; *) src="$CN/$i.img"; tag=CN ;; esac
  echo "flash --slot=all $i  [$tag]  $src"
  fastboot flash --slot=all "$i" "$src"
done
echo "固件刷完；下一步刷 ROM（recovery/rom zip），不要降 oplusstanvbk 反回滚索引。"
