# OnePlus 10T（ovaltine / CPH2415）硬件清单

| 项 | 值 |
|---|---|
| 文档编号 | OVL-HW-2026-10-31 |
| 版本 | 0.9（审计草案） |
| 日期 | 2026-10-31 |
| 设备 | OnePlus Ace Pro / 10T，codename `ovaltine`，报告型号 CPH2415 |
| 证据来源 | `DEVICE_REPORT.md`、`probes/device_scan/*`、`CPH2415_15.0.0.1901_EX01.zip`、`vendor_extract/dump`、baseline 源码 |
| 状态说明 | **本清单是硬件识别与测试台账，不是“已可用”声明。除特别标注 E4 外，均为 E1/E2 证据，功能状态待实测。** |
| 关联 | `AUDIT_REPORT.md`、`TASK_PLAN.md`、`DRIVER_INVENTORY.md` |

---

## 1. 设备身份与 variant

### 1.1 本机身份（DEVICE_REPORT 实测）

| 项 | 值 |
|---|---|
| 市场名 | OnePlus Ace Pro / OnePlus 10T |
| Codename | `ovaltine` |
| 型号 | CPH2415（全球/欧盟） |
| 主板/设备名 | `OP5552L1`（`ro.product.device`） |
| 硬件版本 | CPH2415_11 |
| Android | 15 / SDK 35 |
| 构建 | `S.245f058-1f931-1f92d` |
| 安全补丁 | 2026-06-01 |
| 内核 | `5.10.236-android12-9-o-g55571f3ffcfa` |
| 基带 | `Q_V1_P14,Q_V1_P14` |
| SoC | SM8475（cape），`ro.board.platform=taro` |
| RAM / 存储 | 16 GB / 256 GB |
| 启动 | A/B + dynamic partitions（super） |
| Bootloader | 已解锁（`ro.boot.flash.locked=0`，`verifiedbootstate=orange`） |
| 当前槽 | `_a` |

### 1.2 相关 variant（必须区分，禁止混用）

| Variant | 市场 | 与本项目关系 | 风险 |
|---|---|---|---|
| CPH2415 | 10T 全球/欧盟 | **目标机** | — |
| CPH2417 | 10T 其他区域 | 设备树 `lineage_ovaltine.mk` 当前写的是它 | 身份/fingerprint/区域配置错误 |
| CPH2413 | 10T 印度等 | 设备树 WiFi 配置来源注释引用它 | blob 版本/区域差异 |
| NE2211 / NE2213 | OnePlus 10 Pro | 选定 common 树 `pjgowtham_sm8450-common` 的 blob 来源 | 跨机型相机/音频/充电/显示差异 |
| CPH2419 等 | 10T 运营商版 | 本项目不覆盖 | 基带/运营商配置差异 |

> **结论**：当前构建链中至少出现 CPH2415（目标）、CPH2417（设备树身份）、CPH2413（WiFi blob 注释）、NE2213/NE2211（common blob）四种来源。必须按 `TASK_PLAN.md` T-03/T-04 收敛到 CPH2415，或显式建立 variant 矩阵。

---

## 2. 硬件 BOM 总表

