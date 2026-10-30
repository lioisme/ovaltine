# HARDWARE_MATRIX.md — 硬件清单与驱动状态矩阵

> **2026-10-31 审计注记**：本矩阵已被 `HARDWARE_INVENTORY.md` 取代，保留为历史。事实更正：vendor blobs 已于 2026-10-29 提取完成；HBM/wise-light/rear-ALS 的“22.1 祖先链”结论仅对 lineage-ovaltine-dev common 成立，对最终选定的 pjgowtham common 不成立。以 `AUDIT_REPORT.md` 为准。

> 设备：OnePlus Ace Pro / 10T（ovaltine, CPH2415）· SoC SM8475（cape）· 底包 CPH2415_15.0.0.1901(EX01)
>
> **⚠️ 声明：无真机实测。本矩阵所有状态基于源码证据、官方/组织 Release notes 与兄弟硬件（SM8450/taro）驱动复用关系推断，按任务书规则状态上限为"一般"。**
> 判定依据均可在 baseline/ 镜像、patches/ 存档或 probes/ API 存档中复核；提取产物核验证据记录于 BUILD_LOG.md。

| 硬件模块 | 具体规格 | 状态 | 判定依据（可验证） | 驱动来源 |
|---|---|---|---|---|
| SoC | Snapdragon 8+ Gen 1（SM8475, cape） | 一般 | DTS 完整：`kernel/oneplus/sm8450-devicetrees/qcom/cape-*.dtsi`（mtp/v2/gpu/regulators/thermal 等 10+ 片段）；内核 22.1 分支持续合入 ASB-2025-04 + CAF msm-5.10（HEAD `63aeb92d069b`，2025-05-01）；**底包 boot.img strings 核验：`Linux version 5.10.236-android12-9-o-g55571f3ffcfa`，与任务书锚定完全一致** | 开源内核树 lineage-ovaltine-dev + 上游 DTS |
| GPU | Adreno 730 | 一般 | `cape-gpu.dtsi` 存在；内核 22.1 含 kgsl 调度修复（`8568d36d855b` Elevate command submission thread priority、`aa239ef5f46c` Restore original task priority）；Vulkan 扩展完整性/性能调优未验证 | 开源 kgsl(DRM) + 闭源 Adreno blob（底包提取） |
| 显示 | 6.7" 120Hz Fluid AMOLED 2412×1080 | 一般 | OSS display 栈为 22.1 树默认状态（`BoardConfigCommon.mk:140` 内核模块表含 `qcom/opensource/display-drivers/msm`）；21.0 release notes（2024-08-27）"Force 120Hz refresh rate by default to remove lags" 表明变刷新率策略曾有滞纳问题；LTPO 自适应策略未验证 | OSS display-drivers（内核）+ OSS composer + 闭源 display HDR/HWC 组件 |
| 触摸 | 屏下触摸（Oplus Touch 框架） | 一般 | 触摸 AIDL 服务与手势实现位于 fork `android_hardware_oplus lineage-21-8450`（`0fb1071` "Touch: implement touchscreen gestures through Oplus Touch"，2024-06-09）；**但 22.1 manifest 采用 LineageOS 上游 hardware_oplus `37e78750b957`**（fork 无 22.x 分支），手势等 8450 特化是否被上游携带未验证（风险 R-3a） | 内核 touch 驱动（modules 树）+ hardware_oplus HAL |
| 指纹 (UDFPS) | 光学屏下指纹 | 一般 | 三层配置齐备且均在 22.1 祖先链：① HBM 节点拒绝 `8f7dc6e`（`init.oplus.rc:48` `chmod 0000 /sys/kernel/oplus_display/hbm`，防止厂商 HAL 写 HBM 与框架调光冲突）；② 框架调光 overlay `ac9b624`（`overlay/OPlusSystemUIResTarget/config.xml` `config_udfpsFrameworkDimming=true`）；③ HAL `android.hardware.biometrics.fingerprint@2.3-service.oplus`（`common.mk:136`）。21.0 release notes "Better FOD" 表明录入/解锁在 21 可用；22.1 未实测 | 闭源 fingerprint HAL + 上述内核/overlay 配置 |
| 主摄/超广角/微距 | 50MP 主 + 8MP 超广角 + 2MP 微距 | 受限 | aux camera 解锁补丁 `01c3d5a` 在 22.1 祖先链（NOP 掉 aux 相机 SYSTEM_CAMERA 能力标记）；21.0 notes "Fix AUX camera"（2024-08-27）；相机 HAL 为闭源 blob（vendor 分区提取）；微距录像稳定性、22.1 相机服务崩溃复现情况：release notes 无具名修复条目 → 未验证 | 闭源 camera HAL（camx/chii）+ sm8450-common 相机配置 |
| 充电 | 4800mAh，150W SUPERVOOC | 受限 | 离线充电修复 `258dbbd818fb`（pjgowtham，`init.target.rc` 改用 `ro.boot.startupmode`，已导出 patches/optional）；充电框架走 `init.oplus.hw.rc`/`init.oplus.rc`；150W 专有协议栈（VOOC/SVOOC）无开源实现，峰值功率必然受限；实际充电档位未实测 | 内核充电/电池驱动 + 闭源 oplus 充电 HAL |
| 音频 | 立体声双扬 / 麦克风 / USB-C 耳机 | 一般 | 设备树自带音频拓扑：`device/oneplus/ovaltine/audio/{backend_conf,mixer_paths,resourcemanager,usecaseKvManager}.xml`；common.mk 构建 audio 组件；21.0 起可用（release 历史无音频阻断项）；通路切换/降噪/通话质量未全面验证 | 闭源 audio HAL（底包提取）+ 设备树音频配置 |
| 传感器 | 加速度计/陀螺仪/ALSPS/磁力计 | 一般 | 光传感器注册修复 `42cc1f8` "Register wise light as android.sensor.light"（应用对 `config_displayLightSensorType` 不感知的兼容方案）在 22.1 祖先链；自动亮度配置从一加 8T 移植（release changelog 具名）；传感器 AIDL 路径在 21 分支有 `lineage-21-aidl-sensor` 主题分支（22.1 是否全量携带未验证） | 开源 IIO/内核传感器驱动 + sensors HAL |
| GPS | GNSS | 一般 | `common.mk`/proprietary-files 含 GNSS HAL blob 段（pjgowtham 树 vendor 清单）；定位可用性继承 21.0 实机经验；TTFF/精度未与底包对比 | 闭源 GNSS HAL（blobs） |
| Wi-Fi / BT | Wi-Fi 6/6E, BT 5.2 | 一般 | WLAN 驱动 qcacld-3.0 在 modules 树（22.1 分支 HEAD `cb014aff` 为 qcacld-3.0 内存分配修复）；6GHz 支持修复由 21.0 release notes 具名（"Fix 6GHz WiFi support"，2024-10-03）；6GHz 在 22.1 是否回归未验证 | 闭源 WLAN/BT firmware + qcacld-3.0 模块 |
| 移动网络 | 双 SIM，5G（SA/NSA） | 受限 | DSDS 配置存在（`manifest_dsds.xml`）； modem 固件由底包提供（payload 内 modem 分区 0.28GB）；任务书与 XDA 已知：非官方树上双 SIM "Generally no" → 按单卡可用、双卡受限填报；VoLTE/5G 实际注册状态未实测 | 闭源 RIL/QMI blob + modem 固件 |
| USB | Type-C，USB 2.0 | 一般 | `cape-usb.dtsi` 完整；USB 为标准内核栈（dwc3），兄弟硬件 SM8450 复用成熟；ADB/MTP/OTG 预期可用，未实测 | 开源 USB 驱动 |
| 振动 | X 轴线性马达 | 一般 | Oplus 振动 HAL 头文件与配置在 common 树（`vibrator/VibrationEffectConfig.h`）；效果映射完整性未验证 | 闭源 vibrator HAL + 内核驱动 |

## 补充：构建侧依赖状态

| 项 | 状态 | 依据 |
|---|---|---|
| vendor blobs | 待提取核验 | `vendor_extract/images/` 分区镜像正在从底包 payload 解出；提取流程记录于 BUILD_LOG.md |
| 设备树 blob 清单锚点 | ⚠️ R-1 | ovaltine 设备树 `proprietary-files.txt` 头注锚定 `CPH2415_11.F.66`（OOS14 代），本底包为 15.0.0.1901(EX01)，extract-files 需按实际清单核对缺失项 |
| 内核 GKI 模块 | ⚠️ R-3 | 底包含 `vendor_boot`(0.20GB)/`vendor_dlkm`(0.16GB)/`odm_dlkm` 分区，modules 树 22.1 分支停滞于 2023-07-11，必要时以底包预编译模块回退 |
