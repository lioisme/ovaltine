# OnePlus 10T（ovaltine / CPH2415）驱动清单

| 项 | 值 |
|---|---|
| 文档编号 | OVL-DRV-2026-10-31 |
| 版本 | 0.9（审计草案） |
| 日期 | 2026-10-31 |
| 设备 | OnePlus Ace Pro / 10T，codename `ovaltine`，CPH2415 |
| 目标 | LineageOS 22.1（Android 15） |
| 依据 | 业主驱动原则；`AUDIT_REPORT.md`；`HARDWARE_INVENTORY.md`；baseline/构建树源码；EX01 dump |
| 状态 | **清单为审计草案；开源/闭源分类与许可证需 SPDX/SBOM 二次确认；所有“可用”需 E4 实测；测试仅限内存启动/DSU（DECISION-006）** |

---

## 1. 驱动原则与分级

业主原则（逐级优先）：

1. 官方开源
2. 同硬件其它设备的官方开源
3. 兄弟硬件的开源
4. 基于社区适配的开源/兄弟硬件开源进行适配
5. 同原理重写适配/桥接封装
6. 逆向

本项目实际采用：**内核/平台驱动尽量开源；不可替代的 vendor 组件用闭源 blob；每个子系统保留回退方案。** 任何闭源 blob 必须记录来源、版本、许可证、风险与替代路径。

### 1.1 分类

| 分类 | 含义 | 本项目示例 |
|---|---|---|
| OSS-Official | 官方开源 | Linux kernel、AOSP/Lineage 框架、QCOM CAF 内核驱动 |
| OSS-Sibling | 兄弟硬件开源 | sm8450-common、OnePlus 10 Pro/10T 社区树 |
| OSS-Community | 社区适配开源 | lineage-ovaltine-dev、pjgowtham 设备树/common |
| Bridge/Rewrite | 桥接/重写 | HBM/wise-light/ALS 的 extract-files 修复、shim 库 |
| Proprietary | 闭源 blob/固件 | camera、display、audio、fingerprint、RIL、WiFi/BT、GNSS、charging |
| Reverse | 逆向 | 本项目未采用；如采用需法律/业主批准 |

---

## 2. 驱动总表

