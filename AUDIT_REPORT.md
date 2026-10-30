# OnePlus 10T（ovaltine / CPH2415）LineageOS Bring-up 全量审计报告

| 项 | 值 |
|---|---|
| 文档编号 | OVL-AUDIT-2026-10-31 |
| 版本 | 1.0（审计快照） |
| 审计日期 | 2026-10-31 |
| 审计对象 | 仓库 `ovaltine`：`bringup/ovaltine-lineage-22.1` @ `65d8be2`；`main` @ `6bb80a8`；外部构建树 `/Volumes/los-build/aosp`；底包 `CPH2415_15.0.0.1901_EX01.zip` |
| 设备 | OnePlus Ace Pro / 10T，codename `ovaltine`，报告型号 CPH2415，bootloader 已解锁 |
| 审计依据 | 《开发作业临时约法》、业主七项要求、AOSP/LineageOS 官方构建规范、Android CDD/CTS/VTS、AVB、SELinux、SPDX、Git/OTA 行业惯例 |
| 审计方法 | 静态源码审计、Git 历史审计、补丁可应用性实测、构建日志分析、vendor dump 交叉核验、manifest/props/设备扫描三方对照 |
| 审计结论 | **NO-GO（禁止发布）**；真实刷机永久禁止；可继续内存/DSU 整改开发 |
| 报告状态 | 最终审计结果；整改由 `TASK_PLAN.md` 跟踪 |

> **2026-10-31 业主强制约束更新**：只允许内存启动（`fastboot boot`）或 DSU 调试/测试，**禁止真实刷入任何分区**。
> 该约束已记录为 `DECISIONS.md` DECISION-006；`SOP.md` v2.0 已移除全部刷机/回 stock/EDL 步骤；`TASK_PLAN.md` v1.1 已将 T-09/T-10/OT-05 改为内存/DSU 进出演练。
> 本报告保留为审计快照；其中 SEC-001 的刷机风险路径已被政策关闭，但其余发现仍有效。

---

## 1. 执行摘要

### 1.1 结论

当前仓库**不具备刷机条件，也不具备发布条件**。它不是“接近完成、只差一次编译”的状态，而是存在四类系统性问题：

1. **构建未闭环**：`brunch` 从未成功，`out/target/product/ovaltine` 不存在，没有任何可刷写镜像；当前 16 GB macOS 宿主不是 AOSP/LineageOS 官方支持的生产构建宿主。
2. **安全红线未落地**：业主明确要求“随时可以回到安卓系统”是底线、红线，但仓库中没有回滚 SOP、没有关键分区备份清单、没有 anti-rollback/槽位策略、没有回滚演练记录。**在补齐并演练之前，任何刷机都应被禁止。**
3. **基线混代/混机型**：设备树构建身份写的是 **CPH2417 / Android 13**，实际设备是 **CPH2415 / Android 15**；选定的 `sm8450-common` 来自 **OnePlus 10 Pro（NE2213，Android 14）** 的 blob 清单，而不是 10T CPH2415 EX01。设备树 blob 清单锚点仍是 `CPH2415_11.F.66`（OOS 14 代），只做了 5 处 EX01 适配。
4. **已知修复链断裂**：`lineage-ovaltine-dev` 树中的 HBM、wise-light、rear-ALS 修复在选定的 pjgowtham common 树中**不存在**；导出的补丁对选定树 `git apply --check` 失败。框架调光已开启，但 HBM 节点仍对 fingerprint HAL 可写，UDFPS 冲突风险是实打实的。

### 1.2 关键数字

| 指标 | 数值 | 说明 |
|---|---:|---|
| 审计发现总数 | 73 | P0 7 / P1 26 / P2 32 / P3 8 |
| 构建产物 | 0 | `out/target/product/ovaltine` 不存在 |
| 构建尝试 | 4 轮 | 均失败或被杀；最近一次 `brunch4` 直接因 `T: unbound variable` 退出 |
| 设备树 blob 条目 | 1415 | 仅 3 条保留 SHA-1 pin（EX01 补丁后） |
| common blob 条目 | 1265 | **0 条 SHA-1 pin** |
| 导出的 common 补丁可应用率 | 1/5 | 仅 offline-charging 在 pjgowtham HEAD 中已包含；其余 4 个 `git apply --check` 失败 |
| 本地提交 | 7 | 均在 `bringup/...`，`main` 落后；无 remote、无 tag |
| 测试执行记录 | 0 | 无 smoke/压力/回归/全量测试 |
| 可刷写镜像 | 0 | 无 boot/recovery/vbmeta/system 等产物 |

### 1.3 Top 10 问题（按风险排序）

1. **SEC-001**：没有回滚/退出的 SOP 与演练；**2026-10-31 已补 SOP v2.0（禁止刷机，仅内存/DSU），演练仍未执行**。
2. **BLD-001**：构建从未成功，没有任何镜像；当前宿主不适合作为生产构建机。
3. **ID-001**：构建身份是 CPH2417/Android 13，目标设备是 CPH2415/Android 15。
4. **SEC-002**：安全补丁停在 2025-01（boot/vendor）与 2025-04（平台 ASB），设备底包已是 2026-06。
5. **BLD-002 / BLD-003**：补丁链对选定基线不可应用，且没有自动化应用/回滚；**2026-10-31 已补 apply/verify 脚本与本轮补丁，完整 pinned manifest 仍待 Linux 环境**。
6. **ID-002 / ID-003**：common 树来自 10 Pro（NE2213/Android 14），设备树锚定 OOS 14；属于跨机型、跨代混用。
7. **DRV-001**：框架调光已开启，HBM 节点原为 `chown system`；**2026-10-31 已改为 `chmod 0000`，待 DSU/真机验证**。
8. **DRV-002**：wise-light/rear-ALS 修复原缺失；**2026-10-31 已做名称替换 + rear-ALS overlay；旧 SIGSCAN 在 EX01 缺失，第二段待验证**。
9. **SEC-003**：AVB 使用公共 testkey，并关闭 hashtree/verification；没有生产签名与密钥管理。
10. **GOV-001 / GOV-003 / GOV-004**：非 main 分支作业、无 remote/云端备份、关键交付物被 `.gitignore` 排除。

### 1.4 放行判定

| 门禁 | 判定 | 理由 |
|---|---|---|
| 允许继续源码整改 | **GO** | 基线可用，已知修复可移植，问题边界清晰 |
| 允许刷入测试机 | **NO-GO** | 无镜像、无回滚 SOP、无备份、身份/变体未对齐 |
| 允许发布/OTA | **NO-GO** | 构建未绿、无测试、无签名、SPL 过期、文档不合规 |
| 允许将当前状态标记为“完成” | **NO-GO** | 与《约法》作业篇 3/4 条直接冲突 |

---

## 2. 审计范围、方法与限制

### 2.1 审计对象清单

| 资产 | 路径 / 引用 | 状态 |
|---|---|---|
| 仓库文档 | 根目录 7 份 Markdown | 已读 |
| 本地 manifest | `local_manifests/ovaltine-lineage-22.1.xml` | 已审 |
| 设备树 | `baseline/android_device_oneplus_ovaltine` @ `59052db` | 已审 |
| common 树（选定） | `baseline/pjgowtham_sm8450-common` @ `258dbbd` | 已审 |
| common 树（对照） | `baseline/android_device_oneplus_sm8450-common` @ `5c08eb4` | 已对比 |
| 内核三仓库 | `baseline/android_kernel_oneplus_sm8450*` | 已审关键配置 |
| hardware/oplus | `baseline/android_hardware_oplus` @ `0fb1071`；构建树上游 @ `37e7875` | 已审模块存在性 |
| 补丁 | `patches/` 10 个 patch | 已逐个 `git apply --check` |
| 构建树 | `/Volumes/los-build/aosp`（约 245 GB） | 已审 manifest、device diff、构建日志 |
| 构建日志 | `/Volumes/los-build/brunch{,2,3,4}.log` | 已审 |
| 底包与 dump | `CPH2415_15.0.0.1901_EX01.zip`、`vendor_extract/{images,dump}` | 已抽检 |
| 真机报告 | `DEVICE_REPORT.md`、`probes/device_scan/*` | 已对照 |

### 2.2 证据等级

| 等级 | 含义 | 本次是否具备 |
|---|---|---|
| E1 | 源码/文档/配置静态证据 | 有 |
| E2 | 可复现命令输出（git/apply/ls/grep/rg） | 有 |
| E3 | 构建产物/镜像 | **无** |
| E4 | 真机运行/压力/CTS 结果 | **无**（审计时 `adb devices` 为空） |

> 本报告的所有“功能状态”结论最高只能到 E2；任何“可用/完美”判断都必须等到 E3/E4。

### 2.3 审计方法

1. **Git 考古**：分支、提交、remote、tag、工作区、忽略规则、构建树未提交修改。
2. **补丁可应用性**：对选定设备树和 common 树执行 `git apply --check`，逐条记录失败原因。
3. **构建证据**：读取 4 轮 brunch 日志，确认失败点、被杀点、产物目录。
4. **基线对照**：对比 lineage-ovaltine-dev common 与 pjgowtham common 的 init/overlay/extract-files 差异。
5. **blob 交叉核验**：用 EX01 dump 验证 Pixelworks、CameraHWConfiguration、sensors.ssc 等实际文件。
6. **身份/变体核验**：对照 `DEVICE_REPORT` 的 props 与 `lineage_ovaltine.mk`、`proprietary-files.txt` 头注。
7. **合规矩阵**：逐条对照《约法》与业主七项要求。
8. **大厂级验收映射**：构建可复现性、安全门禁、测试门禁、发布门禁、长期维护。

### 2.4 审计限制（必须如实声明）

- 审计时设备未连接，无法读取真实 `super`/`userdata` 分区尺寸、无法执行 `getenforce`、无法验证 UDFPS/相机/充电等运行时行为。
- 没有 Linux 构建宿主，无法产出 E3 证据；Mac 构建尝试日志只能证明“失败”，不能证明“功能可用”。
- 未做法律意见；blob 再分发合规性需要业主/法务确认。
- 未做动态安全分析、未做 CVE 扫描、未做 CTS/VTS。
- 源码基线为社区 fork，非 OnePlus 官方发布；所有结论以所附 commit 为准。

---

## 3. 合规矩阵

### 3.1 《开发作业临时约法》对照

