# STATUS.md — 实时状态（最终报告）

> **2026-10-31 审计注记（事实更正）**：本文件是 2026-10-29 的终止状态快照，已被后续 brunch 尝试与 `AUDIT_REPORT.md` 取代。事实更正：`repo sync` 已执行（约 245 GB）；`brunch` 已执行 4 轮但均未成功；`out/target/product/ovaltine` 不存在；vendor blobs 已提取完成（0 missing）。以 `AUDIT_REPORT.md` / `TASK_PLAN.md` 为准。

> 更新规则：每完成一个原子动作立即更新，禁止事后补写。
> 最后更新：2026-10-29 06:30 (本地)
> **终止状态：任务书 §6.3 阻塞路径**（构建步骤阻塞于宿主环境，DECISION-003）

## 终止条件判定

任务书 §6.1（成功路径）/ §6.2（降级路径）均要求 brunch 构建成功；§6.3（阻塞路径）满足——
在 lineage-22.1 上遭遇无法在 Agent 权限范围内解决的**构建宿主阻塞**（macOS 无 Linux 构建
环境 + 16 GB 内存，详见 DECISIONS.md [DECISION-003]，含已排除替代方案清单）。

**重要**：阻塞仅限"编译执行"这一个环节。任务书要求的阶段 0/1/2 全部产出物**均已完成且
经过实测验证**，且 vendor blob 提取管线超出任务书要求（不仅记录流程，而且端到端跑通）。

## 构建目标

**lineage-22.1**（DECISION-001：22.2 探针失败降级——五个关键仓库的 lineage-22.2 分支
最近提交均在 90 天窗口外，官方 LineageOS 组织的 ovaltine 设备树为空仓库、内核仓库不存在）

## 已完成项（全部有据可查）

| 阶段 | 事项 | 产出 |
|---|---|---|
| 0 | 来源 A/B 探针（GitHub API 36 次幂等 GET，原始 JSON 存 probes/） | 官方树为空壳（2025-01-29 批量清空）；组织 25 仓库全量遍历；90 天窗口 0 提交 |
| 0 | 底包核验 | CPH2415_15.0.0.1901(EX01) metadata 与任务书锚定一致；boot.img 内核 `5.10.236-android12-9-o-g55571f3ffcfa` 实测一致 |
| 0 | 判定与记录 | DECISION-001；DECISIONS.md / BUILD_LOG.md / STATUS.md |
| 1 | baseline/ 只读镜像 | 7 仓库（HEAD 与 API 交叉验证一致，~2.9GB） |
| 1 | 已知补丁核验与导出 | HBM 拒绝（8f7dc6e）、aux camera（01c3d5a）、wise light（42cc1f8）、UDFPS 调光（ac9b624）、rear ALS（d3cc97a）——**全部验证为 22.1 分支祖先**，导出 patches/；OSS composer 已随 22.1 树内置（无需动作）；可选补丁 pjgowtham offline-charging（258dbbd） |
| 1 | BASELINE_EVALUATION.md | 按任务书 §5 模板逐字段完成；common 树选型 pjgowtham@22.1（`7a3b991` 证明其按 OOS15 EX01 底包适配，与本底包同代）；风险清单 R-1～R-5 |
| 1 | local_manifests/ovaltine-lineage-22.1.xml | 6 工程全部按锁定 commit 固定 revision；已核对官方 22.1 manifest 无路径冲突 |
| 2 | HARDWARE_MATRIX.md | 13 硬件项 + 3 构建依赖项，逐项可验证依据；无真机声明，状态上限"一般" |
| extra | vendor blob 提取管线**实测通过** | payload.bin → 11 分区镜像（逐操作 sha256 校验通过）→ EROFS/ext4 展开（erofs-utils 1.9.4 / 7zz 26.05）→ extract-files 三轮清单适配后 **0 缺失** → 生成 vendor/oneplus/ovaltine（1414 blobs, 1.8GB）+ vendor/oneplus/sm8450-common（1265 blobs, 572MB）+ 全套 makefile；EX01 适配导出 patches/ex01-adaptation/（2 个 patch，16 处清单变更） |

## 阻塞项（精确缺失，按 §6.3 要求）

| # | 缺失项 | 影响 | 已排除的替代方案 |
|---|---|---|---|
| B-1 | Linux x86_64 构建宿主（A15 构建不支持 macOS 宿主） | brunch 无法执行 | 原生构建不支持；Docker/OrbStack/Colima 未安装且 16GB 内存下不可行；云主机需用户付费决策 |
| B-2 | ≥32GB 内存（实用下限） | 构建并行度/稳定性 | VM/容器均受同一约束；无解 |

（非阻塞项已全部自备：磁盘充足、repo 可装、vendor blobs 已生成、工具链脚本已验证。）

## 未执行项（及原因）

- `repo sync`：阻塞于 B-1/B-2（250GB 同步在无构建宿主前提下不产生可验证产出，DECISION-003 已排除"仅备树"方案）
- `brunch ovaltine`：同上
- 真机测试：无真机（HARDWARE_MATRIX.md 开头已声明）

## 移交清单（用户在 Linux 构建机上继续所需的最小集）

1. `local_manifests/ovaltine-lineage-22.1.xml` → 放入构建机源码树 `.repo/local_manifests/`
2. `patches/` → 已知补丁存档（22.1 分支已自带，无需重新应用）+ `patches/ex01-adaptation/` 2 个补丁（应用到 device/oneplus/ovaltine 与 pjgowtham sm8450-common 工作副本）
3. `scratch/vendor/oneplus/` → 直接拷贝到构建机源码树 `vendor/oneplus/`（或按 BUILD_LOG 流程在构建机上重新提取，脚本 vendor_extract/my_dumper.py 随附）
4. `BASELINE_EVALUATION.md` 风险清单 R-1～R-5 → 构建时的重点关注项
5. 底包 zip 保留在根目录（构建机重新提取或对照均需要）

## 文件索引

- 决策：`DECISIONS.md`（DECISION-001/002/003）
- 过程日志：`BUILD_LOG.md`（探针、提取、工具链踩坑全记录）
- 评估：`BASELINE_EVALUATION.md` · 硬件：`HARDWARE_MATRIX.md`
- manifest：`local_manifests/ovaltine-lineage-22.1.xml`
- 补丁：`patches/`（5 个已验证祖先补丁 + 1 可选 + 2 个 EX01 适配）
- 证据：`probes/*.json`（API 原始存档）
- 提取产物：`vendor_extract/{payload.bin,images/,dump/,my_dumper.py}` · `scratch/vendor/oneplus/`
- git：`main`（阶段 0 快照）+ `bringup/ovaltine-lineage-22.1`（工作分支，全部提交遵循 [<模块>] <动作> <对象> 规范）
