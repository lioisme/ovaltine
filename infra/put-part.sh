#!/usr/bin/env bash
# split --filter 的落点：stdin 收到一个分片 → 按 split 给的文件名落盘 → 传到 Release → 删本地副本。
# 由 infra/handoff.sh 的 pack 流水线调用；分片序号来自 split 的 $FILE，依赖环境变量 TAG。
set -euo pipefail
name="$(basename "${FILE:?split 未提供 \$FILE}")"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
cat > "$dir/$name"
echo "  -> $name  $(du -h "$dir/$name" | cut -f1)"
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" gh release upload "${TAG:?TAG}" "$dir/$name" --clobber
