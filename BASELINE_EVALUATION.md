# BASELINE_EVALUATION.md — lineage-ovaltine-dev 采纳评估

> **2026-10-31 审计注记**：本文件中的补丁“已包含于 22.1 祖先链”结论仅对 `lineage-ovaltine-dev/android_device_oneplus_sm8450-common` 成立；最终 manifest 使用 pjgowtham common，HBM/wise-light/rear-ALS/aux 补丁实测不可应用。以 `AUDIT_REPORT.md` DRV-003 为准。

> 评估日期：2026-10-29。构建目标：lineage-22.1（DECISION-001）。
> 原始探针证据：`probes/*.json`（GitHub API 存档）；只读镜像：`baseline/`（HEAD 与 API 交叉验证一致）。
> GitHub REST 未认证探针当日消耗约 36 次，全部为幂等 GET。

## 1. 分支覆盖

### android_device_oneplus_ovaltine
- 分支列表: lineage-20, lineage-21-elf-check, lineage-21-wifi, lineage-21, lineage-22.1-displayconfig, lineage-22.1, lineage-22.2, lineage-23.2
- 默认分支: lineage-23.2
- 目标分支(lineage-22.1)是否存在: **是**
- 最近提交日期(lineage-22.1): **2025-01-24**（HEAD `59052db232dc` "ovaltine: build audio blobs from source"）

### android_device_oneplus_sm8450-common
- 分支列表: als, audio, backup/lineage-20, lineage-20, lineage-21-aidl-sensor, lineage-21-elf-check, lineage-21-touch, lineage-21-zram, lineage-21, lineage-22.1-backup, lineage-22.1, lineage-22.2, lineage-23.0-new-kmod, lineage-23.2, oplus-cam
- 默认分支: lineage-23.2
- 目标分支(lineage-22.1)是否存在: **是**
- 最近提交日期(lineage-22.1): **2025-01-02**（HEAD `5c08eb4dec6a` "sm8450-common: move to aidl bootctrl hal"）
- 备选来源 pjgowtham/android_device_oneplus_sm8450-common：
  分支 lineage-22.1 存在，HEAD `258dbbd818fb`（2025-03-16，"Fix offline charging"）；
  关键提交 `7a3b991` "Update from NE2211_15.0.0.401(EX01)" 表明该树已按 **OOS 15 EX01 底包**（一加 10T 印度版 NE2211，与本项目 CPH2415 全球版同硬件 sm8475）适配 blob 清单。两树 lineage.dependencies 声明完全一致（已 diff 验证）。

### 内核仓库（3 个，均 lineage-ovaltine-dev）
- android_kernel_oneplus_sm8450:
  分支列表: lineage-20/21 系列, lineage-22.1, lineage-22.2{,-ksu,-new-kmod}, lineage-23.{0,2}, ack/android12-5.10-lts-081825 等 25 个
  默认分支: lineage-22.2
  目标分支(lineage-22.1)是否存在: **是**
  最近提交日期(lineage-22.1): **2025-05-01**（HEAD `63aeb92d069b`，Merge ASB-2025-04-05_12-5.10；分支内含 CAF msm-5.10 合入与 kgsl 优先级修复，维护活跃）
- android_kernel_oneplus_sm8450-devicetrees:
  目标分支(lineage-22.1)存在: **是**；HEAD `c05fa09edcb9`（2024-08-27，"cape_overlay_common: Kill useless reserved region of BL log"）
- android_kernel_oneplus_sm8450-modules:
  目标分支(lineage-22.1)存在: **是**；HEAD `cb014aff7629`（**2023-07-11**，"qcacld-3.0: Avoid allocating large chunk of memory statically"）⚠️ 三仓库中最新，但分支基线早于内核主树约 22 个月，见风险 R-2

