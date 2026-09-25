#!/usr/bin/env bash
# 取回存档后的结构体检：manifest 里声明的每个 path 都得在、且非空。
# 分片被别的进程覆盖/删过时，tar 往往照样「成功」但树是缺的 —— 缺文件的构建
# 会跑到一半才炸，白烧几小时，所以在这里先拒收，让调用方去走同步修复。
set -uo pipefail
M=".repo/manifest.xml"
[ -f "$M" ] || { echo "没有 $M，无法体检"; exit 1; }

total=0 miss=0 misslist=""
while read -r p; do
  [ -n "$p" ] || continue
  # slim.sh 会特意删掉主线模块的预编译 SDK（我们从源码编），别把它算成缺件
  case "$p" in prebuilts/module_sdk/*) continue ;; esac
  total=$((total+1))
  if [ ! -d "$p" ] || [ -z "$(ls -A "$p" 2>/dev/null)" ]; then
    miss=$((miss+1)); [ $miss -le 25 ] && misslist="$misslist $p"
  fi
done < <(grep -oE '<project path="[^"]+"' "$M" | sed 's/.*path="\([^"]*\)"/\1/')

echo "体检：manifest 声明 $total 个 path，缺失/空 $miss 个"
[ -n "$misslist" ] && echo "缺失样例:$misslist"

bad=0
for s in build/envsetup.sh build/soong/soong_ui.bash \
         prebuilts/build-tools/linux-x86/bin/ninja \
         frameworks/base/core/java/android/app/Activity.java \
         frameworks/native/services/surfaceflinger/SurfaceFlinger.cpp \
         build/make/core/main.mk; do
  [ -f "$s" ] || { echo "  哨兵缺失：$s"; bad=1; }
done
for d in device/oneplus/ovaltine device/oneplus/sm8450-common hardware/oplus vendor/extra \
         kernel/oneplus/sm8450 vendor/oneplus/ovaltine; do
  [ -d "$d" ] || { echo "  目录缺失：$d"; bad=1; }
done
du -sh prebuilts/clang/host/linux-x86 2>/dev/null | sed 's/^/  clang: /'
[ -d prebuilts/clang/host/linux-x86 ] || bad=1

if [ "$miss" -gt $((total / 50)) ] || [ "$bad" = 1 ]; then
  echo "!! 体检不通过（缺 $miss/$total）→ 需要重新同步修复"
  exit 1
fi
echo "体检通过"