| 条款 | 要求 | 现状 | 判定 | 关联发现 |
|---|---|---|---|---|
| Git 篇 1 | 任务完成后代码 100% 全绿编译并提交 main | 从未构建成功；工作在 `bringup/...`，`main` 落后 | **不符合** | BLD-001、GOV-001 |
| Git 篇 1 | 禁止擅自新建/使用其它分支 | 存在并使用 `bringup/ovaltine-lineage-22.1` | **不符合** | GOV-001 |
| Git 篇 2 | 任务开始前工作区干净 | `.venv/`、`scratch/`、`.DS_Store` 未处理 | **不符合** | GOV-002 |
| Git 篇 3 | 里程碑/长期未上云时远程提交 | 无 remote、无 tag、无 push | **不符合** | GOV-003 |
| 作业篇 1 | 输出含注意事项、原始任务文本、需求/方向/验收/状态的任务计划书 | 本次新增 `TASK_PLAN.md`；旧 `plan.md` 不满足 | **本次补齐** | DOC-004、DOC-005 |
| 作业篇 2 | 按顺序完成并回填工作内容/状态 | 审计完成；整改未执行 | **部分** | 全表 |
| 作业篇 3 | 冒烟/压力/回归/全量测试，全部全绿后再全量 | 0 测试记录 | **不符合** | TST-001～TST-008 |
| 作业篇 4 | 完整编译 100% 全绿；模拟生产环境全量校验 | 0 镜像、0 运行测试 | **不符合** | BLD-001、TST-001 |
| 约束篇 1 | 遵守 RFC/行业标准 | AVB/OTA/分区/权限多处未验证 | **部分** | SEC-003、SEC-010、ID-005 |
| 约束篇 2 | 遵守 REST/OpenAI 等事实标准 | 本项目无 REST/LLM 接口，**不适用** | N/A | — |
| 约束篇 3 | 遵守库/组件规定/推荐做法 | 大体遵循 AOSP/Lineage 结构；补丁系列不规范 | **部分** | BLD-004、BLD-007、DOC-004 |
| 约束篇 4 | 第一性原理、长期主义、性能与功能兼备 | macOS 16 GB 作为主构建路径不符合长期主义；22.1 已停止维护 | **部分** | BLD-001、ARCH-001 |
| 约束篇 5 | 仅一种语言/组件库 | AOSP 本身多语言；无同类 UI 组件库竞争 | **不适用** | — |
| 治理篇 | 专业 SOP、硬件清单、驱动清单 | 仅有状态矩阵；无 SOP/驱动清单 | **不符合** | DOC-005 |
| 业主红线 | 随时可回到安卓系统 | 无回滚 SOP、无备份、无演练 | **不符合** | SEC-001 |

### 3.2 业主七项要求对照

| # | 业主原文要点 | 现状 | 判定 | 关联 |
|---|---|---|---|---|
| 1 | 为 10T 适配可驱动所有硬件的 LineageOS | 基线存在，但无构建、无真机验证、硬件矩阵为推断 | **未完成** | BLD-001、TST-001、DRV-008 |
| 2 | 社区项目版本/质量不一 | 已做基线评估，但选型跨机型/跨代，未做逐项硬件对照 | **部分** | ID-002、ID-003 |
| 3 | BL 已解锁，可调试；必须随时可回安卓，记录到文档 | BL 解锁有证据；红线未记录为可执行 SOP | **不符合** | SEC-001 |
| 4 | adb 进 fastboot，fastboot 回安卓 | 无 fastboot 操作 SOP/演练记录 | **不符合** | SEC-001、DOC-005 |
| 5 | 驱动原则：开源 > 闭源，逐级降级 | 无驱动清单/许可证/开源闭源标注；闭源 blob 占主导 | **不符合** | DRV-008、LEG-001、ARCH-003 |
| 6 | 可利用现有社区 10T 开源项目 | 使用了社区树，但混入 10 Pro common；未系统比较 10T 专用 fork | **部分** | ID-002、ID-003 |
| 7 | 专业 SOP、硬件清单、驱动清单 | 本次新增 `SOP.md`、`HARDWARE_INVENTORY.md`、`DRIVER_INVENTORY.md` 草案 | **本次补齐（草案）** | DOC-005 |

---

## 4. 缺陷清单

### 4.1 严重度定义

| 级别 | 定义 | 处置要求 |
|---|---|---|
| P0 | 阻断刷机/发布，或可能导致设备不可恢复、数据丢失、红线失守 | 立即整改；未关闭前禁止刷机/发布 |
| P1 | 严重功能/安全/合规缺陷，可能导致核心硬件不可用或审计失败 | 发布前必须关闭或由业主书面风险接受 |
| P2 | 中等缺陷/技术债，影响可维护性、可复现性、体验或合规 | 里程碑前关闭；可带条件进入下一阶段 |
| P3 | 改进项/规范项 | 纳入 backlog，不阻断 |

**状态值**：待整改 / 整改中 / 已整改 / 风险接受 / 不适用。

### 4.2 汇总表

| ID | 级别 | 主题 | 状态 |
|---|---|---|---|
| BLD-001 | P0 | 构建未成功、无任何可刷镜像 | 待整改 |
| BLD-002 | P0 | 补丁链对选定基线不可应用且无自动化 | 待整改 |
| BLD-003 | P0 | 无完整 pinned manifest，基础 manifest 被手工改 | 待整改 |
| ID-001 | P0 | 构建身份 CPH2417/Android 13 与目标 CPH2415/Android 15 不符 | 待整改 |
| SEC-001 | P0 | 无回滚到 Android 的 SOP/关键分区备份/演练 | 待整改 |
| SEC-002 | P0 | 安全补丁严重过期（2025-01/2025-04） | 待整改 |
| TST-001 | P0 | 无任何测试执行与全绿门禁 | 待整改 |
| GOV-001 | P1 | 非 main 分支作业，main 落后 | 待整改 |
| GOV-002 | P1 | 工作区不干净（.venv/scratch/.DS_Store） | 待整改 |
| GOV-003 | P1 | 无 remote/tag/push，无云端备份 | 待整改 |
| GOV-004 | P1 | 关键交付物被 .gitignore 排除 | 待整改 |
| BLD-004 | P1 | macOS 补丁全局禁用 Go 测试，未按 darwin 隔离 | 待整改 |
| BLD-005 | P1 | `soong_ui.bash` `$T` unbound，macOS 构建直接退出 | 待整改 |
| ID-002 | P1 | common 树来自 10 Pro NE2213/Android 14，非 10T CPH2415 | 待整改 |
| ID-003 | P1 | 设备树 blob 锚点 OOS14 且混入 CPH2417/CPH2413 | 待整改 |
| ID-004 | P1 | common 0/1265、device 3/1415 blob pin，供应链完整性不足 | 待整改 |
| DRV-001 | P1 | HBM 修复缺失，UDFPS 框架调光与 HAL 冲突 | 待整改 |
| DRV-002 | P1 | wise-light/rear-ALS 修复缺失 | 待整改 |
| DRV-003 | P1 | 导出补丁对选定树不可应用，文档声称“祖先”误导 | 待整改 |
| DRV-006 | P1 | 内核/模块/设备树版本错位，未验证模块兼容 | 待整改 |
| SEC-003 | P1 | AVB 使用公共 testkey 且关闭验证链 | 待整改 |
| SEC-004 | P1 | SELinux enforcing/avc 未验证 | 待整改 |
| SEC-005 | P1 | 闭源 blob 法律/许可证/SBOM 未评估 | 待整改 |
| TST-002 | P1 | 无测试计划与可判定验收标准 | 待整改 |
| TST-003 | P1 | 无 CTS/VTS/Play Integrity/GSI/安全测试 | 待整改 |
| TST-004 | P1 | 无 OTA A/B 更新与回滚测试 | 待整改 |
| DOC-001 | P1 | STATUS/BUILD_LOG/DECISION-003 事实矛盾 | 待整改 |
| DOC-002 | P1 | HARDWARE_MATRIX 信息过期（blob 待提取/无真机） | 待整改 |
| DOC-003 | P1 | BASELINE_EVALUATION 补丁祖先结论仅对未采用树成立 | 待整改 |
| DOC-005 | P1 | 缺 SOP/硬件清单/驱动清单（业主第 7 项） | 本次补齐草案 |
| ARCH-001 | P1 | 22.1 已停止维护，与“安全/长期主义”冲突 | 待整改 |
| ARCH-002 | P1 | 10T 设备树 + 10 Pro common 的变体边界不清 | 待整改 |
| LEG-001 | P1 | 无 LICENSE/NOTICE/SPDX/署名清单 | 待整改 |
| GOV-005 | P2 | 缺 README/SECURITY/CONTRIBUTING/文档索引 | 待整改 |
| GOV-006 | P2 | 无 CI、无版本化构建/刷机/测试脚本 | 待整改 |
| GOV-007 | P2 | 无 release/tag/版本号/OTA 通道 | 待整改 |
| GOV-008 | P2 | 无评审/issue/PR/变更记录流程 | 待整改 |
| BLD-006 | P2 | GNU `date -d`/`stat -c` 在 macOS 报错 | 待整改 |
| BLD-007 | P2 | 16 GB Intel Mac 构建被 3:53 终止，无并行度控制 | 待整改 |
| BLD-008 | P2 | 构建日志/产物校验和未入库 | 待整改 |
| BLD-009 | P2 | sync 重试脚本在仓库外，429 退避策略粗糙 | 待整改 |
| BLD-010 | P2 | 工具链版本未完整锁定 | 待整改 |
| ID-005 | P2 | userdata 镜像尺寸 112 GB 与 256 GB 设备不符 | 待整改 |
| ID-006 | P2 | `BOARD_ONEPLUS_DYNAMIC_PARTITIONS_SIZE` 定义后无人使用 | 待整改 |
| ID-007 | P2 | FCC SAR/OPA model/SVN 等区域与版本属性陈旧 | 待整改 |
| ID-008 | P2 | OP5555L1/OP5552L1 身份记录不一致 | 待整改 |
| DRV-004 | P2 | aux camera 修复实际由 device extract-files.py 完成，补丁文档不符 | 待整改 |
| DRV-005 | P2 | offline-charging 修复已包含，导出补丁冗余且不可应用 | 待整改 |
| DRV-007 | P2 | 底包预编译 vendor_dlkm 回退未落地；vermagic 不一致 | 待整改 |
| DRV-008 | P2 | 硬件矩阵无 driver 版本/许可证/测试 ID | 待整改 |
| SEC-006 | P2 | debug/spoof 属性进入 user 构建 | 待整改 |
| SEC-007 | P2 | 文档含设备序列号/uniqueId，未脱敏 | 已整改（2026-10-31 历史重写脱敏） |
| SEC-008 | P2 | `config.fs` 0771 与 SETUID/SETGID 需最小权限复核 | 待整改 |
| SEC-009 | P2 | AVB vendor 链未包含 odm，rollback index 策略待确认 | 待整改 |
| TST-005 | P2 | 无性能/热/续航/充电测试 | 待整改 |
| TST-006 | P2 | 无相机/音频/传感器/电话/WiFi/BT 矩阵 | 待整改 |
| TST-007 | P2 | 无压力/长稳测试 | 待整改 |
| TST-008 | P2 | 无干净重建/哈希复现测试 | 待整改 |
| DOC-004 | P2 | `plan.md` 面向 Agent、frontmatter 破损、与《约法》冲突 | 待整改 |
| DOC-006 | P2 | 无需求—任务—测试—证据追溯矩阵 | 待整改 |
| DOC-007 | P2 | 无 release notes/changelog/known issues/维护计划 | 待整改 |
| ARCH-003 | P2 | 无按子系统的开源/闭源降级与回退方案 | 待整改 |
| ARCH-004 | P2 | 无 OTA/签名/密钥管理架构 | 待整改 |
| ARCH-005 | P2 | 无上游跟踪/ASB SLA/长期维护计划 | 待整改 |
| LEG-002 | P2 | 无 “unofficial” 商标声明/第三方署名 | 待整改 |
| DOC-008 | P3 | 命名/术语/链接/重复 `0001-` 前缀等规范问题 | 待整改 |
| GOV-009 | P3 | 无 `.editorconfig`/Markdown lint/提交模板 | 待整改 |
| GOV-010 | P3 | 无 CHANGELOG/issue 模板 | 待整改 |
| BLD-011 | P3 | 构建日志含本地绝对路径，迁移性差 | 待整改 |
| DOC-009 | P3 | 文档时间/版本/作者/状态字段不统一 | 待整改 |
| DOC-010 | P3 | 缺术语表/缩写表 | 待整改 |
| DOC-011 | P3 | 截图/原始数据无索引 | 待整改 |
| DOC-012 | P3 | 目录结构扁平，文档与产物混放 | 待整改 |

> 说明：表中 73 项包含已确认缺陷、治理缺口与待验证风险。P2/P3 的详细整改与验收见 §4.5/§4.6；P0/P1 见 §4.3/§4.4。

