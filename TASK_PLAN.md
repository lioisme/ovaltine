# OnePlus 10T（ovaltine / CPH2415）LineageOS 适配任务计划书

| 项 | 值 |
|---|---|
| 文档编号 | OVL-PLAN-2026-10-31 |
| 版本 | 1.1 |
| 编制日期 | 2026-10-31 |
| 依据 | 业主七项要求；业主 2026-10-31 强制约束；《开发作业临时约法》；`AUDIT_REPORT.md`（OVL-AUDIT-2026-10-31） |
| 目标设备 | OnePlus Ace Pro / 10T，codename `ovaltine`，CPH2415（全球/欧盟） |
| 目标系统 | LineageOS 22.1（DECISION-001；22.2 仅探针目标） |
| 当前状态 | **审计完成；构建未成功；禁止真实刷机；发布 NO-GO** |
| 任务负责人 | 业主指定；技术执行：Agent/构建工程师/测试工程师 |
| 文档状态 | 生效；整改执行与状态回填以本文件为准 |

> **2026-10-31 业主强制约束（高于本文件其余描述）**
>
> 只允许**内存启动（`fastboot boot`）**或 **DSU** 进行调试/测试；**禁止真实刷入任何分区**（`fastboot flash`、`adb sideload`、`fastboot -w`、`dd` 写分区、recovery 写入、EDL/MSM 刷写等一律禁止）。
> 本文件中所有“刷机/刷入/回 stock OTA/OTA 安装/切槽”步骤一律作废；相关任务、测试、验收改为“内存启动/DSU/重启退出”。
> 该约束已记录为 `DECISIONS.md` DECISION-006，`SOP.md` v2.0 已按此重写。

---

## 0. 原始任务文本（逐字）

> 1、本项目是致力于为「一加10T」机型适配可以驱动所有硬件的 LineageOS系统；
> 2、目前，已经有一些社区适配的「一加10T」机型的 LineageOS 系统项目，但是版本不一、驱动支持程度、质量不一；
> 3、目前设备已经解锁BL，可以供你调试、测试。但必须将随时可以回到安卓系统作为前提、底线、红线。记录到文档中；
> 4、通常情况下，你可以通过adb进入faatboot模式，也可以在 fastboot模式下回到安卓系统；
> 5、驱动的原则是：开源＞闭源，官方开源＞同硬件其它设备的官方开源＞兄弟硬件的开源＞基于社区适配的开源/兄弟硬件的开源进行适配＞同原理重写适配/桥接封装＞逆向（理论上是这样，实际上使用最佳的方案，并可预留备选方案）；
> 6、鉴于目前已经有一些社区版的「一加10T」机型的开源的 LineageOS 系统，你可以
> 7、要求有专业的、标准的、规范的、详细的 SOP、硬件清单、驱动清单。

**文本完整性说明**：第 6 条在“你可以”处截断，缺少后续动词/宾语。本计划按以下解释执行，并保留业主补充权：

- 可以复用/参考社区 10T 项目（含 lineage-ovaltine-dev、pjgowtham、tangalbert919、KawaiiHachimi 等），但必须逐项验证、记录采纳/不采纳理由，不得把“其他机型可用”当作“本机可用”。
- 若业主补充第 6 条，以补充文本为准，并更新本文件版本。

---

## 1. 任务目标与成功定义

### 1.1 总目标

为 OnePlus 10T（CPH2415）交付一套可构建、可在内存/DSU 中调试测试、可退出、可维护的 LineageOS 22.1 系统，使所有硬件在真机上达到“可日常使用”的质量，并满足 Apple/Google 级工程质量与验收标准。

### 1.2 成功定义（Definition of Done）

同时满足以下条件才算项目完成：

1. **可构建**：干净 Linux 主机 + 固定 manifest + 固定工具链，`brunch ovaltine` 退出 0，产物齐全，两次重建哈希一致或差异可解释。
2. **可退出**：测试只通过内存启动/DSU；退出方式为重启或 DSU 丢弃，**不写系统分区**；DSU 写入的 userdata 已备份。
3. **可启动**：内存启动/DSU 启动后 `sys.boot_completed=1`，无 bootloop/panic，能进设置、通话、相机、网络。
4. **硬件全绿**：`HARDWARE_INVENTORY.md` 所有项有 E4 实测结果，0 未验证；P0/P1 缺陷 0。
5. **测试全绿**：冒烟、压力、回归、全量、安全、OTA 测试 100% 通过；证据归档。
6. **安全合规**：SPL 当前；SELinux Enforcing；发布 key 签名；无未授权 blob 分发；隐私脱敏。
7. **可维护**：文档、SOP、驱动清单、变更记录、维护计划齐全；上游/ASB 跟踪机制运行。
8. **业主验收**：业主签字确认“非官方、风险自担、仅限内存/DSU 测试、不真实刷机”。

### 1.3 当前判定

- 允许继续整改开发：**GO**
- 允许内存启动/DSU 测试：**GO**（前提：构建产物存在、DSU/内存启动路径验证、userdata 已备份）
- 允许真实刷机：**永久 NO-GO**（DECISION-006）
- 允许发布/OTA：**NO-GO**

---

## 2. 范围

### 2.1 范围内

- CPH2415（全球/欧盟）单机型；若业主需要 CPH2413/CPH2417，另立 variant 任务。
- LineageOS 22.1（Android 15）设备树、common、kernel、vendor blobs、manifest、补丁、构建、内存启动/DSU 测试、发布。
- 开源驱动优先，闭源 blob 仅作为不可替代的 vendor 组件，并记录来源/许可证/风险。
- 硬件：SoC/CPU/GPU/显示/触摸/UDFPS/相机/音频/充电/电池/传感器/GPS/WiFi/BT/NFC/蜂窝/USB/振动/热。
- 文档：审计、任务计划、SOP、硬件清单、驱动清单、测试报告、发布说明、维护计划。

### 2.2 范围外（除非业主另行批准）

- 其他 OnePlus 机型（10 Pro NE2211/NE2213、10R 等）的适配。
- LineageOS 22.2/23.x/24.x 的正式适配（仅做探针/预研，不进入发布）。
- 闭源 blob 的逆向工程/重写（除职业/法律允许且业主批准）。
- 云构建资源采购、域名/OTA 服务器采购、法务意见。
- 设备硬件维修/换屏/换电池。

