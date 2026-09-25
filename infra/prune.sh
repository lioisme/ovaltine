#!/usr/bin/env bash
# 编译前腾空磁盘：git 对象库与工程元数据对 out/ 阶段的构建没有用处。
# 保留 .repo/manifests* 与 local_manifests（soong/make 会读 manifest 路径信息）。
set -uo pipefail
avail_g() { df --output=avail -BG / | tail -1 | tr -dc '0-9'; }

echo "清理前 avail=$(avail_g)G"
du -sh .repo 2>/dev/null
rm -rf .repo/project-objects .repo/projects .repo/git-hooks .repo/repo/.git 2>/dev/null
# 工作树里的 .git 是指向 .repo/projects 的 gitfile/目录，一并摘掉
find . -mindepth 2 -maxdepth 5 -name .git -prune -exec rm -rf {} + 2>/dev/null
du -sh .repo 2>/dev/null
echo "清理后 avail=$(avail_g)G"
echo "=== 顶层占用 top15 ==="
du -xsh .repo */ 2>/dev/null | sort -h | tail -15