### 依赖仓库
- android_hardware_oplus（fork）: 仅有 lineage-20 / lineage-21 / lineage-21-8450 分支，**无 22.x 分支** → 不可直接用于 lineage-22.1 manifest。
  替代：LineageOS 上游 android_hardware_oplus **lineage-22.1 存在且活跃**（HEAD `37e78750b957`，2025-04-01），官方 22.1 manifest 不含该工程（已核对 default.xml），无冲突。

## 2. 提交时效性

最近一次与 Android 15 / LineageOS 22.x 相关的提交（按仓库）：
- device ovaltine lineage-22.1: `59052db232dc` "ovaltine: build audio blobs from source"，2025-01-24
- sm8450-common(lineage-ovaltine-dev) lineage-22.1: `5c08eb4dec6a` "sm8450-common: move to aidl bootctrl hal"，2025-01-02
- sm8450-common(pjgowtham) lineage-22.1: `258dbbd818fb` "sm8450-common: Fix offline charging"，2025-03-16；其祖先 `7a3b991` "Update from NE2211_15.0.0.401(EX01)" 为 15 代底包适配提交
- kernel sm8450 lineage-22.1: `63aeb92d069b` ASB-2025-04-05_12-5.10 合入，2025-05-01
- kernel modules lineage-22.1: `cb014aff7629`，2023-07-11（停滞）

是否包含 2025 年后的适配: **是**（device/common/kernel 主树均有 2025-01 ～ 2025-05 的提交；modules 除外）
90 天窗口（2026-07-31 起）内提交: **无任何分支**（这正是 DECISION-001 的触发依据）

## 3. 已知问题继承

核对方式：release 仓库 CHANGELOG/Release notes 具名补丁 → 在目标 22.1 分支 git 历史中验证存在性与祖先关系（`git merge-base --is-ancestor`）。

- 相机服务首次使用崩溃: 22.1 分支未见专条目；aux camera 解锁补丁（见下）为相机问题主修复，21.0 release notes（2024-08-27）声明 "Fix AUX camera"。结论：**随基线树继承，无独立补丁需求**
- 微距镜头录像崩溃: release notes 无具名修复条目 → **视为仍存在，标"未验证"**（HARDWARE_MATRIX 微距项对应）
- gralloc 错误: release notes 无具名修复条目 → **未验证**（依 OSS composer 栈间接缓解）
- HBM 节点冲突: 补丁 `8f7dc6e` "sm8450-common: init: Deny access to HBM node" [Bruno Martins] —— **已包含于 lineage-22.1 分支祖先**（已验证 ancestor of HEAD），无需 cherry-pick；导出存档 `patches/0001-sm8450-common-init-Deny-access-to-HBM-node.patch`
- aux camera 解锁: 补丁 `01c3d5a` "sm8450-common: Unlock aux cameras" [LuK1337] —— **已包含于 22.1 祖先**；存档 `patches/0001-sm8450-common-Unlock-aux-cameras.patch`
- OSS composer 切换: lineage-20 时代补丁（2023-11-16 changelog 具名）；22.1 分支即为 OSS display 栈（BoardConfigCommon.mk 内核模块表含 `qcom/opensource/display-drivers/msm`，已核对）→ **已随树继承**，无需动作
- UDFPS 框架调光: 设备树补丁 `ac9b624` "ovaltine: overlay: Set up UDFPS framework dimming" —— **已包含于 22.1 祖先**；overlay 验证：`overlay/OPlusSystemUIResTarget/res/values/config.xml` 中 `config_udfpsFrameworkDimming=true`；存档 `patches/0001-ovaltine-overlay-Set-up-UDFPS-framework-dimming.patch`
- 光传感器注册: `42cc1f8` "sm8450-common: Register wise light as android.sensor.light" —— **已包含于 22.1 祖先**；存档 `patches/0001-sm8450-common-Register-wise-light-as-android.sensor..patch`
- 补充采纳（可选）: pjgowtham `258dbbd818fb` "Fix offline charging"（依赖 `ro.boot.startupmode` 的 init 修复）—— pjgowtham common 树已自带；存档 `patches/optional-pjgowtham/0001-sm8450-common-Fix-offline-charging.patch`