| 子系统 | 内核驱动/来源 | 用户态 HAL/来源 | 固件/Blob | 开源/闭源 | 版本/commit | 状态 | 回退 |
|---|---|---|---|---|---|---|---|
| SoC/CPU | Linux 5.10 GKI + QCOM CAF（kernel/oneplus/sm8450） | AOSP/Lineage | 无（microcode 随内核/固件） | 开源（GPL-2.0） | `63aeb92d` | 待 E4 | 底包 boot 内核 |
| GPU | msm DRM/kgsl（kernel） | Adreno EGL/Vulkan blob | `vendor/lib64/egl/*adreno*`、GPU 微码 | 混合 | kernel `63aeb92d`；blob EX01 | 待 E4 | 闭源 GPU 栈 |
| 显示 | `qcom/opensource/display-drivers/msm`（kernel modules） | OSS composer + 闭源 HWC/HDR 组件 | `vendor/bin/hw/vendor.qti.hardware.display.composer-service`、`libdisplayconfig`、`libsnapdragoncolor*`、`libpwirisfeature` | 混合 | modules `cb014aff`；blob EX01 | 待 E4 | 闭源 display 栈 |
| 触摸 | Oplus touch 内核驱动（modules） | `vendor.lineage.touch@1.0-service.oplus`（hardware/oplus） | 触摸固件（`/odm/firmware/tp`） | 开源 HAL + 闭源固件 | hardware/oplus `37e78750` | 待 E4 | 通用触摸 HAL |
| UDFPS | 内核 HBM/display 节点 | fingerprint HAL 2.3（hardware/oplus）+ `libudfps_extension.oplus` | `vendor.oplus.hardware.biometrics.fingerprint@2.1-service_uff` 等 | 混合 | hardware/oplus `37e78750`；blob EX01 | **HBM 静态修复，待验证** | 关闭框架调光/恢复 HBM 权限（不推荐） |
| 相机 | `qcom/opensource/camera-kernel`（modules） | camx/chii 闭源 HAL | `vendor/lib64/libcamx*`、`libchii*`、`libAlgoProcess`、`CameraHWConfiguration.config` | 闭源为主 | modules `cb014aff`；blob EX01 | 待 E4 | 主摄/基础拍照；aux 修复 |
| 充电/电池 | QCOM/oplus 充电驱动（kernel） | 闭源 oplus 充电 HAL/服务 | `vendor/bin/hw/*charger*`、oplus battery 服务 | 混合 | kernel `63aeb92d`；blob EX01 | 待 E4；150W 预计受限 | 普通 USB/PD 充电；关闭快充 |
| 音频 | `qcom/opensource/audio-kernel`（modules） | `android.hardware.audio.service` + PAL/AGM（闭源部分） | `audio.primary.taro`、`libpal*`、`libagm*`、`libar-*`（部分源码/部分 blob） | 混合 | modules `cb014aff`；hardware/qcom-caf `sm8450` | 待 E4 | 基础音频通路 |
| 传感器 | SSC/IIO 内核驱动（modules） | `sensors.oplus` + `sensors.dynamic_sensor_hal` | `vendor/lib64/sensors.ssc.so`、`libsnsapi.so`、`libssc.so` | 混合 | hardware/oplus `37e78750`；blob EX01 | **名称替换+ALS 静态，SIGSCAN 待验证** | 标准 light sensor 注册 |
| GPS/GNSS | 内核 GNSS 驱动（modules） | GNSS AIDL HAL（闭源） | `android.hardware.gnss-aidl-service-qti`、`libgarden.so`、`gps.conf` | 闭源 HAL | blob EX01 | 待 E4 | 仅 GPS/AGPS |
| WiFi | qcacld-3.0（modules） | `android.hardware.wifi-service` + wpa_supplicant | `bdwlan.b0a`、`WCNSS_qcom_cfg.ini`、`libwifi-hal-qcom.so` | 混合 | modules `cb014aff` | 待 E4 | 2.4/5GHz；6E 降级 |
| BT | QCOM BT 驱动（modules） | BT HAL + `libbt-vendor` | `bluetooth_a/b` 固件、`bdroid_buildcfg.h` | 混合 | modules `cb014aff` | 待 E4 | 基础 BT/LE |
| NFC/eSE | NXP NFC 驱动（kernel） | 闭源 NFC HAL | `libnfc-nci`/`libnfc-nxp`、eSE | 闭源 | blob EX01 | 待 E4 | 关闭 NFC |
| 蜂窝/RIL | QCOM 内核驱动（modules） | 闭源 RIL/QMI | `libqcrilNr.so`、`libril-db.so`、modem 固件 | 闭源 | blob EX01 | 待 E4 | 单卡/基础数据 |
| USB | dwc3（kernel） | `android.hardware.usb-service.qti`、gadget HAL | `usb_compositions.conf` | 开源/半开源 | kernel `63aeb92d` | 待 E4 | 仅 ADB/充电 |
| 振动 | QCOM/oplus 振动驱动（kernel） | `vendor.qti.hardware.vibrator.service.oplus`（hardware/oplus） | 效果配置 | 混合 | hardware/oplus `37e78750` | 待 E4 | 基础振动 |
| 热 | QCOM thermal（kernel） | `android.hardware.thermal-service.qti` | 热区配置 | 开源/半开源 | kernel `63aeb92d` | 待 E4 | 内核热节流 |
| KeyMint/TEE | QSEE/TEE（kernel/firmware） | `android.hardware.security.keymint-service-qti` | `libqtikeymint.so`、tz/keymaster 固件 | 混合 | blob EX01 | 待 E4 | 无（TEE 不可替代） |
| DRM/Widevine | 无（用户态） | `libwvdrmengine.so`、`libwvhidl.so` | 闭源 | 闭源 | blob EX01 | 待 E4 | L3/无 DRM |

> 版本/commit 为审计时基线；闭源 blob 的“版本”以 EX01 dump 的 SHA256 为准，待 T-05 建立 SBOM。

---

## 3. 内核与开源驱动

### 3.1 内核主树

| 项 | 值 |
|---|---|
| 仓库 | `lineage-ovaltine-dev/android_kernel_oneplus_sm8450` |
| 分支/commit | `lineage-22.1` @ `63aeb92d069b`（2025-05-01，ASB-2025-04） |
| License | GPL-2.0（Linux kernel） |
| 配置 | `gki_defconfig` + `vendor/waipio_GKI.config` + `vendor/oplus_GKI.config` + `vendor/debugfs.config` + `vendor/oplus/ovaltine.config` |
| 关键 | `CONFIG_MODVERSIONS=y`、`CONFIG_KALLSYMS_ALL=y`；`CONFIG_DEBUG_FS=n`（debugfs.config） |
| 风险 | modules 树 2023-07 与 kernel 2025-05 错位；`CONFIG_LOCALVERSION="-gki"`；预编译模块 vermagic 不一致 |

