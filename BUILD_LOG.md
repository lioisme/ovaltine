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

## [2026-10-29] 真机接入扫描（用户指令①）

```
adb：platform-tools 37.0.1（官方 zip 直装 ~/tools/android-platform-tools，避免 brew 源码编译）
设备：已脱敏 = CPH2415（OP5555L1 主板），已授权
关键读数（原始数据 probes/device_scan/*.txt）：
  - 构建 S.245f058-1f931-1f92d（与底包 OTA post-build 一致）
  - 内核 5.10.236-android12-9-o-g55571f3ffcfa（与 boot.img strings 一致）
  - 基带 Q_V1_P14,Q_V1_P14（与任务书锚定逐字一致）
  - ro.boot.flash.locked=0, verifiedbootstate=orange → bootloader 已解锁
  - slot _a；SoC SM8475 / ro.board.platform=taro；CPU part 0xd46×4+0xd47×3+0xd48×1
    = A510×4 + A710×3 + X2×1（8+ Gen 1 拓扑）
  - RAM 15.6GB + swap 9.5GB；userdata 224GB（256GB 版）
  - 显示 1080×2412 120/90/60Hz，HDR types [2,3,4]，540nit
  - 传感器：BMI26x(accel/gyro) + AK0991x(mag) + TCS3701(oplus Fusion Light/proximity)
    → 与 22.1 分支 wise-light 补丁 42cc1f8 语义精确对应
  - 输入：touchpanel/touchpanel_kpd/oplus_fp_input（UDFPS）/waipio-mtp-snd-card
  - 相机 6 ID（5 后 + 1 前）；NFC 全功能 + eSE；dsds 配置
报告：DEVICE_REPORT.md；HARDWARE_MATRIX 升级注记见其 §14
```

## [2026-10-29] 版本选型复核（用户指令②）

DECISION-004：维持 **lineage-22.1**。候选 22.2/23.0/23.2/24.0-6.6/21.0 逐项排除，理由见 DECISIONS.md。

## [2026-10-29] macOS 原生编译环境（用户指令③）

```
宿主：macOS 26 (darwin 25.6.0) x64 · Xcode 21 (clang-2100.1.1.101) 全量版在位
磁盘：APFS 容器 1TB，新增 Case-sensitive APFS 卷 disk1s7 → /Volumes/los-build
      （APFS 动态共享空间，非定容；创建时可用 475GB）
工具链：
  - JDK 17.0.21 Temurin（tar.gz 解压 ~/tools/jdk17；A15 构建要求 17，宿主自带 21 不兼容）
  - git-lfs 3.8.1 官方二进制 ~/tools/git-lfs（brew 慢，改直装）+ git lfs install
  - repo 2.71（~/bin/repo）
  - repo init：gerrit.googlesource.com 被网络阻断（clone.bundle 超时）
    → --repo-url https://github.com/GerritCodeReview/git-repo.git 绕过
    → android.googlesource.com 的 git 端点实测可达（ls-remote 成功），
      同步用 --no-clone-bundle 直接走 git 协议
manifest：lineage-22.1 @ 46ed254 "Track our own forks for 2025-04 ASB patching"
          + .repo/local_manifests/ovaltine.xml（同 local_manifests/ovaltine-lineage-22.1.xml）
同步命令：repo sync -c -j12 --no-clone-bundle --no-tags --fail-fast
          （1212 工程走 aosp 远端 + LineageOS 仓库 + 6 个 local_manifest 工程）
注意：zcode 后台任务 10 分钟上限 → 同步用 nohup+disown 脱离会话存活，轮询监控
brew 依赖（后台）：coreutils gnu-sed gnu-tar gawk cmake ninja ccache openssl@3 libtool
```

### 同步排障记录

```
1) android.googlesource.com 实测被网络阻断（curl 443 超时；ls-remote 侥幸成功一次不可依赖）
   → 第一次 fail-fast 同步死于 platform/bootable/libbootloader 连接超时
2) repo 不允许 local_manifest 覆写主 manifest 已有 remote 属性（"different attributes"报错）
   → 按清华镜像指南做法直接 sed .repo/manifests/default.xml：
     fetch="https://android.googlesource.com" → "https://mirrors.ustc.edu.cn/aosp"
3) USTC 镜像对并发 git 连接限流（HTTP 429）→ j12 立即触发
   → 改 /Volumes/los-build/sync_loop.sh：-j6 + 去 --fail-fast + 外层重试循环（40 轮，轮间退避 60s）
4) 实测吞吐：j6 下 ~23-33MB/s、零 429；预计 180GB 约 2 小时
5) zcode 后台任务 10 分钟上限 → nohup + disown 脱离会话，Bash 轮询监控
```

### soong darwin 支持残留勘察（build/ 同步完成后第一时间检查）

```
build/make/core/main.mk:519  "HOST OS darwin build is broken, disable this check for darwin for now"
                             → darwin 仍是受支持的 HOST_OS 分支（带已知破损依赖的豁免）
build/soong/ui/build/config.go:1043,1634  darwin → darwin-x86 预构建目录映射在位
build/soong/ui/build/sandbox_darwin.go     darwin sandbox 实现存在
结论：A15 构建系统并未完全移除 darwin 支持，模块级 darwin:enabled:false 才是主要风险面
```

