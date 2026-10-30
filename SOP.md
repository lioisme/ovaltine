# OnePlus 10T（ovaltine / CPH2415）LineageOS Bring-up SOP

| 项 | 值 |
|---|---|
| 文档编号 | OVL-SOP-2026-10-31 |
| 版本 | 1.0 |
| 日期 | 2026-10-31 |
| 适用设备 | OnePlus Ace Pro / 10T，codename `ovaltine`，CPH2415（全球/欧盟） |
| 适用系统 | LineageOS 22.1（Android 15），bootloader 已解锁 |
| 依据 | 业主七项要求；《开发作业临时约法》；`AUDIT_REPORT.md`；`TASK_PLAN.md` |
| 状态 | 生效；**未完成回滚演练前禁止刷机** |

> **免责声明**：本 SOP 中的命令是工程模板，不是“无脑复制”脚本。执行前必须确认设备 codename、分区名、当前槽位、镜像哈希与目标版本。任何与本文不符的现场情况，先停止，回到“备份/回滚”流程。

---

## 0. 安全红线（先读）

1. **随时可以回到 Android** 是本项目的前提、底线、红线。未完成 §5 备份、§7 回滚演练、stock OTA 可用性确认之前，**禁止**刷入任何非 stock 镜像。
2. **禁止重新上锁 bootloader**。自定义签名 + 上锁可能导致设备无法启动且无法解锁；本项目全程保持解锁。
3. **禁止在未备份关键分区的情况下刷机**。`persist`、`modemst1/2`、`fsg`、`fsc`、`oplusdycnvbk`、`metadata` 等丢失可能导致 IMEI/基带校准/传感器校准永久损坏。
4. **禁止 anti-rollback（ARB）降级**。不得刷入低于设备当前 ARB/固件版本的 stock 包；不要用旧 OTA“救砖”。
5. **禁止在生产/发布中使用 testkey**。研发构建可 testkey；发布必须独立签名 key。
6. **禁止把“未验证”写成“可用”**。所有状态必须附证据等级（E1-E4）。
7. **禁止擅自改系统网络配置**。代理/镜像只作用于构建工具环境，遵循《约法》网络篇。
8. **禁止非 main 分支长期作业**。所有提交进 `main`；实验分支当天合并/删除。
9. **禁止在 user 构建保留调试属性**（`persist.dbg.*`、`debug.*`、`ro.debuggable=1`、`adb root` 等）。
10. **禁止分发未授权闭源 blob**。默认只提供提取脚本；发布前完成法律评估。

---

## 1. 角色与前置条件

### 1.1 角色

| 角色 | 职责 |
|---|---|
| 操作者 | 按 SOP 执行；记录命令/输出/时间 |
| 复核者 | 第二人复核备份、刷机命令、回滚路径 |
| 业主 | 资源/风险接受/最终验收 |
| 安全/合规 | SPL/AVB/SELinux/SBOM/隐私 |

### 1.2 设备前置

- [ ] 设备为 CPH2415；`getprop ro.product.model=CPH2415`。
- [ ] bootloader 已解锁：`ro.boot.flash.locked=0`、`ro.boot.verifiedbootstate=orange`。
- [ ] 电量 ≥ 60%；使用可靠 USB 线/端口；避免 USB Hub。
- [ ] 已确认当前槽位：`adb shell getprop ro.boot.slot_suffix`。
- [ ] 已确认当前固件/ARB：记录 `ro.build.fingerprint`、`ro.build.version.security_patch`、`ro.boot.*`。
- [ ] 已确认 stock OTA `CPH2415_15.0.0.1901(EX01)` 本地可用，并记录 SHA256。
- [ ] 已确认可用的 MSM/EDL 救砖工具与驱动（Windows 环境更稳妥）。
- [ ] 已准备第二台设备/第二介质保存备份。

### 1.3 构建机前置

- Linux x86_64，Ubuntu 22.04/24.04，32 GB RAM 起，250 GB+ 磁盘。
- JDK 17、repo 2.71、git-lfs、ccache、cmake、ninja、Python 3.12、erofs-utils、7zz。
- 源码树路径无空格；磁盘文件系统大小写敏感（AOSP 要求）。
- 已按 `TASK_PLAN.md` T-02 应用完整 manifest 与补丁。

