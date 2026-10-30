# ADAPTATION_LOG.md — 适配实施记录

| 项 | 值 |
|---|---|
| 文档编号 | OVL-ADAPT-2026-10-31 |
| 版本 | 1.0 |
| 日期 | 2026-10-31 |
| 设备 | OnePlus 10T（ovaltine / CPH2415） |
| 目标 | LineageOS 22.1（Android 15） |
| 执行边界 | **仅内存启动/DSU；禁止真实刷入任何分区（DECISION-006）** |
| 关联 | `AUDIT_REPORT.md`、`TASK_PLAN.md`、`SOP.md` v2.0、`patches/adaptation/` |

---

## 1. 本轮目标

在无法构建/无法刷机的约束下，先完成**静态可验证、可回滚、可审计**的源码适配：

1. 修正设备身份（CPH2417/Android 13 → CPH2415/Android 15）。
2. 端口 10T 已知修复：HBM 节点拒绝、wise-light 名称替换、rear-ALS 配置。
3. 删除已确认无引用的死配置。
4. 建立补丁应用/校验脚本，避免“手工改树后失传”。
5. 把“禁止真实刷机、仅内存/DSU”写入决策与 SOP。

---

## 2. 变更清单

### 2.1 设备身份

**文件**：`device/oneplus/ovaltine/lineage_ovaltine.mk`

| 项 | 修改前 | 修改后 |
|---|---|---|
| `PRODUCT_MODEL` | `CPH2417` | `CPH2415` |
| `BuildFingerprint` | `OnePlus/CPH2417/OP5552L1:13/SKQ1.221119.001/...` | `OnePlus/CPH2415/OP5552L1:15/AP3A.240617.008/S.245f058-1f931-1f92d:user/release-keys` |
| `DeviceProduct` | `CPH2417` | `CPH2415` |
| `SystemName` | `CPH2417` | `CPH2415` |
| `BuildDesc` | `qssi-user 13 TP1A...` | 删除（陈旧且无 timestamp 依据） |

**依据**：`DEVICE_REPORT.md` 真机 props：`ro.product.model=CPH2415`、`ro.build.fingerprint=OnePlus/CPH2415/OP5552L1:15/AP3A.240617.008/S.245f058-1f931-1f92d:user/release-keys`。

**风险**：fingerprint 采用 stock EX01；需在内存/DSU 启动后验证 vendor blob/Play Integrity/运营商逻辑是否接受。若不接受，改用 Lineage 规范 fingerprint。

### 2.2 删除死配置

**文件**：`device/oneplus/ovaltine/BoardConfig.mk`

- 删除 `BOARD_ONEPLUS_DYNAMIC_PARTITIONS_SIZE := 5637144572`。
- 依据：全构建树 `rg` 仅发现定义、无任何引用；保留会误导动态分区尺寸。
- 保留 `BOARD_SUPER_PARTITION_SIZE := 11274289152`。

### 2.3 HBM 节点拒绝

**文件**：`device/oneplus/sm8450-common/init/init.oplus.rc`

- 删除 `chown system system /sys/kernel/oplus_display/hbm`。
- 在 display 块追加 `chmod 0000 /sys/kernel/oplus_display/hbm`。
- 保留 `notify_fppress`、`panel_serial_number` 等必要节点。

**依据**：`overlay/OPlusSystemUIResTarget/res/values/config.xml` 已启用 `config_udfpsFrameworkDimming=true`；厂商 fingerprint HAL 写 HBM 会与框架调光冲突（原 `8f7dc6e` 修复）。

**验证**：`verify-tree.sh` 断言 chmod 存在、chown 不存在。

### 2.4 wise-light 名称替换

**文件**：`device/oneplus/sm8450-common/extract-files.py`

新增：

```python
'vendor/lib64/sensors.ssc.so': blob_fixup()
    .binary_regex_replace(rb'qti\.sensor\.wise_light', b'android.sensor.light\x00'),
```

**验证（对 EX01 dump 的副本执行）**：

- 源 blob：`vendor_extract/dump/vendor/lib64/sensors.ssc.so`（851,736 bytes）。
- `qti.sensor.wise_light` 出现 1 次；替换后 0 次。
- 文件大小不变（长度安全的 NUL 填充）。
- `strings` 出现 `android.sensor.light`，仍保留 `qti.sensor.light_rear`。

**重要限制**：原始 `42cc1f8` 还包括 9 字节 SIGSCAN：

```text
F1 E9 D3 84 52 49 3F A0 72 -> F1 A9 00 80 52 09 00 A0 72
```

该模式在 **EX01 blob 中出现 0 次**，不能原样移植。本轮只做名称替换；第二段代码补丁需在内存/DSU 中重新推导/验证。**不得宣称 wise-light 已完全修复。**