---

## 3. 约束与红线

### 3.1 不可违反的红线

1. **禁止真实刷入任何分区**：只允许内存启动（`fastboot boot`）或 DSU；`fastboot flash`、`adb sideload`、`fastboot -w`、`dd` 写分区、recovery 写入、EDL/MSM 刷写一律禁止。
2. **禁止重新上锁 bootloader**：自定义签名 + 上锁可能导致不可恢复的变砖；本项目全程保持解锁。
3. **DSU 会写 userdata**：测试前必须备份用户数据；不得把 DSU 当作“零写入”。
4. **禁止 anti-rollback 违规**：不得通过任何工具写入低于设备 ARB 版本的固件；不得用旧 stock 包“降级救砖”。
5. **禁止擅自改系统网络配置**：代理/镜像只作用于构建工具环境，遵循《约法》网络篇。
6. **禁止非 main 分支长期作业**：除业主书面要求外，所有提交进 `main`；短期实验分支必须当天合并/删除。
7. **禁止把“未验证”写成“可用/完美”**：文档状态必须与证据等级一致。
8. **禁止发布未签名/使用 testkey 的镜像**：研发构建可 testkey，发布必须独立 key。
9. **禁止分发未授权闭源 blob**：默认只提供提取脚本；如需分发 ROM，先完成法律评估。
10. **禁止在 user 构建保留调试/强制属性**（`persist.dbg.*`、`debug.*`、`ro.debuggable=1` 等）。

### 3.2 技术约束

- 主构建宿主：Linux x86_64，Ubuntu 22.04/24.04，32 GB RAM 起（建议 64 GB），250 GB+ 可用磁盘。
- 测试执行：只允许内存启动/DSU；构建产物不得刷入设备。
- 构建分支：LineageOS 22.1；基础 manifest 固定 commit；所有工程固定 commit。
- 技术栈：AOSP/LineageOS 原生（Soong/Make、Bash、Python 工具链）；不引入同类 UI 框架/组件库。
- 标准：AOSP 分区/AVB/OTA/SELinux 规范；Git 提交 `[<模块>] <动作> <对象>`；SPDX 许可证头。
- 语言：文档中文为主，代码/提交信息英文；术语表统一。

---

## 4. 现状基线（审计结论摘要）

详见 `AUDIT_REPORT.md`。与本计划直接相关的现状：

| 项 | 现状 | 影响 |
|---|---|---|
| 构建 | 4 轮 brunch 均失败/被杀；无 `out/target/product/ovaltine` | 无镜像可测 |
| 宿主 | macOS 26.7 Intel / 16 GB | 官方不支持；内存不足 |
| 分支 | `main` 已 fast-forward；`bringup` 保留为历史归档 | Git 合规已恢复 |
| remote | 无 | 无云端备份 |
| 身份 | 已静态修正为 `CPH2415/Android 15`；待 DSU/内存验证 | 待验证 |
| common | 来自 10 Pro NE2213/Android 14 | 跨机型混用 |
| blob pin | device 3/1415；common 0/1265 | 供应链完整性不足 |
| 补丁 | EX01 + 本轮 adaptation 已落 patch；旧 SIGSCAN 在 EX01 缺失，第二段待验证 | 部分修复，待验证 |
| 安全 | SPL 2025-01/2025-04；testkey；AVB 关闭验证 | 发布阻断 |
| 退出 | SOP v2.0 已补（禁止刷机，仅内存/DSU）；演练未执行 | 红线未落地 |
| 测试 | 0 执行 | 无法验收 |

---

## 5. 工作分解结构（WBS）

### 5.1 任务总表

| ID | 工作包 | 优先级 | 依赖 | 状态 |
|---|---|---|---|---|
| T-00 | 治理、仓库与文档基线 | P0 | 业主提供 remote | 进行中（本次审计提交） |
| T-01 | Linux 构建宿主与工具链 | P0 | 硬件/云资源 | 阻塞（无 Linux 宿主） |
| T-02 | 完整 manifest 与补丁自动化 | P0 | T-00 | 进行中（补丁脚本完成；完整 manifest 待 Linux） |
| T-03 | 设备身份与 variant 对齐 | P0 | T-02 | 进行中（静态身份修复完成；DSU 验证待 T-10） |
| T-04 | 基线选型复审与 common 对齐 | P0 | T-02 | 未开始 |
| T-05 | Blob 溯源、SBOM 与校验 | P0 | T-03/T-04 | 进行中（提取产物 SHA-256 清单完成；SBOM/变体差异待） |
| T-06 | 已知修复端口（HBM/wise-light/ALS/aux/offline） | P0 | T-04 | 进行中（HBM/名称替换/ALS 静态完成；SIGSCAN 待验证） |
| T-07 | 内核/模块/设备树配套 | P1 | T-02 | 未开始 |
| T-08 | 构建全绿与产物验证 | P0 | T-01/T-02/T-03/T-04/T-06 | 未开始 |
| T-09 | 内存/DSU 测试与退出演练 | P0 | T-08 | 未开始 |
| T-10 | 内存启动/DSU 首次启动 | P0 | T-08/T-09 | 未开始 |
| T-11 | 硬件矩阵实测 | P1 | T-10 | 未开始 |
| T-12 | 冒烟/压力/回归/全量/CTS/OTA 测试 | P1 | T-11 | 未开始 |
| T-13 | 安全加固与发布签名 | P1 | T-08/T-12 | 未开始 |
| T-14 | 发布、OTA 与长期维护 | P2 | T-13 | 未开始 |
| T-15 | 文档、追溯与验收 | P1 | 全过程 | 进行中（本次新增审计/计划/SOP/清单） |

### 5.2 任务详情

#### T-00 治理、仓库与文档基线