## [2026-10-29] vendor blob 提取流程（底包 → 分区镜像 → dump）

### 分区清单解析（payload.bin 元数据）

```
工具链：python3.9 venv + payload_dumper 0.2.2（仅用其 protobuf 定义）+ 自写提取脚本 vendor_extract/my_dumper.py
说明：payload_dumper 0.2.2 在 macOS Python 3.9（spawn 模式）下 multiprocessing 报
     "TypeError: cannot pickle '_io.BufferedReader' object"，--workers 1 同样失败，
     故改用自写脚本（ZERO/REPLACE/REPLACE_BZ/REPLACE_XZ，逐操作 sha256 校验）。
底包为 FULL OTA（无 SOURCE_COPY 依赖），目标分区共 11 个 / ~5.9GB 原始数据。
```

### 提取结果（vendor_extract/images/，全部操作 sha256 校验通过）

```
boot.img          0.20 GB   ← 内核版本核验（见下）
dtbo.img          0.03 GB
system.img        0.79 GB
system_ext.img    0.95 GB
product.img       0.01 GB
vendor.img        0.68 GB
vendor_boot.img   0.20 GB
vendor_dlkm.img   0.16 GB
odm.img           1.26 GB
odm_dlkm.img      0.00 GB
my_product.img    1.65 GB
（未提取：my_stock 2.15GB / my_bigball 0.60GB 等 oplus 应用分区，blob 清单不引用）
```

### 内核版本核验（boot.img strings）

```
Linux version 5.10.236-android12-9-o-g55571f3ffcfa (...) #1 SMP PREEMPT Sat Feb 28 09:56:13 UTC 2026
→ 与任务书锚定"内核 5.10.236-android12-9"完全一致 ✓（HARDWARE_MATRIX SoC 项证据补齐）
```

### ext4/EROFS 展开（dump 目录）

```
文件系统检测：oplus 分区（vendor/odm/system/system_ext/product/my_product）全部为 EROFS
（镜像偏移 1024 处 magic e0f5e1e2）；仅 vendor_dlkm 为 ext4。
工具选型记录：
  1. p7zip 17.06：ext4 处理有缺陷（CRC Failed），EROFS 不支持 → 弃用
  2. 7-Zip 26.05 (sevenzip)：EROFS Open Error → 弃用；ext4 可用（用于 vendor_dlkm）
  3. erofs-utils 1.9.4（brew，fsck.erofs）：EROFS 唯一可靠提取工具 → 采纳
     注意：my_product 镜像内含重复路径条目，需 --overwrite 才能完整解出
最终展开结果（vendor_extract/dump/，共 ~10GB）：
  vendor 1.3G ✓  odm 2.2G ✓  system 1.2G ✓  system_ext 1.6G ✓
  product 17M ✓  my_product 2.3G ✓（--overwrite）  vendor_dlkm 154M ✓（7zz ext4）
```

### extract-files 端到端验证（无全量源码树的迷你树方案）

```
布局：scratch/{tools/extract-utils(git clone LineageOS/android_tools_extract-utils),
       device/oneplus/{ovaltine,sm8450-common}(baseline 镜像的本地克隆工作副本),
       prebuilts/extract-tools/{linux,darwin}-x86/bin/patchelf-0_18(brew patchelf 0.19.2 软链),
       python312(python-build-standalone 3.12.16，系统 python3.9 无 match 语法)}
运行：ovaltine 树 extract-files.py（ExtractUtils.device_with_common 同时处理两份清单）
       --allow-prohibited-files <dump>

三轮清单适配（EX01 底包 vs 基线清单锚点差异，已导出 patches/ex01-adaptation/）：
  第1轮：ovaltine 清单 4 处去 pin（|sha1 固定哈希与 EX01 不符）+ 指纹 vintf manifest
         HIDL→AIDL 路径替换（manifest_oplus_fingerprint.xml → manifest_oplus_fingerprint_aidl.xml）
         = 5 insertions/5 deletions
  第2-3轮：pjgowtham common 清单 pixelworks Iris 显示增强 11 项全部注释
         （EX01 仅保留 odm/lib{,64}/libpwiris*.so 与 vendor/lib{,64}/ 同类库，
          odm/bin/hw 服务、rc、vintf manifest、libpwirisIoctlWrapper.so 等已从底包移除）
         = 11 insertions/11 deletions
  第3轮结果：0 missing，extract exit=0

产物（scratch/vendor/oneplus/，即构建树的 vendor/ 目标位置）：
  ovaltine:        1414 blobs（1.8GB）+ Android.bp/Android.mk/BoardConfigVendor.mk/ovaltine-vendor.mk
  sm8450-common:   1265 blobs（572MB）+ 同套 makefile（sm8450-common-vendor.mk）
  blob fixup 全部生效（composer-service ndk 依赖改写、media_codecs_cape 过滤、
  gnss/keymint ndk_platform→ndk、libqcrilNr poweron_opt 改写、msm_irqbalance 扩展等）
```

## 构建尝试记录

（见 DECISIONS.md [DECISION-003]：构建宿主阻塞，未进入 repo sync / brunch 阶段。）
