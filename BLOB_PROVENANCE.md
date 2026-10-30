# BLOB_PROVENANCE.md — Vendor blob 溯源与校验

| 项 | 值 |
|---|---|
| 日期 | 2026-10-31 |
| 来源底包 | `CPH2415_15.0.0.1901_EX01.zip`（OnePlus 10T，Android 15） |
| 提取产物 | `scratch/vendor/oneplus/{ovaltine,sm8450-common}` |
| 校验清单 | `artifacts/blob-manifest.sha256`（2688 个文件） |
| 校验结果 | 2688/2688 OK（`shasum -a 256 -c`） |
| 关联 | `AUDIT_REPORT.md` ID-003/ID-004/SEC-005；`TASK_PLAN.md` T-05 |

---

## 1. 产物规模

| 树 | 文件数（清单） | 目录大小 | 说明 |
|---|---:|---:|---|
| `vendor/oneplus/ovaltine` | 1419 | 1.8 GB | 10T 设备专属 blob + 生成的 makefile |
| `vendor/oneplus/sm8450-common` | 1269 | 572 MB | pjgowtham common blob + 生成的 makefile |
| 合计 | **2688** | 约 2.3 GB | 不含 `vendor_extract/dump` 原始展开 |

> 文件数包含 `Android.bp`/`Android.mk`/`BoardConfigVendor.mk`/`*-vendor.mk` 等生成文件；纯 blob 条目约 1415 + 1265。

## 2. 当前已应用的适配

| 适配 | 证据 |
|---|---|
| EX01 指纹 VINTF 路径改为 `manifest_oplus_fingerprint_aidl.xml` | `patches/ex01-adaptation/0001-ovaltine-...patch` |
| EX01 移除 Pixelworks iris 服务/rc/vintf/特定库 | `patches/ex01-adaptation/0001-sm8450-common-...patch`；dump 中确认 |
| `CameraHWConfiguration.config` aux camera 解锁 | 提取后 `SystemCamera = 0; 0; 0; 0; 0; 0;` |
| wise-light 名称替换 | `sensors.ssc.so` 中 `qti.sensor.wise_light` → `android.sensor.light\0`；长度不变 |
| 其他 extract-files blob fixup（keymint/gnss/display/radio 等） | `extract-files.py`；BUILD_LOG 记录 |

## 3. 校验覆盖与缺口

| 项 | 状态 |
|---|---|
| 提取产物 2688 文件 SHA-256 清单 | ✅ 已生成并校验通过 |
| `proprietary-files.txt` 源 pin 覆盖率 | ⚠️ device 3/1415；common 0/1265（EX01 补丁还主动去掉 4 个 pin） |
| 逐 blob 来源/许可证/SBOM | ❌ 未完成 |
| CPH2415 与 10 Pro/CPH2417/CPH2413 差异清单 | ❌ 未完成（T-04/T-05） |
| 闭源 blob 再分发法律评估 | ❌ 未完成（SEC-005/LEG-002） |

> 本清单解决的是“提取产物是否被篡改/是否一致”，**不解决**“清单里的每个 blob 是否来自正确的机型/版本/许可证”。后者仍需 T-04/T-05 完成。

## 4. 重新生成

```bash
# 1. 重新提取（会覆盖 scratch/vendor）
# 2. 应用 wise-light 字符串替换（由 extract-files.py 自动完成）
# 3. 重新生成清单
cd scratch/vendor
find oneplus -type f -print0 | sort -z | xargs -0 shasum -a 256 > ../../artifacts/blob-manifest.sha256
cd ../..
VENDOR_ROOT=scratch/vendor ./tools/verify_vendor_blobs.sh
```

## 5. 法律/合规

- 本文件与 `artifacts/blob-manifest.sha256` 只含路径与哈希，不含专有二进制。
- 默认不提交/分发 `scratch/vendor`、`vendor_extract/`、`.img`、`.zip`。
- 发布前必须完成 blob 许可证/SBOM/再分发评估（SEC-005、LEG-002）；未完成前不得公开发布 ROM。
