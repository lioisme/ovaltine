# manifests — 完整 pinned manifest

| 项 | 值 |
|---|---|
| 文件 | `lineage-22.1-20261031.xml` |
| 生成方式 | 在 `/Volumes/los-build/aosp` 执行 `repo manifest -r -o ...` |
| 生成日期 | 2026-10-31 |
| 工程数 | **1474**（全部带 40 位 revision） |
| 基础 manifest | LineageOS `lineage-22.1` @ `46ed254`（2025-04 ASB） |
| 本地覆盖 | `local_manifests/ovaltine.xml` 的 6 个工程 |

## 包含的本地工程

| 路径 | 来源 | 固定 commit |
|---|---|---|
| `device/oneplus/ovaltine` | lineage-ovaltine-dev | `59052db232dc` |
| `device/oneplus/sm8450-common` | pjgowtham | `258dbbd818fb` |
| `kernel/oneplus/sm8450` | lineage-ovaltine-dev | `63aeb92d069b` |
| `kernel/oneplus/sm8450-devicetrees` | lineage-ovaltine-dev | `c05fa09edcb9` |
| `kernel/oneplus/sm8450-modules` | lineage-ovaltine-dev | `cb014aff7629` |
| `hardware/oplus` | LineageOS 上游 | `37e78750b957` |

## 重要说明

1. 生成时基础 `default.xml` 曾被手工改为 USTC 镜像；本文件已把 `aosp` remote 还原为 `https://android.googlesource.com`。镜像覆盖应通过 local manifest/脚本，不应写进 pinned manifest。
2. 本文件只固定**源码 commit**，不包含 `patches/` 的本地修改。构建前必须执行 `scripts/apply-patches.sh`，并用 `scripts/verify-tree.sh` 校验。
3. `frameworks/base` 在同步时因 GitHub 502 使用了 shallow clone（见 `BUILD_LOG.md`）；本 manifest 固定其 tip，但换机同步时可能需要重新 shallow/full clone。
4. 本文件是“当前构建树的事实快照”，不是“已验证可构建”的声明；构建仍未成功。

## 使用

```bash
# 方式 A：把本文件放入 manifest 仓库/本地 .repo/manifests 后
repo init -u https://github.com/LineageOS/android.git -b lineage-22.1 \
  -m lineage-22.1-20261031.xml
repo sync -c -j8 --no-clone-bundle --no-tags

# 方式 B：以本文件作为独立 manifest 源（需先放入一个 git 仓库）
repo init -u <your-manifest-repo> -m lineage-22.1-20261031.xml

export AOSP_ROOT=$PWD
/path/to/ovaltine/scripts/apply-patches.sh
/path/to/ovaltine/scripts/verify-tree.sh
```
