# DEVICE_REPORT.md — OnePlus Ace Pro / 10T (ovaltine, CPH2415) 真机全量扫描报告

> 扫描日期：2026-10-29 · 工具：adb（platform-tools 37.0.1）· 串号后段/序列号：`已脱敏`
> 方法：USB 直连，第一性原理逐子系统采集（getprop / procfs / sysfs / dumpsys / getevent），
> 原始数据存档于 `probes/device_scan/*.txt`（未做任何事后编辑）。
> 结论先行：**真机与项目底包 `CPH2415_15.0.0.1901(EX01)` 完全一致（内核/基带/指纹三重匹配），
> bootloader 已解锁，可进入 LineageOS 刷入流程。**

---

## 1. 设备身份与固件

| 项 | 值 | 来源 |
|---|---|---|
| 型号 | CPH2415（OnePlus 10T 全球版 / Ace Pro 同规格） | `ro.product.model` |
| 主板代号 | OP5552L1 | `ro.product.device` / pre-device |
| Android | 15（SDK 35） | `ro.build.version.release` |
| 构建 | `S.245f058-1f931-1f92d`（build date 2026-06-17 CST） | `ro.build.fingerprint` |
| 安全补丁 | 2026-06-01 | `ro.build.version.security_patch` |
| Oplus 基线 | `.94b04e83`（`ro.oplus.version.base`） | props |
| 当前系统指纹 | `OnePlus/CPH2415/OP5552L1:15/AP3A.240617.008/S.245f058-1f931-1f92d:user/release-keys` | props |
| **与底包一致性** | 与 OTA 卡刷包 `post-build` 完全相同（OTA metadata：post-build-incremental=S.245f058-1f931-1f92d）✓ | 交叉验证 |

**Bootloader / A-B 状态（刷机关键）**

| 项 | 值 | 含义 |
|---|---|---|
| `ro.boot.flash.locked` | **0** | **bootloader 已解锁** |
| `ro.boot.verifiedbootstate` | **orange** | AVB 处于解锁态（允许自签/第三方 boot） |
| `ro.boot.vbmeta.device_state` | unlocked | vbmeta 校验放行 |
| `ro.boot.slot_suffix` | `_a` | 当前活动槽 A（A/B 无缝升级布局） |
| `ro.boot.startupmode` | hard_reset | 最近一次启动为硬复位（非重启/充电启动） |

## 2. SoC 与 CPU 拓扑（直接读自 /proc/cpuinfo）

| 集群 | 内核 ID | ARM part | 微架构 | 实测 scaling_max_freq* |
|---|---|---|---|---|
| cpu0–3 | 小核 ×4 | `0xd46` | **Cortex-A510** | 1,804,800 kHz |
| cpu4–6 | 中核 ×3 | `0xd47` | **Cortex-A710** | 2,227,200 kHz |
| cpu7 | 大核 ×1 | `0xd48` | **Cortex-X2** | 2,592,000 kHz |

\* 扫描时设备在充电（5V/0.9A，机身 29–30°C），cpufreq 上限受热策略约束，非设计峰值
（X2 设计 3.2 GHz / A710 2.75 GHz / A510 2.0 GHz）。4+3+1 拓扑与 **Snapdragon 8+ Gen 1（SM8475, cape）** 完全一致。
`ro.soc.model=SM8475`，`ro.board.platform=taro`（SM8450 家族平台名 —— 这正是 sm8450-common 树命名来源，直接印证设备树复用关系）。
ISA 特性（AES/SHA3/SM3/SM4/I8MM/BTI/PAC 等）与 armv9 一致。

GPU：`ro.hardware.egl=adreno`、`ro.hardware.vulkan=adreno`、GLES 版本 0x30002（**OpenGL ES 3.2**）；
GPU 驱动包：`com.oplus.gpudrivers.sm8450.api31`（stable）/ `com.qualcomm.qti.gpudrivers.taro.api32`（pre-release）→ **Adreno 730**。