### 3.2 设备树仓库

| 项 | 值 |
|---|---|
| 仓库 | `lineage-ovaltine-dev/android_kernel_oneplus_sm8450-devicetrees` |
| 分支/commit | `lineage-22.1` @ `c05fa09edcb9`（2024-08-27） |
| License | GPL-2.0 |
| 内容 | `qcom/cape-*.dtsi`、thermal/regulators/GPU/USB 等 |
| 风险 | 与 kernel/modules 时间线不一致；DTS 需与 EX01 底包核对 |

### 3.3 内核模块树

| 项 | 值 |
|---|---|
| 仓库 | `lineage-ovaltine-dev/android_kernel_oneplus_sm8450-modules` |
| 分支/commit | `lineage-22.1` @ `cb014aff7629`（**2023-07-11**） |
| License | GPL-2.0 / 部分 Qualcomm 许可 |
| 关键模块 | display-drivers/msm、audio-kernel、camera-kernel、dataipa、datarmnet、qcacld-3.0、eva-kernel、video-driver 等 |
| 风险 | 陈旧；与 kernel API/ABI 可能不匹配；需 `modinfo`/CRC 验证 |

### 3.4 开源 HAL/服务（hardware/oplus）

| 模块 | 路径 | License | 说明 |
|---|---|---|---|
| `libudfps_extension.oplus` | `hardware/oplus/fingerprint` | Apache-2.0 | UDFPS 扩展 |
| `vendor.lineage.touch@1.0-service.oplus` | `hardware/oplus/hidl/touch` | Apache-2.0 | 触摸手势/高采样率 |
| `vendor.lineage.livedisplay@2.1-service.oplus` | `hardware/oplus/hidl/livedisplay` | Apache-2.0 | LiveDisplay |
| fingerprint 2.3 service | `hardware/oplus/hidl/fingerprint` | Apache-2.0 | 指纹 HAL 包装 |
| `vendor.oplus.hardware.osense.client-service` | `hardware/oplus/aidl/osense-client` | Apache-2.0 | OSense |
| `vendor.qti.hardware.vibrator.service.oplus` | `hardware/oplus/aidl/vibrator/qti` | Apache-2.0 | 振动 |
| `sensors.oplus` | `hardware/oplus/sensors` | Apache-2.0 | 传感器 HAL |
| bootctrl/fastboot/gpt-utils | `hardware/oplus/*` | Apache-2.0 | 启动/分区 |

> License 以源码 SPDX 头为准；T-05 做全量 SPDX 扫描后更新。

### 3.5 设备树/common

| 项 | 值 |
|---|---|
| device/ovaltine | Apache-2.0；`59052db`；身份已静态改为 CPH2415/Android 15（待 DSU 验证） |
| common（选定） | Apache-2.0；pjgowtham `258dbbd`；blob 来源 NE2213/Android 14 |
| hardware/oplus（上游） | Apache-2.0；`37e78750`；模块齐全 |
| 风险 | 设备/common 跨 variant；HBM/名称/ALS 静态补丁已加，SIGSCAN/运行时待验证 |

---

## 4. 闭源组件清单（按子系统）

> 以下为“不可替代/暂不可替代”的 vendor 组件。完整逐文件清单见两棵树的 `proprietary-files.txt` 与 T-05 的 SBOM。

### 4.1 显示/GPU

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| Adreno GPU 用户态 | `vendor/lib64/egl/*adreno*`、`vendor/lib64/*gsl*` | EGL/Vulkan/GLES | 无开源替代；回退 stock GPU 栈 |
| display composer/HWC | `vendor/bin/hw/vendor.qti.hardware.display.composer-service` | 合成/显示 | OSS composer 已用；HWC 闭源 |
| display config/HDR | `vendor/lib64/libdisplayconfig.so`、`libsnapdragoncolor*` | 色彩/HDR | 回退基础显示 |
| Pixelworks | `libpwirisfeature.so`、`libpwirishalwrapper.so`、`libsnapdragoncolor-pxlw.so` | 显示增强 | 可禁用（EX01 服务已移除） |

