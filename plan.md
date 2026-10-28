---

任务书：OnePlus Ace Pro / 10T（ovaltine）LineageOS Bring-up

0. 设备身份与底包锚定

项 值
设备 OnePlus Ace Pro / OnePlus 10T
Codename ovaltine
变体 CPH2415（全球/欧盟）
目标 LineageOS 22.2
底包 OxygenOS CPH2415_15.0.0.1901(EX01)，卡刷包已在项目根目录
基带 Q V1 P14, Q V1 P14
内核 5.10.236-android12-9-o-g55571f3ffcfa
硬件版本 CPH2415_11
SoC Snapdragon 8+ Gen 1（SM8475，平台代号 cape）
架构 arm64，A/B 分区

关键前提：XDA 非官方 22.1 线程中维护者明确声明 “the 22.2 branch isn‘t buildable yet”，且 “Upstream hasn’t published buildable ovaltine sources”。因此本任务书不以 22.2 作为强制构建目标，而是将 22.2 作为 探针评估目标，将 22.1 作为兜底可构建目标。Agent 必须在 DECISIONS.md 中记录这一前提，不得绕过。

---

1. 阶段 0：可构建性判定（必须在任何全量拉取之前完成）

1.1 探针检查

Agent 对以下两个来源执行分支与提交活跃度检查：

来源 A：LineageOS 官方 hudson / 组织

· 检查 LineageOS/android_device_oneplus_ovaltine 是否存在。
· 若存在，列出其所有分支及最近一次提交日期。
· 检查 LineageOS/android_kernel_oneplus_sm8475 是否存在及分支状态。

来源 B：lineage-ovaltine-dev 组织

· 遍历该组织所有仓库，记录仓库名、分支列表、默认分支、最近提交日期。
· 重点检查 android_device_oneplus_ovaltine、android_device_oneplus_sm8450-common、内核仓库是否存在 lineage-22.1 或 lineage-22.2 分支。
· 检查 Releases 页面：已知最新可见版本为 lineage-21.0-20241003-UNOFFICIAL-Pig，未显示 22.1 或 22.2 产物。

1.2 判定规则（严格按优先级执行）

```
如果 来源A 或 来源B 存在 lineage-22.2 分支，
   且最近 90 天内有提交，
   且该分支的 build 目标可被解析（brunch ovaltine 不立即报 recipe 缺失）：
        → 构建目标 = lineage-22.2
   否则：
        → 构建目标 = lineage-22.1
        → 在 DECISIONS.md 中写入：
           [DECISION-001] 22.2 探针失败，降级至 22.1。
           依据：<具体缺失项，引用来源A/B的检查结果>
```

硬性约束：Agent 不得在阶段 0 完成前执行 repo sync 全量同步。阶段 0 的产出写入 DECISIONS.md 和 BUILD_LOG.md。

---

2. 阶段 1：仓库拉取——严格区分“构建必需”与“仅参考”

2.1 构建必需仓库（进入 local_manifests）

以阶段 0 判定的分支为准，以下仓库按优先级拉取：

优先级 仓库 路径 说明
P0 LineageOS 基础 manifest .repo/manifests 用 lineage-22.1 或 lineage-22.2
P0 lineage-ovaltine-dev/android_device_oneplus_ovaltine device/oneplus/ovaltine 设备树首选源；若该仓库有目标分支则直接使用，否则从默认分支 cherry-pick
P0 lineage-ovaltine-dev/android_device_oneplus_sm8450-common 或 pjgowtham/android_device_oneplus_sm8450-common device/oneplus/sm8450-common 22.1 构建已知 fork 自这两个来源。优先使用与目标分支匹配的一方
P0 内核：优先 lineage-ovaltine-dev 组织下的内核仓库；备选 OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8475 kernel/oneplus/sm8475 内核版本要求 5.10.236；若开源内核版本不匹配，以底包中提取的预编译内核模块为回退
P0 Vendor blobs：从根目录 OxygenOS 卡刷包提取 vendor/oneplus/ovaltine 或 vendor/oneplus/sm8450-common 禁止直接使用未经验证的第三方 vendor 树；提取流程写入 BUILD_LOG.md

2.2 仅参考仓库（拉取到 baseline/，不进入 manifest）

