# ovaltine — 一加 Ace Pro / OnePlus 10T 的 LineageOS 构建仓

机型：`ovaltine`（国行 PGP110 = 海外 OnePlus 10T，SM8475）。LineageOS **无官方支持**，
构建基线是社区移植 `lineage-ovaltine-dev`，本仓只提供 CI 编排与本地清单。

## 编译（GitHub Actions）

Actions → **build-rom** → Run workflow，选 `branch`（`lineage-21.0` / `lineage-22.2` /
`lineage-23.2`）与 `variant`。产物在 job 的 Artifacts 里（`lineage-*.zip` + SHA256SUMS）。

一轮 hosted job 装不下一整轮构建，所以它是**自动接力**的：本轮干不完就把 `tree/out` 存进
Release `ci-handoff`，`chain-rom` 读状态再排下一轮，直到出包（无人工干预，上限 10 轮）。
手动只跑一次即可：

```
repo init -u https://github.com/LineageOS/android -b lineage-23.2 --depth=1 --git-lfs
sed -e 's/@PLATFORM@/lineage-23.2/g' -e 's/@COMMUNITY@/lineage-23.2/g' \
    local_manifests/ovaltine.xml > .repo/local_manifests/ovaltine.xml
repo sync -c --no-tags -j32
bash build.sh userdebug
```

## 硬约束（不要绕过）

- **必须 x86_64 Linux**：AOSP 只有 `prebuilts/clang/host/linux-x86`，arm64 主机（含手机/NAS）无法编译。
- **`abl`/`xbl`/`xbl_config` 只用 `vendor/oneplus/ovaltine/radio/` 里的 OOS13 版**（SHA1 已 pin）：
  刷 OOS14/15 的 xbl 会**永久失去 EDL 深刷通道**。
- 底包用国行 PGP110（modem/区域固件与 blob 同源）；固件与 blob 必须同版本。

## 本仓文件

| 文件 | 作用 |
|---|---|
| `.github/workflows/build.yml` | 一轮构建（依赖 → 续建或同步 → 存档 → 限时编译 → 收产物） |
| `.github/workflows/chain.yml` | 轮次编排：读 Release 状态自动排下一轮，出包/超限/连续失败即停 |
| `infra/sync.sh` | 同步策略：单发 `-j32` 优先，超时靠 `repo sync` 可续性续拉，磁盘紧张才分批回收对象库 |
| `infra/handoff.sh` | `tree/out` 分片存进 Release（边压边传边删），续建轮不再重花几小时同步 |
| `infra/prune.sh` `infra/slim.sh` | 回收 git 元数据、只留被引用的 clang 版本，给 `out/` 腾磁盘 |
| `infra/progress.sh` | 活体进度写进 Release 正文（跑中的 job 取不到部分日志，只能靠这条旁路） |
| `local_manifests/ovaltine.xml` | 设备树/内核/blob 清单模板（`@PLATFORM@`/`@COMMUNITY@` 占位） |
| `build.sh` | 构建入口（限并行度与 JVM 堆，避免 runner OOM） |
| `资料清单.md` | 逐项资料清单（来源 + 置信度 A/B/C） |
| `资料清单与缺口分析.md` | 缺口台账 G1–G15、底包/dts/Actions 实测判定 |
| `任务文档.md` | 执行清单与验收门（G-A…G-E、P1–P4），当前进度以此为准 |

## 实测的算力结论（2026-09-25）

| 候选 | 实测结果 |
|---|---|
| 手机 Termux + Ubuntu（arm64） | `prebuilts/clang/host/linux-x86`、`prebuilts/go/linux-x86` 是 manifest 里唯一的 host 预编译（`linux-arm64` 出现 0 次；`prebuilts/build-tools` 也只有 `linux-x86`/`darwin-x86`/`linux_musl-*`）→ **arm64 主机编不动 A14+ 的 LineageOS**（解包、算哈希、比对 blob 都能干，已在用） |
| 国内任一节点同步源码 | `android.googlesource.com` 从本机与手机都 TCP 超时（lineage manifest 的 `remote="aosp"` 直指它）→ 源码侧只能走境外 runner |
| Actions `ubuntu-24.04`（4 核/16GB/~108G 可用） | 单轮 6 小时上限 + 磁盘只够「树 + 一份 out」→ **不能一轮跑完，但可以跨轮接力**（`infra/handoff.sh` + `chain.yml`，见上） |
| Actions `ubuntu-24.04-16core` | 一直 `queued` 不启动 → 本账户无 larger-runner 额度 |

结论：出包走 hosted 的多轮接力；有 self-hosted x86_64（≥250G）时把 `runs-on` 换掉即可，
一轮就能跑完，续建存档对它无害。