### 4.2 相机

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| camx/chii | `vendor/lib64/libcamx*`、`libchii*` | 相机 HAL/算法 | 无开源替代；回退基础拍照 |
| Oplus camera service | `odm/bin/hw/vendor.oplus.hardware.cammidasservice-V1-service` | 相机中间件 | 依赖 blob |
| 算法库 | `libAlgoProcess.so`、`libarcsoft_*`、`libSuperRaw.so` | 多帧/HDR/超分 | 关闭高级效果 |
| 配置 | `odm/etc/camera/CameraHWConfiguration.config` | 相机能力/aux | 已应用 aux 解锁 |

### 4.3 音频

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| audio HAL | `vendor/bin/hw/android.hardware.audio.service` | 音频服务 | 回退基础通路 |
| PAL/AGM | `libpal*`、`libagm*`、`audio.primary.taro` | 音频通路 | 部分源码/部分 blob |
| 效果 | `libqcomvoiceprocessing`、`libqcomvisualizer` 等 | 降噪/音效 | 可禁用 |

### 4.4 指纹/UDFPS

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| fingerprint HAL | `vendor.oplus.hardware.biometrics.fingerprint@2.1-service_uff` | 指纹服务 | HBM `chmod 0000` 已加；待验证 |
| OLC/CommonDCS | `libolc_vnd.so`、`vendor.oplus.hardware.commondcs-V1-ndk_platform.so` | 指纹算法/通信 | 依赖 blob |
| 固件 | `odm/vendor/firmware/uff_jv.b00` | 指纹固件 | 不可替代 |

### 4.5 充电/电池

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| oplus charger service | `vendor/bin/hw/*charger*` | 快充协议 | 150W 预计受限；回退普通充电 |
| battery/health | `vendor/bin/hw/android.hardware.health-service.qti` | 电池健康 | 回退 AOSP health |
| 充电配置 | `init.oplus.hw.rc`/`init.oplus.rc` | 充电节点 | 需权限/温控验证 |

### 4.6 传感器

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| sensors.ssc | `vendor/lib64/sensors.ssc.so` | 传感器 HAL | 名称替换已加；SIGSCAN 第二段待验证 |
| SSC 库 | `libsnsapi.so`、`libssc.so`、`libsnsdiaglog.so` | SSC 通信 | 依赖 blob |
| 配置 | `vendor/etc/sensors/hals.conf`、`sensors.ssc.so` | HAL 注册 | 需与 overlay 对齐 |

### 4.7 GNSS

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| GNSS AIDL HAL | `android.hardware.gnss-aidl-service-qti` | 定位 | 依赖 blob/固件 |
| garden | `libgarden.so`、`libgarden_haltests_e2e.so` | 测试/辅助 | 可移除测试库 |
| 配置 | `odm/etc/gps.conf` | AGPS/NTP | 需区域校验 |

### 4.8 蜂窝/RIL

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| RIL | `libqcrilNr.so`、`libril-db.so`、`qcril*` | 电话/数据 | 闭源；双卡/5G 待测 |
| modem 固件 | `modem` 分区（0.28 GB） | 基带 | 不可替代；备份/恢复 |
| IMS | `ims*` 库/服务 | VoLTE/VoWiFi | 依赖运营商 |

### 4.9 WiFi/BT/NFC

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| WLAN 驱动 | `qcacld-3.0`（modules） | WiFi | 开源；固件闭源 |
| WLAN 固件 | `bdwlan.b0a`、`WCNSS_qcom_cfg.ini` | 射频 | 区域/6E 待测 |
| BT 固件 | `bluetooth_a/b`、`bdroid_buildcfg.h` | BT | 版本/区域 |
| NFC | `libnfc-nci`/`libnfc-nxp`、`nfc_nci*` | NFC/eSE | 闭源 HAL |

### 4.10 安全/DRM

| 组件 | 路径示例 | 作用 | 风险/回退 |
|---|---|---|---|
| KeyMint | `android.hardware.security.keymint-service-qti`、`libqtikeymint.so` | 密钥/TEE | 不可替代 |
| Widevine | `libwvdrmengine.so`、`libwvhidl.so` | DRM | 可禁用（L3/无 DRM） |
| TEE 固件 | `tz_a/b`、`keymaster_a/b` | 安全世界 | 不可替代 |

---

## 5. 固件清单（部分）

