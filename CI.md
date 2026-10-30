# CI — GitHub Actions 构建说明

| 项 | 值 |
|---|---|
| 仓库 | https://github.com/lioisme/ovaltine |
| 静态 CI | `.github/workflows/static-ci.yml` |
| 全量构建 | `.github/workflows/aosp-build.yml` |
| 设备写入 | **无**（工作流不调用 fastboot/adb 写设备） |
| 约束 | DECISION-006：只允许内存启动/DSU；本 CI 只构建，不刷机 |
| 当前状态 | `static-ci` **passing**（run 41104019019 @ `442350c`）；`aosp-build` 尚未运行（缺大 runner + vendor secret） |

---

## 1. 为什么标准 GitHub runner 不能跑全量构建

GitHub 免费/标准 `ubuntu-latest` 大致是 4 vCPU / 16 GB RAM / 14 GB 可用磁盘。AOSP/LineageOS 22.1 全量构建需要：

| 资源 | 实用下限 | 建议 |
|---|---:|---:|
| RAM | 32 GB | 64 GB |
| 可用磁盘 | 350 GB | 500 GB+ |
| CPU | 8 核 | 16 核+ |
| 构建时间 | 2–6 h | 取决于缓存/CPU |

标准 runner 会在 `Preflight` 步骤直接失败，并给出明确错误，不会浪费 6 小时。

## 2. 两种可行路径

### 路径 A：GitHub larger runner（如果套餐支持）

在 GitHub 仓库/组织 Settings → Actions → Runners 配置 larger runner，给它一个标签（例如 `aosp-builder`），然后手动运行 `aosp-build`，`runner_label` 填该标签。

> GitHub larger runner 的可用规格/计费取决于账号套餐；本项目不假设它一定可用。

### 路径 B：self-hosted Linux runner（推荐/最可控）

在任意 Linux x86_64 机器/云主机上安装 GitHub Actions self-hosted runner，标签包含 `aosp-builder`。要求：

- 32 GB+ RAM（建议 64 GB）
- 400 GB+ 可用磁盘
- 16+ 核
- Ubuntu 22.04/24.04，已安装 build-essential/JDK 17 等（工作流也会尝试安装）
- 能访问 GitHub、AOSP/LineageOS 源或镜像

快速步骤（在云主机上执行）：

```bash
# 1. 在 GitHub 仓库 Settings → Actions → Runners → New self-hosted runner
#    复制官方下载/配置命令；标签填 aosp-builder
mkdir -p ~/actions-runner && cd ~/actions-runner
# 按页面给出的 URL/版本下载 runner，然后：
./config.sh --url https://github.com/lioisme/ovaltine \
  --token <RUNNER_REGISTRATION_TOKEN> \
  --labels aosp-builder
sudo ./svc.sh install
sudo ./svc.sh start
```

> 注册 token 只在配置时使用，不要提交到仓库。构建完可停掉/销毁云主机；源码与产物不落在公开仓库。

> “完全在 GitHub 中编排”可以做到；但计算资源仍需一个满足规格的 runner。GitHub 免费标准 runner 无法改变硬件上限。

## 3. Vendor blobs（必须由业主提供）

本仓库是公开仓库，**不包含也不应包含** OnePlus 专有 blob。全量构建必须提供私有 vendor 归档：

```bash
# 在本地已提取 vendor 的机器上
cd /path/to/ovaltine
tar --zstd -cf /tmp/vendor-oneplus.tar.zst -C scratch/vendor oneplus
sha256sum /tmp/vendor-oneplus.tar.zst
```

归档顶层必须是 `oneplus/`，解压后得到 `vendor/oneplus/ovaltine` 与 `vendor/oneplus/sm8450-common`。

把归档上传到**私有**存储（S3/对象存储/私有 release asset 等），然后在 GitHub 仓库 Settings → Secrets and variables → Actions 设置：

| Secret | 必填 | 说明 |
|---|---|---|
| `VENDOR_ARCHIVE_URL` | 是 | 私有下载 URL；不要在公开 issue/日志中暴露 |
| `VENDOR_ARCHIVE_SHA256` | 建议 | 归档 SHA-256；不设置会 warning |
| `VENDOR_ARCHIVE_TOKEN` | 可选 | 若 URL 需要 Bearer token（如受保护的 release asset）则设置；签名 URL 不需要 |

> 不要把 vendor blob 提交到公开仓库；不要把带专有内容的 `system.img`/`vendor.img`/OTA 上传为公开 artifact。

## 4. 运行全量构建

GitHub UI：Actions → `aosp-build` → Run workflow：

- `runner_label`：`aosp-builder`（或你的 larger runner 标签）
- `upload_images`：默认 `false`

或使用 `gh`（需本机已登录）：

```bash
gh workflow run aosp-build.yml \
  -f runner_label=aosp-builder \
  -f upload_images=false
```

构建流程：

1. Preflight 检查 RAM/磁盘。
2. 下载并校验私有 vendor 归档。
3. `repo init` 使用本仓库的 `manifests/lineage-22.1-20261031.xml`（1474 工程，全部 pinned）。
4. `repo sync`。
5. `scripts/apply-patches.sh` + `verify-tree.sh`。
6. `breakfast ovaltine` + `brunch ovaltine -j<cap 16>`。
7. 上传 `build.log`、`artifacts-SHA256SUMS.txt`、`artifacts-list.txt`。
8. 仅在 `upload_images=true` 时上传 boot/dtbo/recovery/vbmeta 镜像。

## 5. 静态 CI（自动）

`static-ci` 在 push/PR 时自动运行，不需要 secrets，也不需要 AOSP 全量源码。它验证：

- workflow YAML / Python / shell 语法；
- `manifests/lineage-22.1-20261031.xml` 1474 工程、全部 40 位 revision、无 USTC 镜像；
- `artifacts/blob-manifest.sha256` 2688 条格式；
- 脚本中不存在 `fastboot flash`/`adb sideload`/`fastboot -w`/`dd` 写分区等禁刷命令；
- 通过 `actions/checkout` 拉取两棵 pinned 设备树（device ovaltine @ `59052db`、common @ `258dbbd`），应用 EX01 + adaptation 补丁，跑 `verify-tree.sh`。

**当前结果**：passing，见 https://github.com/lioisme/ovaltine/actions/runs/41104019019 。

> 首次运行曾失败（raw git clone + 未使用的 apt 依赖）；已改为 `actions/checkout` pinned ref，并移除无关依赖后通过。

## 6. 已知限制

- GitHub 标准 runner 不能全量构建；这不是 workflow 配置问题，是硬件上限。
- 首次全量构建很可能暴露新的编译错误；`build.log` 会作为 artifact 保留 7 天。
- 公开仓库的 Actions artifact 可被有仓库访问权限的人下载；默认只上传元数据/日志。不要上传 vendor/system/OTA。
- 构建成功不等于设备可用；仍需按 `SOP.md` v2.0 做内存启动/DSU 测试，禁止真实刷机。
- vendor 归档/许可证/再分发仍需 T-05/LEG-002 的法务评估。
