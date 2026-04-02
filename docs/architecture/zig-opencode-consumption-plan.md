# framework 对 zig-opencode 的消费计划

## 1. 目标

本文档用于说明 `zig-opencode` 未来如何消费 `framework` 当前已经落地的：

- `effects`
- `tooling`
- `workflow`

并明确哪些能力适合下沉到 `framework`，哪些仍应保留在 `zig-opencode` 内部。

## 2. 当前判断

`zig-opencode` 当前最适合优先消费的是：

- `framework/tooling`
- `framework/effects`
- `framework/workflow`

最不适合立即下沉的是：

- session timeline
- provider runtime
- prompt assembly
- model/category routing
- TUI/chat 产品语义

## 3. 推荐第一批接入点

### 3.1 builtin tools

`zig-opencode/src/tools/builtin/*` 中最适合先替换或包装成 `framework/tooling` 消费方的，是 deterministic 工具，例如：

- 文件扫描/列举
- shell 执行
- 简单脚本宿主
- repo health / diagnostics 类工具

### 3.2 workflow-like orchestration

`zig-opencode` 现在已有：

- loop
- orchestration

后续可以逐步把其中 deterministic orchestration 的部分，迁移为对 `framework/workflow` 的消费，而不是让 `zig-opencode` 自己承载全部可重试/可组合执行逻辑。

### 3.3 script-backed tool

若 `zig-opencode` 未来要接 skill backend 或外部 helper script，最合适的消费点将是：

- `framework/tooling/script_host`

而不是在 `zig-opencode` 内部再单独造一套脚本托管能力。

## 4. 最小真实场景建议

推荐一个最小真实验证场景：

> 在 `zig-opencode` 中引入一个 `framework/tooling` 提供的 deterministic builtin tool，用于 repo / workspace 健康检查或 markdown/script fetch。

这个场景足够说明：

- `framework` 的 tooling substrate 能被 `zig-opencode` 消费
- 不需要先改 session/runtime 主链路

## 5. 当前边界结论

一句话总结：

> `zig-opencode` 适合把 deterministic tool 与 orchestration substrate 逐步交给 `framework`，但不应把 AI session / provider / prompt 主链路过早下沉。

## 6. Phase 1 已实现切片

当前已经完成一个最小真实接入：

- 在 `zig-opencode/src/framework_integration/*` 中新增薄桥接层
- 由桥接层持有 `framework.ToolingRuntime`
- 将 `framework.RepoHealthCheckTool` 适配为 `zig-opencode` builtin tool `repo_health_check`

这次接入验证了：

- `framework/tooling` 可以被 `zig-opencode` 消费，而不必复制 deterministic tool host
- `zig-opencode` 可以把 framework-backed tool 包装回自身 builtin tool surface
- 接入不需要改 session / provider / prompt 主链路

这次接入没有做的事：

- 不把 `framework` command surface 直接混进 `zig-opencode`
- 不把 provider runtime、session runtime、prompt assembly 下沉到 `framework`

## 7. Phase 2B 已实现切片

当前已经完成一个 phase 2B 的第二批接入：

- `framework/agentkit` 提供 provider catalog / readiness / selection helper
- `zig-opencode` 的 category resolver 通过 bridge 消费这些 helper

这次接入验证了：

- `agentkit` 已经不只是占位层，而能承载共享 provider substrate
- `zig-opencode` 可以消费 `framework` 的 agent-oriented中层，而不是继续把 provider selection 逻辑完全留在 app 内

这次接入仍然没有做的事：

- 不把 provider concrete runtime 搬进 `framework`
- 不把 session runtime、prompt assembly、chat timeline 下沉到 `framework`
