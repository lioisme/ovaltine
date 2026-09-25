#!/usr/bin/env bash
# 从 Release 的 state.json 推出本轮轮次，写进 GITHUB_ENV（CYCLE）。
# state.json 留在工作区根目录，后面的 get / save-out 直接读它。
set -uo pipefail
TAG="${HANDOFF_TAG:-ci-handoff}"
export GH_REPO="${GH_REPO:-${GITHUB_REPOSITORY:-}}"
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" gh release download "$TAG" -p state.json --clobber 2>/dev/null || true
prev=$(sed -n 's/.*"cycle": *\([0-9]*\).*/\1/p' state.json 2>/dev/null | head -1)
[ -n "${prev:-}" ] || prev=0
echo "== 上一轮 cycle=$prev（$( [ -f state.json ] && echo 有状态 || echo 无状态，首轮 )）"
echo "CYCLE=$((prev + 1))" >> "$GITHUB_ENV"
echo "PREV_CYCLE=$prev" >> "$GITHUB_ENV"
df -h / | tail -1
