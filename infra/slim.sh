#!/usr/bin/env bash
# 只保留被代码显式引用到的 clang 版本目录。
# prebuilts/clang/host/linux-x86 里通常并存十几个 clang-rNNN，单个几 GB，
# 而一次构建只用 global.go 里 pin 的那一个 —— 省下的 15-25G 是 out/ 能落盘的关键。
set -uo pipefail
BASE=prebuilts/clang/host/linux-x86
[ -d "$BASE" ] || { echo "无 $BASE，跳过"; exit 0; }

refs=$(grep -rhoE 'clang-r[0-9]+[a-z]?' build/soong build/make build/blueprint \
        device/oneplus kernel/oneplus hardware/oplus vendor/lineage 2>/dev/null | sort -u)
echo "== 被引用的 clang 版本 =="
echo "$refs" | tr '\n' ' '; echo
[ -n "$refs" ] || { echo "引用集合为空（grep 失手？），保守起见不删"; exit 0; }

echo "== 清理前 =="
du -sh "$BASE" 2>/dev/null
for d in "$BASE"/clang-r*; do
  [ -d "$d" ] || continue
  n=$(basename "$d")
  if printf '%s\n' "$refs" | grep -qx "$n"; then
    echo "  keep $n"
  else
    echo "  rm   $n ($(du -sh "$d" 2>/dev/null | cut -f1))"
    rm -rf "$d"
  fi
done
echo "== 清理后 =="
du -sh "$BASE" 2>/dev/null

# 主线模块的预编译 SDK：我们从 packages/modules 源码编，这些快照只是给「用快照构建」的产物用。
# 24 个仓、十几个 G。老存档里可能还带着它们，所以这里也删一次（与 cull.xml 同效，可重复执行）。
if [ -d prebuilts/module_sdk ]; then
  echo "== 删 prebuilts/module_sdk（$(du -sh prebuilts/module_sdk 2>/dev/null | cut -f1)）"
  rm -rf prebuilts/module_sdk
fi

df -h / | tail -1
