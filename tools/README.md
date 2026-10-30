# tools — 项目工具

| 工具 | 用途 | 依赖 |
|---|---|---|
| `extract_payload.py` | 从 A/B full OTA `payload.bin` 提取分区镜像，逐操作/最终分区 SHA-256 校验 | Python 3.9+、`payload_dumper`（仅 protobuf 定义） |
| `verify_vendor_blobs.sh` | 校验已提取的 vendor 树与 `artifacts/blob-manifest.sha256` 一致 | Bash、`sha256sum` 或 `shasum` |

## 使用

```bash
# 列出 payload 内所有分区
python3 tools/extract_payload.py --zip CPH2415_15.0.0.1901_EX01.zip --list

# 提取 bring-up 常用分区
python3 tools/extract_payload.py \
  --zip CPH2415_15.0.0.1901_EX01.zip \
  --output vendor_extract/images \
  --partitions boot,dtbo,vendor_boot,vendor,vendor_dlkm,odm,odm_dlkm,system,system_ext,product,my_product

# 校验
sha256sum vendor_extract/images/*.img
```

## 说明

- 只支持 **full OTA**；遇到 `SOURCE_COPY` 会明确失败，不会静默跳过。
- 每个 `REPLACE*` 操作校验 `data_sha256_hash`；完成后校验 `new_partition_info.hash`。
- 单进程实现，避免 macOS Python 3.9 spawn/pickle 问题；大分区会较慢，但可复现。
- 不负责解包 EROFS/ext4；解包用 `fsck.erofs`/`7zz`，见 `SOP.md`/`BUILD_LOG.md`。
- 底包/镜像/dump 属于大文件/专有内容，默认被 `.gitignore` 忽略；本工具源码入库。

## 安装依赖

```bash
python3 -m venv .venv
.venv/bin/pip install payload_dumper==0.2.2
```