## 3. 内存与存储

| 项 | 值 | 来源 |
|---|---|---|
| RAM | `MemTotal: 15,576,204 kB`（16 GB 规格） | /proc/meminfo |
| Swap | 9,961,468 kB（~9.5 GB，zram/swap 分区混合策略） | /proc/meminfo |
| 用户数据 | 224 GB 总量，已用 109 GB → **256 GB 存储版本** | df |
| 布局 | **A/B + dynamic partitions（super）**：/ 750M、system_ext 899M、product 7.7M、vendor 639M、vendor_dlkm 149M、odm 1.1G、odm_dlkm 232K、my_product 1.5G、my_stock 1.9G、my_preload 1.4G、my_bigball 571M 等 | df + by-name |

分区表要点（`/dev/block/by-name/`，全部双槽）：boot、dtbo、vbmeta、vbmeta_system、vbmeta_vendor、vendor_boot、modem、bluetooth、dsp、recovery_a/b（recovery 分区在 15 上保留但 A/B 启动主用 boot）、tz/xbl/abl/hyp 等 Qualcomm 引导链、`oplusreserve1–5`、`oplusdycnvbk`（oplus 动态 NV）、`vm-bootsys_a/b` + `vm-data`（**pVM/受保护虚拟机分区，A15 Microdroid 栈**）、`mdtp`、`metadata`（FBE 元数据加密）。

## 4. 显示（dumpsys display 原始解析）

| 项 | 值 |
|---|---|
| 分辨率 | 1080 × 2412（20:9），密度 480 dpi（391.9 × 395.3）≈ 6.7" |
| 支持模式 | **120 Hz / 90 Hz / 60 Hz** 三档（modeId 1/3/2），当前渲染 120（override 层） |
| HDR | types [2(HLG), 3(Dolby-Vision 声明), 4(HDR10)]，峰值亮度 **540 nit**，平均 270.2，最低 0.4 |
| 色彩模式 | [0, 7, 9]（SRGB/DISPLAY_P3/ADOBE_RGB 类） |
| 开孔 | 顶部居中打孔（cutout inset 107px），四角圆角 r=60px |
| 面板标识 | manufacturerPnpId=**QCM**，port=130（DSI 内建屏），uniqueId `已脱敏` |
| 亮度 | brightnessDefault 4599.5（0–1 归一后 max=1.0），mAutoBrightnessAvailable=true |
| 刷新策略 | 无 LTPO 分级暴露（thermalRefreshRateThrottling 空）→ 变刷新率由 vendor 侧管理 |

> 印证：任务书"6.7" 120Hz Fluid AMOLED"无误；LineageOS 上"Force 120Hz"补丁与三档模式列表吻合。

## 5. 输入与生物识别（getevent -il）

| 设备 | 节点 | 说明 |
|---|---|---|
| `touchpanel` / `touchpanel_kpd` | event5/event6 | 屏下触摸主通道 + 按键通道（oplus 统一 touchpanel 框架） |
| `oplus_fp_input` | event2 | **UDFPS 光学指纹**专用输入设备 |
| `waipio-mtp-snd-card Headset/Button Jack` | event7/8 | 3.5mm 无 → USB-C 耳机 + 线控（音频卡名 waipio = SM8450 家族，再次印证平台） |
| `pmic_pwrkey` / `pmic_resin` | event3/4 | 电源键 / 音量（QCOM PMIC） |
| `uinput_nav` | event9 | 内核导航 uinput |

## 6. 传感器（dumpsys sensorservice，含厂商——对驱动映射至关重要）