- **关联发现**：GOV-001～010、BLD-008、DOC-001～012、LEG-001/002。
- **需求**：仓库清洁、main-only、有 remote/备份、关键交付物入库、文档可读可追溯。
- **实现方向**
  1. `git checkout main`；`git merge --ff-only bringup/ovaltine-lineage-22.1`；后续只在 `main` 提交。`bringup` 分支保留为历史，经业主确认后删除。
  2. `.gitignore` 增加 `.venv/`、`scratch/`、`.DS_Store`、`*.log`；取消忽略 `patches/optional-pjgowtham/`；用 `probes/*` 白名单提交公共探针 JSON，设备扫描原始数据继续忽略并说明原因。
  3. 配置 remote（业主提供 URL/凭证）；推送 `main` 与 tag。
  4. 新增 `README.md`、`SECURITY.md`、`CONTRIBUTING.md`、`CHANGELOG.md`、`KNOWN_ISSUES.md`、`MAINTENANCE.md`。
  5. 新增 `scripts/`：`init-repo.sh`、`sync.sh`、`apply-patches.sh`、`verify-tree.sh`、`build.sh`、`collect-artifacts.sh`、`flash.sh`、`rollback.sh`、`test.sh`。
  6. 修正 `STATUS.md`/`BUILD_LOG.md`/`DECISIONS.md` 的事实矛盾；追加 DECISION-005 记录“DECISION-003 事实前提失效，构建尝试失败，主路径改 Linux”。
- **验收标准**
  - `git branch --show-current=main`；`git status --porcelain` 空；`git remote -v` 有 origin；远端可 `ls-remote`。
  - 干净 clone 后按 README 能定位审计报告、任务计划、SOP、硬件/驱动清单。
  - 所有脚本 `shellcheck` 通过（或明确豁免）；`apply-patches.sh` 幂等。
  - 文档事实一致：STATUS/BUILD_LOG/DECISIONS 不再互相矛盾。
- **状态**：进行中（文档/禁刷约束/静态适配已完成并提交；remote/推送待业主）。

#### T-01 Linux 构建宿主与工具链

- **关联发现**：BLD-001、BLD-006～011、ARCH-001。
- **需求**：具备官方支持的构建环境，能稳定完成 A15 全量构建。
- **实现方向**
  1. 准备 Linux x86_64：Ubuntu 22.04/24.04，32 GB RAM 起，250 GB+ SSD，`nproc>=16` 更佳。
  2. 安装并锁定：JDK 17、repo 2.71、git-lfs、ccache、cmake、ninja、Python 3.12、erofs-utils、7zz、payload_dumper 0.2.2。
  3. 记录 `tool-versions.txt`、`uname -a`、`free -h`、`nproc`、`df -h`、`java -version`、`clang --version`。
  4. 配置镜像/代理（仅构建环境，不改系统网络配置）：优先官方源，失败时使用业主提供的代理/镜像；禁止把镜像 URL 写死到官方 manifest。
  5. macOS 构建仅作为实验：不进入发布；mac 补丁按 OS 隔离、单独 CI job。
- **验收标准**
  - `brunch` 在 Linux 上退出 0；峰值内存/磁盘/耗时记录完整。
  - 工具版本与 `tool-versions.txt` 一致；新机器按脚本可复现。
  - macOS 实验构建不阻塞 Linux 发布；mac 补丁不在 Linux 上生效。
- **状态**：阻塞（缺 Linux 宿主/云资源；需业主决策）。

#### T-02 完整 manifest 与补丁自动化

- **关联发现**：BLD-002、BLD-003、GOV-004、DOC-003。
- **需求**：任意时间/任意机器都能同步到同一源码树，补丁应用可验证、可回滚。
- **实现方向**
  1. `repo manifest -r -o manifests/lineage-22.1-<date>.xml`；提交完整 manifest。
  2. local manifest 只放 6 个覆盖工程；镜像覆盖用 `<remote>`/`scripts/init-repo.sh`，不 `sed` 官方 `default.xml`。
  3. `patches/` 按树/子系统组织：`patches/device-ovaltine/`、`patches/common-sm8450/`、`patches/kernel/`、`patches/build-macos/`；`series` 文件定义顺序。
  4. `scripts/apply-patches.sh`：`git apply --check` → `git apply`；失败即停；重复执行幂等；输出每棵树 diff 哈希。
  5. `scripts/verify-tree.sh`：断言 HBM `chmod 0000`、UDFPS overlay、wise-light 字符串、ALS 配置、aux camera 等。
  6. 禁止手工改构建树后直接编译；所有修改必须来自 patch。
- **验收标准**
  - 全新目录 `repo init -m ...` + `repo sync` 成功；所有 HEAD 与 manifest 一致。
  - `apply-patches.sh` 在干净树上退出 0；二次执行不重复修改；`verify-tree.sh` 全断言通过。
  - 两次干净同步 + 补丁后的 `git diff` 哈希一致。
- **状态**：进行中（`scripts/apply-patches.sh`、`scripts/verify-tree.sh` 已完成；完整 pinned manifest 待 Linux/T-01）。

#### T-03 设备身份与 variant 对齐

- **关联发现**：ID-001、ID-003、ID-008。
- **需求**：系统身份与真实设备一致；OTA/Play Integrity/运营商/相机逻辑不被错误 fingerprint 误导。
- **实现方向**
  1. 明确单 variant（CPH2415）或多 variant；本计划默认单 variant。
  2. `lineage_ovaltine.mk`：`PRODUCT_MODEL=CPH2415`、`DeviceProduct=CPH2415`、`SystemName=CPH2415`；`TARGET_OTA_ASSERT_DEVICE`/`board-info.txt` 与实测一致。
  3. `PRODUCT_BUILD_PROP_OVERRIDES`：使用 CPH2415 EX01 真实 fingerprint，或按 Lineage 规范移除伪造；若保留，写明依赖它的 blob/服务与风险。
  4. 构建期断言：`PRODUCT_MODEL`、`PRODUCT_DEVICE`、fingerprint、SPL 与配置一致。
  5. 内存/DSU 启动后 `getprop` 验证四件套：model/device/fingerprint/security_patch。
- **验收标准**
  - 构建与真机 `ro.product.model=CPH2415`、`ro.product.device=OP5552L1`、`ro.product.name=CPH2415`。
  - `ro.build.fingerprint` 与选定策略一致；代码无 CPH2417/Android 13 残留。
  - OTA assert 通过；Play Integrity/运营商测试无身份相关失败（或记录预期限制）。
- **状态**：进行中（静态身份修复完成；DSU/内存启动验证待 T-10）。

