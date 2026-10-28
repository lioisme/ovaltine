# BUILD_LOG.md — 构建与操作日志

> 记录规则：每次构建尝试、探针、提取操作即时记录（命令、分支、commit hash、结果、错误摘要）。

---

## [2026-10-29] 阶段 0 探针记录（非构建操作，任务书 §1.1）

### 宿主环境

- macOS darwin 25.6.0 x64，16 GB RAM，32 核，磁盘可用 522 GB
- 工具：git 2.51.0 ✓、jq ✓、python3 ✓、curl ✓、unzip ✓；repo ✗（未安装，可 `curl` 安装）；simg2img ✗（提取时再解决）
- Docker / OrbStack / Colima：全部未安装（`which` 均无结果）

### 底包核验

```
文件：CPH2415_15.0.0.1901_EX01.zip（原名 9132631d4aa84fe78efdf36975a09306.zip，6,501,554,769 字节）
结构：META-INF/com/android/metadata + metadata.pb、payload.bin (6.50GB)、payload_properties.txt、care_map.pb、otacert
metadata 关键字段：
  product_name=CPH2415
  version_name=CPH2415_15.0.0.1901(EX01)     ← 与任务书底包锚定一致
  ota-id=CPH2415_11.H.85_3850_202606171345   ← 硬件版本 CPH2415_11 与任务书一致
  android_version=15, post-sdk-level=35, ota-type=AB
  security_patch=2026-06-01, google_patch=20260601
  post-build=OnePlus/CPH2415/OP5552L1:15/AP3A.240617.008/S.245f058-1f931-1f92d:user/release-keys
```

注：该 zip 于探针开始后才出现在项目根目录（文件时间戳 05:08），已重命名为 `CPH2415_15.0.0.1901_EX01.zip`。

### 来源 A 探针（GitHub API，原始 JSON 存 probes/）

```
GET /repos/LineageOS/android_device_oneplus_ovaltine        → 200, default_branch=main, pushed_at=2025-01-29
GET /repos/LineageOS/android_device_oneplus_ovaltine/branches → 200, 返回 []（空数组）
GET /repos/LineageOS/android_device_oneplus_ovaltine/commits  → 409 {"message":"Git Repository is empty."}
GET /repos/LineageOS/android_kernel_oneplus_sm8475           → 404 Not Found
结论：官方组织无可用 ovaltine 设备树/内核，无 lineage-22.2 分支可言
```

### 来源 B 探针（GitHub API，原始 JSON 存 probes/）

```
GET /orgs/lineage-ovaltine-dev/repos?per_page=100 → 200，25 个仓库（probes/srcB_org_repos.json）
关键仓库默认分支与推送时间：
  android_device_oneplus_ovaltine   default=lineage-23.2  pushed=2026-06-11
  android_device_oneplus_sm8450-common default=lineage-23.2 pushed=2026-06-11
  android_kernel_oneplus_sm8450     default=lineage-22.2  pushed=2026-06-11
  android_kernel_oneplus_sm8450-devicetrees default=lineage-22.2 pushed=2026-06-12
  android_kernel_oneplus_sm8450-modules default=lineage-22.2 pushed=2026-06-11
  android_oneplus_kernel_gki-modules default=lineage-23.2 pushed=2026-06-12
  android_kernel_modules_and_devicetree_oneplus_sm8475 default=oneplus_sm8475_t_13.0_oneplus_11R_5G pushed=2025-07-10
  android_manifest                  default=lineage-21    pushed=2024-09-03
  release                           default=main          pushed=2024-10-03

分支枚举（probes/srcB_branches_*.json）：
  device ovaltine   : lineage-20, lineage-21{,-elf-check,-wifi}, lineage-22.1{,-displayconfig}, lineage-22.2, lineage-23.2
  sm8450-common     : lineage-20/21 系列, lineage-22.1{,-backup}, lineage-22.2, lineage-23.0-new-kmod, lineage-23.2 等 15 分支
  kernel sm8450     : lineage-20/21 系列, lineage-22.1, lineage-22.2{,-ksu,-new-kmod}, lineage-23.{0,2} 等 25 分支
  kernel devicetrees: lineage-20/21, lineage-22.1, lineage-22.2, lineage-23.2, staging/lineage-22.2 等 7 分支
  kernel modules    : lineage-20/21 系列, lineage-22.1, lineage-22.2{,-cam}, lineage-23.0-new-kmod, lineage-23.2 等 14 分支
  gki-modules       : 仅 lineage-23.2
  hardware_oplus    : 仅 lineage-20, lineage-21, lineage-21-8450

分支 HEAD 提交日期（probes/srcB_head_*.json）：
  repo                              branch         HEAD         日期
  android_device_oneplus_ovaltine   lineage-22.1   59052db232dc 2025-01-24  "ovaltine: build audio blobs from source"
  android_device_oneplus_ovaltine   lineage-22.2   608c30290340 2024-01-29  "ovaltine: Update supported framerates for camera"
  android_device_oneplus_sm8450-common lineage-22.1 5c08eb4dec6a 2025-01-02 "sm8450-common: move to aidl bootctrl hal"
  android_device_oneplus_sm8450-common lineage-22.2 4d8084160cf8 2025-08-17 "sm8450-common: Disable LiveDisplay SunlightEnhancement feature"
  android_kernel_oneplus_sm8450     lineage-22.1   63aeb92d069b 2025-05-01  "Merge tag 'ASB-2025-04-05_12-5.10' ..."
  android_kernel_oneplus_sm8450     lineage-22.2   bcdb38a104bf 2023-01-13  "alarmtimer: Minimize wakeup time"
  android_kernel_oneplus_sm8450-devicetrees lineage-22.1 c05fa09edcb9 2024-08-27 "cape_overlay_common: Kill useless reserved region of BL log"
  android_kernel_oneplus_sm8450-devicetrees lineage-22.2 7d4aba979e7d 2025-05-02 "Import oplus dts{i}"
  android_kernel_oneplus_sm8450-modules lineage-22.1 cb014aff7629 2023-07-11 "qcacld-3.0: Avoid allocating large chunk of memory statically"
  android_kernel_oneplus_sm8450-modules lineage-22.2 5835ae8692f8 2025-08-21 "oplus: display: kill log spams"

90 天窗口（2026-07-31 起）内提交数：0（所有关键分支均无）→ 触发 DECISION-001

Releases（probes/srcB_release_repo_releases.json）：
  共 9 个，最新 lineage-21.0-20241003-UNOFFICIAL-Pig（2024-10-03，assets=2）
  无 lineage-22.1 / 22.2 任何产物
```

### 阶段 0 判定

```
来源A 或 来源B 存在 lineage-22.2 分支 = 是（来源B 五个关键仓库均有）
最近 90 天内有提交                    = 否（0 提交）
→ 判定规则不满足 → 构建目标 = lineage-22.1，写入 DECISION-001
```

API 用量记录：GitHub REST 未认证限额 60/小时，探针共消耗 31 次（剩余 29），探针方法为幂等 GET，无副作用，符合"不得在全量拉取前 repo sync"约束（未执行任何 repo/sync 操作）。

---

## 构建尝试记录

（暂无。构建尝试将按任务书 §4.3 SOP 逐条记录。）