### 1.4 工具

| 工具 | 用途 | 版本/说明 |
|---|---|---|
| `adb` | 设备调试/日志/备份 | platform-tools 37.x |
| `fastboot` | 刷机/槽位 | platform-tools 37.x |
| `avbtool` | AVB 校验/签名 | AOSP `external/avb` |
| `payload_dumper`/自写脚本 | OTA 提取 | 0.2.2 或项目脚本 |
| `erofs-utils`/`7zz` | 镜像展开 | 1.9.4 / 26.05 |
| MSM Download Tool | 救砖 | OnePlus 官方/可信来源 |

---

## 2. 环境准备（构建机）

### 2.1 目录

```text
~/ovaltine/
  aosp/                  # repo 工作树
  manifests/             # 完整 pinned manifest
  artifacts/             # 构建产物 + SHA256SUMS
  tests/results/         # 测试证据
  backups/               # 设备备份（加密/访问控制）
```

### 2.2 初始化 repo

```bash
# 示例：以项目 manifest 为准；不要手工 sed 官方 default.xml
repo init -u https://github.com/LineageOS/android.git -b lineage-22.1 \
  -m manifests/lineage-22.1-20261031.xml
repo sync -c -j8 --no-clone-bundle --no-tags
```

> 网络不可达时，按《约法》网络篇使用前置代理/镜像；镜像配置写入 `scripts/init-repo.sh` 或 local manifest，不修改系统网络配置。

### 2.3 应用补丁与校验

```bash
./scripts/apply-patches.sh
./scripts/verify-tree.sh
```

`apply-patches.sh` 必须先 `git apply --check`，失败即停；`verify-tree.sh` 必须断言 HBM、wise-light、ALS、UDFPS、aux camera 等关键修复。

### 2.4 工具链记录

```bash
./scripts/record-toolchain.sh > artifacts/tool-versions.txt
```

至少记录：Ubuntu、`uname -a`、`nproc`、`free -h`、`df -h`、JDK、repo、clang、Python、erofs-utils、7zz、payload_dumper。

---

## 3. 设备信息采集（刷机前）

```bash
adb devices -l
adb shell getprop > artifacts/device-props-before.txt
adb shell getprop ro.product.model
adb shell getprop ro.product.device
adb shell getprop ro.build.fingerprint
adb shell getprop ro.build.version.security_patch
adb shell getprop ro.boot.flash.locked
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.boot.hardware
adb shell getprop ro.boot.project_name
adb shell getprop ro.boot.prjname
adb shell getprop ro.boot.product.hardware.sku
adb shell 'blockdev --getsize64 /dev/block/by-name/super'
adb shell 'blockdev --getsize64 /dev/block/by-name/userdata'
adb shell 'blockdev --getsize64 /dev/block/by-name/boot'
adb shell 'blockdev --getsize64 /dev/block/by-name/recovery'
adb shell 'blockdev --getsize64 /dev/block/by-name/vendor_boot'
adb shell 'blockdev --getsize64 /dev/block/by-name/dtbo'
```

> 目的：验证 `BoardConfig` 的 `BOARD_SUPER_PARTITION_SIZE`、`BOARD_USERDATAIMAGE_PARTITION_SIZE`、boot/recovery 尺寸；任何不一致都必须在刷机前修正，不得“先刷再说”。

同时采集：

```bash
adb shell dumpsys display > artifacts/display-before.txt
adb shell dumpsys sensorservice > artifacts/sensors-before.txt
adb shell dumpsys media.camera > artifacts/camera-before.txt
adb shell dumpsys usb > artifacts/usb-before.txt
adb shell getevent -il > artifacts/getevent-before.txt
```

---

## 4. 构建 SOP

### 4.1 构建前检查

- [ ] `git status --porcelain` 为空（补丁作为已提交 commit 或脚本化应用）。
- [ ] `repo manifest -r` 与 `manifests/` 一致。
- [ ] `verify-tree.sh` 通过。
- [ ] 磁盘可用 ≥ 150 GB；内存 ≥ 32 GB；无其他重负载。
- [ ] `out/` 为空或确认增量构建可接受。

### 4.2 构建命令

```bash
cd ~/ovaltine/aosp
source build/envsetup.sh
breakfast ovaltine
brunch ovaltine -j8
```

