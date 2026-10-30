# OnePlus 10T（ovaltine / CPH2415）LineageOS Bring-up SOP

| 项 | 值 |
|---|---|
| 文档编号 | OVL-SOP-2026-10-31 |
| 版本 | **2.0（禁止真实刷机版）** |
| 日期 | 2026-10-31 |
| 适用设备 | OnePlus Ace Pro / 10T，codename `ovaltine`，CPH2415（全球/欧盟） |
| 适用系统 | LineageOS 22.1（Android 15），bootloader 已解锁 |
| 依据 | 业主 2026-10-31 强制约束；《开发作业临时约法》；`AUDIT_REPORT.md`；`TASK_PLAN.md` |
| 状态 | 生效；**禁止真实刷入任何分区** |

> **版本说明**：v1.0 中的刷机/回 stock/EDL 步骤已全部作废。v2.0 只允许两类测试执行方式：
> **① 内存启动（`fastboot boot`）；② DSU（Dynamic System Updates）**。
> 除这两类外，任何写入设备分区的操作都被禁止。

---

## 0. 安全红线（先读）

1. **禁止真实刷入任何分区。** 包括但不限于 `fastboot flash`、`adb sideload`、`fastboot -w`、`fastboot set_active`、`dd` 写分区、recovery 写入、EDL/MSM 刷写、任何脚本/工具的分区写操作。
2. **只允许内存启动或 DSU。** 调试/测试必须在 RAM（`fastboot boot`）或 DSU 动态系统中进行；不得改变 boot/system/vendor/vbmeta 等分区内容。
3. **禁止重新上锁 bootloader。** 自定义签名 + 上锁可能导致不可恢复的变砖；本项目全程保持解锁。
4. **DSU 也会写 userdata**（动态系统镜像/用户数据），测试前必须备份用户数据；不得把 DSU 当作“零写入”。
5. **禁止 anti-rollback（ARB）降级。** 即使不刷机，也不得通过任何工具写入低版本固件。
6. **禁止用 testkey 发布。** 研发构建可 testkey；发布必须独立签名。
7. **禁止把“未验证”写成“可用”。** 所有状态必须附证据等级（E1-E4）。
8. **禁止擅自改系统网络配置。** 代理/镜像只作用于构建工具环境，遵循《约法》网络篇。
9. **禁止非 main 分支长期作业。** 所有提交进 `main`；实验分支当天合并/删除。
10. **禁止分发未授权闭源 blob。** 默认只提供提取脚本；发布前完成法律评估。

> 任何违反第 1/2/3 条的操作，立即停止，记录现场，按 `DECISIONS.md` DECISION-006 处理。不要“先刷了再说”。

---

## 1. 允许 / 禁止操作

| 操作 | 状态 | 说明 |
|---|---|---|
| `adb devices` / `adb shell` / `adb pull` / `adb logcat` | ✅ 允许 | 只读调试/取证 |
| `fastboot devices` / `fastboot getvar` | ✅ 允许 | 只读查询 |
| `fastboot boot <image>` | ✅ 允许 | 镜像加载到 RAM，不写分区 |
| DSU 安装/启动/丢弃 | ✅ 允许 | 动态系统；写 userdata，需备份 |
| `adb reboot` / `fastboot reboot` | ✅ 允许 | 重启回 stock/DSU |
| `adb push` 到 `/data/local/tmp` | ✅ 允许 | 测试文件，不写系统分区 |
| `fastboot flash ...` | ❌ 禁止 | 真实写入分区 |
| `adb sideload ...` | ❌ 禁止 | recovery 写入 |
| `fastboot -w` / `fastboot erase` / `fastboot format` | ❌ 禁止 | 擦除/格式化 |
| `fastboot set_active` | ❌ 禁止 | 改槽位状态 |
| `dd of=/dev/block/...` | ❌ 禁止 | 直接写分区 |
| EDL/MSM/QFIL 刷写 | ❌ 禁止 | 底层写入 |
| `fastboot flashing lock` / `oem lock` | ❌ 禁止 | 重新上锁 |
| 任何“回 stock OTA 刷写” | ❌ 禁止 | 本项目不执行；回 stock = 重启 |

---

## 2. 角色与前置条件

### 2.1 角色

| 角色 | 职责 |
|---|---|
| 操作者 | 按 SOP 执行；记录命令/输出/时间 |
| 复核者 | 第二人复核“无分区写入”与 DSU/内存启动路径 |
| 业主 | 资源/风险接受/最终验收 |
| 安全/合规 | SPL/AVB/SELinux/SBOM/隐私 |

