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