#### T-04 基线选型复审与 common 对齐

- **关联发现**：ID-002、ARCH-002、DOC-003。
- **需求**：common 树必须服务 10T CPH2415，而不是把 10 Pro 的配置直接套用。
- **实现方向**
  1. 重新评估 common 候选：lineage-ovaltine-dev sm8450-common、pjgowtham sm8450-common、10T 专用 fork、兄弟硬件树。
  2. 建立“共享/覆盖/禁用”矩阵：每个 common 配置/blob 标注 10T 是否使用、来源、差异。
  3. 优先选择：官方开源 > 同硬件官方开源 > 兄弟硬件开源 > 社区适配 > 重写/桥接 > 逆向（按业主原则）。
  4. 若继续用 pjgowtham，必须把 10T 差异全部落到 device/ovaltine 或 patch，并逐项测试。
  5. 记录基线选型决策（使用下一个 DECISION 编号）与证据；不要用“同代”替代“同机型”。
- **验收标准**
  - 决策记录含候选、证据、成本、风险、业主签字。
  - common 清单头注与目标机型一致；每个 common blob 有 10T 实际文件校验。
  - 相机/音频/充电/传感器/显示在真机通过；无 10 Pro 专属残留导致的问题。
- **状态**：未开始。

#### T-05 Blob 溯源、SBOM 与校验

- **关联发现**：ID-003、ID-004、SEC-005、LEG-001/002。
- **需求**：每个闭源 blob 可追溯到 CPH2415 EX01；可校验、可审计、可法律评估。
- **实现方向**
  1. 以 CPH2415 EX01 dump 为唯一来源，重生成/校对两棵树的 `proprietary-files.txt`；删除 CPH2417/CPH2413 来源注释。
  2. 为每个 blob 记录：源分区、路径、大小、SHA256、所属硬件、许可证状态。
  3. 已生成 `artifacts/blob-manifest.sha256`（2688 个文件）+ `tools/verify_vendor_blobs.sh`；后续把源 pin/SBOM/许可证状态补上。
  4. 生成 `SBOM.csv`/`SBOM.json` 与 `CREDITS.md`；标注可再分发/不可再分发。
  5. 去 pin 条目必须附原因、替代哈希、人工核对记录、风险接受。
- **验收标准**
  - extract-files 0 missing；`verify_vendor_blobs.sh` 100% 通过；哈希漂移 CI 失败。
  - SBOM 覆盖全部闭源组件；每个 blob 有来源与许可证状态。
  - 发布包不含未授权 blob；NOTICE/CREDITS 齐全。
- **状态**：进行中（`artifacts/blob-manifest.sha256` 2688/2688 通过；源 pin/SBOM/变体差异待完成）。

#### T-06 已知修复端口

- **关联发现**：DRV-001～005。
- **需求**：10T 已知问题在最终选定树上真实生效，而不是“在另一个树上是祖先”。
- **实现方向**
  1. HBM：在 pjgowtham `init.oplus.rc` 移除 hbm chown，追加 `chmod 0000`；`verify-tree.sh` 断言。
  2. wise-light：在 pjgowtham `extract-files.py` 增加 `sensors.ssc.so` 名称替换；旧 9 字节 SIGSCAN 在 EX01 blob 中不存在（count=0），第二段代码补丁需重新推导/验证，不得原样套用。
  3. rear-ALS：在 overlay 增加 `config_displayLightSensorType=qti.sensor.light_rear`（或按 10T 实测）。
  4. aux camera：确认 device `extract-files.py` 的 `CameraHWConfiguration.config` 修复生效；补丁文档改为“实现位置”。
  5. offline charging：确认 pjgowtham HEAD 已包含；从“待应用”清单移除。
  6. 每个修复单独 commit/patch，附前后对比与测试记录。
- **验收标准**
  - `verify-tree.sh` 全部断言通过；`git apply --check` 无失败补丁。
  - 100 次 UDFPS 解锁 0 失败；自动亮度曲线通过；6 相机 ID 可用；关机充电通过。
  - 文档不再出现“祖先即生效”的误导表述。
- **状态**：进行中（HBM/名称替换/ALS 静态完成；SIGSCAN 第二段待验证）。

#### T-07 内核/模块/设备树配套

- **关联发现**：DRV-006、DRV-007、ARCH-001。
- **需求**：kernel、devicetrees、modules 三元组 ABI/版本配套，模块可加载。
- **实现方向**
  1. 选择同一时间线/维护者的三元组；modules 2023-07 与 kernel 2025-05 错位必须解决。
  2. 记录每个仓库 commit/日期/配置；构建后 `modinfo` 检查 vermagic/CRC。
  3. 明确 vendor_dlkm 来源：源码构建 vs 底包预编译；若用预编译，先解决 vermagic（`5.10.236-gki-g3a16d49f0607` vs `5.10.236-android12-9-o-g55571f3ffcfa`）与 CRC。
  4. 评估 ASB/内核 CVE 回移；记录 `CONFIG_LOCALVERSION`/`CONFIG_MODVERSIONS`/`CONFIG_MODULE_SIG` 策略。
- **验收标准**
  - 三元组配套有书面依据；`brunch` 通过；关键模块 `modprobe`/`insmod` 成功。
  - `dmesg` 无 vermagic/CRC/未知符号错误；内核日志无 panic/oops。
  - 安全配置（SELinux、KASLR、STRICT_KERNEL_RWX 等）符合基线。
- **状态**：未开始。

#### T-08 构建全绿与产物验证

- **关联发现**：BLD-001、TST-001、TST-008。
- **需求**：产出可刷写的完整镜像，且可复现。
- **实现方向**
  1. Linux 上 `source build/envsetup.sh && breakfast ovaltine && brunch ovaltine`；显式 `-j` 与 ccache。
  2. 产物：boot/dtbo/recovery/vbmeta/vbmeta_system/vbmeta_vendor/vendor_boot/system/system_ext/product/vendor/vendor_dlkm/odm/super_empty/OTA zip。
  3. `scripts/collect-artifacts.sh` 生成 `SHA256SUMS`、`build-info.txt`、`source-manifest.xml`、`tool-versions.txt`。
  4. `avbtool verify_image` 逐镜像验证（研发 testkey；发布 key 另做）。
  5. 两次干净重建对比；记录 non-determinism。
