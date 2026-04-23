# framework 日志模块复用性评估

## 1. 目标

本文档用于评估 `framework/src/core/logging` 当前这套日志设计是否适合继续作为后续开发的共享底座，以及在什么层面上已经足够复用、在哪些层面上应优先优化。

本文档同时结合了：

- `framework/src/core/logging/*`
- `framework/docs/architecture/logging.md`
- `framework/docs/architecture/logging-tracing-design.md`
- `framework/examples/` 下现有日志示例
- `ourclaw` 对这套日志能力的实际消费方式

## 2. 核心结论

结论可以先写明确：

> 当前 `framework` 的日志设计是可以继续复用的，而且已经具备平台级日志底座的雏形。

但与此同时：

> 它还没有达到可以长期冻结不动、直接作为最终形态日志内核的程度。在继续支撑更多 runtime、workflow、tooling 能力之前，建议做一轮有边界的优化。

因此，最合适的策略不是推倒重来，而是：

- 继续复用现有设计
- 在并发、安全、语义化渲染、redaction、容量治理这几个点上逐步优化

## 3. 当前设计中适合继续复用的部分

### 3.1 结构化数据模型

`framework/src/core/logging/record.zig` 中的 `LogRecord` 设计是健康的。

它已经具备平台级日志底座的关键字段：

- `level`
- `subsystem`
- `message`
- `trace_id`
- `span_id`
- `request_id`
- `error_code`
- `duration_ms`
- `fields`

这意味着：

- 它可以继续服务 `ourclaw`
- 也能服务 future `tooling`
- 也适合给 `workflow`、`zig-opencode` 和未来 manager/GUI 消费

### 3.2 Logger / SubsystemLogger / Sink 分层

`framework/src/core/logging/logger.zig` 的分层是合理的：

- `Logger`
- `SubsystemLogger`
- `LogSink`

尤其 `SubsystemLogger` 的价值非常高，因为它支持稳定构造：

- `runtime/dispatch`
- `tool/repo.health_check`
- `workflow/runner`
- `config/post_write`

这类层级式子系统路径对平台开发很重要。

### 3.3 Sink 体系

当前 sink 体系已经很接近可复用底座：

- `MemorySink`
- `ConsoleSink`
- `JsonlFileSink`
- `TraceTextFileSink`
- `MultiSink`

这意味着：

- 测试与调试有内存 sink
- 交互式运行有 console sink
- 机器消费有 JSONL sink
- 人工阅读调用链有 trace text sink

方向上是对的。

### 3.4 Trace 分层能力

从文档与 `ourclaw` 实际消费情况看，这套日志体系最强的部分其实不是“普通行日志”，而是：

- `request_trace`
- `MethodTrace`
- `SummaryTrace`
- `TraceTextFileSink`

这说明它已经在往 “execution observability substrate” 演进，而不是仅仅停留在普通日志库层面。

这对未来的：

- `tooling`
- `workflow`
- `ourclaw`
- `zig-opencode`

都非常有价值。

## 4. 当前设计中最值得优先优化的部分

### 4.1 并发安全边界

这是当前最优先需要优化的部分。

例如：

- `MemorySink` 已经加了 `mutex`
- 但 `latest()` / `recordAt()` 返回内部元素指针后就释放了锁

这意味着：

- 在单线程或测试场景问题不大
- 在更高并发的 runtime 中，这些引用的稳定性并不强

另外：

- `ConsoleSink`
- `JsonlFileSink`
- `TraceTextFileSink`

当前也没有统一的并发写保护策略。

建议：

- 为各 sink 明确并发策略
- 更稳的方向是提供 snapshot API，而不是长期依赖内部指针
- 视未来负载情况考虑统一序列化写入层

### 4.2 专用 pretty 渲染的耦合方式

`ConsoleSink` 和 `TraceTextFileSink` 当前对 request/method/step/summary 的识别，较多依赖：

- `subsystem`
- `message`
- 若干特殊字段名

这在当前阶段是可行的，但长期会有两个问题：

1. 渲染层开始“懂业务语义”
2. 一旦 message/subsystem 命名变动，渲染可能悄悄失效

建议未来考虑：

- 为 `LogRecord` 增加更显式的 `kind` / `semantic_class`
- 让 request/method/step/summary 这类记录拥有稳定类型标记