仓库 用途 采纳规则
lineage-ovaltine-dev/release（Releases 页面的提交历史） 提取已知补丁：HBM 节点访问拒绝、OSS composer 切换、UDFPS 框架调光、aux camera 解锁 按 commit message 逐条 cherry-pick 到本地 patches/，每条补丁必须单独验证
tangalbert919/android_device_oneplus_ovaltine 历史 WIP 树 不采纳。最后提交 2023-05-22，基于 OOS 13.1.0.520，与底包 15.0.0.1901 代差过大
KawaiiHachimi/twrp_device_oneplus_ovaltine TWRP/OrangeFox recovery 仅在 Lineage Recovery 无法构建时作为临时 recovery 参考；需验证与 15.0.0.1901 底包的兼容性
sm8450-mainline/fdt SM8475（cape）下游 DTS 参考 用于内核 DTS 对照，不直接编入

产出：local_manifests/ 目录、patches/ 目录、BASELINE_EVALUATION.md（逐仓库记录采纳/不采纳 + 理由 + commit hash）。

---

3. 阶段 2：硬件清单与驱动状态矩阵

Agent 必须在 HARDWARE_MATRIX.md 中逐项填写下表。“状态”列不允许留空或主观填写；每一项必须附带至少一条可验证的判定依据，来源可以是：构建产物实测、源码 commit 引用、已知 issue 链接、或“与兄弟硬件（SM8450/taro）的驱动复用关系”。若无法实测且无源码依据，状态填 “未验证（默认一般）”。

硬件模块 具体规格 状态 判定依据（必须可验证） 驱动来源
SoC Snapdragon 8+ Gen 1（SM8475, cape） 完美 内核启动，CPU 频率调节正常，dmesg 无 CrashDump 开源内核 + 上游 SM8475 DTS
GPU Adreno 730 一般 UI 渲染可用；Vulkan 扩展完整性未验证，性能调优缺失 闭源 GPU blob（底包提取）+ 开源 msm DRM 驱动
显示 6.7“ 120Hz Fluid AMOLED, 2412×1080 一般 HWC 可工作；LTPO 可变刷新策略可能不完整；需验证 OSS composer 切换后 HWC 是否正常 开源 OSS composer + 闭源 display HAL
触摸 屏下触摸 完美/一般 触摸坐标正确，多点触控无断触；若实测有问题则降为“一般” 开源触摸驱动
指纹 (UDFPS) 光学屏下指纹 一般 录入/解锁可用；已知 HBM 节点冲突需通过 init 拒绝访问修复；框架调光需 overlay 支持 闭源 fingerprint HAL + 内核 HBM 补丁 + overlay 调光配置
主摄/超广角/微距 50MP 主摄 + 8MP 超广角 + 2MP 微距 受限 基础拍照可用；aux camera 需通过 sm8450-common 补丁解锁；微距录像稳定性未验证 闭源 camera HAL/blob + sm8450-common camera hack
充电 4800mAh，150W SUPERVOOC 受限 能充电；峰值功率大概率无法达到原厂 150W，专有充电协议无开源实现 内核充电驱动 + 闭源充电协议栈
音频 立体声扬声器 / 麦克风 / USB-C 耳机 一般 基本出声；通路切换/降噪/通话音频质量未全面验证 闭源 audio HAL + 开源 codec 驱动
传感器 加速度计、陀螺仪、ALSPS、磁力计 一般 各传感器在 HAL 层可上报；ALSPS 映射需验证（已知需将 wise light 注册为 android.sensor.light） 开源 IIO 驱动 + sensors HAL
GPS GNSS 一般 定位可用；TTFF/精度未与底包对比 闭源 GNSS HAL
Wi-Fi / BT Wi-Fi 6/6E, BT 5.x 一般 2.4/5GHz 可用；6GHz 需验证（历史 lineage-21 曾修复 6GHz WiFi） 闭源 WLAN/BT blob
移动网络 双 SIM，5G 受限 单卡通话/数据预期可用；双 SIM 在非官方 LineageOS 上已知“Generally no” 闭源 RIL/QMI blob
USB Type-C（USB 2.0） 完美 ADB/MTP/OTG 正常 开源 USB 驱动

补充规则：若 Agent 无真机可测，“状态”列全部禁止填“完美”，上限为“一般”，并在文件开头声明“无真机实测，所有状态基于源码和兄弟硬件推断”。

---

4. 阶段 3：SOP 与实时记录（强制）

4.1 Git 管理规范