- **验收标准**
  - `brunch` 退出 0；产物齐全非 0；OTA `unzip -t` 通过。
  - `SHA256SUMS` 可校验；`avbtool` 通过；两次构建哈希一致或差异有报告。
  - `out/target/product/ovaltine` 存在且归档。
- **状态**：未开始。

#### T-09 内存/DSU 测试与退出演练

- **关联发现**：SEC-001（按 DECISION-006 转为“无分区写入”方案）。
- **需求**：在不刷入任何分区的前提下，能安全进入内存启动/DSU 测试，并能随时退出回 stock。
- **实现方向**
  1. 按 `SOP.md` v2.0 执行：只允许 `fastboot boot` 与 DSU；禁止 `fastboot flash`/sideload/`fastboot -w`/`dd` 写分区/EDL。
  2. 记录 stock 状态：`fastboot getvar all`、`current-slot`、`ro.build.fingerprint`、SPL、ARB。
  3. 备份 userdata（DSU 会写 userdata）；记录 SHA256/介质。
  4. 演练 `fastboot boot` 进入/退出；演练 DSU 安装/启动/丢弃；记录耗时/日志/结果。
  5. 记录“退出后 stock 指纹/IMEI/基带/指纹传感器正常”；不得用刷机修复。
  6. 禁止重新上锁；文档加粗警告。
- **验收标准**
  - 第二人按 SOP 可独立完成内存启动/DSU 进出；记录命令/日志/耗时/结果。
  - 全程 0 分区写入（可用操作日志/命令审计证明）；DSU 丢弃后 stock 正常。
  - 业主签字确认红线流程。
- **状态**：未开始（DECISION-006 生效；禁止真实刷机）。

#### T-10 内存启动/DSU 首次启动

- **关联发现**：SEC-001、TST-004、DOC-005。
- **需求**：在不写系统分区的前提下启动测试镜像，验证首启与核心功能。
- **实现方向**
  1. 路径 A：`fastboot boot boot.img`（仅 boot 侧验证，不写分区）；路径 B：DSU 安装 system/GSI（写 userdata，需备份）。
  2. 首启采集：`adb wait-for-device`、`getprop sys.boot_completed`、`dmesg`、`logcat`、`getprop` 全量。
  3. 验证 DSU/内存启动身份、SELinux、指纹录入、相机、通话、WiFi。
  4. 任何 bootloop：重启回 stock 或丢弃 DSU；**不得刷机/EDL**。
- **验收标准**
  - `sys.boot_completed=1`；无 bootloop/panic；首次设置可完成。
  - 关键硬件冒烟通过；日志归档。
  - 退出后 stock 可在 5 分钟内恢复（重启/DSU 丢弃）。
- **状态**：未开始。

#### T-11 硬件矩阵实测

- **关联发现**：DRV-008、TST-002、TST-005～007。
- **需求**：所有硬件有 E4 实测结论，不用推断代替。
- **实现方向**
  1. 按 `HARDWARE_INVENTORY.md` 逐项测试；每项正向 + 边界/负向。
  2. 使用 `getevent`、`dumpsys`、`/proc`、`/sys`、`logcat`、`dmesg`、专用测试 App/命令。
  3. 每项记录：测试 ID、构建 SHA256、步骤、预期、实际、证据、判定。
  4. 失败项进入缺陷跟踪；P0/P1 修复后回归。
- **验收标准**
  - 15 类硬件/子系统全部有结果；0 未验证。
  - 通过项有证据；失败项有缺陷 ID/整改/回归。
  - 矩阵与 `HARDWARE_INVENTORY.md` 一致。
- **状态**：未开始。

#### T-12 冒烟/压力/回归/全量/CTS/OTA 测试

- **关联发现**：TST-001～008。
- **需求**：按《约法》作业篇 3/4 完成四维测试，全部全绿后再全量。
- **实现方向**
  1. 冒烟：启动、设置、通话、相机、WiFi、指纹、充电。
  2. 压力：72h 长稳、1000 次相机、10k 指纹、24h 网络、1h 4K、充电循环。
  3. 回归：每个补丁/配置变更后跑受影响模块 + 冒烟；发布前跑全量。
  4. 全量：硬件矩阵 + 系统功能 + 安全 + OTA + 性能。
  5. CTS/VTS/GSI/Play Integrity 基本检查；记录豁免。
  6. 证据归档 `tests/results/<date>/`。
- **验收标准**
  - 四维测试 100% 执行；0 未执行/0 阻塞。
  - 全量测试在最终候选上 100% 通过；0 P0/P1。
  - CTS/VTS 关键套件通过（或业主批准豁免）；GSI 可启动。
- **状态**：未开始。

#### T-13 安全加固与发布签名

- **关联发现**：SEC-002～009、ARCH-004。
- **需求**：安全基线达标，发布镜像可信。
- **实现方向**
  1. SPL 更新/ASB 回移；`BOOT_SECURITY_PATCH`/`VENDOR_SECURITY_PATCH` 与实际一致。
  2. 发布 key 生成/离线保存；`avbtool` 签名；`verify_image` 门禁。
  3. SELinux Enforcing + avc 清零；移除 `persist.dbg.*`/`debug.*`。
  4. 隐私脱敏；blob 法律评估；SBOM/NOTICE。
  5. AVB 链/rollback index 策略；是否保留 hashtree disabled 的书面风险接受。
- **验收标准**
  - SPL 达标；发布 key 签名通过；私钥不在仓库。
  - `getenforce=Enforcing`；0 未解释 avc；user 构建无调试强制属性。
  - 公共文档无设备唯一标识；SBOM/许可证齐全。
- **状态**：未开始。

#### T-14 发布、OTA 与长期维护

- **关联发现**：GOV-007、ARCH-004/005、DOC-007。
- **需求**：可持续发布/更新/退出，不是一次性操作。
- **实现方向**
  1. 版本号 `22.1-YYYYMMDD-ovaltine`；tag；release notes；known issues。
  2. 生成 signed OTA（归档/分析用，不安装）；校验和；DSU/退出说明。
  3. 维护计划：月度上游扫描、ASB、依赖升级、设备树 rebase、回归。
  4. 发布门禁：G5 清单逐项签字。
