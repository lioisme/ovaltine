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

### 2.7 完整 pinned manifest

- 在 `/Volumes/los-build/aosp` 执行 `repo manifest -r -o manifests/lineage-22.1-20261031.xml`。
- 生成 1474 个 `<project>`，全部带 40 位 revision。
- 生成时 `default.xml` 含 USTC 镜像；已把 `aosp` remote 还原为 `https://android.googlesource.com`，镜像覆盖应由 local manifest/脚本处理。
- 新增 `manifests/README.md`，说明基础 manifest `46ed254`、6 个本地工程、shallow `frameworks/base` 例外、补丁不包含在 manifest 内。

### 2.8 Vendor blob SHA-256 清单

- 对 `scratch/vendor/oneplus` 生成 `artifacts/blob-manifest.sha256`：2688 个文件（ovaltine 1419 + common 1269），约 2.3 GB。
- 校验：`2688/2688 OK`。
- 新增 `tools/verify_vendor_blobs.sh`，可在 `scratch/vendor` 或构建树 `vendor` 上校验。
- 已把 wise-light 名称替换应用到 `scratch/vendor` 与构建树 `vendor` 的 `sensors.ssc.so`；替换后大小不变，`qti.sensor.wise_light` 为 0。
- 新增 `BLOB_PROVENANCE.md` 记录规模、已应用适配、覆盖缺口（源 pin 仍 3/1415、0/1265；SBOM/许可证未完成）。

### 2.9 macOS `$T` 构建阻塞修复

- `build/soong/soong_ui.bash` 的 Darwin 分支在 `set -u` 下引用未定义 `$T`；改为用脚本路径推导 `SOONG_TOP`。
- 导出 `patches/macos-build/0003-soong-ui-darwin-trace-top.patch`；`scripts/apply-patches.sh` 在 `APPLY_MAC_PATCHES=1` 且 Darwin 时应用。
- `bash -n build/soong/soong_ui.bash` 通过；`breakfast ovaltine` 已不再出现 `$T: unbound variable`。
- 新增 `patches/macos-build/README.md`，明确 macOS 仅为实验环境、0002 全局跳过 Go 测试的已知缺陷。

### 2.10 macOS `repolastsync` 的 GNU date 兼容

- `vendor/lineage/build/envsetup.sh` 的 `repolastsync` 在 Darwin 使用 `gdate`/`gstat`，缺失时输出 unknown；Linux 保持原行为。
- 导出 `patches/macos-build/0004-lineage-envsetup-portable-date.patch` 并接入 `apply-patches.sh`（Darwin + `APPLY_MAC_PATCHES=1`）。
- 残留：`build/make/core/version_util.mk` / `main.mk` 仍使用 GNU `date -d`，`breakfast` 仍会打印 `date: illegal option -- d`，但不阻塞；AUDIT BLD-006 仍未关闭。

### 2.11 GitHub 公开仓库、历史脱敏与 CI

- 目标远端：`https://github.com/lioisme/ovaltine`（public，空仓库，默认 `main`）；SSH 443 认证可用。
- **公开前脱敏**：设备序列号与 display uniqueId 已从 `DEVICE_REPORT.md`、`BUILD_LOG.md`、`AUDIT_REPORT.md` 移除；`git filter-branch` 重写全部历史，旧 refs 已删除并 `git gc --prune=now`；`git log --all -S` 敏感串为空。
- 公开仓库不含 `baseline/`、`scratch/`、`vendor_extract/`、`.venv/`、`probes/device_scan/`、底包 zip、vendor blob；`.gitignore` 已覆盖。
- 新增 `.github/workflows/static-ci.yml`：标准 runner 上验证补丁可应用性、1474 工程 manifest、2688 条 blob 清单、脚本语法与禁刷策略。
- 新增 `.github/workflows/aosp-build.yml`：手动全量构建；要求 larger/self-hosted runner（32 GB+ RAM、400 GB+ 磁盘），vendor 归档通过 `VENDOR_ARCHIVE_URL`/`VENDOR_ARCHIVE_SHA256` secrets 提供；标准 runner preflight 直接拒绝。
- 新增 `CI.md` 说明标准 GitHub runner 无法全量构建 AOSP、vendor 归档如何制作/配置、artifact 策略（默认只上传日志/校验和，不上传 system/vendor/OTA）。
- 当前仍缺 vendor 归档 secret 与足够大的 runner，因此 `aosp-build` 尚未运行；`static-ci` 将在首次 push 后自动运行。
- **static-ci 结果**：首次失败（raw `git clone` + 未使用的 apt 依赖）；改为 `actions/checkout` 拉取 pinned ref、移除无关 apt 包后，run 41105251333 @ `a76644e` **success**。badge: passing。
- 公开仓库远端：`origin` = `ssh://git@ssh.github.com:443/lioisme/ovaltine.git`；已推送 `main` 与 `audit-2026-10-31`。

---

## 3. 变更文件与补丁

| 补丁 | 目标树 | 文件 |
|---|---|---|
| `patches/adaptation/0001-device-ovaltine-fix-identity-and-dead-config.patch` | device/oneplus/ovaltine | `lineage_ovaltine.mk`、`BoardConfig.mk` |
| `patches/adaptation/0002-common-hbm-deny-access.patch` | device/oneplus/sm8450-common | `init/init.oplus.rc` |
| `patches/adaptation/0003-common-wise-light-and-rear-als.patch` | device/oneplus/sm8450-common | `extract-files.py`、`overlay/.../config.xml` |
| `patches/macos-build/0003-soong-ui-darwin-trace-top.patch` | build/soong | `soong_ui.bash` |
| `patches/macos-build/0004-lineage-envsetup-portable-date.patch` | vendor/lineage | `build/envsetup.sh` |

补丁均可对基线 `59052db` / `258dbbd` / 构建树 `build/soong` 通过 `git apply --check` 或反向检查。

---

## 4. 静态验证

| 检查 | 结果 |
|---|---|
| `python3 -m py_compile extract-files.py` | 通过 |
| overlay `config.xml` XML 解析 | 通过 |
| sensor blob 替换 | 长度不变；wise 0；light/rear 存在 |
| `apply-patches.sh` 幂等 | 已应用项全部 skip |
| `verify-tree.sh` | 18 项 OK，VERIFY OK |
| 完整 pinned manifest | 1474 工程，全部 40 位 revision |
| blob 清单 | 2688/2688 OK |
| `soong_ui.bash` `bash -n` | 通过 |

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
| 1.1 | 2026-10-31 | 增加完整 pinned manifest（1474 工程）、blob SHA-256 清单（2688 文件）、macOS `$T` 修复 |
| 1.2 | 2026-10-31 | 公开仓库前历史脱敏、GitHub Actions static-ci/aosp-build、CI.md | 审计 Agent |
