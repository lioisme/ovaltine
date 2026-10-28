# STATUS.md — 实时状态

> 更新规则：每完成一个原子动作立即更新，禁止事后补写。
> 最后更新：2026-10-29 05:30 (本地)

## 当前阶段

**阶段 0（可构建性判定）：✅ 已完成** → 已进入 **阶段 1（仓库拉取与基线评估）**

## 构建目标

**lineage-22.1**（依据 DECISIONS.md [DECISION-001]，22.2 探针失败降级）

## 已完成项

| 阶段 | 事项 | 结果 |
|---|---|---|
| 0 | 宿主环境勘察 | macOS x64 / 16GB / 32核 / 522GB 可用；git/jq/python3/curl/unzip 可用；repo、simg2img 未安装（可补）；Docker/OrbStack/Colima 未安装 |
| 0 | 底包核验 | 根目录 `CPH2415_15.0.0.1901_EX01.zip`（6.1GB，A/B payload 卡刷包）metadata 核验通过：`version_name=CPH2415_15.0.0.1901(EX01)`、`ota-id=CPH2415_11.H.85_3850_202606171345`、Android 15、SPL 2026-06-01，与任务书锚定一致。**注**：该文件初始 ls 时不存在，于探针中途（05:08 时间戳）出现在根目录，已重命名为规范文件名 |
| 0 | 来源 A 探针 | `LineageOS/android_device_oneplus_ovaltine` 存在但为空仓库（branches=[], commits 409）；`LineageOS/android_kernel_oneplus_sm8475` 404 |
| 0 | 来源 B 探针 | 组织 25 仓库全量遍历；关键 5 仓库的 lineage-22.1/22.2 分支枚举 + HEAD 提交日期抓取；无任何分支在 90 天窗口内有提交 |
| 0 | Releases 核对 | `release` 仓库最新 release = `lineage-21.0-20241003-UNOFFICIAL-Pig`，无 22.x 产物，与任务书预告一致 |
| 0 | 判定 | **DECISION-001**：22.2 探针失败（90 天窗口条件不满足），降级 lineage-22.1 |
| 0 | 记录载体 | DECISIONS.md / BUILD_LOG.md / STATUS.md 建立；probes/ 原始证据 15 份存档 |

## 阻塞项

| # | 阻塞 | 影响 | 状态 |
|---|---|---|---|
| B-1 | 宿主为 macOS 且无 Docker/Linux（详见 DECISION-002） | 仅阻塞最终 brunch 构建步骤；不阻塞阶段 1–2 产出 | 预警，构建尝试时正式定性 |
| B-2 | 16 GB 内存低于 A15 构建实用下限 | 同上 | 同上 |

## 下一动作

1. 初始化 git（main + bringup/ovaltine-lineage-22.1 分支，遵守任务书 §4.1 提交规范）。
2. 阶段 1：baseline/ 只读镜像浅克隆（设备树、sm8450-common、内核三仓库、release 仓库）。
3. 阶段 1：BASELINE_EVALUATION.md 逐仓库评估；从 release 仓库/分支历史提取已知补丁（HBM 拒绝访问、OSS composer、UDFPS 调光、aux camera）至 patches/。
4. 阶段 1：编写 local_manifests/ovaltine-lineage-22.1.xml。
5. vendor blob 提取管线验证（payload-dumper-go → vendor/odm 分区 → 提取流程记录入 BUILD_LOG.md）。
6. 阶段 2：HARDWARE_MATRIX.md（无真机，状态上限"一般"，逐项附可验证依据）。