### 4.3 P0 阻断级（7 项）

#### BLD-001 构建未成功，无任何可刷镜像

- **证据**
  - `/Volumes/los-build/aosp/out/target/product` 不存在；`out/` 仅 1.5 GB，只有 host 工具与 soong 中间产物。
  - `brunch.log`：`soong bootstrap failed with: exit status 1`。
  - `brunch2.log`：`Unsupported macOS SDK version "26.5" not in [11 12 13 14]`，`FAILED: out/soong/build.lineage_ovaltine.ninja`。
  - `brunch3.log`：`05:04:10 Got signal: terminated`，`failed to build some targets (03:53:04)`。
  - `brunch4.log`：`build/soong/soong_ui.bash: line 20: T: unbound variable`，无后续构建。
- **根因**
  1. LineageOS 22.x/AOSP 官方只支持 Linux x86_64 宿主；当前宿主为 macOS 26.7 Intel。
  2. 16 GB RAM 低于全量构建实用下限；soong 分析阶段被内存/超时终止。
  3. macOS 兼容补丁不完整：`$T` 未绑定、GNU `date -d`、Go bootstrap 测试。
- **影响**：无法产出 boot/recovery/vbmeta/system/vendor 等镜像；无法进行 E3/E4 验证；所有“硬件可用”结论都只是推断。
- **整改方案**
  1. 将主构建路径迁移到 Linux x86_64（32 GB RAM 起，建议 64 GB；250 GB+ SSD；Ubuntu 22.04/24.04）。
  2. macOS 仅保留为“实验性分析环境”，不进入发布路径；mac 补丁单独目录、单独 CI job、不得污染 Linux 构建。
  3. 构建参数：`source build/envsetup.sh && breakfast ovaltine && brunch ovaltine`，显式 `-j8`/`-j12`，启用 ccache；记录 `free -h`、`nproc`、`df -h`。
  4. 产物清单：`boot.img`、`dtbo.img`、`recovery.img`、`vbmeta.img`、`vbmeta_system.img`、`vbmeta_vendor.img`、`vendor_boot.img`、`system.img`、`system_ext.img`、`product.img`、`vendor.img`、`vendor_dlkm.img`、`odm.img`、`super_empty.img`、OTA zip；逐项生成 SHA256。
- **验收标准**
  - `brunch` 退出码 0；
  - 上述产物全部存在且非 0 字节；
  - `unzip -t` OTA zip 通过；
  - `avbtool verify_image` 对每个 AVB 镜像通过（允许 testkey 的研发构建，发布构建必须用发布 key）；
  - 构建日志、`build-info.txt`、`SHA256SUMS` 归档。
- **状态**：待整改。

#### BLD-002 补丁链对选定基线不可应用且无自动化

- **证据**
  - 对 `baseline/pjgowtham_sm8450-common` 执行 `git apply --check`：
    - HBM 补丁：`error: patch failed: init/init.oplus.rc:29`；
    - wise-light 补丁：`error: extract-files.sh: No such file or directory`、`proprietary-files.txt: patch does not apply`；
    - rear-ALS 补丁：`error: overlay/OPlusFrameworksResCommon/res/values/config.xml: patch does not apply`；
    - aux-camera 补丁：`error: extract-files.sh: No such file or directory`；
    - offline-charging：`patch does not apply`（因为 HEAD 已包含）。
  - 构建树 `device/oneplus/{ovaltine,sm8450-common}` 的 `proprietary-files.txt` 处于 `M`（未提交）状态；`repo sync` 会覆盖。
  - `patches/` 目录没有任何 `apply.sh`/`series`/`verify.sh`。
- **根因**：补丁从 lineage-ovaltine-dev 树导出，但最终 common 基线切换到 pjgowtham；两树的 `extract-files.sh`→`extract-files.py`、init/overlay 内容不同，补丁未重做。
- **影响**：已知修复（HBM/wise-light/ALS）实际未生效；每次同步后需要人工猜测哪些补丁已应用；不可复现、不可审计。
- **整改方案**
  1. 建立 `patches/series/` 与 `scripts/apply-patches.sh`：按树、按 commit、按顺序应用；先 `git apply --check`，再 `git apply`；失败即停。
  2. 对 pjgowtham 树重做 HBM/wise-light/rear-ALS 补丁，优先改 `extract-files.py` 与 overlay，而不是已不存在的 `extract-files.sh`。
  3. `scripts/verify-tree.sh` 输出每棵树的 `git diff --stat` 与关键行断言（HBM `chmod 0000`、`config_udfpsFrameworkDimming=true`、`config_displayLightSensorType`、sensors.ssc 字符串等）。
  4. 将补丁应用后的树 diff 作为构建输入的一部分归档；禁止手工修改构建树后直接编译。
- **验收标准**
  - `apply-patches.sh` 在干净 `repo sync` 树上幂等退出 0；
  - `verify-tree.sh` 全部断言通过；
  - 任一补丁无法应用时构建脚本立即失败；
  - 连续两次干净重建的补丁 diff 哈希一致。
- **状态**：待整改。

#### BLD-003 无完整 pinned manifest，基础 manifest 被手工修改

- **证据**
  - `local_manifests/ovaltine-lineage-22.1.xml` 只固定 6 个工程；官方 manifest 有 1319 个 `<project>`。
  - 基线 manifest revision `46ed254` 只记录在 `BUILD_LOG.md`，仓库内没有 full manifest 快照。
  - 构建树 `.repo/manifests/default.xml` 显示 `M`，为绕过网络阻断被 `sed` 改成 USTC 镜像。
  - `frameworks/base` 因 GitHub 502 被改为 `--depth=1` + 手工 worktree，不是标准 `repo sync` 结果。
- **根因**：网络受限下的临时处置没有沉淀为可复现脚本；local manifest 只负责 6 个项目，不负责全树。
- **影响**：换机器/换时间无法重现同一源码树；无法证明构建产物对应的完整源码版本；审计链断裂。
- **整改方案**
  1. 在可联网/镜像环境执行 `repo manifest -r -o manifests/lineage-22.1-<date>.xml`，提交完整 pinned manifest。
  2. 镜像覆盖使用 `.repo/local_manifests/mirror.xml` 的 `<remote fetch=...>`，不要 `sed` 官方 `default.xml`；或提交 `scripts/init-repo.sh` 统一处理。
  3. `frameworks/base` 使用完整 clone，或明确记录 shallow 深度与 commit；不得依赖手工 worktree。
  4. 构建前生成 `source-manifest.xml`、`repo forall -c 'git rev-parse HEAD'`、`git status --porcelain` 空检查。
- **验收标准**
  - 在全新目录用 `repo init -m manifests/lineage-22.1-<date>.xml` 可完整同步；
  - 所有工程 HEAD 与 manifest 一致；
  - 构建树 `git status` 在补丁应用后仅包含预期修改，且这些修改有对应 patch 文件；
  - 两次全新同步得到相同 commit 列表。
- **状态**：待整改。

#### ID-001 构建身份 CPH2417/Android 13 与目标 CPH2415/Android 15 不符

- **证据**
  - `baseline/android_device_oneplus_ovaltine/lineage_ovaltine.mk:22`：`PRODUCT_MODEL := CPH2417`。
  - 同文件 `:28`：`BuildFingerprint=OnePlus/CPH2417/OP5552L1:13/SKQ1.221119.001/...`。
  - 同文件 `:30-32`：`DeviceProduct=CPH2417`、`SystemName=CPH2417`。
  - `DEVICE_REPORT.md`：`ro.product.model=CPH2415`、`ro.build.fingerprint=OnePlus/CPH2415/OP5552L1:15/...`、安全补丁 2026-06-01。
- **根因**：设备树来自 CPH2417 时代，后续未按 CPH2415 EX01 重新锚定身份。
- **影响**：系统会把自己报告为另一机型、另一 Android 版本；影响 OTA 兼容性、Play Integrity、运营商/相机/音频等按 fingerprint 分支的逻辑；用户与审计都会误判设备状态。
- **整改方案**
  1. 明确产品定位：仅 CPH2415，还是 CPH2415/2417 多 variant；若单 variant，改 `PRODUCT_MODEL`/`DeviceProduct`/`SystemName` 为 CPH2415。
  2. `PRODUCT_BUILD_PROP_OVERRIDES` 使用 CPH2415 EX01 的真实 fingerprint，或按 Lineage 规范不伪造 stock fingerprint；如保留伪造，必须写明依赖它的 blob 与风险。
  3. 在 `device.mk` 增加构建期断言：`PRODUCT_MODEL`、`TARGET_OTA_ASSERT_DEVICE`、`board-info.txt` 与目标 variant 一致。
  4. 刷机后验证 `getprop ro.product.model`、`ro.product.device`、`ro.build.fingerprint`、`ro.build.version.security_patch`。
- **验收标准**
  - 构建产物 `ro.product.model=CPH2415`、`ro.product.name=CPH2415`、`ro.product.device=OP5552L1`（或项目明确规定的 variant 值）；
  - `ro.build.fingerprint` 与选定策略一致，且不在代码中残留 CPH2417/Android 13；
  - 设备 `getprop` 与 `DEVICE_REPORT` 身份字段一致；
  - OTA 安装脚本的 `assert` 通过。
- **状态**：待整改。

#### SEC-001 无内存/DSU 退出 SOP 与演练（原“回滚”项，按 DECISION-006 调整）

- **证据（审计时）**
  - `DEVICE_REPORT.md:164-169` 只写了“bootloader 已解锁、AVB orange、可刷机”，并提示 `fastboot flash vbmeta --disable-verity --disable-verification`，没有退出/备份流程。
  - 审计时全仓库无 `SOP.md`、无 `backup`/`persist`/`modemst`/`anti-rollback` 的可执行流程。
  - 业主原话：“必须将随时可以回到安卓系统作为前提、底线、红线。记录到文档中。”
- **2026-10-31 约束更新**：业主进一步要求**禁止真实刷入任何分区**，只允许内存启动/DSU。原“刷机+回滚”路径全部作废；本项改为“内存/DSU 进出演练”。
- **根因**：项目按“能刷入”推进；红线只停留在口头/背景。
- **影响**：DSU/内存测试若无法退出，会卡在测试系统；虽然不再有分区写入风险，但 userdata/DSU 状态仍需可恢复。
- **整改方案**
  1. `SOP.md` v2.0 已写入：只允许 `fastboot boot`/DSU；禁止 flash/sideload/`-w`/`dd`/EDL；退出方式为重启或 DSU 丢弃。
  2. 备份 userdata（DSU 会写 userdata）；记录 SHA256/介质。
  3. 记录 stock 状态：`fastboot getvar all`、`current-slot`、fingerprint、SPL、ARB。
  4. 演练 `fastboot boot` 进入/退出；演练 DSU 安装/启动/丢弃；记录 0 分区写入的证据（命令审计/操作日志）。
  5. 明确 anti-rollback：不得通过任何工具写入低版本固件。
  6. 文档写明：**禁止重新上锁**；上锁可能因自定义签名直接变砖。
- **验收标准**
  - 第二人按 SOP 可独立完成内存启动/DSU 进出；
  - 全程 0 分区写入（命令审计/日志）；
  - 退出后 stock `sys.boot_completed=1`、指纹/IMEI/基带/传感器正常；
  - 业主签字确认红线流程。
- **状态**：待整改（SOP v2.0 已编写，演练未执行）。

#### SEC-002 安全补丁严重过期