| 传感器 | 芯片/厂商 | Android 类型 | Bring-up 关联 |
|---|---|---|---|
| 加速度计 | **BOSCH bmi26x**（非唤醒） | accelerometer(1) | 开源 IIO 驱动 |
| 陀螺仪 | **BOSCH bmi26x**（+uncal） | gyroscope(4)/(16) | 开源 IIO 驱动 |
| 磁力计 | **AKM ak0991x**（+uncal） | magnetic_field(2)/(14) | 开源 + QTI fusion |
| **环境光** | **oplus TCS3701**（"**OPLUS Fusion Light Sensor**"，type 5）+ Side Panel Fusion Light | light(5) | **与 22.1 分支补丁 `42cc1f8` "Register wise light as android.sensor.light" 语义精确对应**（patch 正是把该 oplus 私有光传感器注册为标准 light） |
| 接近 | **oplus tcs3701**（wakeup） | proximity(8) | 同芯（TCS3701 为光+接近合一） |
| 旋转向量/重力/线性加速度/游戏旋转 | QTI Fusion（软件融合） | 3/9/10/11/15 | SSP 框架 |
| 动态传感器管理 | Google Dynamic Sensor Manager | 32 | HID 传感器通道 |

## 7. 相机（dumpsys media.camera）

- 共 **6 个相机 ID**：1×前置（Facing: Front）+ **5×后置**（Facing: Back）。
- 后置 5 个 ID 中 1 个资源占用 100（主摄，50MP），其余 66 —— 符合"主摄 + 超广角 + 微距 + 逻辑多摄（logical camera 聚合 ID）"结构。
- 特性：`camera.capability.manual_sensor`、`camera.flash`、RAW（`camera.full`/`camera.raw` in common.mk 权限表）。
- 厂商栈：闭源 camx/chii（vendor blob，已由提取管线产出）+ `libcamximageformatutils.so` fixup 已验证。

## 8. 音频

- ALSA 声卡：`waipio-mtp-snd-card`（SM8450 家族标准 AGM/PAL 栈）。
- 路径配置：设备树 `audio/{backend_conf,mixer_paths,resourcemanager,usecaseKvManager}.xml`（已随 baseline 镜像在库）。
- 立体声双扬声器 + 麦克风阵列 + USB-C 音频（无 3.5mm）。

## 9. 无线连接

| 子系统 | 证据 | 说明 |
|---|---|---|
| Wi-Fi | `ro.vendor.wifi.chip` 缺省（WLAN firmware 由 modem/dsp 分区携带），qcacld-3.0 在 modules 树 | Wi-Fi 6E（WCNSS cfg 由 22.1 树携带；6GHz 修复见 21.0 release notes） |
| Bluetooth | `bluetooth_a/b` 固件分区 + `ro.bluetooth` 栈 | BT 5.2 |
| NFC | features: `nfc` / `nfc.any` / `nfc.ese` / `nfc.hce` / `nfc.hcef` | 全功能 NFC + eSE 安全元件 |
| USB | `dumpsys usb`：USB 2.0（480Mbps），MTP+ADB 当前功能 | Type-C，OTG 支持 |
| UWB | `apex/com.android.uwb@352090000` 挂载 | UWB 栈在 A15 mainline 内（10T 无 UWB 硬件，apex 为框架组件） |

## 10. 蜂窝 / 基带

| 项 | 值 | 与任务书对照 |
|---|---|---|
| 基带 | **`Q_V1_P14,Q_V1_P14`** | **与任务书锚定逐字一致** ✓ |
| SIM | `LOADED,ABSENT`（SIM1 在位，SIM2 空置），`persist.radio.multisim.config=dsds` | 双卡待机配置（5G NSA/SA：热区含 `sub1_mcg_fr1_cc`/`sub1_mcg_fr2_cc`/`sub1_scg_fr1_cc`/`sub1_scg_fr2_cc` → **FR1+FR2 双段 5G 载波管理在位**） |
| modem 固件 | `modem_a/b` + `oplusstanvbk` NV 分区 | payload 内 0.28GB modem 镜像对应 |

## 11. 电源 / 充电 / 热