| ID | 子系统 | 主要器件/规格 | 证据 | 状态 | 测试 ID |
|---|---|---|---|---|---|
| HW-01 | SoC/CPU | Snapdragon 8+ Gen 1（SM8475, cape）；4×A510 + 3×A710 + 1×X2 | `ro.soc.model=SM8475`；`/proc/cpuinfo` part 0xd46/0xd47/0xd48；DEVICE_REPORT §2 | 已识别，待 E4 | HW-01 |
| HW-02 | GPU | Adreno 730 | `ro.hardware.egl/vulkan=adreno`；GLES 3.2；DEVICE_REPORT §2 | 已识别，待 E4 | HW-02 |
| HW-03 | 显示 | 6.7" AMOLED，1080×2412，20:9，480 dpi，60/90/120 Hz，HDR HLG/HDR10/DV 声明，峰值 540 nit | `dumpsys display`；DEVICE_REPORT §4 | 已识别，待 E4 | HW-03 |
| HW-04 | 触摸 | 屏下触摸 + 按键通道；Oplus touchpanel 框架 | `getevent -il` event5/6；DEVICE_REPORT §5 | 已识别，待 E4 | HW-04 |
| HW-05 | UDFPS | 光学屏下指纹；`oplus_fp_input` | event2；DEVICE_REPORT §5；overlay UDFPS 参数 | 已识别，已知 HBM 风险待修 | HW-05 |
| HW-06 | 相机 | 1 前 + 5 后（主摄 50MP + 超广角 8MP + 微距 2MP + 逻辑多摄） | `dumpsys media.camera` 6 ID；DEVICE_REPORT §7 | 已识别，待 E4 | HW-06 |
| HW-07 | 充电/电池 | 4800 mAh；150W SUPERVOOC（闭源协议）；USB PD/普通充电 | DEVICE_REPORT §11；oplus battery service | 已识别，峰值功率预计受限 | HW-07 |
| HW-08 | 音频 | 立体声双扬声器、麦克风阵列、USB-C 耳机（无 3.5mm）；waipio-mtp-snd-card | `getevent`；DEVICE_REPORT §8 | 已识别，待 E4 | HW-08 |
| HW-09 | 传感器 | BMI26x（accel/gyro）、AK0991x（mag）、TCS3701（light/proximity）、QTI fusion | `dumpsys sensorservice`；DEVICE_REPORT §6 | 已识别，wise-light/ALS 待修 | HW-09/HW-10 |
| HW-10 | 自动亮度 | 环境光 + 后置 ALS（待确认） | TCS3701；对照 overlay `qti.sensor.light_rear` | 已知风险 | HW-10 |
| HW-11 | GPS | GNSS（Qualcomm） | HAL/blob；DEVICE_REPORT §9 | 已识别，待 E4 | HW-11 |
| HW-12 | WiFi/BT | WiFi 6/6E（qca6490）、BT 5.2 | modules/固件；DEVICE_REPORT §9 | 已识别，6E 待验证 | HW-12 |
| HW-13 | NFC/eSE | 全功能 NFC + eSE | props features；DEVICE_REPORT §9 | 已识别，待 E4 | HW-13 |
| HW-14 | 蜂窝 | 双 SIM DSDS；5G SA/NSA；FR1/FR2 热区 | 基带 `Q_V1_P14`；DEVICE_REPORT §10 | 已识别，双卡/5G 待实测 | HW-14 |
| HW-15 | USB | Type-C USB 2.0；ADB/MTP/OTG | `dumpsys usb`；DEVICE_REPORT §9 | 已识别，待 E4 | HW-15 |
| HW-16 | 振动 | X 轴线性马达 | common vibrator HAL/config | 已识别，待 E4 | HW-16 |
| HW-17 | 热 | 40+ 热区（aoss/cpuss/gpu/bcl/modem PA/mmw 等） | DEVICE_REPORT §11 | 已识别，待 E4 | HW-17 |
| HW-18 | 安全/虚拟化 | TEE/KeyMint、AVB、FBE、pVM/Microdroid | DEVICE_REPORT §12 | 已识别，待 E4 | SC-01～08 |
| HW-19 | 按键/其他 | 电源、音量、PMIC pwrkey/resin | event3/4 | 已识别，待 E4 | HW-04 |

> 状态取值：已识别 / 待 E4 / 已知缺陷 / 阻塞 / 已验证。**“已识别”不等于“可用”。**

---

## 3. 子系统详表

### 3.1 SoC / CPU（HW-01）

