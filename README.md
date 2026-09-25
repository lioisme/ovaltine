# ovaltine — 一加 Ace Pro / OnePlus 10T 的 LineageOS 构建仓

机型：`ovaltine`（国行 PGP110 = 海外 OnePlus 10T，SM8475）。LineageOS **无官方支持**，
构建基线是社区移植 `lineage-ovaltine-dev`，本仓只提供 CI 编排与本地清单。

## 编译（GitHub Actions）

Actions → **Build ROM** → Run workflow，选 `branch`（`lineage-21.0` / `lineage-22.2` /
`lineage-23.2`）与 `variant`。产物在 job 的 Artifacts 里（`lineage-*.zip` + SHA256SUMS）。

```
repo init -u https://github.com/LineageOS/android -b lineage-23.2 --depth=1 --git-lfs
sed -e 's/@PLATFORM@/lineage-23.2/g' -e 's/@COMMUNITY@/lineage-23.2/g' \
    local_manifests/ovaltine.xml > .repo/local_manifests/ovaltine.xml
repo sync -c --no-tags --no-clone-bundle --optimized-storage
repo forall -c 'git lfs pull'
./build.sh userdebug
```

## 硬约束（不要绕过）

- **必须 x86_64 Linux**：AOSP 只有 `prebuilts/clang/host/linux-x86`，arm64 主机（含手机/NAS）无法编译。
- **`abl`/`xbl`/`xbl_config` 只用 `vendor/oneplus/ovaltine/radio/` 里的 OOS13 版**（SHA1 已 pin）：
  刷 OOS14/15 的 xbl 会**永久失去 EDL 深刷通道**。
- 底包用国行 PGP110（modem/区域固件与 blob 同源）；固件与 blob 必须同版本。

## 本仓文件

| 文件 | 作用 |
|---|---|
| `.github/workflows/build.yml` | 编译编排（依赖安装 → 浅同步 → 编译 → 收产物） |
| `local_manifests/ovaltine.xml` | 设备树/内核/blob 清单模板（`@PLATFORM@`/`@COMMUNITY@` 占位） |
| `build.sh` | 构建入口（限并行度与 JVM 堆，避免 runner OOM） |
| `资料清单与缺口分析.md` | 资料分层清单 + 缺口台账 G1–G15 + 底包/dts/Actions 判定 |
