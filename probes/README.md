# probes — 探针证据说明

本目录保存 2026-10-29 阶段 0/1 的**公共** GitHub API 探针快照，用于复核 `DECISIONS.md`、`BASELINE_EVALUATION.md` 与 `AUDIT_REPORT.md` 中的事实。

## 已入库（公共数据）

| 文件 | 内容 |
|---|---|
| `srcA_*.json` | LineageOS 官方组织：ovaltine 设备树、sm8475 内核、sm8450-common 的分支/提交/仓库信息 |
| `srcB_*.json` | lineage-ovaltine-dev：组织仓库、分支、各关键分支 HEAD、release |
| `ref_*.json` | 参考项目：pjgowtham、tangalbert919、KawaiiHachimi TWRP、sm8450-mainline fdt |
| `upstream_*.json` | LineageOS 上游 hardware/oplus 仓库/分支/HEAD |
| `lineage221_default.xml` | LineageOS 22.1 官方 manifest 快照（用于路径冲突核对） |

采集方式：GitHub REST API `GET`（未认证，幂等，无副作用）；采集日期 2026-10-29；原始 JSON 未做内容编辑，仅重命名。

## 未入库（隐私/大文件）

| 路径 | 原因 |
|---|---|
| `device_scan/*.txt` | 真机 props/分区/传感器扫描，包含设备序列号、display uniqueId 等唯一标识；保留本地，公开摘要见 `DEVICE_REPORT.md` |
| `../vendor_extract/**` | 6.5 GB 底包、分区镜像、dump；体积大且含专有内容，默认不入库 |
| `../baseline/**` | 只读源码镜像；由 manifest 的 commit 固定，不入库 |

## 校验

```bash
cd probes
shasum -a 256 -c SHA256SUMS
```

`SHA256SUMS` 仅覆盖已入库的公共文件，不包含 `device_scan/` 与任何压缩包。

## 重新采集（示意）

```bash
curl -fsSL https://api.github.com/repos/lineage-ovaltine-dev/android_device_oneplus_ovaltine/branches > srcB_branches_android_device_oneplus_ovaltine.json
# 其余端点按文件名对应；注意未认证 API 限额 60 次/小时
```

> 注意：GitHub API 的 `pushed_at`/commit 日期会随时间变化；本目录是 2026-10-29 的快照，不作为“当前最新”依据。