- **验收标准**
  - 每个发布有 tag/OTA/SHA256/release notes/known issues。
  - DSU 可安装/可丢弃；OTA 归档可校验；维护计划执行有记录。
  - 业主签字发布。
- **状态**：未开始。

#### T-15 文档、追溯与验收

- **关联发现**：DOC-001～012、LEG-002。
- **需求**：文档专业、标准、规范、详细；需求—任务—测试—证据可追溯。
- **实现方向**
  1. 维护 `AUDIT_REPORT.md`、`TASK_PLAN.md`、`SOP.md`、`HARDWARE_INVENTORY.md`、`DRIVER_INVENTORY.md`、`README.md`、`SECURITY.md`、`CHANGELOG.md`、`KNOWN_ISSUES.md`、`MAINTENANCE.md`。
  2. 每份文档加 version/date/status/owner/证据等级。
  3. 建立追溯矩阵（§11）；每个发现关闭时填 commit/测试/证据。
  4. 变更记录：每次任务完成立即回填状态（禁止事后补写）。
- **验收标准**
  - 文档齐全、无事实矛盾、无未脱敏数据。
  - 任一业主要求可追到任务/测试/证据。
  - 新成员按 README/SOP 可在 1 天内完成环境搭建与首次构建（有 Linux 宿主前提下）。
- **状态**：进行中（审计/计划/SOP/清单/ADAPTATION_LOG/静态适配已完成；运行时内容待后续回填）。

---

## 6. 测试计划

### 6.1 测试维度与门禁

| 维度 | 目标 | 执行时机 | 通过标准 |
|---|---|---|---|
| 构建测试 BT | 构建可复现、产物完整 | 每次提交/T-08 | 退出 0；产物齐全；哈希一致 |
| 冒烟 SM | 系统能启动、核心功能可用 | 每次内存/DSU 启动/T-10 | 全部 SM 通过；无 bootloop |
| 硬件 HW | 所有硬件可用 | T-11 | 15 类全部通过；0 未验证 |
| 压力 ST | 长稳/热/功耗/无崩溃 | T-12 | 72h 无重启/崩溃/数据丢失 |
| 回归 RG | 变更不破坏已通过项 | 每次补丁/配置变更 | 受影响项 + 冒烟 100% |
| 全量 FT | 发布前全量 | T-12 | 全部用例 100% |
| 安全 SC | SELinux/AVB/SPL/密钥 | T-13 | 全绿 |
| DSU/退出 OT | DSU 安装/启动/丢弃/重启 | T-12/T-14 | 进入/退出成功；stock 恢复；0 分区写入 |
| 复现 RF | 干净重建/哈希 | T-08/T-12 | 哈希一致或差异可解释 |

### 6.2 构建测试（BT）

| ID | 步骤 | 预期 | 判定 |
|---|---|---|---|
| BT-01 | 干净目录 `repo init -m manifests/... && repo sync` | 所有工程 HEAD 与 manifest 一致 | 100% 一致 |
| BT-02 | `apply-patches.sh` | 退出 0；`verify-tree.sh` 通过 | 0 失败 |
| BT-03 | `brunch ovaltine` | 退出 0；产物齐全 | 0 错误 |
| BT-04 | `avbtool verify_image` 全镜像 | 通过 | 100% |
| BT-05 | `unzip -t` OTA | 通过 | 0 错误 |
| BT-06 | 二次干净重建 | SHA256 一致或差异有报告 | 通过 |

### 6.3 冒烟测试（SM）

| ID | 测试 | 步骤 | 预期 |
|---|---|---|---|
| SM-01 | 首次启动 | 内存/DSU 启动后等待 | `sys.boot_completed=1`，无 bootloop |
| SM-02 | 设置向导 | 完成基础设置 | 可进桌面，无 crash/ANR |
| SM-03 | ADB | `adb devices`、`adb shell` | 授权后可进入 |
| SM-04 | 通话 | SIM1 拨号/接听 | 通话建立，音频双向 |
| SM-05 | 数据 | 打开移动数据 | 可上网 |
| SM-06 | WiFi | 连接 2.4/5G | 获取 IP，可上网 |
| SM-07 | 相机 | 打开主摄拍照 | 预览/拍照成功 |
| SM-08 | 指纹 | 录入 + 解锁 10 次 | 0 失败 |
| SM-09 | 充电 | 插入充电器 | 显示充电，功率/温度正常 |
| SM-10 | 音频 | 扬声器/耳机播放 | 左右声道正常 |

### 6.4 硬件矩阵（HW）

> 详细规格/驱动/证据见 `HARDWARE_INVENTORY.md`。以下为验收级用例。

| ID | 子系统 | 关键步骤 | 预期/容差 |
|---|---|---|---|
| HW-01 | SoC/CPU | `dmesg`、`/proc/cpuinfo`、`cpufreq` | 8 核在线；无 panic/oops；频率可调 |
| HW-02 | GPU | `dumpsys SurfaceFlinger`、3D 负载 | UI 60/120Hz；无 GPU fault |
| HW-03 | 显示 | `dumpsys display`、亮度 0-100%、HDR | 1080×2412；60/90/120Hz；无闪烁 |
| HW-04 | 触摸 | `getevent`、多点、手势 | 10 点；坐标正确；无断触/鬼触 |
| HW-05 | UDFPS | 录入/100 次解锁/HBM | 0 失败；无闪烁；无 avc |
| HW-06 | 相机 | 6 个 ID、拍照/录像/RAW/4K/微距/aux | 全部可打开；无崩溃；文件可读 |
| HW-07 | 充电/电池 | 原装/普通充电、离线充电、温升 | 充电正常；温度/功率记录；无过流 |
| HW-08 | 音频 | 扬声器/麦克风/USB-C/通话/蓝牙 | 无破音/断续；左右声道正确 |
| HW-09 | 传感器 | `dumpsys sensorservice` 全类型 | 全部上报；数值随动作变化 |
| HW-10 | 自动亮度 | 10→1000 lux 扫描 | 亮度平滑；无跳变/偏暗 |
| HW-11 | GPS | 冷/热启动、定位 | 冷启 <60s；热启 <5s；精度达标 |
| HW-12 | WiFi/BT | 2.4/5/6E、BT 音频/LE | 连接稳定；吞吐达标；无断连 |
| HW-13 | 蜂窝 | 双卡、VoLTE、5G SA/NSA | 按运营商能力通过；无掉网 |
| HW-14 | USB | ADB/MTP/OTG | 全部可用；无断连 |
| HW-15 | 振动/热 | 振动强度、30min 压力 | 振动正常；温度低于阈值 |