### 2.2 设备前置

- [ ] CPH2415；`getprop ro.product.model=CPH2415`。
- [ ] bootloader 已解锁：`ro.boot.flash.locked=0`、`ro.boot.verifiedbootstate=orange`。
- [ ] 当前系统可正常启动（stock Android 或已有可用系统）；否则先恢复，**不得刷机**。
- [ ] 电量 ≥ 60%；可靠 USB 线/端口。
- [ ] 已备份 userdata 重要数据（DSU 会写 userdata）。
- [ ] 已确认内存启动/DSU 的镜像与设备匹配（kernel/ramdisk、GSI/system）。
- [ ] 已记录 `fastboot getvar all`、槽位、固件/SPL、ARB。

### 2.3 构建机前置

- Linux x86_64，Ubuntu 22.04/24.04，32 GB RAM 起，250 GB+ 磁盘。
- JDK 17、repo 2.71、git-lfs、ccache、cmake、ninja、Python 3.12、erofs-utils、7zz。
- 源码树路径无空格；文件系统大小写敏感。
- 已按 `TASK_PLAN.md` T-02 应用完整 manifest 与补丁。

---

## 3. 环境准备（构建机）

### 3.1 目录

```text
~/ovaltine/
  aosp/                  # repo 工作树
  manifests/             # 完整 pinned manifest
  artifacts/             # 构建产物 + SHA256SUMS
  tests/results/         # 测试证据
  backups/               # 设备数据备份（访问控制）
```

### 3.2 初始化 repo

```bash
repo init -u https://github.com/lioisme/ovaltine.git -b main \
  -m manifests/lineage-22.1-20261031.xml
repo sync -c -j8 --no-clone-bundle --no-tags
```

> 网络不可达时，按《约法》网络篇使用前置代理/镜像；镜像配置写入脚本/local manifest，不修改系统网络配置。

### 3.3 应用补丁与校验

```bash
export AOSP_ROOT=/path/to/aosp
./scripts/apply-patches.sh
./scripts/verify-tree.sh
```

`apply-patches.sh` 先 `git apply --check`，已应用则跳过，失败即停；`verify-tree.sh` 断言 CPH2415 身份、HBM `chmod 0000`、wise-light/ALS、EX01 适配等关键行。

### 3.4 GitHub Actions 构建

- `static-ci.yml` 每次 push 自动运行：补丁可应用性、清单/脚本/禁刷校验。
- `aosp-build.yml` 手动运行：需要 larger runner 或 self-hosted Linux runner（32 GB+ RAM、400 GB+ 磁盘）；标准 `ubuntu-latest` 资源不足，preflight 会拒绝。
- vendor blob 不入公开仓库；通过 `VENDOR_ARCHIVE_URL` / `VENDOR_ARCHIVE_SHA256` secrets 提供私有归档。
- 详见 `CI.md`。CI 只构建/测试，不写设备分区。

---

## 4. 构建 SOP

### 4.1 构建前检查

- [ ] `git status --porcelain` 为空（补丁脚本化应用）。
- [ ] `repo manifest -r` 与 `manifests/` 一致。
- [ ] `verify-tree.sh` 通过。
- [ ] 磁盘 ≥ 150 GB；内存 ≥ 32 GB。

### 4.2 构建

```bash
cd "$AOSP_ROOT"
source build/envsetup.sh
breakfast ovaltine
brunch ovaltine -j8
```

### 4.3 产物

```bash
ls -lh out/target/product/ovaltine/
./scripts/collect-artifacts.sh
sha256sum -c artifacts/SHA256SUMS
unzip -t out/target/product/ovaltine/lineage-22.1-*-ovaltine.zip
avbtool verify_image --image out/target/product/ovaltine/boot.img
```

> 构建产物只用于内存启动/DSU 分析，**不得刷入设备**。

### 4.4 可复现性

- 两次干净 sync + patch + build，比较 `SHA256SUMS`。
- 记录 non-determinism；不能解释的差异视为失败。
- 归档 `build-info.txt`、`source-manifest.xml`、`tool-versions.txt`。

---

## 5. 设备只读采集与数据备份

### 5.1 只读采集（不写设备）

