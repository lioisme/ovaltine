# artifacts — 构建/提取产物与校验清单

本目录只提交**文本清单**，不提交大文件/专有二进制。

| 文件 | 用途 |
|---|---|
| `blob-manifest.sha256` | 2026-10-31 从 `scratch/vendor/oneplus` 生成的 2688 个文件的 SHA-256 清单 |

## 生成

```bash
cd scratch/vendor
find oneplus -type f -print0 | sort -z | xargs -0 shasum -a 256 > ../../artifacts/blob-manifest.sha256
```

## 校验

```bash
VENDOR_ROOT=scratch/vendor ./tools/verify_vendor_blobs.sh
# 或构建树：
VENDOR_ROOT=/path/to/aosp/vendor ./tools/verify_vendor_blobs.sh
```

## 说明

- 清单只含路径与哈希，不含 blob 内容。
- 它验证的是**当前提取结果**，不是 `proprietary-files.txt` 的源 pin；后者仍只有 device 3/1415、common 0/1265（见 `AUDIT_REPORT.md` ID-004）。
- 重新执行 extract-files 后，清单必须重新生成；wise-light 字符串替换已应用到当前 `sensors.ssc.so`。
- 不要把 `vendor_extract/`、`scratch/` 或任何 `.img`/`.zip` 提交到本目录。