- **证据**
  - `baseline/pjgowtham_sm8450-common/BoardConfigCommon.mk:173-174`：`BOOT_SECURITY_PATCH := 2025-01-01`、`VENDOR_SECURITY_PATCH := $(BOOT_SECURITY_PATCH)`。
  - `BUILD_LOG.md:136`：Lineage 22.1 manifest 跟踪 `2025-04 ASB patching`；平台补丁级别停留在 2025-04。
  - `DEVICE_REPORT.md`：真机 `ro.build.version.security_patch=2026-06-01`。
  - 审计日期为 2026-10-31。
- **根因**：22.1 分支在 2025 年后基本停止维护；项目未建立 ASB 回移/内核 CVE 跟踪机制。
- **影响**：系统自带约 18 个月未修复的 Android 安全漏洞；与“安全、长期主义、Apple/Google 验收标准”直接冲突；Play Integrity/企业合规也可能不通过。
- **整改方案**
  1. 重新评估目标分支：优先选择仍在维护的分支（如 23.2），或明确承诺 22.1 + 自维护 ASB/CVE 回移。
  2. 建立 `SECURITY.md`/`ASB.md`：记录当前 SPL、目标 SPL、已回移 CVE、内核 CVE、验证方法。
  3. 将 `BOOT_SECURITY_PATCH`/`VENDOR_SECURITY_PATCH` 更新到与底包/实际修复一致，不得虚报。
  4. 每月检查 Android Security Bulletin、Qualcomm 公告、LineageOS ASB 合并；超过 90 天未更新即视为发布阻断。
  5. 对闭源 blob 做 CVE/版本核对（至少记录来源版本与已知漏洞）。
- **验收标准**
  - `getprop ro.build.version.security_patch` 与文档声明一致；
  - 发布前 SPL 不早于当前月往前 1 个月（或业主书面接受例外）；
  - ASB 回移清单、CVE 清单、验证日志齐全；
  - 安全门禁在 CI 中自动检查 SPL 最小值。
- **状态**：待整改。

#### TST-001 无任何测试执行与全绿门禁

- **证据**
  - 仓库无 `tests/`、无测试脚本、无测试报告；`git ls-files` 中没有任何 `.sh`/`.py` 测试脚本。
  - `HARDWARE_MATRIX.md` 状态全部为“一般/受限/未验证”，依据是源码/Release notes/兄弟硬件推断。
  - 无 `cts`/`vts`/`gts`/`play integrity` 结果；无 `getenforce`、无 `dmesg`、无 `logcat` 归档。
- **根因**：项目在“可构建性/基线评估”阶段即被宿主阻塞，测试阶段尚未开始；但文档没有把“未测试”提升为发布阻断。
- **影响**：无法证明任何硬件可用；无法区分“源码看起来有”与“设备上真的工作”；无法满足《约法》作业篇 3/4。
- **整改方案**
  1. 按 `TASK_PLAN.md` 的测试矩阵执行：构建测试 → 冒烟 → 硬件矩阵 → 压力/长稳 → 回归 → 全量 → 安全/OTA。
  2. 每个测试用例必须有 ID、前置条件、步骤、预期结果、实际结果、证据路径、判定。
  3. 任何 P0/P1 失败立即停止后续测试；修复后从受影响的最小测试集回归，再跑全量。
  4. 测试记录归档到 `tests/results/<date>/`，含命令、日志、截图、`getprop`、`dmesg`、`logcat`。
- **验收标准**
  - 测试矩阵 100% 执行，0 未执行、0 阻塞；
  - 所有用例“通过”或有业主签字的“风险接受”；
  - 全量测试在最终候选版本上再跑一遍且 100% 通过；
  - 测试证据可从仓库追溯到具体构建 SHA256。
- **状态**：待整改。

### 4.4 P1 严重级（26 项）

#### GOV-001 非 main 分支作业，main 落后

- **证据**：`git branch -vv` 显示当前 `bringup/ovaltine-lineage-22.1` @ `65d8be2`，`main` @ `6bb80a8`；`main` 是 HEAD 的祖先，落后 7 个提交。
- **影响**：违反《约法》Git 篇 1“禁止擅自新建和使用其它分支”；云端/默认分支看不到最新工作。
- **整改**：将 `main` fast-forward 到当前已验证的文档/补丁状态；后续只在 `main` 提交；`bringup` 分支保留为历史归档，经业主确认后删除。同步修订 `plan.md` 的分支策略。
- **验收**：`git branch --show-current` 为 `main`；`git log main..bringup/...` 为空；CI/发布只从 `main` 取。
- **状态**：待整改（本次审计收尾将 fast-forward `main` 并提交文档）。

#### GOV-002 工作区不干净

- **证据**：`git status --short --branch` 显示 `?? .venv/`、`?? scratch/`；根目录有 `.DS_Store`；`scratch/` 含 2.3 GB vendor 产物、68 MB Python。
- **影响**：违反《约法》Git 篇 2；误提交会污染仓库/泄露本地环境。
- **整改**：`.gitignore` 增加 `.venv/`、`scratch/`、`.DS_Store`、`*.log`；保留 `vendor_extract/`、`baseline/` 忽略；提交前 `git status --porcelain` 必须为空。
- **验收**：干净 clone 后执行 `git status` 无未跟踪文件；生成的 vendor/venv 不会进入版本库。
- **状态**：待整改（本次收尾处理）。

#### GOV-003 无 remote/tag/push

- **证据**：`git remote -v` 为空；`git tag -l` 为空；7 个提交只在本地。
- **影响**：违反《约法》Git 篇 3；机器损坏即丢失全部工作；无法协作/审计。
- **整改**：配置 GitHub/GitLab remote（业主提供地址与权限）；推送 `main`；打里程碑 tag（如 `audit-2026-10-31`）；后续每次里程碑推送。
- **验收**：`git remote -v` 有 origin；`git ls-remote origin` 可见 `main` 与 tag；本地与远端 SHA 一致。
- **状态**：待整改（需业主提供远端地址/凭证）。

#### GOV-004 关键交付物被 .gitignore 排除

- **证据**：`.gitignore:9` 忽略 `patches/optional-pjgowtham/`（但 `STATUS.md`/`BASELINE_EVALUATION.md` 引用该补丁）；`:10` 忽略 `probes/`（文档引用 `probes/*.json`）；`:3` 忽略 `vendor_extract/`（其中 `my_dumper.py` 是提取源码）。
- **影响**：clone 后交付物缺失，审计链断裂；`patches/optional` 被文档称为“可选采纳”却不存在于版本库。
- **整改**：取消忽略 `patches/optional-pjgowtham/`；提交公共 probe JSON 与 manifest 证据，设备扫描原始数据因隐私继续忽略并说明；将 `my_dumper.py` 移入 `tools/` 并提交（或提供等价脚本）；生成 `SHA256SUMS`。
- **验收**：`git ls-files` 包含可选补丁、公共探针 JSON、提取脚本；`probes/README.md` 说明哪些数据未入库及原因。
- **状态**：待整改（本次收尾处理可选补丁与公共探针）。

#### BLD-004 macOS 补丁全局禁用 Go 测试

- **证据**：`patches/macos-build/0002-blueprint-bootstrap-skip-go-tests-on-darwin.patch` 将 `test` 规则无条件改为 `touch $out`，没有 `darwin` 条件；注释声称“on darwin”，但规则对所有宿主生效。
- **影响**：若该补丁进入 Linux 构建链，会静默跳过 blueprint/soong 单元测试，降低构建系统可信度；若只用于 macOS，也与注释不符。
- **整改**：用 `HOST_OS=darwin` 条件或 `--skip-tests` 构建开关；Linux 构建保持完整测试；补丁使用 `git format-patch` 标准头（From/Subject/Change-Id），并附测试证据。
- **验收**：Linux 构建中 Go 测试实际执行并通过；macOS 仅在显式开关下跳过；补丁可被 `git am` 干净应用。
- **状态**：待整改。

#### BLD-005 `soong_ui.bash` `$T` unbound

- **证据**：`/Volumes/los-build/aosp/build/soong/soong_ui.bash:20` 在 `Darwin)` 分支使用 `$T`；脚本以 `#!/bin/bash -eu` 运行，`T` 未设置时直接退出。`brunch4.log` 首行即该错误。
- **影响**：macOS 构建无法进入 soong 分析；当前第 4 轮构建直接失败。
- **整改**：在脚本中 `T=${T:-$(gettop)}` 或使用 `gettop` 结果；将修复纳入 `patches/macos-build/` 并加测试；同时验证 Linux 不受影响。
- **验收**：macOS 下 `brunch` 越过 `soong_ui.bash` 且不再报 unbound；Linux 构建无回归。
- **状态**：待整改。

#### ID-002 common 树来自 10 Pro NE2213/Android 14，非 10T CPH2415

- **证据**：`baseline/pjgowtham_sm8450-common/proprietary-files.txt:1-2` 头注为 `OnePlus 10 Pro 5G (NE2213_14.0.0.920(EX01))`；`BASELINE_EVALUATION.md` 却以 `7a3b991 Update from NE2211_15.0.0.401(EX01)` 论证其“按 OOS 15 EX01 适配”。NE2211 是 10 Pro，不是 10T CPH2415。
- **影响**：common 的 blob 清单、音频/相机/显示配置面向 10 Pro；10T 的硬件差异（相机模组、充电、扬声器、传感器）可能不被覆盖；这是跨机型混用，不是“同代复用”。
- **整改**：重新做 common 选型：优先 10T 专用/同硬件兄弟树的 common；若必须用 10 Pro common，建立逐 blob/逐配置的 10T 差异清单，所有差异以 CPH2415 EX01 dump 为准，并在 `DRIVER_INVENTORY.md` 标注“共享/替换/禁用”。
- **验收**：common 清单头注与目标机型一致；每个 common blob 有 10T 实际文件校验；相机/音频/充电/传感器在真机通过；文档不再声称“同代即兼容”。
- **状态**：待整改。

#### ID-003 设备树 blob 锚点 OOS14 且混入 CPH2417/CPH2413

- **证据**：`baseline/android_device_oneplus_ovaltine/proprietary-files.txt:1-2` 声明 blobs 来自 `CPH2415_11.F.66`（OOS 14 代）；`:1377` 指纹来自 `CPH2417_11_C.46`；`:1443` WiFi 配置来自 `CPH2413_11.A.05`。`patches/ex01-adaptation/` 只改 5 处（4 个去 pin + 1 个 AIDL 路径）。
- **影响**：目标底包是 CPH2415 EX01（Android 15）；清单锚点与目标代差一代，且跨 variant 混用；虽然 extract-files 从 EX01 dump 抽到了文件，但没有版本/哈希证明这些文件就是正确版本。
- **整改**：以 CPH2415 EX01 dump 为唯一来源，重新生成/校对 `proprietary-files.txt`；删除 CPH2417/CPH2413 注释来源，改为实际路径与哈希；对每个 blob 记录来源分区、文件大小、SHA256；重新跑 extract-files 0 missing。
- **验收**：清单头注只声明 CPH2415 EX01；所有 blob 可追溯到 dump 路径与哈希；extract-files 0 missing；相机/指纹/WiFi 真机通过。
- **状态**：待整改。

#### ID-004 blob pin 覆盖不足

- **证据**：构建树应用 EX01 补丁后，`device/oneplus/ovaltine/proprietary-files.txt` 1415 条有效条目中仅 3 条有 `|sha1`；`device/oneplus/sm8450-common/proprietary-files.txt` 1265 条中 0 条有 pin。EX01 补丁还主动去掉 4 个 pin。
- **影响**：提取时几乎不校验文件内容；错误版本/被替换的 blob 不会被发现；供应链完整性不足。
- **整改**：至少对所有可校验 blob 使用 SHA256（若 extract-utils 仅支持 SHA1，则增加后处理校验脚本）；去 pin 必须附带原因、替代哈希与人工核对记录；生成 `blob-manifest.sha256`。
- **验收**：`verify-blobs.sh` 对 100% 条目校验通过；去 pin 条目有书面风险接受；CI 对哈希漂移失败。
- **状态**：待整改。