```bash
adb devices -l
adb shell getprop > artifacts/device-props-before.txt
adb shell 'blockdev --getsize64 /dev/block/by-name/super'
adb shell 'blockdev --getsize64 /dev/block/by-name/userdata'
adb shell dumpsys display > artifacts/display-before.txt
adb shell dumpsys sensorservice > artifacts/sensors-before.txt
adb shell dumpsys media.camera > artifacts/camera-before.txt
adb shell getevent -il > artifacts/getevent-before.txt
fastboot getvar all > artifacts/fastboot-getvar-before.txt
```

### 5.2 数据备份（DSU 前置）

- 用户数据：照片/文档/聊天记录/应用数据；至少两份介质。
- 若设备已 root/可临时启动 recovery，可备份关键分区**到外部介质**；这是“读取”，不是“写入分区”。
- 没有 root/无法读取时，至少完成用户数据备份；不得为了备份而刷入 recovery。
- 记录备份时间、大小、SHA256、操作者/复核者。

> 本项目不要求、也不允许为了“回滚”而刷 stock；回滚方式是重启/DSU 丢弃。

---

## 6. 内存启动（fastboot boot）

> 适用：需要验证 boot/kernel/ramdisk 或临时调试；**镜像只在 RAM 中，不写分区**。

### 6.1 前置

- [ ] `boot.img` 与设备/底包匹配；SHA256 已记录。
- [ ] `fastboot getvar current-slot` 已记录。
- [ ] 设备可进 fastboot；电量充足。
- [ ] 已确认设备支持 `fastboot boot`（部分 A/B + vendor_boot 设备可能不支持；不支持则停止，改用 DSU，禁止改为 flash）。

### 6.2 步骤

```bash
adb reboot bootloader
fastboot devices
fastboot getvar current-slot
fastboot boot /path/to/boot.img
```

### 6.3 观察

```bash
adb wait-for-device
adb shell getprop sys.boot_completed
adb shell dmesg > artifacts/dmesg-ramboot.txt
adb logcat -d > artifacts/logcat-ramboot.txt
```

### 6.4 退出

```bash
adb reboot
# 或长按电源键重启
```

- 若 `fastboot boot` 失败/黑屏：强制重启回 stock；**不要**改为 `fastboot flash`。
- 若 RAM boot 成功但系统分区仍是 stock，这是预期：内存启动只验证 boot 侧，不验证自定义 system。

---

## 7. DSU（Dynamic System Updates）

> 适用：在不写 boot/system/vendor 分区的前提下，用动态系统镜像启动自定义 system/GSI 进行调试。
> DSU 会写 userdata 的动态系统镜像；测试前必须备份用户数据。

### 7.1 前置

- [ ] stock Android 可正常启动。
- [ ] bootloader 已解锁（DSU 通常要求）。
- [ ] 系统镜像（GSI 或项目 system 镜像）与设备 ABI/分区匹配；SHA256 已记录。
- [ ] userdata 已备份。
- [ ] 已确认设备 Android 版本的 DSU 命令/入口；不同版本/厂商可能不同。

### 7.2 安装与启动（命令以设备实际为准）

DSU 的安装入口随 Android 版本/厂商不同。执行前先确认：

```bash
adb shell cmd -l | grep -i dynamic
adb shell pm list packages | grep -i dynsystem
```

常见流程（示意，不是盲抄模板）：

```text
1. 将 system 镜像推送到 /data/local/tmp/dsu/
2. 通过设备支持的 DSU 安装入口（DynamicSystemInstallationService/厂商入口/官方 DSU 工具）安装
3. 按提示重启进入 DSU
4. 在 DSU 中执行测试
5. 通过 DSU 设置/命令丢弃动态系统，重启回 stock
```

> 不要使用 `fastboot flash` 安装 DSU 镜像；不要把 DSU 镜像写到 boot/system/vendor 分区。

### 7.3 验证

```bash
adb shell getprop sys.boot_completed
adb shell getprop ro.product.model
adb shell getprop ro.build.fingerprint
adb shell getenforce
adb shell dmesg | grep -i avc
```

### 7.4 退出/丢弃

- 优先使用系统设置中的 DSU 卸载/丢弃入口，或设备支持的 DSU 命令。
- 重启回 stock；确认 `ro.build.fingerprint` 恢复为 stock。
- 若 DSU 无法启动：重启回 stock；**不要**刷机修复。
- 若 DSU 导致 userdata 异常：从备份恢复用户数据；不要格式化分区。

---

## 8. 测试 SOP

> 详细矩阵见 `TASK_PLAN.md` §6 与 `HARDWARE_INVENTORY.md`。所有测试只在内存启动/DSU 中进行。