分支 用途 写入规则
main 已验证可构建的 manifest 状态 仅在实际构建成功后 merge
bringup/ovaltine-<目标分支> 实际 bring-up 工作分支 所有日常工作在此进行
baseline/lineage-ovaltine-dev lineage-ovaltine-dev 的只读镜像 不允许提交，仅用于 git diff 对照

提交信息格式（强制）：[<模块>] <动作> <对象>，例如：

· [hardware|fingerprint] apply HBM-deny init patch from lineage-ovaltine-dev
· [kernel] switch to OnePlusOSS sm8475 tree at commit <hash>
· [build] brunch ovaltine fails with recipe missing on 22.2, decision-001 triggered

4.2 实时记录载体（每完成一个原子动作立即更新，禁止事后补写）

文件 内容 更新触发
STATUS.md 当前阶段、已完成项、阻塞项、下一动作 每次 Agent 循环结束
DECISIONS.md 关键决策、依据、不可逆标记 每次做出不可逆选择时
HARDWARE_MATRIX.md 阶段 2 的矩阵 每次源码确认或实测后
BUILD_LOG.md 构建命令、分支、commit hash、结果、错误摘要 每次构建尝试

4.3 构建尝试的 SOP（严格顺序，不允许跳过）

1. repo sync -d → 记录各仓库 HEAD commit hash 到 BUILD_LOG.md。
2. 应用 patches/ 中的补丁 → 记录补丁列表和每个补丁的来源 commit。
3. source build/envsetup.sh && breakfast ovaltine → 若 breakfast 阶段失败，先判定是否属于 22.2 上游不可构建，若是则触发 DECISION-001，降级至 22.1，停止当前分支的构建尝试。
4. brunch ovaltine → 若编译失败，记录错误摘要；若同一错误在 2 次以上尝试后仍无法解决，降级至 22.1。
5. 构建成功后，先验证 recovery 和 boot，再进入系统功能测试。
6. 按 HARDWARE_MATRIX.md 逐项测试，每测一项立即更新状态，不允许攒批。

---

5. 阶段 4：lineage-ovaltine-dev 采纳评估报告

Agent 必须输出 BASELINE_EVALUATION.md，至少包含以下字段，每个字段都必须有证据支撑：

```
## lineage-ovaltine-dev 采纳评估

### 1. 分支覆盖
- android_device_oneplus_ovaltine:
  分支列表: <列出>
  默认分支: <名称>
  目标分支是否存在: 是/否
  最近提交日期: <日期>
- android_device_oneplus_sm8450-common:
  <同上>
- 内核仓库:
  <同上>

### 2. 提交时效性
最近一次与 Android 15 / LineageOS 22.x 相关的提交:
  commit: <hash>
  message: <原文>
  date: <日期>
是否包含 2025 年后的适配: 是/否

### 3. 已知问题继承
其 Release notes 中列出的问题:
  - 相机服务首次使用崩溃: <目标分支是否仍存在 / 是否已被后续提交修复>
  - 微距镜头录像崩溃: <同上>
  - gralloc 错误: <同上>
  - HBM 节点冲突: <补丁 commit hash / 是否已 cherry-pick>
  - aux camera 解锁: <补丁 commit hash / 是否已 cherry-pick>
  - OSS composer 切换: <补丁 commit hash / 是否已 cherry-pick>

### 4. 最终判定
判定: 采纳为基线 / 仅参考 / 不采纳
若“采纳为基线”:
  锁定的 commit hash: <hash>
  进入 local_manifests 的仓库: <列表>
若“仅参考”:
  cherry-pick 的 commit 列表: <hash + message>
  不采纳的具体理由: <逐条>
```

---

6. 任务终止条件

Agent 在以下任一条件满足时停止并输出最终报告：

1. 成功路径：目标分支构建成功，HARDWARE_MATRIX.md 中所有模块状态已填写（无空项），BASELINE_EVALUATION.md 已完成，BUILD_LOG.md 最后一次构建记录为成功。
2. 降级路径：22.2 不可构建，已降级至 22.1 并完成上述成功路径的产出物，DECISIONS.md 中 DECISION-001 完整记录。
3. 阻塞路径：在 22.1 上也遭遇无法在 Agent 权限范围内解决的阻塞（如 vendor blob 缺失关键 HAL、内核源码与底包版本不匹配且无回退方案），停止并输出 STATUS.md，列出精确的缺失项和已排除的替代方案。不允许无限循环尝试。