#### DRV-001 HBM 修复缺失，UDFPS 冲突

- **证据**：`baseline/pjgowtham_sm8450-common/init/init.oplus.rc:16` 仍是 `chown system system /sys/kernel/oplus_display/hbm`，没有 `chmod 0000`；`baseline/android_device_oneplus_ovaltine/overlay/OPlusSystemUIResTarget/res/values/config.xml:9` 已启用 `config_udfpsFrameworkDimming=true`。`patches/0001-sm8450-common-init-Deny-access-to-HBM-node.patch` 对 pjgowtham 树 `git apply --check` 失败。
- **影响**：厂商 fingerprint HAL 可在按压时写 HBM，与框架调光叠加，导致亮度闪烁、指纹识别不稳定或失败；这是 10T 已知问题。
- **整改**：在 pjgowtham `init.oplus.rc` 中移除 hbm 的 chown，追加 `chmod 0000 /sys/kernel/oplus_display/hbm`；保留 `notify_fppress` 等必要节点；在 `verify-tree.sh` 加断言；跑 100 次指纹解锁测试。
- **验收**：`grep -n "hbm" init.oplus.rc` 只显示 `chmod 0000`；`getprop`/`dmesg` 无 HBM 权限错误；100 次 UDFPS 解锁 0 失败；框架调光开启时亮度无闪烁。
- **状态**：待整改。

#### DRV-002 wise-light/rear-ALS 修复缺失

- **证据**：pjgowtham 树没有 `extract-files.sh`，`extract-files.py` 的 `blob_fixups` 不含 `sensors.ssc.so`；`scratch/vendor/.../sensors.ssc.so` 仍包含 `qti.sensor.wise_light`，没有替换为 `android.sensor.light`。pjgowtham overlay 中没有 `config_displayLightSensorType`，对照树 `baseline/android_device_oneplus_sm8450-common/overlay/OPlusFrameworksResCommon/res/values/config.xml:123` 有 `qti.sensor.light_rear`。
- **影响**：自动亮度可能使用屏下 wise light 而非后置 ALS，导致亮度跳变/偏暗；部分依赖标准 light sensor 类型的应用可能拿不到光感。
- **整改**：在 pjgowtham `extract-files.py` 中增加 `sensors.ssc.so` 的二进制替换（`qti.sensor.wise_light` → `android.sensor.light`）与 SIGSCAN；在 overlay 增加 `config_displayLightSensorType=qti.sensor.light_rear`（或按 10T 实测选择）；真机对比自动亮度曲线。
- **验收**：`strings sensors.ssc.so | grep android.sensor.light` 命中；`dumpsys sensorservice` 显示标准 light 类型；自动亮度在 10→1000 lux 变化下无跳变/可回滞；日志无 sensor 权限错误。
- **状态**：待整改。

#### DRV-003 导出补丁对选定树不可应用，文档误导

- **证据**：`BASELINE_EVALUATION.md:58-62` 声称 HBM/aux/wise-light/UDFPS/rear-ALS 均“已包含于 22.1 祖先/无需 cherry-pick”；但这些结论只在 `lineage-ovaltine-dev/android_device_oneplus_sm8450-common` 成立。最终 manifest 选的是 pjgowtham；实测 4 个补丁不可应用。
- **影响**：评审者会误以为修复已生效；实际 HBM/wise-light/ALS 缺失；补丁存档成为“装饰品”。
- **整改**：重写 `BASELINE_EVALUATION.md` 为“按最终选定树逐补丁验证矩阵”；每条补丁标注 `already-present / ported / not-applicable / pending`；删除“祖先即生效”的推断。
- **验收**：每个补丁在最终树上有 `git apply --check` 或等价断言结果；文档与 `verify-tree.sh` 一致；评审可复现。
- **状态**：待整改。

#### DRV-006 内核/模块/设备树版本错位

- **证据**：`BASELINE_EVALUATION.md`：kernel 22.1 HEAD `63aeb92d`（2025-05-01）、devicetrees `c05fa09e`（2024-08-27）、modules `cb014aff`（2023-07-11）。modules 比 kernel 主树早约 22 个月。
- **影响**：模块源码与内核 API/ABI 可能不匹配；`CONFIG_MODVERSIONS=y` 下符号 CRC 可能不一致；构建可能失败或运行时模块加载失败。
- **整改**：优先使用同一时间线/同一维护者的 kernel + devicetree + modules 三元组；若 modules 树陈旧，逐模块确认是否仍被 `TARGET_KERNEL_EXT_MODULES` 使用；建立 `kernel-triad.md` 记录 commit/日期/ABI；构建后 `modinfo` 检查 vermagic/CRC。
- **验收**：三仓库 commit 有明确配套依据；`brunch` 构建通过；`modprobe`/`insmod` 关键模块无 vermagic/CRC 错误；`dmesg` 无模块加载失败。
- **状态**：待整改。

#### SEC-003 AVB 使用公共 testkey 且关闭验证链

- **证据**：`baseline/pjgowtham_sm8450-common/BoardConfigCommon.mk:181-215`：所有 AVB key 指向 `external/avb/test/data/testkey_rsa4096.pem`；`:182` `--set_hashtree_disabled_flag`；`:183` `--flags 2`。
- **影响**：任何拿到公共 testkey 的人都能签出“通过校验”的镜像；hashtree/verification 关闭降低完整性保证；不适合发布/长期维护。
- **整改**：研发构建可继续用 testkey，但必须在文档标注“仅研发”；发布构建生成独立 RSA 4096 私钥，离线保存，CI 只拿公钥/签名机；评估是否保留 hashtree disabled（若保留，需业主书面风险接受）；`avbtool verify_image` 加入发布门禁。
- **验收**：发布镜像由发布 key 签名；`avbtool verify_image --key` 通过；私钥不在仓库/构建日志；风险接受记录（如保留 disabled）。
- **状态**：待整改。

#### SEC-004 SELinux enforcing/avc 未验证

- **证据**：无 `getenforce`、`dmesg | grep avc`、`audit2allow` 记录；`device/oneplus/ovaltine` 无 device-specific sepolicy 目录，仅继承 `device/qcom/sepolicy_vndr` 与 `hardware/oplus/sepolicy/qti`。
- **影响**：vendor blobs/新 HAL 可能触发 avc denial；若为通过测试而设 permissive，会掩盖问题并降低安全性。
- **整改**：刷机后默认 `Enforcing`；跑完整硬件矩阵时采集 `dmesg | grep avc`、`logcat` 中的 `avc: denied`；对每条 denial 评估是补策略还是修调用；禁止 `setenforce 0` 作为长期方案；将 avc 检查加入测试门禁。
- **验收**：`getenforce=Enforcing`；全量测试期间 0 未解释 avc denial；策略修改有 diff/说明；CTS SELinux 相关项通过。
- **状态**：待整改。

#### SEC-005 闭源 blob 法律/许可证/SBOM 未评估

- **证据**：`proprietary-files.txt` 列出 1415 + 1265 条闭源文件；无 `LICENSE`/`NOTICE`/第三方清单；无 blob 来源版本/许可证/SBOM。
- **影响**：再分发可能违反 OnePlus/Qualcomm/第三方许可；发布包可能缺少必要声明；企业/合规验收不通过。
- **整改**：建立 `DRIVER_INVENTORY.md` + `SBOM`（组件、版本、来源、许可证、是否可再分发）；默认不分发 blob，只提供提取脚本与本地构建说明；如分发 ROM，先取得法律意见；加入 `NOTICE`/`CREDITS`。
- **验收**：每个闭源 blob 有来源与许可证状态；发布包含 NOTICE/CREDITS；法务/业主书面确认；不分发未授权文件。
- **状态**：待整改。

#### TST-002 无测试计划与可判定验收标准

- **证据**：`HARDWARE_MATRIX.md` 只有“一般/受限/未验证”，没有测试步骤、预期值、判定标准；无测试用例 ID。
- **影响**：无法判断“通过”与否；不同人执行会得到不同结论；无法回归。
- **整改**：采用 `TASK_PLAN.md` 的测试矩阵；每个硬件项至少 1 个正向 + 1 个负向/边界用例；明确命令、预期输出、容差、证据。
- **验收**：测试计划覆盖所有硬件/系统功能；每个用例可独立执行；结果可判定；全量执行记录齐全。
- **状态**：待整改。

#### TST-003 无 CTS/VTS/Play Integrity/GSI/安全测试

- **证据**：仓库/日志无 CTS/VTS/GTS/Play Integrity/GSI 记录；无 `getenforce`、无 `avbtool` 验证记录。
- **影响**：无法证明框架/供应商接口兼容性；无法满足“大厂验收标准”；可能无法通过企业/银行/流媒体应用的环境检查。
- **整改**：在 Linux 构建机跑 CTS/VTS（至少 `cts-tradefed` 关键模块 + `vts` HAL 检查）；记录失败项与豁免；GSI 启动测试；Play Integrity 基本检查（设备未认证属预期，需记录）；安全基线检查。
- **验收**：CTS/VTS 关键套件通过率 100%（或豁免经业主批准）；GSI 可启动；安全基线检查通过；报告归档。
- **状态**：待整改。

#### TST-004 无 OTA A/B 更新与回滚测试

- **证据**：`AB_OTA_PARTITIONS`/`update_engine` 配置存在，但无 OTA 生成/安装/回滚测试记录；无 `ota_from_target_files` 产物。
- **影响**：A/B 设备的核心能力未验证；一次失败 OTA 可能导致无法启动；与“随时回安卓”红线相关。
- **整改**：生成 signed OTA；在测试机执行 `adb sideload`/`update_engine` 两次（A→B→A）；验证槽位切换、回滚、userdata 保留、失败恢复；记录 `update_engine` 日志。
- **验收**：OTA 安装成功；重启后 `sys.boot_completed=1`；槽位正确；失败注入后可回滚；数据不丢；日志齐全。
- **状态**：待整改。

#### DOC-001 STATUS/BUILD_LOG/DECISION-003 事实矛盾

- **证据**
  - `STATUS.md:44-48` 写“未执行 repo sync”“brunch 同上”；但 `BUILD_LOG.md:168-202` 记录 245 GB 同步与 4 轮 brunch。
  - `BUILD_LOG.md:284` 写“未进入 repo sync / brunch 阶段”，与前文直接矛盾。
  - `DECISIONS.md` DECISION-003 写“不执行 repo sync，不进行 brunch”，但实际已执行；没有 DECISION-005 记录后续事实。
- **影响**：审计/接手者会得到错误状态；违反“实时记录、禁止事后补写”；无法判断哪些结论仍有效。
- **整改**：以事实为准重写 `STATUS.md`：构建目标、已执行动作、失败点、产物、下一步；追加 DECISION-005 记录“DECISION-003 的事实前提已失效，构建尝试失败，主构建路径改为 Linux”；保留历史但标注 superseded。
- **验收**：STATUS/BUILD_LOG/DECISIONS 对同一事实的描述一致；每条决策有日期/证据/状态；读者 5 分钟内能判断当前状态。
- **状态**：待整改。

#### DOC-002 HARDWARE_MATRIX 信息过期