### 8.1 顺序

1. 构建测试（BT）→ 2. 内存/DSU 启动（SM）→ 3. 硬件（HW）→ 4. 压力（ST）→ 5. 回归（RG）→ 6. 全量（FT）→ 7. 安全（SC）→ 8. DSU 退出（OT）→ 9. 复现（RF）。

### 8.2 记录模板

```text
Test ID:
Execution mode: RAM boot / DSU
Build SHA256:
Device/stock firmware:
前置条件:
步骤:
预期结果:
实际结果:
判定: PASS/FAIL/BLOCKED
证据: artifacts/tests/... (log/screenshot)
备注:
```

### 8.3 失败处理

- P0/P1 失败：停止后续测试，建缺陷，修复后回归受影响项 + 冒烟，再继续。
- P2 失败：记录，评估是否阻断里程碑。
- 任何“通过”必须有证据；口头/记忆不算。

---

## 9. 发布 SOP（当前 NO-GO）

- 构建产物可用于分析/测试，但**不得刷入设备**。
- 发布前门禁：G4 全量测试通过、SPL 达标、SELinux Enforcing、发布 key 签名、DSU/内存测试证据齐全、SBOM/NOTICE/隐私脱敏、文档齐全、业主签字。
- 由于本项目禁止真实刷机，发布验证必须依赖 DSU/内存启动/仿真/静态证据；无法验证的项必须标注“未验证”，不得宣称“已通过”。
- 发布包只作为产物归档/研究，不提供刷机指令。

---

## 10. 故障处理

| 现象 | 优先排查 | 处理 |
|---|---|---|
| `fastboot boot` 失败 | 镜像/设备支持/电量/USB | 重启回 stock；改用 DSU；**禁止 flash** |
| RAM boot 黑屏 | boot 镜像不匹配 | 重启；记录；不要刷机 |
| DSU 无法启动 | 镜像/GSI 兼容/空间 | 丢弃 DSU；重启 stock；检查镜像 |
| DSU 后数据异常 | userdata 写入 | 从备份恢复；不要格式化分区 |
| 设备无法启动 | stock 是否仍可进 fastboot/recovery | 重启/切回 stock（若可用）；**禁止刷机/EDL 刷写** |
| 指纹/相机/亮度异常 | HBM/wise-light/ALS/HAL | 记录；DSU 内验证；回 stock 复测 |
| 误触刷机命令 | 立即停止 | 记录现场；按 DECISION-006 升级；不要继续操作 |

---

## 11. 记录与审计

每次操作必须记录：

- 日期/时间、操作者/复核者；
- 执行方式（RAM boot / DSU）；
- 设备固件/槽位/SPL/ARB；
- 构建 commit/manifest/工具链；
- 命令与输出摘要；
- 镜像/备份 SHA256；
- 测试 ID/结果/证据；
- 异常/退出/耗时。

禁止：

- 事后补写状态；
- 删除失败日志；
- 把“未测”写成“通过”；
- 在公共文档保留设备唯一标识；
- 执行任何分区写入。

---

## 12. 命令速查（仅允许项）

```bash
# 只读
adb devices -l
adb shell getprop | sort
adb shell dmesg
adb logcat -d
fastboot devices
fastboot getvar all
fastboot getvar current-slot

# 内存启动
fastboot boot /path/to/boot.img

# 重启/退出
adb reboot
fastboot reboot

# 构建
source build/envsetup.sh
breakfast ovaltine
brunch ovaltine -j8

# 校验
sha256sum -c artifacts/SHA256SUMS
avbtool verify_image --image boot.img

# DSU
adb shell cmd -l | grep -i dynamic
adb shell pm list packages | grep -i dynsystem
# 具体安装/丢弃命令以设备 Android 版本与厂商入口为准
```

> 本速查表**不包含**任何 `fastboot flash`、`adb sideload`、`fastboot -w`、`fastboot erase`、`dd` 写分区、EDL 刷写命令；需要这些操作时，说明已越界，停止并升级。

---

## 13. 变更记录

| 版本 | 日期 | 变更 | 作者 |
|---|---|---|---|
| 1.0 | 2026-10-31 | 首次 SOP；含刷机/回滚/救砖流程 | 审计 Agent |
| 2.0 | 2026-10-31 | 按业主强制约束重写：禁止真实刷入任何分区；仅允许内存启动/DSU；移除所有刷机/EDL 步骤 | 审计 Agent |
