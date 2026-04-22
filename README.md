# framework

`framework` 是一个可复用的 Zig 应用框架，当前仍以骨架为主，但已经开始承载首批共享基础类型。

> **Prerequisite:** use Zig 0.16.0 for build and tests.

当前目标是沉淀一套与具体业务无关的基础能力，供 `ourclaw` 和未来其他 Zig 应用复用，包括：

- 日志
- trace
- 校验
- 错误模型
- 命令分发
- 任务系统
- 事件系统
- 配置字段注册表
- 结构化契约

## 当前状态

- 已初始化 Zig 工程骨架
- 已建立模块边界骨架
- 已落地首批共享错误与响应契约：`AppError`、`Envelope<T>`、`EnvelopeMeta`、`TaskAccepted`
- 已落地常见内部错误到 `AppError` 的统一映射 helper，可供后续 dispatcher 直接复用
- 已落地 `ValidationIssue`、`ValidationReport` 与 `fromValidationReport(...)` 的共享校验结果主干
- 已补齐 `rule.zig`、`rules_basic.zig`、`rules_security.zig`、`validator.zig`，支持 request/config 模式、unknown field 严格检查、object/array/schema 校验和基础安全规则执行
- 已补齐 `rules_config.zig`，并把 shared validator 接到最小 `CommandDispatcher` / `ConfigWritePipeline`
- `ValidationIssue.details_json` 与 schema/details 输出已接通，type mismatch / unknown field / required field 等场景会带结构化 details
- 已落地 `ConfigStore` / `MemoryConfigStore` 与 `ConfigWritePipeline.applyWrite(...)`，配置写回现在有最小受控 store 链路
- 已给 `TaskRunner` 补状态流转与查询接口，支持 `queued` / `running` / `succeeded` / `failed` / `cancelled`
- 已落地 `command_types.zig`、`command_context.zig`、`command_registry.zig` 与最小 `TaskRunner`，dispatcher 现已支持 authority 校验、sync handler dispatch 和 async task accept 骨架
- 已落地 `Observer`、`MultiObserver`、`EventBus`、`MemoryEventBus`，并已把 dispatcher、config write、task state 接到事件流
- `TaskRunner.submitJob(...)` 已支持真正异步执行与结果回写，async handler 可回填 `result_json`
- 已补齐 `LogObserver`、`JsonlFileObserver`、`MetricsObserver`，observer 层现在已有 log/file/metrics 三类最小实现
- `EventBus` 已补订阅治理与按 subscription cursor 轮询语义，支持 `subscribe` / `pollSubscription` / `unsubscribe`
- 配置写回 diff 已补充 `kind`、`sensitive`、`value_kind`，并已接入 side effect hook
- 已落地 `AppContext`，可统一装配 logger、observer、event bus、task runner、command registry、config store 等核心依赖
- `MetricsObserver` 已补更细请求/任务指标；配置写回已支持 post-write hook 与更细 side effect 分类
- `AppContext.makeDispatcher(...)` 与 `AppContext.makeConfigPipeline(...)` 已可直接产出共享运行时入口，便于后续 CLI/bridge/HTTP 与命令域接入
- 已经实际支撑 `ourclaw` 落下最小业务层：provider/channel/tool registry、ourclaw runtime app context、最小 CLI/bridge/HTTP adapter，以及 `app.meta` / `config.get` / `config.set` / `logs.recent` 命令
- 已落地首批共享日志主干：`LogLevel`、`LogField`、`LogRecord`、`LogSink`、`MemorySink`、`Logger`
- 已补齐 `ConsoleSink`、`JsonlFileSink`、`MultiSink`、`RedactMode` 与基础脱敏接线
- 已补 `TraceTextFileSink`，当前既支持机器友好的 JSONL 文件日志，也支持调用链友好的文本 trace 文件日志
- 已给 `Logger` 补 trace 上下文自动注入接口，后续 runtime 可直接挂接 `trace_id` / `span_id` / `request_id`
- 已补 `SummaryTrace`，可输出 `ME / RT / BT / ET` 风格摘要日志，与 `MethodTrace` / `StepTrace` 形成互补
- `app`、`config`、`runtime`、`observability` 已形成更完整的最小联通骨架，当前已经能够承载 `ourclaw` 的最小可运行业务层；后续重点转向真实 provider/channel/tool 业务能力、入口协议细化和 agent 运行链路

## 模块方向

- `src/core/`
- `src/config/`
- `src/observability/`
- `src/runtime/`
- `src/app/`
- `src/contracts/`

## 文档入口

- `framework/docs/README.md`
- `framework/docs/architecture/logging.md`
- `framework/docs/architecture/logging-usage-guide.md`
- `framework/docs/architecture/validation.md`
- `framework/docs/architecture/runtime-pipeline.md`

## 日志能力快速导航

如果你要接日志 / trace，建议优先看下面这些入口：

- 设计说明：`framework/docs/architecture/logging.md`
- 使用规范：`framework/docs/architecture/logging-usage-guide.md`
- 方法级链路示例：`framework/examples/logging_method_trace_demo.zig`
- 摘要级链路示例：`framework/examples/logging_summary_trace_demo.zig`

当前日志能力分层：

- `request_trace`
- `MethodTrace`
- `StepTrace`
- `SummaryTrace`
- `TraceTextFileSink`
- `JsonlFileSink`

推荐理解方式：

- `MethodTrace` 看完整调用链
- `SummaryTrace` 看 `ME / RT / BT / ET` 摘要结果
- `TraceTextFileSink` 适合本地调试和 grep
- `JsonlFileSink` 适合机器采集和后处理