### 4.3 静默截断

`SubsystemLogger` 当前有这些硬编码限制：

- `max_subsystem_len = 128`
- `max_default_fields = 8`
- `max_combined_fields = 16`

问题不是这些限制本身，而是：

- 超限后是静默截断
- 调用方不一定知道字段已经丢失

这对后续 `tooling` / `workflow` 调试是不利的。

建议：

- 保留小而稳的默认上限
- 但要补截断可观测性，例如：
  - `dropped_field_count`
  - `truncated_subsystem`
  - sink degrade 标记

### 4.4 Redaction 规则表达能力

`redact.zig` 当前主要基于字段名关键字做敏感信息判断。

这对第一版很实用，但存在两类问题：

- 名字不明显的敏感字段可能漏掉
- 名字撞关键词的普通字段可能误伤

建议的长期方向是：

- 保留启发式规则作为兜底
- 逐步支持基于 schema / field definition 的显式敏感性标记

### 4.5 文件写入治理

当前 `JsonlFileSink` 和 `TraceTextFileSink` 已经有：

- `max_bytes`
- `dropped_records`

这比完全裸写要强很多，但对长期运行平台来说还不够。

后续可考虑：

- rotation
- retention
- degrade / dropped state 暴露
- 面向 diagnostics 的 sink 状态可见性

## 5. 对 examples 的判断

当前 `framework/examples` 下与日志相关的示例包括：

- `logging_demo.zig`
- `logging_method_trace_demo.zig`
- `logging_summary_trace_demo.zig`

### 5.1 值得保留的例子

#### `logging_method_trace_demo.zig`

这个例子是目前最接近“正确示范”的：

- `ConsoleSink + Logger`
- `request_trace.begin(...)`
- 多层 `MethodTrace.begin(...)`
- `finishSuccess(...)`
- `request_trace.complete(...)`

它很好地展示了：

- request trace
- method trace
- 多层调用链

对后续开发很有参考价值。

#### `logging_summary_trace_demo.zig`

这个例子也值得保留，因为它补了另一种使用面：

- `TraceTextFileSink`
- `MethodTrace`
- `SummaryTrace`
- request + method + summary 的组合输出

它说明日志系统不只是控制台友好，也支持人类阅读的调用链文本输出。

### 5.2 不够理想的例子

#### `logging_demo.zig`

这个例子不够理想，原因是：

- 它不是纯 `framework` 示例
- 它直接依赖了 `ourclaw`
- 它更像“展示应用运行时日志”，而不是“教别人如何使用 framework logging”

因此它不适合作为 `framework` 日志模块的主例子。

建议：

- 要么重写成纯 `framework` 版本
- 要么弱化其在 `framework/examples` 中的“日志主入口”地位

### 5.3 还缺的例子

若希望 examples 真正支撑 future 开发，建议补充：

- `logging_basic_demo.zig`
  - 演示最小 logger + sink 用法
- `logging_redaction_demo.zig`
  - 演示 safe / strict redaction
- `logging_multi_sink_demo.zig`
  - 演示 console + memory / jsonl 组合
- `tooling_observability_demo.zig`
  - 演示 ToolRunner / ScriptHost 的日志与 trace
- `workflow_observability_demo.zig`
  - 演示 WorkflowRunner 的 request/step/method/summary trace

## 6. 对 future 复用的建议

### 6.1 可以继续复用

以下方向现在就可以继续复用：

- `LogRecord` 结构
- `Logger / SubsystemLogger`
- sink 体系
- trace 上下文自动注入
- `request_trace / MethodTrace / SummaryTrace`

### 6.2 复用前最好先优化

建议在更大规模复用前优先做这几项优化：

1. 并发安全边界
2. 记录类型语义化
3. 静默截断可观测
4. redaction 能力增强

## 7. 最终结论

如果把整个判断压缩成一句话，可以写成：

> `framework/src/core/logging` 这套设计已经足够继续作为 vNext 的共享日志底座复用，尤其是 request/method/summary trace 分层能力很有平台价值；但在继续支撑更多 runtime、workflow、tooling 场景之前，最好补一轮并发安全、语义化渲染、截断可观测与 redaction 的优化。

这意味着：

- 现在不用推翻
- 也不应完全冻结
- 最合适的策略是：继续复用，渐进优化
