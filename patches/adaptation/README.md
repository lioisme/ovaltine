# patches/adaptation — 2026-10-31 适配补丁

这些补丁基于**最终选定的基线**生成，必须按以下顺序应用：

1. `patches/ex01-adaptation/*.patch`（EX01 底包适配）
2. `patches/adaptation/*.patch`（本轮身份/HBM/光感修复）

## 补丁清单

| 补丁 | 目标树 | 内容 | 证据 |
|---|---|---|---|
| `0001-device-ovaltine-fix-identity-and-dead-config.patch` | `device/oneplus/ovaltine` | `PRODUCT_MODEL`/`DeviceProduct`/`SystemName` 改为 CPH2415；fingerprint 改为 CPH2415 EX01 Android 15；删除未使用的 `BOARD_ONEPLUS_DYNAMIC_PARTITIONS_SIZE` | `DEVICE_REPORT.md` 的 `ro.product.model`/`ro.build.fingerprint`；全构建树 `rg` 确认该变量无引用 |
| `0002-common-hbm-deny-access.patch` | `device/oneplus/sm8450-common` | 移除 HBM 节点 chown，追加 `chmod 0000` | 选定树 `init.oplus.rc:16` 原为 chown；overlay 已开启 `config_udfpsFrameworkDimming=true` |
| `0003-common-wise-light-and-rear-als.patch` | `device/oneplus/sm8450-common` | `sensors.ssc.so` 将 `qti.sensor.wise_light` 长度安全替换为 `android.sensor.light\0`；overlay 设置 `config_displayLightSensorType=qti.sensor.light_rear` | EX01 blob 中 `qti.sensor.wise_light` 出现 1 次；替换后长度不变，`strings` 验证通过；`qti.sensor.light_rear` 在 blob 中存在 |

## 重要限制（0003）

原始 `42cc1f8` 补丁还包括一个 9 字节 SIGSCAN 代码补丁：

```text
F1 E9 D3 84 52 49 3F A0 72 -> F1 A9 00 80 52 09 00 A0 72
```

实测该模式在 **CPH2415 EX01 的 `sensors.ssc.so` 中出现 0 次**，不能原样移植。本补丁只做长度安全的字符串替换；第二段代码补丁需要在真机/DSU 上重新推导和验证（见 `AUDIT_REPORT.md` DRV-002、`ADAPTATION_LOG.md`）。

## 应用

```bash
export AOSP_ROOT=/path/to/aosp
./scripts/apply-patches.sh
./scripts/verify-tree.sh
```

`apply-patches.sh` 会先 `git apply --check`，已应用则跳过，失败则停止；`verify-tree.sh` 断言关键行存在/不存在。