- **证据**：`HARDWARE_MATRIX.md:5` 声明“无真机实测”，但 `DEVICE_REPORT.md` 已有真机扫描；`:29` 写 vendor blobs“待提取核验”，但 `STATUS.md` 与 `BUILD_LOG.md` 记录提取已完成（0 missing，1414 + 1265 blobs）；`:14/:18` 声称 HBM/wise-light 在“22.1 祖先链”，对最终选定树不成立。
- **影响**：矩阵不能作为决策依据；状态“一般”无法区分“已验证”“推断”“已知缺陷”。
- **整改**：重建矩阵：每项加“证据等级（E1-E4）”“测试 ID”“驱动来源/许可证”“已知缺陷”“阻塞项”；把“待提取”改为实际结果；把“祖先链”改为“最终树是否生效”；明确“真机扫描 ≠ 功能实测”。
- **验收**：矩阵每一行可追溯到测试/源码证据；无“待提取/未验证”与实际状态矛盾；状态值有定义。
- **状态**：待整改。

#### DOC-003 BASELINE_EVALUATION 补丁祖先结论误导

- **证据**：`BASELINE_EVALUATION.md:53-63` 用 `git merge-base --is-ancestor` 在 lineage-ovaltine-dev 树验证补丁，但最终 manifest 用 pjgowtham common；结论“无需 cherry-pick”不适用于最终树。
- **影响**：把“在另一个仓库的分支上是祖先”误当成“在最终构建中已生效”；导致 HBM/wise-light/ALS 缺失未被发现。
- **整改**：把评估对象改为“最终 manifest 的 6 个工程”；每条补丁在每个工程上做 `git apply --check`/代码断言；明确 `not-applicable` 与 `already-present` 的区别。
- **验收**：评估报告与最终树一致；每条补丁有可复现命令与结果；无“祖先”推断。
- **状态**：待整改。

#### DOC-005 缺 SOP/硬件清单/驱动清单

- **证据**：仓库只有状态矩阵，没有可执行的构建/刷机/回滚 SOP；没有硬件 BOM；没有驱动来源/许可证/版本清单。业主第 7 项明确要求。
- **影响**：不可交接、不可复现、不可审计；违反《约法》治理篇与业主明确要求。
- **整改**：本次新增 `SOP.md`、`HARDWARE_INVENTORY.md`、`DRIVER_INVENTORY.md` 草案；后续按测试结果升级为 v1.0；所有文档加版本/日期/证据等级。
- **验收**：三份文档覆盖业主第 7 项；第二人可按 SOP 独立完成构建/刷机/回滚；硬件/驱动清单与真机一致。
- **状态**：本次补齐草案；运行时验证待整改。

#### ARCH-001 22.1 已停止维护，与“安全/长期主义”冲突

- **证据**：DECISION-001/004 选择 22.1；探针显示 90 天窗口 0 提交，22.1 平台 ASB 停在 2025-04；设备底包 SPL 2026-06。
- **影响**：选择“成熟”版本的同时锁定了安全债；后续每个月都在扩大 CVE 暴露面；与业主“安全、非激进、长期主义”目标冲突。
- **整改**：做一次显式决策：A) 维持 22.1，但建立 ASB/CVE 回移与月度发布；B) 迁移到仍在维护的分支（23.2），接受更大 bring-up 成本；C) 双轨：22.1 维护 + 23.2 预研。记录收益/成本/风险，业主签字。
- **验收**：决策记录含备选、证据、成本、风险；有 12 个月维护计划；SPL 更新 SLA 可执行。
- **状态**：待整改（需业主决策）。

#### ARCH-002 10T 设备树 + 10 Pro common 的变体边界不清

- **证据**：设备树 `ovaltine` 面向 10T；common 来自 10 Pro NE2213；两者通过 `device.mk` 继承组合；没有 variant/overlay 分层文档。
- **影响**：任何 common 修改都可能同时影响 10 Pro/10T；无法判断某个 blob/配置属于哪个硬件；回归范围不可控。
- **整改**：定义 `device/oneplus/ovaltine`（10T 专属）与 `sm8450-common`（平台共享）的边界；列出“共享/覆盖/禁用”清单；common 修改必须跑 10T 全量测试；必要时建立 10T 专用 common fork。
- **验收**：每个 common 配置有归属说明；10T 全量测试通过；common 变更的回归影响可评估。
- **状态**：待整改。

#### LEG-001 无 LICENSE/NOTICE/SPDX/署名清单

- **证据**：根目录无 `LICENSE`、`NOTICE`、`CREDITS`；源码头有 Apache-2.0/GPL-2.0，但没有项目级声明；无第三方组件清单。
- **影响**：再分发/协作的法律基础不清；上游作者署名不完整；企业验收不通过。
- **整改**：确定项目许可证（建议 Apache-2.0，与 Lineage/AOSP 设备树一致；内核为 GPL-2.0）；添加 `LICENSE`、`NOTICE`、`CREDITS`；SPDX 扫描（`reuse lint` 或 `scancode`）；保留补丁作者信息。
- **验收**：根目录有 LICENSE/NOTICE/CREDITS；SPDX 扫描通过或有豁免清单；所有上游补丁作者被署名。
- **状态**：待整改。

### 4.5 P2 中等级（27 项）

| ID | 问题与证据 | 整改方案 | 验收标准 |
|---|---|---|---|
| GOV-005 | 无 README/SECURITY/CONTRIBUTING/文档索引；新接手者不知道从哪读 | 新增 `README.md` 作为入口；加 `SECURITY.md`（漏洞报告/安全门禁）、`CONTRIBUTING.md`（分支/提交/测试规范） | 根目录有入口文档；5 分钟内可找到构建/刷机/回滚/测试说明 |
| GOV-006 | 仓库无任何版本化 `.sh/.py/.yml` 脚本；构建/刷机/测试全靠手工/外部路径 | 新增 `scripts/{init-repo,sync,apply-patches,verify-tree,build,collect-artifacts,flash,test}.sh` 与 CI | 干净机器按脚本可复现；CI 至少跑静态检查+构建 |
| GOV-007 | 无 release/tag/版本号/OTA 通道；`LINEAGE_VERSION` 只是日期串 | 定义版本 `22.1-YYYYMMDD-ovaltine`；打 tag；生成 signed OTA；记录 release notes | 每个发布有 tag、OTA、SHA256、release notes |
| GOV-008 | 无评审/issue/PR/变更记录流程 | 启用 GitHub Issues/PR 模板；每个变更关联发现 ID/测试 ID；变更记录进 CHANGELOG | 每个提交可追溯到任务/测试；PR 有评审记录 |
| BLD-006 | `vendor/lineage/build/envsetup.sh:720-721` 使用 GNU `date -d`、`stat -c`，macOS 报错 | 用 `gdate`/`gstat` 或 portable wrapper；或在 mac 环境安装 coreutils 并加 PATH（已有，但脚本未兜底） | macOS 下 `brunch` 无 date/stat 报错；Linux 无回归 |
| BLD-007 | 16 GB Intel Mac 构建 3:53 被杀；无 `-j` 限制/内存监控 | 主构建迁 Linux 32 GB+；临时 mac 构建用 `-j6`、`GOMEMLIMIT`、监控 RSS、预生成 swap；记录峰值内存 | 构建完成且峰值内存有记录；无 OOM/被杀 |
| BLD-008 | 构建日志在 `/Volumes/los-build`，无产物 SHA256/build-info | 归档 `build.log`、`build-info.txt`、`SHA256SUMS` 到版本库/制品库 | 任意产物可追溯到 commit/manifest/工具链/日志 |
| BLD-009 | `sync_loop.sh` 在仓库外；429 固定 60s 重试 40 次，无 jitter/指数退避 | 移入 `scripts/sync.sh`；指数退避+随机抖动；区分 429/5xx/认证失败；限制并发 | 429 下不雪崩；失败可诊断；脚本可复现 |
| BLD-010 | 工具链版本散落在 BUILD_LOG，未锁定 | 记录并锁定：Ubuntu 版本、JDK 17、repo 2.71、clang、Python 3.12、erofs-utils 1.9.4、7zz 26.05、payload_dumper 0.2.2；提供 `tool-versions.txt` | 新机器按清单可复现；版本漂移有告警 |
| ID-005 | `BOARD_USERDATAIMAGE_PARTITION_SIZE := 112362319872`（约 104.6 GiB），设备为 256 GB（`DEVICE_REPORT` userdata 224 GB） | 按实际分区/产品容量设置，或明确只用于生成镜像、刷机用 `fastboot -w`；验证 128/256 GB variant | `userdata` 配置与设备容量策略一致；`fastboot -w` 后容量正确 |
| ID-006 | `device/oneplus/ovaltine/BoardConfig.mk:19` 定义 `BOARD_ONEPLUS_DYNAMIC_PARTITIONS_SIZE := 5637144572`，但全构建树无任何引用 | 删除死变量，或改为正确的 `BOARD_QTI_DYNAMIC_PARTITIONS_SIZE`/group size；加配置断言 | `rg` 无死变量；动态分区实际尺寸与 `super` 匹配 |
| ID-007 | `odm.prop:29` `ro.vendor.oplus.radio.sar_regionmark=FCC`（全球/EU 设备）；`product.prop:9` `ro.opa.device_model_id=...os121...`（OOS12）；`odm.prop:32` `ro.build.version.svn=82` | 按 CPH2415 区域设置 SAR（CE/FCC/自动）；更新/删除过期 GMS/SVN 属性；逐项验证 | `getprop` 与区域/版本一致；SAR 测试/认证记录；无过期 OOS12 标识 |
| ID-008 | `DEVICE_REPORT` 说主板 `OP5552L1`；`BUILD_LOG.md:101` 说 `OP5555L1` | 以 `ro.product.device`/`ro.boot.project_name` 实测为准，统一文档；加 `getprop` 证据 | 文档/构建/真机三处一致 |
| DRV-004 | aux camera 修复实际在 `device/.../extract-files.py:47-48`，但 `patches/0001-sm8450-common-Unlock-aux-cameras.patch` 针对 `extract-files.sh`，不可应用 | 文档改为“由 device extract-files.py 实现”；保留补丁为历史参考；加测试（6 个 camera ID、第三方相机） | 文档与实现一致；6 相机 ID 可见；第三方相机可访问 aux |
| DRV-005 | pjgowtham HEAD 已含 offline-charging（`init.target.rc:127` `ro.boot.startupmode=usb_charger`），导出的 patch 冗余且不可应用 | 从“待应用”清单移除；文档标注 `already-present`；保留 patch 作为来源证据 | 文档无“需应用”误导；关机充电测试通过 |
| DRV-007 | “底包预编译 vendor_dlkm 回退”未落地；EX01 dump 模块 vermagic 为 `5.10.236-gki-g3a16d49f0607`，与 boot 内核 `5.10.236-android12-9-o-g55571f3ffcfa` 不同；若直接使用会加载失败 | 明确 vendor_dlkm 来源：全部源码构建，或建立匹配的预编译模块清单；若回退，先做 vermagic/CRC 兼容验证；不要在生产中使用未知模块 | `modinfo`/`insmod` 关键模块通过；`dmesg` 无 vermagic 错误；回退方案有验证记录 |
| DRV-008 | `HARDWARE_MATRIX` 无驱动版本/许可证/开源闭源/测试 ID；状态“一般”不可判定 | 用 `DRIVER_INVENTORY.md` 补全；每项映射测试 ID；状态改为“通过/失败/阻塞/未测” | 每个硬件项有驱动来源、许可证、测试 ID、证据 |
| SEC-006 | user 构建仍带 `persist.dbg.volte_avail_ovr=1`、`persist.dbg.vt_avail_ovr=1`、`persist.dbg.wfc_avail_ovr=1`、`debug.sf.*`、`persist.vendor.sensors.debug.hal=0` | 将调试/强制属性限定到 `userdebug` 或删除；`user` 构建用脚本断言禁止 `persist.dbg.*`/`debug.*` | `user` 构建 `getprop` 无强制 IMS/debug 属性；IMS 测试真实通过 |
| SEC-007 | `DEVICE_REPORT.md:3` 曾含序列号后段；`§4` 曾含 display uniqueId；已于 2026-10-31 脱敏并重写历史 | 文档脱敏；原始证据保留本地并限制访问；提交前扫描 `serial|imei|iccid|uniqueId|mac` | 公共文档无设备唯一标识；原始证据有访问控制 |
| SEC-008 | `config.fs` 对 `bt_firmware/`、`dsp/`、`firmware/`、`persist/` 用 0771；`loc_launcher` 有 SETUID/SETGID；多处重复 `system/vendor` 与 `vendor` 条目 | 逐项最小权限复核；确认 A15 路径语义；删除重复/无效条目；保留必要的 vendor AID | `fs_config` 生成无冲突；权限审计通过；无多余 SETUID/SETGID |
| SEC-009 | `BOARD_AVB_VBMETA_VENDOR := vendor vendor_dlkm` 未包含 `odm`；`BOARD_AVB_*_ROLLBACK_INDEX` 用 `PLATFORM_SECURITY_PATCH_TIMESTAMP` | 解析 stock `vbmeta_vendor` 确认 odm 是否在链上；若不在，评估加入；定义 rollback index 策略，避免 SPL 回退 | `avbtool info_image` 显示预期分区；AVB 验证通过；rollback 策略有文档 |
| TST-005 | 无性能/热/续航/充电测试 | 加入：冷启动/热启动时间、应用启动、帧率/jank、GPU、存储、充电功率/曲线、待机功耗、热区温度 | 每项有阈值与实测；不达标有分析/整改 |
| TST-006 | 无相机/音频/传感器/电话/WiFi/BT 矩阵 | 相机 6 ID/RAW/4K/微距/aux；音频扬声器/麦克风/USB-C/通话/编解码；传感器全部类型；VoLTE/5G SA/NSA/双卡；WiFi 2.4/5/6E；BT 音频/LE | 每项有测试用例和通过标准；失败有日志 |
| TST-007 | 无压力/长稳测试 | 72h 重启/待机；1000 次相机开关；10k 次指纹；24h 5G/WiFi；4K 录制 1h；充电循环；温度监控 | 无崩溃/重启/数据丢失；温度/功耗在阈值内 |
| TST-008 | 无干净重建/哈希复现测试 | 两次 `repo sync` + 两次 `brunch`，比较产物 SHA256/差异；记录非确定性来源 | 产物哈希一致或差异可解释；复现报告归档 |
| DOC-004 | `plan.md` 面向 Agent、frontmatter 只有开头 `---`、Git 分支策略与《约法》冲突、目标写 22.2 与 DECISION-001 的 22.1 不一致 | 归档为历史；以 `TASK_PLAN.md` 为唯一任务书；修订分支策略为 main-only；目标以 DECISION-001 为准 | 仓库只有一个有效任务书；分支策略与《约法》一致；目标版本无歧义 |
| DOC-006 | 无需求—任务—测试—证据追溯矩阵 | 在 `TASK_PLAN.md` 加追溯表：业主条款 → 任务 → 测试 → 证据 → 状态 | 每条业主要求可追到任务/测试/证据 |
| DOC-007 | 无 release notes/changelog/known issues/维护计划 | 新增 `CHANGELOG.md`、`KNOWN_ISSUES.md`、`MAINTENANCE.md`；每次发布更新 | 发布包含变更/已知问题/维护窗口/回滚说明 |
| ARCH-003 | 无按子系统的开源/闭源降级与回退方案 | 在 `DRIVER_INVENTORY.md` 为每项写：首选开源、次选兄弟开源、再次闭源 blob、回退方案、风险 | 每项有 fallback；关键项至少两个来源 |
| ARCH-004 | 无 OTA/签名/密钥管理架构 | 设计：构建机 → 签名机 → OTA 服务器/本地包 → 设备；密钥离线；发布清单 | 签名/OTA 流程可演练；私钥不落仓库 |
| ARCH-005 | 无上游跟踪/ASB SLA/长期维护计划 | 建立月度上游扫描、ASB 合并、设备树 rebase、依赖升级；记录 SLA | 每月有记录；超过 SLA 自动告警 |
| LEG-002 | 无 “unofficial” 商标声明/第三方署名 | README/SOP 加“非官方、与 OnePlus/LineageOS 无隶属关系”；`CREDITS.md` 列作者/上游 | 发布包含声明；无商标误用 |