- 电池：oplus 电池服务（`Current OPLUS Battery Service state`），35% / 3830 mV / 29°C，USB 充电 5V×0.9A（普通 USB 档），`ChargerTechnology: 0`（未触发快充握手——扫描时为普通 USB 口供电）。
- SUPERVOOC 专有协议栈在 vendor（闭源），150W 档位需原厂适配器 + 闭源充电 HAL，开源栈上限受此约束（HARDWARE_MATRIX"受限"结论不变）。
- 热区：aoss/cpuss/gpu/bcl-warn/modem PA/mmw/sub1 等 40+ 区，标准 QCOM 8+ Gen 1 布局。

## 12. 安全 / 虚拟化

- AVB：vbmeta + vbmeta_system + vbmeta_vendor 三链（boot/system/vendor 分区独立校验），当前 orange（解锁）。
- TEE：`tz_a/b` + `keymaster_a/b`（KeyMint TEE 版本，vendor 含 keymint-service fixup 已验证）。
- pVM：`vm-bootsys_a/b`、`vm-data` + APEX `com.android.virt@2` → Microdroid 受保护虚拟机栈完整。
- FBE 加密 + `metadata` 分区元数据加密（刷机后 LineageOS 格式化 userdata 时将重建）。
- `ro.odm_dlkm.build.fingerprint = oplus/ossi/ossi:12/SKQ1.221119.001` → **odm_dlkm 基于 Android 12 分支构建**，与 GKI 5.10 (android12-9) 一致。

## 13. 与项目底包 / 任务书的交叉验证汇总

| 验证项 | 任务书/底包 | 真机实测 | 结果 |
|---|---|---|---|
| Android/构建指纹 | 15 / S.245f058-1f931-1f92d | 同 | ✅ |
| 内核 | 5.10.236-android12-9 | `Linux version 5.10.236-android12-9-o-g55571f3ffcfa` | ✅ |
| 基带 | Q V1 P14, Q V1 P14 | `Q_V1_P14,Q_V1_P14` | ✅ |
| SoC | SM8475 (cape) | `ro.soc.model=SM8475` + CPU part 拓扑 | ✅ |
| 硬件版本 | CPH2415_11 | OTA-id CPH2415_11.H.85（本机即该版本） | ✅ |
| 显示 | 6.7" 120Hz AMOLED | 1080×2412 / 120·90·60Hz / 540nit HDR | ✅ |
| 传感器方案 | ALSPS 需 wise light 注册 | TCS3701 + OPLUS Fusion Light | ✅（补丁 `42cc1f8` 语义吻合） |

## 14. 对 HARDWARE_MATRIX 的影响（真机核验升级）

- SoC：一般 → **一般（真机核验）**：内核/拓扑/平台名三重实证（仍是"运行中的 OOS"，LineageOS 上行为待实测）。
- 显示：状态不变，但三档模式与 HDR 类型由真机 dumpsys 直接确认。
- 传感器：wise light 补丁与真机传感器清单精确对应 → 置信度提升。
- 触摸/指纹：`touchpanel` 与 `oplus_fp_input` 设备节点实证存在，UDFPS 方案与 22.1 树配置吻合。
- 蜂窝：dsds 配置 + FR1/FR2 热区实证；双卡可用性仍按"受限"填报（需 LineageOS RIL 实测）。
- 其余维持原判（LineageOS 环境下的实际表现仍需构建+刷入后验证）。

## 15. 刷机就绪度结论

bootloader 已解锁 + AVB orange + 底包/OTA 三重一致 + A/B 双槽 + super 动态分区 ——
**设备具备完整刷机前提**。风险点：解锁态下 `fastboot flash` 不会校验签名，需保证刷入镜像与
vbmeta 处理（`fastboot flash vbmeta vbmeta.img --disable-verity --disable-verification`）正确；
bootloader 解锁本身不 wipe userdata，但 LineageOS 首刷必须 `fastboot -w` / recovery format data。