| 项 | 内容 |
|---|---|
| 器件 | Snapdragon 8+ Gen 1（SM8475，平台 cape，`taro` 家族） |
| 拓扑 | 4×Cortex-A510（cpu0-3）+ 3×Cortex-A710（cpu4-6）+ 1×Cortex-X2（cpu7） |
| 实测频率 | 充电/热约束下 A510 1.80 GHz、A710 2.23 GHz、X2 2.59 GHz；设计峰值 X2 3.2 GHz |
| 内核 | 5.10.236-android12-9；GKI + vendor modules |
| 证据 | `DEVICE_REPORT` §2；`probes/device_scan/cpu_soc.txt` |
| 待验证 | LineageOS 下 cpufreq/热调/大小核调度、 suspend/resume、ASB/CVE |
| 测试 ID | HW-01、ST-01、ST-07 |
| 验收 | 8 核在线；频率可调；无 panic/oops；72h 无异常重启 |

### 3.2 GPU（HW-02）

| 项 | 内容 |
|---|---|
| 器件 | Adreno 730 |
| 用户态 | Adreno EGL/Vulkan blob；`ro.hardware.egl=adreno` |
| 内核 | msm DRM/kgsl（开源）+ 闭源 GPU 微码 |
| 证据 | `DEVICE_REPORT` §2；kernel `cape-gpu.dtsi`；kgsl 调度修复 |
| 待验证 | Vulkan 扩展完整性、GPU 频率/热、游戏稳定性、HWC 组合 |
| 测试 ID | HW-02、ST-01、FT-05 |
| 验收 | UI 60/120Hz；无 GPU fault；3D 负载 30min 无崩溃/花屏 |

### 3.3 显示（HW-03）

| 项 | 内容 |
|---|---|
| 面板 | 6.7" AMOLED，1080×2412，20:9，480 dpi，圆角 60px，打孔 107px |
| 模式 | 60/90/120 Hz（modeId 1/3/2） |
| HDR | types [2 HLG, 3 Dolby Vision 声明, 4 HDR10]；峰值 540 nit |
| 色彩 | [0,7,9]（sRGB/Display P3/Adobe RGB 类） |
| 栈 | OSS display-drivers + OSS composer + 闭源 display HDR/HWC 组件 |
| 证据 | `DEVICE_REPORT` §4；`BoardConfigCommon.mk` 内核模块表 |
| 待验证 | HWC 组合、LTPO/变刷新、HDR 播放、亮度曲线、DC 调光、烧屏策略 |
| 测试 ID | HW-03、ST-01、FT-05 |
| 验收 | 分辨率/模式正确；亮度 0-100% 平滑；HDR 视频可播；无闪烁/撕裂 |

### 3.4 触摸（HW-04）

| 项 | 内容 |
|---|---|
| 器件 | Oplus touchpanel（event5/6） |
| 栈 | 内核 touch 驱动 + `vendor.lineage.touch@1.0-service.oplus` |
| 证据 | `getevent -il`；hardware/oplus `hidl/touch` |
| 待验证 | 10 点触控、坐标、手势、双击唤醒、游戏触控采样率、湿手/手套 |
| 测试 ID | HW-04、ST-01 |
| 验收 | 10 点无断触/鬼触；坐标误差在阈值内；手势可用；双击唤醒可控 |

### 3.5 UDFPS（HW-05）

| 项 | 内容 |
|---|---|
| 器件 | 光学屏下指纹（`oplus_fp_input`，event2） |
| 栈 | 闭源 fingerprint HAL（2.3 service）+ `libudfps_extension.oplus` + overlay 调光 |
| 关键配置 | `config_udfpsFrameworkDimming=true`；UDFPS sensor props 540/2182/86 |
| 已知风险 | 选定 common 树 `init.oplus.rc` 仍 `chown system .../hbm`，与框架调光冲突；HBM 补丁未应用 |
| 证据 | `overlay/.../config.xml:9`；`init.oplus.rc:16`；`AUDIT_REPORT` DRV-001 |
| 测试 ID | HW-05、ST-03 |
| 验收 | 录入成功；100 次解锁 0 失败；无亮度闪烁；`dmesg` 无 avc/HBM 权限错误 |