> 并行度按内存调整：32 GB 建议 `-j8`；64 GB 可 `-j16`；16 GB 机器不建议作为主构建机（见 AUDIT BLD-001/007）。

### 4.3 产物检查

```bash
ls -lh out/target/product/ovaltine/
./scripts/collect-artifacts.sh
sha256sum -c artifacts/SHA256SUMS
unzip -t out/target/product/ovaltine/lineage-22.1-*-ovaltine.zip
```

产物至少包含：

```text
boot.img
dtbo.img
recovery.img
vbmeta.img
vbmeta_system.img
vbmeta_vendor.img
vendor_boot.img
system.img
system_ext.img
product.img
vendor.img
vendor_dlkm.img
odm.img
super_empty.img
lineage-22.1-*-ovaltine.zip
```

AVB 校验（研发 testkey；发布 key 另做）：

```bash
avbtool verify_image --image out/target/product/ovaltine/boot.img
avbtool verify_image --image out/target/product/ovaltine/vbmeta.img
# 其余镜像逐项验证
```

### 4.4 构建失败处理

1. 保存完整日志到 `artifacts/build-<date>.log`。
2. 记录失败命令、commit、manifest、工具版本、错误摘要。
3. 不要手工改构建树后继续；把修复变成 patch/commit。
4. 同一错误连续 2 次无法解决，停止并升级，不要无限重试。

### 4.5 可复现性

- 两次干净 sync + patch + build，比较 `SHA256SUMS`。
- 记录 non-determinism（时间戳、路径、随机种子）；不能解释的差异视为失败。
- 产物与 `build-info.txt`、`source-manifest.xml`、`tool-versions.txt` 一起归档。

---

## 5. 刷机前备份 SOP（红线）

> **未完成本节，禁止刷机。** 备份必须在取得 root/自定义 recovery 或 EDL 访问后执行；如果无法备份关键分区，停止。

### 5.1 备份目标

| 分区 | 原因 | 优先级 |
|---|---|---|
| `persist` | 传感器/指纹/校准/DRM 等持久数据 | P0 |
| `modemst1`/`modemst2` | IMEI/基带校准 | P0 |
| `fsg`/`fsc` | 基带/射频校准 | P0 |
| `oplusdycnvbk` | OPlus 动态 NV | P0 |
| `metadata` | FBE 元数据加密 | P1（刷机可能重建） |
| `boot_a/b`、`vbmeta_a/b`、`dtbo_a/b`、`vendor_boot_a/b` | 回 stock/排障 | P0 |
| `super` 当前槽 | 回滚/对比 | P1（大，需空间） |
| `userdata` 重要数据 | 用户数据 | P0（用户自行备份） |
| `modem`/`bluetooth`/`dsp` | 固件 | P1 |
| 全量分区表 | 对照 | P0 |

### 5.2 备份方式（按可用性选择）

#### 方式 A：临时启动自定义 recovery（推荐，若不覆盖 stock recovery）

1. 确认 recovery 镜像与设备/底包兼容（项目参考 `KawaiiHachimi/twrp_device_oneplus_ovaltine`，但必须验证）。
2. `fastboot boot recovery.img`（若设备支持临时启动）；不要先 `fastboot flash recovery` 覆盖 stock。
3. 在 recovery shell 中：

```bash
# 示例；分区名以设备实际 by-name 为准
mkdir -p /tmp/backup
dd if=/dev/block/by-name/persist of=/tmp/backup/persist.img bs=1M
dd if=/dev/block/by-name/modemst1 of=/tmp/backup/modemst1.img bs=1M
dd if=/dev/block/by-name/modemst2 of=/tmp/backup/modemst2.img bs=1M
dd if=/dev/block/by-name/fsg of=/tmp/backup/fsg.img bs=1M
dd if=/dev/block/by-name/fsc of=/tmp/backup/fsc.img bs=1M
dd if=/dev/block/by-name/oplusdycnvbk of=/tmp/backup/oplusdycnvbk.img bs=1M
# boot/vbmeta/dtbo/vendor_boot 按当前槽位备份
adb pull /tmp/backup ./backups/2026-10-31/
```

4. 对每个备份计算 SHA256；保存到两台独立介质。