### 4.6 P3 改进级（8 项）

| ID | 问题 | 整改 | 验收 |
|---|---|---|---|
| DOC-008 | 补丁文件名重复 `0001-*`，排序/检索困难；中英文术语混用 | 采用 `NNNN-subsystem-description.patch`；统一术语表 | 补丁按编号排序无歧义；术语表存在 |
| GOV-009 | 无 `.editorconfig`/Markdown lint/提交模板 | 添加配置与模板；CI 跑 markdownlint/shellcheck | 提交格式一致；lint 通过 |
| GOV-010 | 无 CHANGELOG/issue 模板 | 添加模板 | 新 issue/PR 有固定字段 |
| BLD-011 | 日志含 `/Volumes/los-build` 等本地绝对路径 | 用相对路径/变量；日志归档时脱敏 | 日志可迁移；无个人路径 |
| DOC-009 | 文档时间/版本/作者/状态字段不统一 | 统一 frontmatter | 每份文档有 version/date/status/owner |
| DOC-010 | 缺少术语表/缩写表 | 增加 GLOSSARY | 新成员可理解 UDFPS/AVB/ASB 等 |
| DOC-011 | 图片/截图/原始数据无索引 | 建立 evidence index | 每个证据有路径/哈希/说明 |
| DOC-012 | 目录结构扁平，文档与产物混放 | 规划 `docs/`、`scripts/`、`tests/`、`artifacts/`（保持兼容链接） | 结构清晰；旧链接不失效 |

### 4.7 风险登记册（待验证，不能当作已通过）

| 风险 | 概率 | 影响 | 触发条件 | 验证/缓解 |
|---|---|---|---|---|
| CPH2415 与 CPH2417/NE2213 的相机/音频/充电 blob 不兼容 | 高 | 高 | 刷入后相机/扬声器/充电异常 | 逐 blob 对照 + 真机矩阵；准备回退 |
| `super`/`userdata` 分区尺寸与 BoardConfig 不符 | 中 | 高（刷机失败/变砖） | `fastboot flash super` 或 `fastboot -w` 失败 | 设备 `blockdev --getsize64` 实测；对比 OTA/分区表 |
| 内核/模块 ABI 不匹配 | 中 | 高（无法启动/模块加载失败） | `modprobe`/`insmod` 报 vermagic/CRC | 三仓库对齐；构建后 `modinfo`；`dmesg` |
| Mac 补丁在 Linux 上产生隐性行为 | 中 | 中 | Linux 构建异常/测试被跳过 | 补丁按 OS 隔离；Linux CI |
| AVB 关闭验证导致安全/OTA 兼容问题 | 中 | 高 | 系统更新/Play Integrity/企业策略 | 发布 key；验证链策略；风险接受 |
| 22.1 安全债继续扩大 | 高 | 高 | 每月新 CVE | 分支重评/ASB 回移 |
| 闭源 blob 法律风险 | 中 | 高 | 公开发布 ROM | 法务评估；不分发 blob |
| UDFPS HBM 冲突导致指纹不可用 | 高 | 中 | 按压指纹闪烁/失败 | 端口 HBM 补丁；100 次测试 |
| 自动亮度使用错误传感器 | 高 | 中 | 亮度跳变/偏暗 | wise-light/rear-ALS 端口；亮度曲线测试 |
| 无回滚路径导致设备不可恢复 | 中 | 极高 | 刷机失败/ARB 触发 | SOP + 备份 + 演练；未演练禁止刷机 |

### 4.8 已核验通过项（正向控制）

这些不是“已验收”，而是审计中确认“没有明显错误/已有基础”的项，避免报告只呈现负面：

1. **官方 manifest 无路径冲突**：`probes/lineage221_default.xml` 中不存在 `device/oneplus/*` 或 `hardware/oplus` 工程，6 个本地工程不会与官方 manifest 冲突。
2. **6 个工程均按完整 40 位 commit 固定**：`local_manifests/ovaltine-lineage-22.1.xml` 的 revision 均为完整 SHA-1，不是浮动分支。
3. **vendor 提取有逐操作 SHA256**：`vendor_extract/my_dumper.py` 对每个 REPLACE op 校验 `data_sha256_hash`；提取日志记录 0 missing。
4. **aux camera 修复实际生效**：`scratch/vendor/oneplus/ovaltine/proprietary/odm/etc/camera/CameraHWConfiguration.config:816` 为 `SystemCamera = 0; 0; 0; 0; 0; 0;`。
5. **offline charging 已在 pjgowtham HEAD**：`init.target.rc:127` 使用 `ro.boot.startupmode=usb_charger`，与 `258dbbd` 一致。
6. **Pixelworks 删除项与 EX01 实际文件一致**：EX01 dump 中不存在 patch 注释掉的服务/rc/vintf/`libpwiris*` 特定库；保留的 `libpwirisfeature`/`libpwirishalwrapper`/`snapdragoncolor` 仍在。
7. **hardware/oplus 上游具备关键模块**：构建树中存在 `libudfps_extension.oplus`、`vendor.lineage.touch@1.0-service.oplus`、fingerprint 2.3 service、livedisplay、osense、vibrator、sensors 等模块定义。
8. **内核配置文件存在**：`kernel/oneplus/sm8450/arch/arm64/configs/vendor/oplus/ovaltine.config` 存在；`TARGET_KERNEL_EXT_MODULES` 的目录均存在。
9. **设备树 UDFPS overlay 已启用**：`config_udfpsFrameworkDimming=true`、UDFPS sensor props 存在。
10. **真机底包三重一致**：`DEVICE_REPORT` 的 kernel/baseband/fingerprint 与 OTA metadata 一致；bootloader 已解锁（`ro.boot.flash.locked=0`、`verifiedbootstate=orange`）。

---

## 5. 整改路线图

### 5.1 阶段与门禁

| 阶段 | 目标 | 关键任务 | 门禁 |
|---|---|---|---|
| G0 治理冻结 | 仓库可审计、可交接 | main-only、remote/push、.gitignore、README、证据入库、STATUS 纠正 | `git status` 干净；远端可见；证据齐全 |
| G1 构建可复现 | 在 Linux 上产出完整镜像 | full manifest、补丁自动化、工具链锁定、Linux 构建、产物 SHA256 | `brunch` 退出 0；产物齐全；两次重建一致 |
| G2 可启动 | 刷入后能进系统 | 回滚 SOP/备份演练、boot/recovery/vbmeta 验证、首次启动、logcat/dmesg | `sys.boot_completed=1`；无 bootloop；可回 stock |
| G3 硬件矩阵 | 所有硬件有实测结论 | HBM/wise-light/ALS 端口、相机/音频/传感器/充电/网络测试 | 矩阵 100% 有状态；P0/P1 关闭 |
| G4 全量测试 | 冒烟/压力/回归/全量全绿 | 测试矩阵、CTS/VTS、OTA、安全、性能 | 100% 通过；0 P0/P1；证据归档 |
| G5 发布 | 可发布、可维护 | 发布 key、signed OTA、release notes、维护计划 | 签名/OTA 验证；文档完整；业主签字 |

### 5.2 优先级顺序（不可跳步）

