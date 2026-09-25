#!/usr/bin/env bash
# 活体进度：把一行状态写进 Release 的正文，便于在 job 运行期间随时读。
# （跑中的 job 拿不到部分日志，只能靠这条旁路观察同步/编译速率。）
# 用法：bash infra/progress.sh "sync -j32 累计 1200s avail=88G"
set -uo pipefail
TAG="${HANDOFF_TAG:-ci-handoff}"
TEXT="${1:-}"
export GH_REPO="${GH_REPO:-${GITHUB_REPOSITORY:-}}"
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" gh release edit "$TAG" \
  --notes "$(date -u '+%F %H:%M:%SZ') [run ${GITHUB_RUN_ID:-?}] $TEXT" >/dev/null 2>&1 || true