### 6.5 压力/长稳（ST）

| ID | 测试 | 时长/次数 | 预期 |
|---|---|---|---|
| ST-01 | 系统长稳 | 72h 待机+周期唤醒 | 无重启/崩溃/ANR；内存无泄漏 |
| ST-02 | 相机开关 | 1000 次 | 0 失败/0 崩溃 |
| ST-03 | 指纹 | 10,000 次 | 失败率 <1%；无 HBM 异常 |
| ST-04 | 网络 | 24h WiFi+5G 交替 | 无断连/掉网；功耗正常 |
| ST-05 | 4K 录像 | 1h | 无过热停止/文件损坏 |
| ST-06 | 充电循环 | 20 次 | 无异常温升/充电失败 |
| ST-07 | 重启 | 100 次 | 全部正常启动；无 fs corruption |

### 6.6 回归/全量（RG/FT）

| ID | 测试 | 触发 | 预期 |
|---|---|---|---|
| RG-01 | 补丁后受影响模块 | 每次补丁 | 通过 |
| RG-02 | 配置后冒烟 | 每次配置变更 | 通过 |
| FT-01 | 硬件矩阵全量 | 发布前 | 100% 通过 |
| FT-02 | 系统功能全量 | 发布前 | 100% 通过 |
| FT-03 | 安全全量 | 发布前 | 100% 通过 |
| FT-04 | DSU/退出 | 发布前 | 100% 通过 |
| FT-05 | 性能/热/续航 | 发布前 | 达到阈值 |

### 6.7 安全（SC）

| ID | 测试 | 预期 |
|---|---|---|
| SC-01 | `getenforce` | Enforcing |
| SC-02 | `dmesg \| grep avc` | 0 未解释 denial |
| SC-03 | `avbtool verify_image` | 全部通过 |
| SC-04 | SPL | >= 目标（当前月-1） |
| SC-05 | `ro.debuggable`/`ro.secure` | 0/1（user） |
| SC-06 | `adb root` | 被拒绝（user） |
| SC-07 | 指纹/Keymaster | 正常工作 |
| SC-08 | 隐私扫描 | 公共文档无序列号/IMEI/MAC |

### 6.8 DSU/退出（OT）

| ID | 测试 | 预期 |
|---|---|---|
| OT-01 | 生成 DSU 系统镜像 | 成功；SHA256 记录 |
| OT-02 | DSU 安装/启动 | 成功；`sys.boot_completed=1` |
| OT-03 | DSU 丢弃/重启 | 成功回 stock；userdata 保留/可恢复 |
| OT-04 | 失败注入/中止 | 可重启回 stock；0 分区写入 |
| OT-05 | 退出后 stock 验证 | `ro.build.fingerprint` 恢复；IMEI/基带/指纹正常 |

### 6.9 复现（RF）

| ID | 测试 | 预期 |
|---|---|---|
| RF-01 | 两次干净 sync+patch | diff 哈希一致 |
| RF-02 | 两次 clean build | 产物 SHA256 一致或差异报告 |
| RF-03 | 工具链清单 | 与 `tool-versions.txt` 一致 |

---

## 7. 里程碑与门禁

| 里程碑 | 内容 | 门禁 | 当前 |
|---|---|---|---|
| M0 | 审计完成、计划生效 | `AUDIT_REPORT`/`TASK_PLAN` 评审通过 | **已完成（本次）** |
| M1 | 治理基线关闭 | T-00 验收；main/remote/文档/脚本 | 进行中 |
| M2 | Linux 构建全绿 | T-01/T-02/T-08 验收；产物齐全 | 未开始（阻塞） |
| M3 | 内存/DSU 进出演练通过 | T-09 验收；第二人独立执行；0 分区写入 | 未开始 |
| M4 | 内存/DSU 首次启动成功 | T-10 验收；SM 全绿 | 未开始 |
| M5 | 硬件矩阵全绿 | T-11 验收；HW 100% | 未开始 |
| M6 | 全量测试全绿 | T-12 验收；ST/RG/FT/SC/OT 100% | 未开始 |
| M7 | 发布 | T-13/T-14 验收；签名/OTA/文档 | 未开始 |

**门禁规则**：上一里程碑未通过，不得进入下一里程碑；银行/支付/OTA 等高风险动作必须双人复核。

---

## 8. 风险登记册

| 风险 | 概率 | 影响 | 触发 | 缓解 | 负责人 |
|---|---|---|---|---|---|
| 无 Linux 宿主导致项目停滞 | 高 | 高 | T-01 无法开始 | 业主提供机器/云资源；mac 仅实验 | 业主/构建 |
| 内存/DSU 测试无法退出 | 中 | 高 | DSU/内存启动异常 | T-09 先行；重启/DSU 丢弃；禁止刷机修复 | 测试/业主 |
| CPH2415 与 2417/NE2213 blob 不兼容 | 高 | 高 | 相机/音频/充电异常 | T-04/T-05 逐项对齐；回退 | 驱动 |
| super/userdata 尺寸不符 | 中 | 高 | DSU/内存测试失败 | 设备实测 `blockdev`；对比分区表 | 构建 |
| 内核/模块 ABI 不匹配 | 中 | 高 | 模块加载失败 | T-07 三元组配套；modinfo | 内核 |
| 22.1 安全债扩大 | 高 | 高 | 新 CVE | T-13 ASB 回移/分支重评 | 安全 |
| 闭源 blob 法律风险 | 中 | 高 | 公开发布 | T-05 法务/SBOM；默认不分发 | 业主/法务 |
| UDFPS HBM 冲突 | 高 | 中 | 指纹闪烁/失败 | T-06 端口 HBM 补丁 | 驱动 |
| 自动亮度错误 | 高 | 中 | 亮度跳变 | T-06 wise-light/ALS | 驱动 |
| 无 remote 丢失工作 | 中 | 高 | 机器故障 | T-00 配置 remote/备份 | 业主/Agent |