### 3.6 相机（HW-06）

| 项 | 内容 |
|---|---|
| 相机 ID | 6 个：1 前 + 5 后（主摄 50MP、超广角 8MP、微距 2MP、逻辑多摄） |
| 栈 | 闭源 camx/chii blob + device/common 配置 + `CameraHWConfiguration.config` aux 解锁 |
| 已生效 | `scratch/.../CameraHWConfiguration.config:816` 已为 `SystemCamera = 0; 0; 0; 0; 0; 0;` |
| 待验证 | 6 ID 全部可开；拍照/录像/RAW/4K/慢动作/微距/超广角/第三方相机；HDR/夜景/人像；相机服务稳定性 |
| 证据 | `DEVICE_REPORT` §7；`extract-files.py:47-48` |
| 测试 ID | HW-06、ST-02、ST-05 |
| 验收 | 6 ID 可打开；拍照/录像文件可读；1000 次开关 0 崩溃；4K 1h 无过热停止；微距录像稳定 |

### 3.7 充电/电池（HW-07）

| 项 | 内容 |
|---|---|
| 电池 | 4800 mAh（双电芯）；150W SUPERVOOC |
| 协议 | VOOC/SVOOC 闭源；开源栈无法保证峰值 150W |
| 栈 | 内核充电/电池驱动 + 闭源 oplus 充电 HAL |
| 证据 | `DEVICE_REPORT` §11；`TARGET_HEALTH_CHARGING_CONTROL_CHARGING_PATH` |
| 待验证 | 原装 150W、普通 USB、PD、离线充电、温度/功率曲线、电池健康 |
| 测试 ID | HW-07、ST-06 |
| 验收 | 充电正常；功率/温度记录；无过流/过热；关机充电可用；20 次循环无异常 |

### 3.8 音频（HW-08）

| 项 | 内容 |
|---|---|
| 器件 | 立体声双扬声器、麦克风阵列、USB-C 耳机（无 3.5mm）；waipio-mtp-snd-card |
| 栈 | 闭源 audio HAL（PAL/AGM）+ 开源 audio-kernel + 设备树 XML |
| 证据 | `DEVICE_REPORT` §8；`device/ovaltine/audio/*` |
| 待验证 | 左右声道、音量、免提、听筒、麦克风、USB-C、蓝牙、通话降噪、VoIP、低延迟 |
| 测试 ID | HW-08、SM-10 |
| 验收 | 无破音/断续；左右声道正确；通话双向；USB-C/蓝牙可用；音频 HAL 无 crash |

### 3.9 传感器（HW-09）

| 项 | 内容 |
|---|---|
| 器件 | BOSCH BMI26x（accel/gyro）、AKM AK0991x（mag）、Oplus TCS3701（light/proximity） |
| 栈 | 内核 IIO/SSC + 闭源 sensors.ssc + `sensors.oplus` |
| 关键风险 | wise-light 未注册为 `android.sensor.light`；rear-ALS 配置缺失 |
| 证据 | `DEVICE_REPORT` §6；`strings sensors.ssc.so` 仍为 `qti.sensor.wise_light` |
| 测试 ID | HW-09、HW-10、ST-01 |
| 验收 | 所有类型上报；数值随动作变化；自动亮度曲线平滑；无 sensor 权限错误 |

### 3.10 自动亮度（HW-10）

| 项 | 内容 |
|---|---|
| 输入 | TCS3701 光感/接近；后置 ALS（待确认使用策略） |
| 配置 | 选定 common 树无 `config_displayLightSensorType`；对照树用 `qti.sensor.light_rear` |
| 测试 | 10/50/100/300/1000 lux 扫描；遮挡/强光；夜间/户外 |
| 验收 | 亮度单调/平滑；无明显跳变；夜间不刺眼；户外可读；回滞合理 |

