# framework tooling 模块设计

## 1. 目标

`tooling` 模块负责把：

- Zig 原生工具
- 外部脚本
- command surface

统一收敛到同一 execution substrate 上。

## 2. 当前已落能力

当前已落：

- `ToolDefinition`
- `ToolContext`
- `ToolRegistry`
- `ToolRunner`
- `ScriptContract`
- `ScriptHost`
- `ToolingRuntime`
- `CommandSurface`
- native tool helper

## 3. 设计意图

它的关键目标不是替代 command dispatcher，而是：

- 把 tool 变成一等执行单元
- 让 command、tool、script 能共用主干
- 为 future `zig-opencode` / `ourclaw` 提供中层 substrate

## 4. 当前限制

当前仍然未完成的部分包括：

- `ToolExecutionEnvelope` 与现有 contracts 的更正式对齐
- authority / risk policy 的更完整 hook
- script-backed tool 错误映射细化

## 5. 示例

当前已有两个最小垂直切片：

- `repo.health_check`
- `script.markdown_fetch`

它们共同证明：

- direct tool 调用
- command surface 调用
- script-backed tool

都已经能在同一条 execution substrate 上工作。