#### 方式 B：已 root 的 stock/Lineage

```bash
adb root   # 仅 userdebug/已 root 可用；stock 通常不可用
adb shell 'mkdir -p /sdcard/backup'
adb shell 'dd if=/dev/block/by-name/persist of=/sdcard/backup/persist.img bs=1M'
# 其余分区同理
adb pull /sdcard/backup ./backups/2026-10-31/
```

#### 方式 C：EDL/MSM 全量备份

- 使用 OnePlus MSM Download Tool/EDL 读取分区；需要 Windows/驱动/授权。
- 优点：可救砖；缺点：工具/驱动复杂，操作风险高。
- 必须由有经验人员执行；记录工具版本/固件包校验和。

### 5.3 备份校验

```bash
sha256sum backups/2026-10-31/*.img > backups/2026-10-31/SHA256SUMS
sha256sum -c backups/2026-10-31/SHA256SUMS
```

- 备份文件可读、大小与分区一致。
- 至少一份离线介质；不要只放同一块磁盘。
- 记录备份时间、固件版本、槽位、操作者、复核者。

### 5.4 回滚演练（刷 system 前）

1. 只切槽或只回 stock boot，验证能正常启动。
2. 记录 `fastboot getvar current-slot`、`fastboot --set-active`、`fastboot reboot`。
3. 确认 stock OTA 可回刷；确认 IMEI/基带/指纹/传感器正常。
4. 演练通过后才允许刷完整 Lineage 镜像。

---

## 6. 刷机 SOP

> 推荐优先使用 **Lineage Recovery + signed OTA sideload**，而不是手工 `fastboot flash` 所有分区。手工路径仅用于 bring-up/救援，且必须逐步验证。

### 6.1 进入 fastboot

```bash
adb reboot bootloader
# 或关机后按音量下+电源
fastboot devices
fastboot getvar current-slot
fastboot getvar all > artifacts/fastboot-getvar-before.txt
```

### 6.2 路径 A：Recovery + OTA（推荐）

1. 刷入 boot/vendor_boot/dtbo（按项目说明；不要覆盖不该覆盖的分区）：

```bash
fastboot flash boot boot.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash dtbo dtbo.img
# vbmeta 仅在项目明确要求时刷；否则优先用 OTA 的 vbmeta
```

2. 重启到 recovery：

```bash
fastboot reboot recovery
```

3. 在 recovery 中：

```text
Factory reset → Format data/factory reset（会清空 userdata）
Apply update → Apply from ADB
```

4. 电脑执行：

```bash
adb sideload lineage-22.1-*-ovaltine.zip
```

5. 回主菜单 → Reboot system now。

### 6.3 路径 B：手工 fastboot（仅 bring-up）

```bash
fastboot flash boot boot.img
fastboot flash dtbo dtbo.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash vbmeta vbmeta.img
fastboot flash vbmeta_system vbmeta_system.img
fastboot flash vbmeta_vendor vbmeta_vendor.img
# system/vendor/product 等动态分区通常通过 fastbootd + OTA/逻辑分区刷入
fastboot reboot
```

> **警告**：`fastboot flash vbmeta --disable-verity --disable-verification` 会削弱验证链；仅在项目明确要求且已记录风险时使用。不要把它当作默认步骤。

### 6.4 首次启动

```bash
adb wait-for-device
adb shell getprop sys.boot_completed
adb shell getprop ro.product.model
adb shell getprop ro.build.fingerprint
adb shell getprop ro.build.version.security_patch
adb shell getenforce
adb logcat -d > artifacts/logcat-firstboot.txt
adb shell dmesg > artifacts/dmesg-firstboot.txt
```

预期：

- `sys.boot_completed=1`；
- 首次设置可完成；
- 无 bootloop/panic；
- `getenforce=Enforcing`；
- `ro.product.model=CPH2415`；
- 指纹/相机/通话/WiFi 冒烟通过。

### 6.5 失败处理

- 任何 bootloop/黑屏/无法进 recovery：立即停止，按 §7 回滚；不要反复刷。
- 记录最后一条 `fastboot`/`adb` 输出、屏幕状态、LED、震动、温度。
- 如果 fastboot 仍可用，优先回 stock boot/切槽；如果 fastboot 不可用，进入 EDL/MSM 救砖。