### 3.11 GPS（HW-11）

| 项 | 内容 |
|---|---|
| 栈 | 闭源 GNSS HAL（AIDL）+ 固件；`gps.conf` |
| 证据 | `common.mk` GNSS blobs；`configs/gps.conf` |
| 测试 | 冷启动 TTFF、热启动、精度、室内/室外、AGPS |
| 验收 | 冷启 <60s、热启 <5s；精度达标；无持续定位失败 |

### 3.12 WiFi / BT（HW-12）

| 项 | 内容 |
|---|---|
| WiFi | qca6490 / qcacld-3.0；WiFi 6/6E；2.4/5/6GHz |
| BT | BT 5.2；音频/LE；固件分区 `bluetooth_a/b` |
| 证据 | modules 树；DEVICE_REPORT §9 |
| 测试 | 2.4/5/6E 连接/吞吐/延迟；热点；WiFi Direct/Aware；BT 音频/LE/通话 |
| 验收 | 连接稳定；6E 可用（若区域/AP 支持）；BT 无断连/杂音 |

### 3.13 NFC / eSE（HW-13）

| 项 | 内容 |
|---|---|
| 特性 | `nfc`, `nfc.any`, `nfc.ese`, `nfc.hce`, `nfc.hcef` |
| 栈 | 闭源 NFC HAL + eSE |
| 测试 | 读卡/写卡/Android Beam（如支持）/HCE/支付类应用识别/eSE |
| 验收 | NFC 开关/读卡/ HCE 正常；eSE 可用；无 HAL crash |

### 3.14 蜂窝（HW-14）

| 项 | 内容 |
|---|---|
| 基带 | Q_V1_P14（双卡 DSDS） |
| 能力 | 5G SA/NSA；FR1+FR2 热区；VoLTE/VoWiFi |
| 栈 | 闭源 RIL/QMI + modem 固件 |
| 证据 | `DEVICE_REPORT` §10；`persist.radio.multisim.config=dsds` |
| 测试 | SIM1/SIM2 单卡/双卡；通话/短信/数据；VoLTE；5G SA/NSA；切换/漫游 |
| 验收 | 按运营商能力通过；无掉网/无法呼；双卡待机稳定；SAR 区域正确 |

### 3.15 USB（HW-15）

| 项 | 内容 |
|---|---|
| 接口 | Type-C USB 2.0（480 Mbps）；OTG |
| 栈 | dwc3 + QTI USB HAL |
| 测试 | ADB/MTP/OTG/充电/耳机；插拔稳定性 |
| 验收 | 全部功能可用；无断连；OTG 供电正常 |

### 3.16 振动（HW-16）

| 项 | 内容 |
|---|---|
| 器件 | X 轴线性马达 |
| 栈 | 闭源 vibrator HAL + 内核驱动；`USE_EFFECT_STREAM=true` |
| 测试 | 强度/波形/键盘/来电/通知/游戏 |
| 验收 | 振动正常；强度可调；无杂音/卡顿 |

### 3.17 热（HW-17）

| 项 | 内容 |
|---|---|
| 热区 | 40+（aoss/cpuss/gpu/bcl-warn/modem PA/mmw/sub1 等） |
| 测试 | 待机/游戏/4K/充电/5G 下温度；热节流 |
| 验收 | 温度低于阈值；无热重启；性能降级可接受 |

### 3.18 安全/虚拟化（HW-18）

| 项 | 内容 |
|---|---|
| TEE | tz/keymaster；KeyMint |
| AVB | vbmeta/vbmeta_system/vbmeta_vendor；orange（解锁） |
| FBE | metadata 加密 |
| pVM | vm-bootsys/vm-data + Microdroid |
| 测试 | `getenforce`、`avbtool`、指纹/Keymaster、FBE、pVM |
| 验收 | Enforcing；AVB 验证；指纹/Keymaster 正常；数据加密 |

