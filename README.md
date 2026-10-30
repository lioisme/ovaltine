# ovaltine — OnePlus 10T LineageOS Bring-up

OnePlus Ace Pro / 10T（codename **ovaltine**，目标型号 **CPH2415**）的 LineageOS 22.1 适配工作区。

> **当前状态：NO-GO（发布）。**
> 构建尚未成功，没有可用于内存/DSU 测试的产物；按业主 2026-10-31 约束，**本项目永久禁止真实刷入任何分区**，只允许内存启动/DSU 调试测试。
> 在 `AUDIT_REPORT.md` 的 P0 项关闭前，禁止发布。

---

## 安全红线

1. **禁止真实刷入任何分区。** 只允许内存启动（`fastboot boot`）或 DSU 调试/测试；`fastboot flash`、`adb sideload`、`fastboot -w`、`dd` 写分区、EDL/MSM 刷写等一律禁止。
2. 禁止重新上锁 bootloader。
3. DSU 也会写 userdata；测试前必须备份用户数据。
4. 禁止 anti-rollback 降级。
5. 禁止用 testkey 发布；发布必须独立签名。
6. 禁止把“未验证”写成“可用”。

完整操作见 [SOP.md](SOP.md)。该约束已记录为 `DECISIONS.md` DECISION-006。

---

## 文档索引

| 文档 | 用途 |
|---|---|
| [AUDIT_REPORT.md](AUDIT_REPORT.md) | 全量审计报告：73 项发现（P0 7 / P1 26 / P2 32 / P3 8）、证据、整改、验收 |
| [TASK_PLAN.md](TASK_PLAN.md) | 任务计划书：原始任务、WBS、测试矩阵、门禁、状态、追溯 |
| [SOP.md](SOP.md) | 构建、内存启动、DSU、测试、退出 SOP（v2.0，禁止真实刷机） |
| [HARDWARE_INVENTORY.md](HARDWARE_INVENTORY.md) | 硬件 BOM、variant 差异、测试映射 |
| [DRIVER_INVENTORY.md](DRIVER_INVENTORY.md) | 驱动来源、开源/闭源、许可证、回退方案 |
| [ADAPTATION_LOG.md](ADAPTATION_LOG.md) | 2026-10-31 起的适配实施记录与静态验证结果 |
| [DEVICE_REPORT.md](DEVICE_REPORT.md) | 真机扫描报告（历史证据） |
| [BASELINE_EVALUATION.md](BASELINE_EVALUATION.md) | 社区基线采纳评估（注意：部分结论已被审计修正） |
| [HARDWARE_MATRIX.md](HARDWARE_MATRIX.md) | 旧硬件状态矩阵（已被 HARDWARE_INVENTORY 取代，保留历史） |
| [BUILD_LOG.md](BUILD_LOG.md) | 构建/探针/提取日志（历史；末尾与 DECISION-003 有矛盾，见审计 DOC-001） |
| [DECISIONS.md](DECISIONS.md) | 决策记录（DECISION-001～004；DECISION-003 事实前提已被后续构建尝试推翻） |
| [STATUS.md](STATUS.md) | 历史终止状态（已过期，以审计/任务计划为准） |

---

## 当前结论（审计摘要 + 2026-10-31 整改进展）

- **构建**：4 轮 brunch 均失败/被杀；`out/target/product/ovaltine` 不存在。
- **身份**：已静态修正为 `CPH2415 / Android 15`；待内存/DSU 验证。
- **基线**：设备树 blob 锚定 OOS14；common 来自 OnePlus 10 Pro（NE2213/Android 14）；待 T-04/T-05 收敛。
- **修复链**：HBM、wise-light 名称替换、rear-ALS 已落静态补丁；旧 SIGSCAN 在 EX01 缺失，第二段待验证。
- **安全**：SPL 2025-01/2025-04；AVB testkey；SELinux/CTS/VTS 未验证。
- **红线**：SOP v2.0 已补（禁止真实刷机，仅内存/DSU）；退出演练未执行。
- **仓库**：已切到 `main`、打 tag、补 remote 待业主；工作区干净；公共探针/可选补丁已入库。

---

## 目标路线（详见 TASK_PLAN）

```text
M0 审计完成（当前）
 → M1 治理基线关闭（main/remote/文档/脚本）
 → M2 Linux 构建全绿（有产物）
 → M3 内存/DSU 进出演练通过（0 分区写入）
 → M4 内存/DSU 首次启动
 → M5 硬件矩阵全绿
 → M6 全量测试全绿
 → M7 签署发布
```

---

## 目录

```text
.
├── AUDIT_REPORT.md / TASK_PLAN.md / SOP.md
├── HARDWARE_INVENTORY.md / DRIVER_INVENTORY.md
├── DEVICE_REPORT.md / BASELINE_EVALUATION.md / HARDWARE_MATRIX.md
├── DECISIONS.md / STATUS.md / BUILD_LOG.md
├── local_manifests/           # 6 个工程 pinned revision
├── patches/                   # 历史补丁、EX01 适配、本轮 adaptation、macOS 适配
├── scripts/                   # apply-patches / verify-tree 等（无刷机脚本）
├── probes/                    # 公共探针证据（设备扫描原文因隐私不入库）
├── baseline/                  # 只读镜像（忽略，不入库）
├── vendor_extract/            # 底包/镜像/dump（忽略，不入库）
├── tools/                     # 可提交的提取工具
├── scratch/                   # 生成工作区（忽略）
└── CPH2415_15.0.0.1901_EX01.zip  # 底包（忽略）
```

---

## 非官方声明

本项目是个人/社区 bring-up 工作，**与 OnePlus、LineageOS 官方无隶属关系**。刷机有风险，可能导致设备变砖、数据丢失、保修失效；请自行承担风险，并先完成回滚演练。

## 许可证

项目许可证待业主确认。源码目录中的 SPDX 头（Apache-2.0 / GPL-2.0）各自有效；闭源 blob 不随仓库分发，默认只提供提取脚本。详见 `DRIVER_INVENTORY.md`。