---

## 7. 回滚到 Android SOP（红线）

### 7.1 决策树

```text
设备能否进 fastboot？
├─ 能 → 能进 recovery？
│   ├─ 能 → 优先 stock OTA sideload / 恢复备份
│   └─ 不能 → fastboot 刷 stock boot/vbmeta/dtbo → 再进 recovery
└─ 不能 → 能否进 EDL？
    ├─ 能 → MSM Download Tool 刷 stock 全量包
    └─ 不能 → 停止；检查 USB/驱动/按键/电量；不要盲目短接
```

### 7.2 路径 A：stock OTA 回刷（推荐）

1. 获取与设备匹配的 stock OTA `CPH2415_15.0.0.1901(EX01)`；校验 SHA256。
2. 进入 stock recovery（或 Lineage recovery 支持 sideload 时）：

```bash
adb reboot recovery
# 选择 Apply update → Apply from ADB
adb sideload CPH2415_15.0.0.1901_EX01.zip
```

3. 如 OTA 不允许降级/校验失败，记录错误，不要强行改包。
4. 回 stock 后验证：

```bash
adb shell getprop ro.product.model
adb shell getprop ro.build.fingerprint
adb shell getprop ro.build.version.security_patch
adb shell getprop ro.boot.flash.locked
```

### 7.3 路径 B：fastboot 恢复 stock 镜像

1. 从 stock OTA `payload.bin` 提取 boot/dtbo/vendor_boot/vbmeta/vbmeta_system/vbmeta_vendor（项目脚本/`payload_dumper`）。
2. 校验哈希；确认槽位。
3. 刷入：

```bash
fastboot flash boot boot.img
fastboot flash dtbo dtbo.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash vbmeta vbmeta.img
fastboot flash vbmeta_system vbmeta_system.img
fastboot flash vbmeta_vendor vbmeta_vendor.img
fastboot reboot
```

4. 若仍 bootloop，切到另一槽：

```bash
fastboot getvar current-slot
fastboot --set-active=b   # 或 a
fastboot reboot
```

5. 若 dynamic partitions 损坏，使用 stock OTA 全量包/`fastbootd` 逻辑分区刷入；不要手工 `fastboot flash super` 除非确认尺寸/镜像格式。

### 7.4 路径 C：EDL/MSM 救砖

- 适用：fastboot 不可用、黑屏、9008 端口可见。
- 工具：OnePlus MSM Download Tool + 匹配 CPH2415 的 stock 包 + 驱动。
- 步骤（概要）：
  1. 安装驱动；关机；进入 EDL（按键组合/授权工具）。
  2. 打开 MSM，选择 stock 包，确认型号/区域。
  3. 开始刷写；不要断电/拔线。
  4. 完成后首次启动可能较慢；验证 IMEI/基带/指纹/传感器。
- **风险**：EDL 操作可能清空数据；错误固件可能触发 ARB/变砖。必须由有经验人员执行，并记录工具/固件版本。

### 7.5 回滚后验证

- [ ] `sys.boot_completed=1`。
- [ ] `ro.product.model=CPH2415`，stock fingerprint/SPL 正确。
- [ ] IMEI/基带（`getprop gsm.sim.operator.*`、`dumpsys telephony.registry`）正常。
- [ ] 指纹录入/解锁正常。
- [ ] 相机/音频/WiFi/BT/传感器正常。
- [ ] 备份的 `persist`/`modemst` 未被误写；必要时按官方流程恢复。
- [ ] 记录回滚耗时、命令、日志、截图。

---

## 8. 测试 SOP

> 详细矩阵见 `TASK_PLAN.md` §6 与 `HARDWARE_INVENTORY.md`。本节只规定执行纪律。

### 8.1 顺序

1. 构建测试（BT）→ 2. 冒烟（SM）→ 3. 硬件（HW）→ 4. 压力（ST）→ 5. 回归（RG）→ 6. 全量（FT）→ 7. 安全（SC）→ 8. OTA/回滚（OT）→ 9. 复现（RF）。

### 8.2 记录模板

