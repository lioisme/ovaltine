#!/usr/bin/env bash
# 编译前腾空磁盘：只删 git 对象库（.repo/project-objects，动辄几十 G）。
# 保留 .repo/projects 与工作树里的 .git gitfile：它们只有几 G，留着才能让
# 「取回存档后的校验/增量修复」认得出每个仓库该在哪个 revision（runed 过：全删掉之后，
# 下一轮的 repo sync 会把 1100 多个仓库全部重下一遍）。
set -uo pipefail
avail_g() { df --output=avail -BG / | tail -1 | tr -dc '0-9'; }

echo "清理前 avail=$(avail_g)G"
du -sh .repo 2>/dev/null
rm -rf .repo/project-objects .repo/git-hooks .repo/repo/.git 2>/dev/null
sync 2>/dev/null || true
du -sh .repo 2>/dev/null
echo "清理后 avail=$(avail_g)G"
echo "=== 顶层占用 top15 ==="
du -xsh .repo */ 2>/dev/null | sort -h | tail -15