## 4. 最终判定

判定: **采纳为基线**（限定于 lineage-22.1 分支线；22.2/23.2 分支不采纳）

锁定的 commit hash：
| 工程 | 来源 | commit |
|---|---|---|
| device/oneplus/ovaltine | lineage-ovaltine-dev | `59052db232dc` |
| device/oneplus/sm8450-common | **pjgowtham** | `258dbbd818fb` |
| kernel/oneplus/sm8450 | lineage-ovaltine-dev | `63aeb92d069b` |
| kernel/oneplus/sm8450-devicetrees | lineage-ovaltine-dev | `c05fa09edcb9` |
| kernel/oneplus/sm8450-modules | lineage-ovaltine-dev | `cb014aff7629` |
| hardware/oplus | LineageOS 上游 | `37e78750b957` |

进入 local_manifests 的仓库: 上表 6 个（`local_manifests/ovaltine-lineage-22.1.xml`）。

common 树选型理由（逐条）：
1. 任务书 P0 允许二选一（"优先使用与目标分支匹配的一方"），两树均有 lineage-22.1 分支；
2. pjgowtham 树更新（2025-03-16 > 2025-01-02）且维护者持续合入修复（offline charging、radio poweron_opt）；
3. 决定性证据：pjgowtham `7a3b991` 表明其 blob 清单已按 **OOS 15 EX01** 底包适配；本项目底包为 `CPH2415_15.0.0.1901(EX01)`（同代）；lineage-ovaltine-dev 设备树自带清单锚定 `CPH2415_11.F.66`（OOS 14 代，见 proprietary-files.txt 头注）；
4. 两树 lineage.dependencies 完全一致（已 diff），不引入额外依赖差异。

不采纳的具体理由：
- lineage-ovaltine-dev sm8450-common @ lineage-22.1：blob 锚点落后一代（F.66/OOS14），与本项目 EX01 底包代差大 → 不作为 common 基线（保留为 diff 对照镜像）
- lineage-ovaltine-dev device ovaltine @ lineage-22.2 / lineage-23.2：目标分支不符（DECISION-001）且 23.2 面向未来主线（gki-modules 仅 23.2），超范围
- tangalbert919/android_device_oneplus_ovaltine：不采纳（任务书 §2.2 预判成立：默认分支 staging/lineage-20，最后推送 2023-05-27，基于 OOS 13.1 时代，与 15.0.0.1901 底包代差过大）
- KawaiiHachimi/twrp_device_oneplus_ovaltine：仅参考（最后推送 2023-02-19；仅在 Lineage Recovery 构建失败时按任务书回退启用）
- sm8450-mainline/fdt：仅参考（DTS 对照，不编入）

## 5. 风险清单（转入构建阶段）

| # | 风险 | 依据 | 缓解 |
|---|---|---|---|
| R-1 | 设备树 proprietary-files.txt 锚定 CPH2415_11.F.66（OOS14），对 EX01 底包提取时部分 blob 路径/版本可能缺失 | proprietary-files.txt 头注 | extract-files 实测缺失清单 → 对照 pjgowtham EX01 清单逐条修正 |
| R-2 | kernel modules 22.1 分支停滞于 2023-07-11 | git HEAD 日期 | 构建失败时对照 lineage-22.2-new-kmod / lineage-23.0-new-kmod 分支回移 |
| R-3 | gki-modules 仓库仅 lineage-23.2 分支 | 分支枚举 | 若 22.1 构建引用该仓库，评估 23.2 分支兼容性或从底包 vendor_boot/vendor_dlkm 预编译模块回退 |
| R-4 | NE2211（印度版）与 CPH2415（全球版）区域差异 blob（RIL/NFC） | 7a3b991 | 提取时以 CPH2415 底包实际文件为准 |
| R-5 | 宿主 macOS + 16GB RAM 无 Linux 构建环境 | DECISION-002 | 阻塞 brunch 步骤，见 STATUS.md B-1/B-2 |