```text
Test ID:
Build SHA256:
Device/固件:
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

## 9. 发布 SOP

### 9.1 发布前门禁

- [ ] G4 全量测试 100% 通过，0 P0/P1。
- [ ] SPL 达标；SELinux Enforcing；0 未解释 avc。
- [ ] 发布 key 签名；`avbtool verify_image` 通过。
- [ ] OTA 安装/回滚通过。
- [ ] SBOM/NOTICE/CREDITS/隐私脱敏完成。
- [ ] Release notes/CHANGELOG/KNOWN_ISSUES/维护计划齐全。
- [ ] 业主签字。

### 9.2 产物

```text
lineage-22.1-YYYYMMDD-ovaltine.zip
lineage-22.1-YYYYMMDD-ovaltine.zip.sha256
boot.img / dtbo.img / recovery.img / vbmeta*.img / vendor_boot.img
build-info.txt
source-manifest.xml
tool-versions.txt
SHA256SUMS
```

### 9.3 发布记录

- 版本号、commit、manifest、工具链、SPL、已知问题、回滚说明。
- 签名 key 指纹（不暴露私钥）。
- 下载地址/校验和。

---

## 10. 故障处理

| 现象 | 优先排查 | 处理 |
|---|---|---|
| bootloop | 最后刷入的分区、vbmeta、槽位 | 切槽/回 stock boot；按 §7 |
| 黑屏但 fastboot 可用 | boot/vendor_boot/dtbo | 回 stock；检查镜像/哈希 |
| fastboot 不可用 | 电量/USB/驱动/按键 | EDL/MSM；不要盲目短接 |
| 无 IMEI/基带 | modemst/fsg/persist | 恢复备份；MSM 全量；不要继续刷 |
| 指纹失败 | HBM/UDFPS overlay/HAL | 检查 `chmod 0000 hbm`、overlay、avc；回滚 |
| 相机失败 | camera blob/aux fixup | 检查 `CameraHWConfiguration`、6 ID、avc |
| 自动亮度异常 | wise-light/ALS | 检查 sensors.ssc 字符串、overlay、亮度曲线 |
| 充电异常 | 充电 HAL/温度 | 停止快充；记录功率/温度；回滚 |
| WiFi/BT 异常 | firmware/blob/avc | 检查 MAC/firmware/驱动；回滚 |
| 通话异常 | RIL/IMS/双卡 | 检查 SIM/运营商/VoLTE 配置；回滚 |

---

## 11. 记录与审计

每次操作必须记录：

- 日期/时间、操作者/复核者；
- 设备序列号（内部记录，不公开）、固件/槽位/ARB；
- 构建 commit/manifest/工具链；
- 命令与输出摘要；
- 镜像/备份 SHA256；
- 测试 ID/结果/证据；
- 异常/回滚/耗时。

禁止：

- 事后补写状态；
- 删除失败日志；
- 把“未测”写成“通过”；
- 在公共文档保留设备唯一标识。

---

## 12. 命令速查（模板）

```bash
# 设备
adb devices -l
adb shell getprop | sort
adb reboot bootloader
fastboot devices
fastboot getvar all
fastboot getvar current-slot

# 构建
source build/envsetup.sh
breakfast ovaltine
brunch ovaltine -j8

# 产物
sha256sum out/target/product/ovaltine/*.img > SHA256SUMS
avbtool verify_image --image boot.img

# 备份（recovery/root shell）
dd if=/dev/block/by-name/persist of=/tmp/persist.img bs=1M
sha256sum /tmp/persist.img

# 刷机（示例，按项目说明）
fastboot flash boot boot.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash dtbo dtbo.img
fastboot reboot recovery
adb sideload lineage-22.1-*-ovaltine.zip

# 回滚
fastboot flash boot stock-boot.img
fastboot --set-active=b
fastboot reboot
adb sideload CPH2415_15.0.0.1901_EX01.zip

# 验证
adb shell getprop sys.boot_completed
adb shell getenforce
adb shell dmesg | grep -i avc
```

> 再次强调：以上命令必须结合设备实际分区/槽位/项目说明执行；不确定时停止并复核。

---

## 13. 变更记录

| 版本 | 日期 | 变更 | 作者 |
|---|---|---|---|
| 1.0 | 2026-10-31 | 首次 SOP；覆盖构建、备份、刷机、回滚、测试、发布、故障处理 | 审计 Agent |