1. **先做 G0**：没有干净仓库和可追溯证据，后面所有结论都不可信。
2. **再做 G1**：没有镜像，硬件讨论都是空谈。
3. **G2 之前必须完成 SEC-001**：回滚 SOP + 备份 + 演练；否则禁止刷机。
4. **G3 先修 DRV-001/002/003**：HBM、wise-light/ALS、补丁链是 10T 的核心已知问题。
5. **G3 同时做 ID-001/002/003/004**：身份/变体/blob 溯源；否则硬件测试结果不可归因。
6. **G4 再谈性能/体验/CTS**；不要在未启动的系统上做优化。
7. **G5 最后做签名/OTA/发布**；不要用 testkey 发布。

### 5.3 建议工作量（粗略）

| 工作包 | 估计 | 依赖 |
|---|---|---|
| G0 治理 | 0.5–1 天 | 业主提供 remote |
| G1 Linux 构建 | 2–5 天 | Linux 主机、网络/镜像、250 GB+ |
| 补丁/身份/blob 修正 | 3–7 天 | G1 源码树 |
| G2 回滚/首启 | 1–3 天 | G1 镜像、备份 |
| G3 硬件矩阵 | 5–10 天 | G2、真机 |
| G4 全量测试 | 5–10 天 | G3、测试工具 |
| G5 发布 | 2–4 天 | G4、签名机 |

> 以上为工程估算，不含法务/云资源审批/硬件返修。

---

## 6. 验收标准（Apple/Google 级）

### 6.1 构建与可复现性

- [ ] 固定 commit + 固定完整 manifest + 固定工具链，在干净 Linux 主机上 `brunch` 退出 0。
- [ ] 产物清单完整，逐项 SHA256；OTA zip `unzip -t` 通过。
- [ ] 两次干净重建产物哈希一致，或差异有可解释的 non-determinism 报告。
- [ ] 构建日志、`build-info.txt`、`source-manifest.xml`、`tool-versions.txt` 归档。
- [ ] 构建失败时 CI 失败；不允许“手工改树后继续”。

### 6.2 安全

- [ ] 发布镜像使用独立发布 key 签名；私钥离线；`avbtool verify_image` 通过。
- [ ] `ro.build.version.security_patch` 不早于当前月往前 1 个月（或业主书面例外）。
- [ ] SELinux `Enforcing`；全量测试 0 未解释 avc denial。
- [ ] 关闭/移除 user 构建中的 `persist.dbg.*`、`debug.*` 强制属性。
- [ ] 无设备序列号/IMEI/MAC 等个人数据进入公共文档。
- [ ] 闭源 blob 有来源、许可证、SBOM；不分发未授权文件。
- [ ] 回滚 SOP 演练通过；关键分区备份可恢复。

### 6.3 功能与硬件

- [ ] 13 项硬件矩阵全部有 E4 实测结果；无“未验证”项。
- [ ] UDFPS 100 次解锁 0 失败；亮度无闪烁。
- [ ] 6 个 camera ID 可用；主摄/超广角/微距/RAW/4K 通过。
- [ ] 扬声器/麦克风/USB-C 音频/通话通过。
- [ ] 传感器全部类型上报；自动亮度曲线通过。
- [ ] WiFi 2.4/5/6E、BT 音频/LE、NFC/eSE、GPS、USB、振动、充电通过。
- [ ] 双卡/5G/VoLTE 按目标能力通过（若硬件/运营商支持）。
- [ ] 72h 长稳、1000 次相机、10k 次指纹、24h 网络、1h 4K 录制无崩溃/重启/数据丢失。

### 6.4 质量与体验

- [ ] 冷启动/热启动、应用启动、帧率/jank、GPU、存储达到设定阈值。
- [ ] 充电功率/曲线、待机功耗、热区温度达到设定阈值。
- [ ] 设置/相机/电话/音频等关键 UI 无 crash/ANR；无障碍/本地化抽检通过。
- [ ] 用户可感知的“舒适度”指标（亮度、振动、触控、音质、发热）有量化/主观评分记录。

### 6.5 发布与维护

- [ ] Signed OTA 可安装、可回滚、A/B 槽位正确、userdata 保留。
- [ ] Release notes/CHANGELOG/KNOWN_ISSUES/维护计划齐全。
- [ ] 上游跟踪/ASB SLA/月度维护有记录。
- [ ] 业主签字确认“非官方、风险自担、可回滚”。

### 6.6 Definition of Done

一个任务只有同时满足以下条件才算“完成”：

1. 需求/验收标准明确（本文件 + `TASK_PLAN.md`）。
2. 实现/变更已提交到 `main`，有 commit hash。
3. 构建 100% 全绿（或文档任务不影响构建）。
4. 相关测试执行并全绿，证据归档。
5. 文档/状态回填（STATUS/矩阵/决策/变更记录）。
6. 无 P0/P1 未关闭；P2 有整改计划或风险接受。

---

## 7. 证据索引

### 7.1 命令与结果（可复现）

| 证据 | 命令 | 结果摘要 |
|---|---|---|
| 分支/工作区 | `git status --short --branch` | `## bringup/ovaltine-lineage-22.1`；`?? .venv/`、`?? scratch/` |
| 分支关系 | `git branch -vv` | `main` @ `6bb80a8`，落后 7 个提交 |
| remote/tag | `git remote -v; git tag -l` | 均为空 |
| 构建产物 | `ls /Volumes/los-build/aosp/out/target/product/ovaltine` | 目录不存在 |
| 构建失败 | `brunch{,2,3,4}.log` | SDK 26.5 不支持；`$T` unbound；3:53 被终止 |
| 补丁可应用性 | `git apply --check <patch>` | HBM/wise-light/rear-ALS/aux 失败；offline 已包含 |
| blob pin | `grep -c '^[^#-].*|' ...` | device 3/1415；common 0/1265 |
| HBM | `grep -n hbm init.oplus.rc` | 仅 `chown system system .../hbm` |
| wise-light | `strings sensors.ssc.so \| grep wise_light` | 仍为 `qti.sensor.wise_light` |
| 身份 | `grep -n PRODUCT_MODEL lineage_ovaltine.mk` | `CPH2417` |
| 安全补丁 | `grep -n SECURITY_PATCH BoardConfigCommon.mk` | `2025-01-01` |
| 设备扫描 | `adb devices` | 审计时无设备连接；设备报告为历史证据 |
| 官方 manifest | `grep -n device/oneplus probes/lineage221_default.xml` | 无冲突 |
| 模块存在性 | `rg -l 'name: "..."' device hardware vendor` | 关键 HAL 模块均存在 |

### 7.2 文件索引

| 主题 | 文件 |
|---|---|
| 设备身份 | `baseline/android_device_oneplus_ovaltine/lineage_ovaltine.mk` |
| 分区/AVB/内核 | `baseline/pjgowtham_sm8450-common/BoardConfigCommon.mk` |
| 设备分区覆盖 | `baseline/android_device_oneplus_ovaltine/BoardConfig.mk` |
| init/HBM | `baseline/pjgowtham_sm8450-common/init/init.oplus.rc` |
| overlay/UDFPS | `baseline/android_device_oneplus_ovaltine/overlay/OPlusSystemUIResTarget/res/values/config.xml` |
| 光感 overlay | `baseline/android_device_oneplus_sm8450-common/overlay/OPlusFrameworksResCommon/res/values/config.xml` |
| blob 清单 | 两棵树的 `proprietary-files.txt` |
| 提取修复 | 两棵树的 `extract-files.py` |
| 补丁 | `patches/**` |
| manifest | `local_manifests/ovaltine-lineage-22.1.xml` |
| 构建日志 | `/Volumes/los-build/brunch{,2,3,4}.log`、`BUILD_LOG.md` |
| 设备证据 | `DEVICE_REPORT.md`、`probes/device_scan/*` |
| 探针 | `probes/*.json`、`probes/lineage221_default.xml` |
| 底包/dump | `CPH2415_15.0.0.1901_EX01.zip`、`vendor_extract/{images,dump}` |

---

## 8. 附录

### 8.1 业主原始任务文本（逐字）

> 1、本项目是致力于为「一加10T」机型适配可以驱动所有硬件的 LineageOS系统；
> 2、目前，已经有一些社区适配的「一加10T」机型的 LineageOS 系统项目，但是版本不一、驱动支持程度、质量不一；
> 3、目前设备已经解锁BL，可以供你调试、测试。但必须将随时可以回到安卓系统作为前提、底线、红线。记录到文档中；
> 4、通常情况下，你可以通过adb进入faatboot模式，也可以在 fastboot模式下回到安卓系统；
> 5、驱动的原则是：开源＞闭源，官方开源＞同硬件其它设备的官方开源＞兄弟硬件的开源＞基于社区适配的开源/兄弟硬件的开源进行适配＞同原理重写适配/桥接封装＞逆向（理论上是这样，实际上使用最佳的方案，并可预留备选方案）；
> 6、鉴于目前已经有一些社区版的「一加10T」机型的开源的 LineageOS 系统，你可以
> 7、要求有专业的、标准的、规范的、详细的 SOP、硬件清单、驱动清单。

> 注：第 6 条原文在此处截断（“你可以”后无内容）。本报告与 `TASK_PLAN.md` 按“可参考/复用社区 10T 项目，但须逐项验证并记录采纳理由”理解；如业主有补充，以业主补充为准。

### 8.2 《开发作业临时约法》摘录（与本项目直接相关）

- Git 篇 1：每次任务完成后，代码 100% 全绿编译通过并提交 `main`；除业主要求外，禁止新建/使用其它分支。
- Git 篇 2：任务开始前工作区必须干净；有未提交内容先提交。
- Git 篇 3：里程碑/长期未上云时应远程提交。
- 作业篇 1：输出含注意事项、原始任务文本、需求/实现方向/验收标准/任务状态的任务计划书。
- 作业篇 3：冒烟、压力、回归、全量测试，结果 100% 全绿后再全量。
- 作业篇 4：完整编译 100% 全绿；模拟生产环境全量校验。
- 约束篇 1-3：遵守 RFC/事实标准/组件规范。
- 约束篇 4：第一性原理、长期主义、性能与功能兼备、统一标准。
- 约束篇 5：技术选型通常仅一种语言/组件库。

### 8.3 术语

| 术语 | 含义 |
|---|---|
| UDFPS | Under-Display Fingerprint Sensor，屏下指纹 |
| HBM | High Brightness Mode，高亮模式（屏下指纹常用） |
| ALS | Ambient Light Sensor，环境光传感器 |
| SPL | Security Patch Level，安全补丁级别 |
| ASB | Android Security Bulletin，Android 安全公告 |
| AVB | Android Verified Boot，Android 验证启动 |
| ARB | Anti-Rollback，防回滚 |
| DSDS | Dual SIM Dual Standby，双卡双待 |
| GKI | Generic Kernel Image，通用内核镜像 |
| SBOM | Software Bill of Materials，软件物料清单 |
| E1-E4 | 证据等级：静态/命令/构建/真机 |

### 8.4 变更记录

| 版本 | 日期 | 变更 | 作者 |
|---|---|---|---|
| 1.0 | 2026-10-31 | 首次全量审计；73 项发现；NO-GO 判定 | 审计 Agent |

---

**审计人结论**：当前项目是一个“有价值基线、但尚未形成可交付系统”的状态。基线选择、vendor 提取、探针记录有可取之处；但身份/变体、补丁链、构建闭环、安全红线和测试体系是硬缺口。建议按 `TASK_PLAN.md` 的 G0→G5 顺序整改；在 G0/G1/G2 门禁通过前，不要刷机，不要发布，也不要把当前状态标记为“完成”。
