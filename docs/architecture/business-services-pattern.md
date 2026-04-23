# framework business services / service bundle 模式

## 1. 目标

本文档用于解释在 `framework` 上构建业务项目时，为什么需要 `service bundle` / `services facade`，以及推荐的最小使用模式。

它解决的问题是：

- `framework.CommandContext` 足够做 dispatch，但不足以直接承载复杂业务依赖
- 业务项目不应把所有依赖重新塞回 `framework.AppContext`
- 命令处理器需要一个稳定、可组合、可测试的服务聚合入口

## 2. 核心结论

推荐模式是：

```text
framework.AppContext
  = kernel runtime

ToolingRuntime / WorkflowRuntime
  = shared substrate

BusinessServices
  = app-specific service bundle

CommandContext.user_data
  -> BusinessServices
```

这意味着：

- kernel 继续保持通用
- 中层 runtime 继续保持可复用
- 业务项目通过 `BusinessServices` 暴露自己的稳定服务面

## 3. 为什么不能把所有依赖都塞回 AppContext

如果业务项目继续把所有依赖都放进一个 giant `AppContext`：

- framework 边界会越来越模糊
- kernel 会被 app-specific 依赖污染
- 测试时很难只替换局部依赖
- 后续 `zig-opencode` / `ourclaw` 的依赖模型会越来越重

因此推荐：

- `framework.AppContext` 只承载 kernel
- `ToolingRuntime` 等组合层承载 shared substrate
- `BusinessServices` 承载业务项目自己的依赖聚合

## 4. 推荐结构

一个最小业务服务束建议至少包含：

- `framework_context`
- `tooling_runtime`
- 项目自己的业务配置或根路径
- 项目自己的 registry / repository / service

并提供：

- `fromCommandContext(...)`

这样命令 handler 只依赖：

- `CommandContext`
- `BusinessServices`

而不直接到处传具体依赖。

## 5. 什么时候该用 BusinessServices

当某个项目满足以下任一条件时，就应考虑引入 `BusinessServices`：

- 命令数量开始变多
- 命令需要共享多种运行时依赖
- 既要消费 `framework.AppContext`，又要消费 `ToolingRuntime`
- 需要为测试注入替身或 mock 服务

## 6. 示例模式

建议后续参考：

- `framework/src/tooling/examples/business_services_demo.zig`
- `framework/examples/business_services_demo.zig`

它们演示了：

- 如何定义 `ExampleServices`
- 如何把它挂到 `CommandContext.user_data`
- 如何通过 dispatcher 调用 command

## 7. 最终建议

如果把本文压缩成一句话，可以写成：

> `BusinessServices` 是 app-specific facade，负责把 kernel 与 shared substrate 组合成业务项目真正消费的依赖面；它应成为 future `zig-opencode` 与 `ourclaw` 消费 `framework` 的标准模式之一。
