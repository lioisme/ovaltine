# patches/macos-build — macOS 实验性构建补丁

> **仅用于实验性分析环境，不进入 Linux/发布构建。** macOS 不是 AOSP/LineageOS 官方支持的构建宿主；这些补丁只用于在 16 GB Intel Mac 上尽量推进 soong 分析。

| 补丁 | 目标 | 内容 | 风险 |
|---|---|---|---|
| `0001-soong-cc-config-allow-macos-sdk-26.patch` | `build/soong` | 在 `darwin_host.go` 的 SDK allowlist 增加 15/25/26 | 放宽了 SDK 版本检查；需确认工具链行为 |
| `0002-blueprint-bootstrap-skip-go-tests-on-darwin.patch` | `build/blueprint` | 将 bootstrap Go `test` 规则改为 `touch $out` | **不是 darwin-only**，会全局跳过 Go 测试；Linux/发布禁用（AUDIT BLD-004） |
| `0003-soong-ui-darwin-trace-top.patch` | `build/soong` | 修复 `soong_ui.bash` 在 `set -u` 下引用未定义 `$T` 的问题；用脚本路径推导 TOP | 仅 Darwin 分支；Linux 不受影响 |

## 应用

```bash
export AOSP_ROOT=/path/to/aosp
APPLY_MAC_PATCHES=1 ./scripts/apply-patches.sh
```

`apply-patches.sh` 只在 `uname -s == Darwin` 且 `APPLY_MAC_PATCHES=1` 时应用这些补丁；默认跳过。

## 已知限制

- `soong_ui.bash` 修复后仍可能遇到 GNU `date -d`/`stat -c` 等噪声；这些不阻塞构建，但应逐步用 `gdate`/`gstat` 或 portable wrapper 修掉。
- 16 GB 内存/Intel Mac 不是生产构建环境；即使 soong 分析通过，全量 `brunch` 仍可能因内存/时间失败。
- 这些补丁是实验性的，不应作为“支持 macOS 构建”的承诺。
