# DECISIONS.md — 关键决策记录

> 设备：OnePlus Ace Pro / OnePlus 10T（codename **ovaltine**，CPH2415）
> 记录规则：每次做出不可逆选择时立即追加；每条决策附可验证依据。

---

## [DECISION-001] 22.2 探针失败，构建目标降级至 lineage-22.1

- **日期**：2026-10-29
- **状态**：已生效（不可逆标记：此后所有阶段 1–3 工作以 lineage-22.1 为目标分支）
- **触发条件**：任务书 §1.2 判定规则

### 依据（来源 A：LineageOS 官方组织）

| 检查项 | 结果 | 证据 |
|---|---|---|
| `LineageOS/android_device_oneplus_ovaltine` | 仓库存在但为**空仓库**（无任何分支、无任何提交） | GitHub API：`/branches` 返回 `[]`；`/commits` 返回 `409 "Git Repository is empty."`；raw 存档 `probes/srcA_device_repo.json`、`probes/srcA_device_branches.json`、`probes/srcA_device_commits.json` |
| `LineageOS/android_kernel_oneplus_sm8475` | **404 不存在** | GitHub API：`probes/srcA_kernel_sm8475.json` |
| 官方组织是否存在 lineage-22.2 ovaltine 分支 | **否**（设备树空仓库，内核仓库不存在） | 同上 |

### 依据（来源 B：lineage-ovaltine-dev 组织）

90 天窗口：2026-07-31 ～ 2026-10-29（探针执行日 2026-10-29）。

**lineage-22.2 分支存在性：存在**（满足条件 1），但**最近 90 天内无任何提交（条件 2 失败）**：

| 仓库 | lineage-22.2 分支最后一次提交 | 日期 | 距今 |
|---|---|---|---|
| `android_device_oneplus_ovaltine` | `608c30290340` "ovaltine: Update supported framerates for camera" | 2024-01-29 | ~27 个月 |
| `android_device_oneplus_sm8450-common` | `4d8084160cf8` "sm8450-common: Disable LiveDisplay SunlightEnhancement feature" | 2025-08-17 | ~14 个月 |
| `android_kernel_oneplus_sm8450` | `bcdb38a104bf` "alarmtimer: Minimize wakeup time" | 2023-01-13 | ~46 个月 |
| `android_kernel_oneplus_sm8450-devicetrees` | `7d4aba979e7d` "Import oplus dts{i}" | 2025-05-02 | ~18 个月 |
| `android_kernel_oneplus_sm8450-modules` | `5835ae8692f8` "oplus: display: kill log spams" | 2025-08-21 | ~14 个月 |

> 佐证：该组织默认分支已前移（设备树/sm8450-common/gki-modules 默认分支为 `lineage-23.2`，内核默认分支为 `lineage-22.2`），但即便默认分支本身最后推送时间也是 2026-06-11/12（距今 ~140 天），同样不在 90 天窗口内。

**build 目标可解析性（条件 3）**：未执行 brunch 实测（按任务书禁止在全量同步前测试），但 XDA 非官方线程维护者明确声明 "the 22.2 branch isn't buildable yet"、"Upstream hasn't published buildable ovaltine sources"（任务书 §0 前提），与上述提交停滞证据相互印证。

**Releases 佐证**：`lineage-ovaltine-dev/release` 仓库共 9 个 release，最新为 `lineage-21.0-20241003-UNOFFICIAL-Pig`（2024-10-03），**无任何 22.1/22.2 产物**（`probes/srcB_release_repo_releases.json`）。

### 判定

```
条件 1（lineage-22.2 分支存在）：满足
条件 2（最近 90 天有提交）    ：不满足 ← 决定性
条件 3（brunch 可解析）       ：无需评估（条件 2 已失败，判定为"或"逻辑短路）
→ 构建目标 = lineage-22.1
```

### 风险注记（转入阶段 1 评估）

- `android_kernel_oneplus_sm8450-modules` 的 lineage-22.1 分支最后提交为 **2023-07-11**，远早于设备树 22.1 分支（2025-01-24），22.1 内核模块树陈旧，需在阶段 1 核对其与 sm8450-common 22.1 的配套关系。
- `android_oneplus_kernel_gki-modules` **仅有 lineage-23.2 分支**，无 22.1/22.2 分支；若 22.1 构建依赖 GKI 模块仓库，需另行解决。
- `android_hardware_oplus` 仅有 lineage-20/lineage-21 分支，22.1 构建需确认该依赖的取用来源。
- `android_kernel_modules_and_devicetree_oneplus_sm8475`（OnePlusOSS 下游镜像，默认分支 `oneplus_sm8475_t_13.0_oneplus_11R_5G`，2025-07-10 推送）保留为内核备选源。

---

## [DECISION-002] 构建宿主环境约束记录（预先声明，非阻塞确认）

- **日期**：2026-10-29
- **状态**：预警（构建尝试前最终确认）

当前宿主为 **macOS（darwin 25.6.0, x64）**，16 GB 内存 / 32 核 / 522 GB 可用磁盘。事实依据：

1. LineageOS 22.x（Android 15）构建系统官方仅支持 **Linux x86_64** 宿主；macOS 原生构建不受支持。
2. 宿主未安装 Docker / OrbStack / Colima（`which docker orbstack colima` 全部 not found）。
3. 16 GB 内存低于 A15 全量构建的实用下限（32 GB+，或 16 GB + 大容量 swap 且大幅降低并行度）。
4. 项目根目录 OxygenOS 卡刷包 `CPH2415_15.0.0.1901(EX01)` 已确认存在（`CPH2415_15.0.0.1901_EX01.zip`，6.1 GB，metadata 已核验），vendor blob 提取不受此约束影响。

结论：vendor 提取、树分析、补丁整理、manifest 编写等阶段 1–2 产出可正常完成；**brunch 构建步骤本身在当前宿主不可执行**，除非用户决策引入 Linux 环境（真实机/云主机/ARM Linux 盒子）或接受在 Docker + 16 GB 内存的勉强条件下超长耗时尝试。最终处理见 STATUS.md 与 BUILD_LOG.md 构建尝试记录。