| 分区/路径 | 内容 | 备份 | 风险 |
|---|---|---|---|
| `modem` / `modem_a/b` | 基带固件 | P0 | 丢失导致无信号 |
| `bluetooth` / `bluetooth_a/b` | BT 固件 | P1 | BT 异常 |
| `dsp` / `dsp_a/b` | DSP 固件 | P1 | 音频/传感器异常 |
| `vendor/firmware/*` | WLAN/GPU/触控等 | P1 | 硬件异常 |
| `odm/firmware/*` | 指纹/触控/相机等 | P1 | 指纹/相机异常 |
| `persist` | 校准/DRM/传感器 | P0 | 不可再生 |
| `modemst1/2`、`fsg`、`fsc` | 基带校准 | P0 | IMEI/信号 |
| `oplusdycnvbk` | OPlus 动态 NV | P0 | 设备身份/校准 |

---

## 6. 驱动缺口与风险

| ID | 缺口 | 影响 | 整改 | 验收 |
|---|---|---|---|---|
| DRV-001 | HBM 修复缺失 | UDFPS 闪烁/失败 | 已加 `chmod 0000`（静态）；待验证 | 100 次解锁 0 失败 |
| DRV-002 | wise-light/rear-ALS 缺失 | 自动亮度异常 | 名称替换 + overlay 已加；SIGSCAN 待重推导 | 亮度曲线通过 |
| DRV-003 | 补丁链不可应用 | 已知修复未生效 | apply/verify 脚本 + 本轮补丁已完成；完整 manifest 已生成 | 全补丁 apply/断言通过 |
| DRV-006 | kernel/modules/devicetree 错位 | 模块加载失败 | 三元组配套 | modinfo/insmod 通过 |
| DRV-007 | 预编译 vendor_dlkm 回退未落地 | 回退不可用 | 明确来源/vermagic/CRC | 模块可加载 |
| DRV-008 | 无驱动版本/许可证/测试 ID | 不可审计 | 清单 + blob SHA-256 清单已加；SBOM 待 | 每项有来源/许可证/测试 |
| — | 闭源 blob 法律状态 | 发布风险 | 法务/SBOM | 书面确认 |
| — | 10 Pro common 跨机型 | 相机/音频/充电异常 | T-04 对齐 | 真机通过 |

---

## 7. 驱动测试映射

| 驱动/子系统 | 测试 ID | 关键检查 |
|---|---|---|
| SoC/CPU | HW-01 | `dmesg`、cpufreq、suspend |
| GPU | HW-02 | SurfaceFlinger、3D 负载 |
| Display | HW-03 | dumpsys display、HDR、亮度 |
| Touch | HW-04 | getevent、多点、手势 |
| UDFPS | HW-05 | 100 次解锁、HBM、avc |
| Camera | HW-06 | 6 ID、拍照/录像/RAW |
| Charging | HW-07 | 功率/温度/离线充电 |
| Audio | HW-08 | 扬声器/麦克风/USB-C/蓝牙 |
| Sensors | HW-09/10 | 全类型、自动亮度 |
| GNSS | HW-11 | TTFF/精度 |
| WiFi/BT | HW-12 | 连接/吞吐/音频 |
| NFC | HW-13 | 读卡/HCE/eSE |
| Cellular | HW-14 | 双卡/VoLTE/5G |
| USB | HW-15 | ADB/MTP/OTG |
| Vibrator | HW-16 | 强度/波形 |
| Thermal | HW-17 | 压力温度 |
| Security | SC-01～08 | SELinux/AVB/Keymaster |

---

## 8. 许可证与 SBOM 待办

- [ ] 对 device/common/hardware/oplus/kernel 做 SPDX 扫描（`reuse`/`scancode`）。
- [ ] 为每个闭源 blob 记录来源分区/路径/SHA256/许可证/可再分发状态。
- [ ] 生成 `SBOM.csv`/`SBOM.json`；发布包附 `NOTICE`/`CREDITS`。
- [ ] 对 GPL-2.0 内核与 Apache-2.0 设备树做许可证兼容性检查。
- [ ] 对 Qualcomm/OnePlus 专有许可做法律评估；默认不分发 blob。
- [ ] 对 shim 库（`libcrypto_shim`、`libgui_shim`、`libbinder_shim` 等）记录来源/许可证。

---

## 9. 变更记录

| 版本 | 日期 | 变更 | 作者 |
|---|---|---|---|
| 0.9 | 2026-10-31 | 首次驱动清单；按开源/闭源/回退分类；标注 HBM/wise-light/内核错位风险 | 审计 Agent |