---

## 4. 存储与分区

| 分区 | 配置/实测 | 证据 | 状态 |
|---|---|---|---|
| boot | 201,326,592 B | 提取镜像 | 匹配 |
| dtbo | 25,165,824 B | 提取镜像 | 匹配 |
| vendor_boot | 201,326,592 B | 提取镜像 | 匹配 |
| recovery | 配置 104,857,600 B | BoardConfig | 待实测 |
| vendor_dlkm | 159,449,088 B | 提取镜像 | 待模块验证 |
| super | 配置 11,274,289,152 B | BoardConfig | **待设备实测** |
| userdata | 配置 112,362,319,872 B；设备 256 GB | BoardConfig vs DEVICE_REPORT | **不匹配/待确认** |
| odm | 1.25 GB 镜像 | 提取镜像 | 待实测 |
| dynamic list | odm/product/system/system_ext/vendor/vendor_dlkm | BoardConfig | 待实测 |

> 刷机前必须用 `blockdev --getsize64 /dev/block/by-name/{super,userdata,...}` 实测并对照；任何不一致先修正配置。

---

## 5. Variant 差异与风险

| 差异项 | CPH2415（目标） | CPH2417/CPH2413/NE2213 | 风险 |
|---|---|---|---|
| 型号/fingerprint | CPH2415 / Android 15 | CPH2417 Android 13；CPH2413；NE2213 Android 14 | 身份/OTA/Play Integrity |
| 相机 | 50MP+8MP+2MP | 10 Pro 为 Hasselblad 三摄，模组不同 | 相机 HAL/效果/崩溃 |
| 充电 | 150W SUPERVOOC | 10 Pro 80W | 充电策略/功率/温度 |
| 显示 | 6.7" 1080p 120Hz | 10 Pro LTPO 2.0 1440p | 面板/刷新/HDR 配置 |
| 音频 | 双扬声器 | 10 Pro 双扬声器但腔体不同 | 音频校准/音量 |
| 区域 | 全球/欧盟（CE） | FCC/其他 | SAR/运营商 |
| WiFi | 6E | 10 Pro 6E | 固件/配置 |

---

## 6. 测试映射

| 测试 ID | 覆盖硬件 | 关键证据 |
|---|---|---|
| HW-01 | SoC/CPU | `dmesg`、`/proc/cpuinfo`、cpufreq |
| HW-02 | GPU | `dumpsys SurfaceFlinger`、3D 负载 |
| HW-03 | 显示 | `dumpsys display`、亮度/HDR |
| HW-04 | 触摸 | `getevent`、多点/手势 |
| HW-05 | UDFPS | 录入/100 次解锁/HBM |
| HW-06 | 相机 | 6 ID/拍照/录像/RAW/4K |
| HW-07 | 充电 | 功率/温度/离线充电 |
| HW-08 | 音频 | 扬声器/麦克风/USB-C/蓝牙 |
| HW-09 | 传感器 | `dumpsys sensorservice` |
| HW-10 | 自动亮度 | lux 扫描/曲线 |
| HW-11 | GPS | TTFF/精度 |
| HW-12 | WiFi/BT | 连接/吞吐/音频 |
| HW-13 | NFC/eSE | 读卡/HCE/eSE |
| HW-14 | 蜂窝 | 双卡/VoLTE/5G |
| HW-15 | USB | ADB/MTP/OTG |
| HW-16 | 振动 | 强度/波形 |
| HW-17 | 热 | 压力温度 |
| HW-18 | 安全 | SELinux/AVB/Keymaster |

---

## 7. 变更记录

| 版本 | 日期 | 变更 | 作者 |
|---|---|---|---|
| 0.9 | 2026-10-31 | 首次硬件清单；基于审计与设备扫描；所有功能状态标记为待实测 | 审计 Agent |