---

## 9. 交付物清单

### 9.1 文档

- `AUDIT_REPORT.md`（本审计）
- `TASK_PLAN.md`（本文件）
- `SOP.md`
- `HARDWARE_INVENTORY.md`
- `DRIVER_INVENTORY.md`
- `README.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `CHANGELOG.md`
- `KNOWN_ISSUES.md`
- `MAINTENANCE.md`
- `manifests/lineage-22.1-<date>.xml`
- `tool-versions.txt`

### 9.2 脚本

- `scripts/init-repo.sh`
- `scripts/sync.sh`
- `scripts/apply-patches.sh`
- `scripts/verify-tree.sh`
- `scripts/build.sh`
- `scripts/collect-artifacts.sh`
- `scripts/dsu-test.sh`（仅 DSU 安装/启动/丢弃，不写系统分区）
- `scripts/test.sh`

### 9.3 构建/测试产物

- 完整镜像集（boot/dtbo/recovery/vbmeta*/vendor_boot/system*/vendor*/odm/super_empty）
- OTA zip（signed；归档/分析用，**不安装、不刷入**）
- `SHA256SUMS`、`build-info.txt`、`source-manifest.xml`
- 测试报告（SM/HW/ST/RG/FT/SC/OT/RF）
- 日志（build/dmesg/logcat/update_engine）
- 内存/DSU 进出演练记录

### 9.4 证据

- 公共探针 JSON/manifest（已计划入库）
- 设备扫描摘要（脱敏）
- vendor dump 哈希清单（不入库大文件）
- 补丁可应用性/树断言结果

---

## 10. 状态跟踪与变更管理

### 10.1 状态值

| 状态 | 含义 |
|---|---|
| 未开始 | 尚未执行 |
| 进行中 | 已开始，未满足验收 |
| 阻塞 | 依赖未满足（如无 Linux 宿主） |
| 已完成 | 验收标准全部满足，证据归档 |
| 风险接受 | 业主书面接受，记录期限/条件 |
| 不适用 | 本项目无该场景（如 REST API） |

### 10.2 更新规则

1. 每完成一个原子动作立即更新本文件对应任务状态与证据路径；禁止事后补写。
2. 每次提交信息遵循 `[<模块>] <动作> <对象>`；提交正文引用发现 ID/任务 ID。
3. 每次里程碑更新 `STATUS.md`、`CHANGELOG.md`、`KNOWN_ISSUES.md`。
4. 任何 P0/P1 变更必须双人复核；任何内存/DSU 测试必须有退出预案；禁止任何刷机动作。
5. 文档版本号递增；保留变更记录。

### 10.3 评审节奏

- 每日：构建/测试阻塞同步（15 分钟）。
- 每周：风险/进度/缺陷评审；更新矩阵。
- 每个里程碑：业主验收会；签字。

---

## 11. 追溯矩阵

### 11.1 业主要求 → 任务 → 测试 → 证据

| 业主要求 | 任务 | 测试 | 证据 | 状态 |
|---|---|---|---|---|
| 1 全硬件 LineageOS | T-04/T-06/T-11 | HW-01～15 | HARDWARE_INVENTORY + 测试报告 | 未开始 |
| 2 社区项目质量不一 | T-04 | 文档评审 | BASELINE_EVALUATION 修订 | 未开始 |
| 3 红线：随时可回 Android | T-09 | OT-05 | 内存/DSU 退出演练记录（0 分区写入） | 未开始 |
| 4 adb/fastboot | T-09/T-10 | SM-03/OT-05 | SOP v2.0 + 日志 | 未开始 |
| 5 驱动开源优先 | T-04/T-05 | 文档评审 | DRIVER_INVENTORY + SBOM | 未开始 |
| 6 复用社区 10T | T-04 | 文档评审 | 采纳/不采纳记录 | 部分 |
| 7 SOP/硬件/驱动清单 | T-15 | 文档评审 | SOP/HARDWARE/DRIVER | 草案完成 |

### 11.2 《约法》→ 任务

| 条款 | 任务 | 验收 |
|---|---|---|
| Git main-only/全绿 | T-00/T-08 | main 分支 + 构建 0 |
| 工作区干净 | T-00 | `git status` 空 |
| 远程提交 | T-00 | remote/tag/push |
| 任务计划书 | T-15 | 本文件 |
| 测试四维 | T-12 | ST/RG/FT 全绿 |
| 生产级校验 | T-12/T-13 | CTS/VTS/OTA/安全 |
| SOP/清单 | T-15 | 三份文档 |
| 红线 | T-09 | 演练通过 |

---

## 12. 附录

### 12.1 优先级/严重度

- P0：阻断内存/DSU 测试/发布/红线；必须立即整改。
- P1：严重功能/安全/合规；发布前关闭或书面风险接受。
- P2：中等技术债；里程碑前关闭。
- P3：改进项；backlog。

### 12.2 角色

| 角色 | 职责 |
|---|---|
| 业主 | 资源/决策/风险接受/验收 |
| 技术负责人 | 架构/基线/补丁/发布签字 |
| 构建工程师 | 环境/manifest/构建/产物 |
| 驱动工程师 | kernel/common/blob/硬件 |
| 测试工程师 | 测试矩阵/证据/回归 |
| 安全/合规 | SPL/AVB/SELinux/SBOM/隐私 |

### 12.3 变更记录

| 版本 | 日期 | 变更 | 作者 |
|---|---|---|---|
| 1.0 | 2026-10-31 | 首次任务计划书；基于 73 项审计发现；定义 WBS/测试/门禁/追溯 | 审计 Agent |

---

**执行提示**：本计划不是“愿望清单”，而是门禁化的执行合同。T-09 未完成前，任何内存/DSU 测试都是违规；T-08 未完成前，任何硬件“可用”结论都是推断；T-12 未完成前，任何“发布”都是冒险。全程禁止真实刷入任何分区。请按 M0→M7 顺序推进，并在每次状态变化时回填本文件与 `STATUS.md`。