### 2.5 rear-ALS 配置

**文件**：`device/oneplus/sm8450-common/overlay/OPlusFrameworksResCommon/res/values/config.xml`

新增：

```xml
<string name="config_displayLightSensorType" translatable="false">qti.sensor.light_rear</string>
```

**依据**：EX01 `sensors.ssc.so` 中存在 `qti.sensor.light_rear`；原 `d3cc97a` 用后置 ALS 替代屏下 wise light。**待 DSU/内存启动后验证自动亮度曲线。**

### 2.6 补丁自动化

新增：

- `scripts/apply-patches.sh`：按顺序应用 EX01 适配 + 本轮适配；`git apply --check` 先验，已应用则跳过；失败即停。
- `scripts/verify-tree.sh`：静态断言身份/HBM/wise-light/ALS/EX01。
- `patches/adaptation/README.md` + 3 个补丁。

**验证输出**：

```text
[s] already applied: EX01 patches (2)
[s] already applied: adaptation patches (3)
[ok] device model is CPH2415
[ok] device fingerprint is CPH2415/Android 15
[ok] no stale CPH2417 identity
[ok] no dead dynamic-partition variable
[ok] HBM node denied to vendor HAL
[ok] HBM node is not chowned to system
[ok] wise-light name replacement present
[ok] rear-ALS config present
[ok] rear-ALS sensor type set
[ok] EX01 fingerprint AIDL manifest
[ok] old fingerprint manifest unpinned
[ok] EX01 Pixelworks service removal
VERIFY OK
```

---

## 3. 变更文件与补丁

| 补丁 | 目标树 | 文件 |
|---|---|---|
| `patches/adaptation/0001-device-ovaltine-fix-identity-and-dead-config.patch` | device/oneplus/ovaltine | `lineage_ovaltine.mk`、`BoardConfig.mk` |
| `patches/adaptation/0002-common-hbm-deny-access.patch` | device/oneplus/sm8450-common | `init/init.oplus.rc` |
| `patches/adaptation/0003-common-wise-light-and-rear-als.patch` | device/oneplus/sm8450-common | `extract-files.py`、`overlay/.../config.xml` |

补丁均可对基线 `59052db` / `258dbbd` 通过 `git apply --check`。

---

## 4. 静态验证

| 检查 | 结果 |
|---|---|
| `python3 -m py_compile extract-files.py` | 通过 |
| overlay `config.xml` XML 解析 | 通过 |
| sensor blob 替换 | 长度不变；wise 0；light/rear 存在 |
| `apply-patches.sh` 幂等 | 已应用项全部 skip |
| `verify-tree.sh` | 18 项 OK，VERIFY OK |

---

## 5. 未完成/待验证

| 项 | 状态 | 说明 |
|---|---|---|
| 实际构建 | 阻塞 | 仍需 Linux x86_64 / 32 GB+ 宿主；当前 macOS 16 GB 不适用 |
| 内存启动 | 未执行 | 无构建产物；设备审计时未连接 |
| DSU | 未执行 | 无系统镜像；DSU 命令需按设备/Android 版本确认 |
| wise-light SIGSCAN 第二段 | 未完成 | EX01 blob 无旧模式；需反汇编/运行时验证 |
| 自动亮度曲线 | 未验证 | 需 DSU/内存启动 + 真实光照 |
| 指纹 HBM 冲突 | 未验证 | 静态修复已加；需 100 次解锁测试 |
| 身份/fingerprint 兼容 | 未验证 | 需 vendor blob/Play Integrity/运营商测试 |
| 相机/音频/充电等 | 未验证 | 见 `HARDWARE_INVENTORY.md` |

---

## 6. 下一步

1. T-01：准备 Linux 构建宿主，完成 `brunch` 全绿。
2. T-02：把完整 manifest/补丁脚本纳入构建；生成产物 SHA256。
3. T-09/T-10：按 `SOP.md` v2.0 做 `fastboot boot`/DSU 进出演练（0 分区写入）。
4. T-11：在 DSU/内存启动中验证 HBM/wise-light/ALS/身份，再跑硬件矩阵。
5. T-13：处理 SPL/AVB/SELinux；T-14：发布门禁。

> 本记录只证明“静态适配已落地”，不证明“设备上可用”。在 Linux 构建和 DSU/内存启动验证完成前，所有硬件状态仍为“未验证”。

---

## 7. 变更记录

| 版本 | 日期 | 变更 | 作者 |
|---|---|---|---|
| 1.0 | 2026-10-31 | 首轮静态适配：身份、HBM、wise-light 名称替换、rear-ALS、补丁脚本、禁刷约束 | 审计 Agent |
