# ovaltine — OnePlus 10T LineageOS Bring-up

OnePlus Ace Pro / 10T（codename **ovaltine**，目标型号 **CPH2415**）的 LineageOS 22.1 适配工作区。

> **当前状态：NO-GO。**
> 构建尚未成功，没有可刷写镜像；回滚到 Android 的 SOP/备份/演练尚未完成。
> **在 `AUDIT_REPORT.md` 的 P0 项关闭前，禁止刷机、禁止发布。**

---

## 安全红线

1. 必须随时可以回到 Android；未备份、未演练回滚前禁止刷机。
2. 禁止重新上锁 bootloader。
3. 禁止未备份 `persist`/`modemst`/`fsg`/`oplusdycnvbk` 等关键分区。
4. 禁止 anti-rollback 降级。
5. 禁止用 testkey 发布；发布必须独立签名。
6. 禁止把“未验证”写成“可用”。

完整操作见 [SOP.md](SOP.md)。

---

## 文档索引

| 文档 | 用途 |
|---|---|
| [AUDIT_REPORT.md](AUDIT_REPORT.md) | 全量审计报告：73 项发现（P0 7 / P1 26 / P2 32 / P3 8）、证据、整改、验收 |
| [TASK_PLAN.md](TASK_PLAN.md) | 任务计划书：原始任务、WBS、测试矩阵、门禁、状态、追溯 |
| [SOP.md](SOP.md) | 构建/备份/刷机/回滚/测试/发布/救砖 SOP |
| [HARDWARE_INVENTORY.md](HARDWARE_INVENTORY.md) | 硬件 BOM、variant 差异、测试映射 |
| [DRIVER_INVENTORY.md](DRIVER_INVENTORY.md) | 驱动来源、开源/闭源、许可证、回退方案 |
| [DEVICE_REPORT.md](DEVICE_REPORT.md) | 真机扫描报告（历史证据） |
| [BASELINE_EVALUATION.md](BASELINE_EVALUATION.md) | 社区基线采纳评估（注意：部分结论已被审计修正） |
| [HARDWARE_MATRIX.md](HARDWARE_MATRIX.md) | 旧硬件状态矩阵（已被 HARDWARE_INVENTORY 取代，保留历史） |
| [BUILD_LOG.md](BUILD_LOG.md) | 构建/探针/提取日志（历史；末尾与 DECISION-003 有矛盾，见审计 DOC-001） |
| [DECISIONS.md](DECISIONS.md) | 决策记录（DECISION-001～004；DECISION-003 事实前提已被后续构建尝试推翻） |
| [STATUS.md](STATUS.md) | 历史终止状态（已过期，以审计/任务计划为准） |

---

## 当前结论（审计摘要）

- **构建**：4 轮 brunch 均失败/被杀；`out/target/product/ovaltine` 不存在。
- **身份**：构建写的是 `CPH2417 / Android 13`；真机是 `CPH2415 / Android 15`。
- **基线**：设备树 blob 锚定 OOS14；common 来自 OnePlus 10 Pro（NE2213/Android 14）。
- **修复链**：HBM、wise-light、rear-ALS 在选定 common 树中缺失，导出补丁不可应用。
- **安全**：SPL 2025-01/2025-04；AVB testkey；SELinux/CTS/VTS 未验证。
- **红线**：无回滚 SOP/备份/演练。
- **仓库**：非 main 分支、无 remote/tag、工作区不干净、关键证据被 ignore。

---

## 目标路线（详见 TASK_PLAN）

```text
M0 审计完成（当前）
 → M1 治理基线关闭（main/remote/文档/脚本）
 → M2 Linux 构建全绿（有镜像）
 → M3 回滚演练通过（红线）
 → M4 首次启动
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
├── patches/                   # 历史补丁与 EX01/macOS 适配
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
