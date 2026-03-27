# framework 日志优化设计

## 1. 目标

本文档在 [`logging-optimization-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/logging-optimization-requirements.md) 的基础上，进一步说明：

- 本轮日志优化建议采用什么设计方向
- 哪些模块应该怎么改
- 哪些点先做、哪些点后做

本文档只说明“推荐怎么做”，不直接承担施工清单角色。

## 2. 核心设计判断

### 2.1 继续沿用现有 logging 架构，不做推翻式重写

当前架构：

- `record.zig`
- `logger.zig`
- `sink.zig`
- `memory_sink.zig`
- `console_sink.zig`
- `file_sink.zig`
- `trace_text_file_sink.zig`
- `multi_sink.zig`
- `redact.zig`

仍然是合理的。

本轮优化不建议打散它，而是建议：

- 增量增强
- 补足边界
- 降低未来演进风险

### 2.2 优先补“稳定性”，再补“表达力”

优先级建议如下：

1. 并发与读取语义
2. 记录类型语义化
3. 截断可观测性
4. redaction 增强
5. 文件 sink 治理
6. examples 体系补齐

## 3. 并发与可见性设计

### 3.1 MemorySink

当前问题：

- 写入已加锁
- 但 `latest()` / `recordAt()` 返回内部元素指针，锁释放后稳定性不足

推荐设计：

- 保留现有 API 以兼容测试
- 新增 `snapshot()` 或 `cloneLatest()` 一类接口
- 明确把旧接口标注为“仅适合测试/受控场景”

这样能兼顾：

- 向后兼容
- 未来更高并发可见性

### 3.2 Console / File / Trace sink

推荐设计：

- 各 sink 内部自带最小 mutex
- 不急于引入统一异步日志队列

原因：

- 结构简单
- 变更局部
- 对当前体量更稳

如果 future 负载真的成为问题，再考虑统一序列化写层。

## 4. 语义化记录设计

### 4.1 为 LogRecord 增加稳定类型

推荐在 `LogRecord` 中新增类似：

- `kind: ?LogRecordKind`

其中 `LogRecordKind` 至少支持：

- `generic`
- `request`
- `step`
- `method`
- `summary`

### 4.2 Trace helper 主动设置 kind

由：

- `request_trace`
- `StepTrace`
- `MethodTrace`
- `SummaryTrace`

在写入记录时主动设置稳定 kind。

这样：

- JSON 输出更稳定
- pretty 渲染更稳
- diagnostics 层也更容易做结构化消费

### 4.3 sink 渲染先看 kind，再看字段

推荐策略：

1. 先根据 `kind` 分发渲染
2. 再根据字段补充输出
3. 最后再保留自由字段回退

这样可以把当前对 `message` 文本的强耦合降低很多。

## 5. 截断可观测性设计

### 5.1 Logger 内部保留轻量计数

推荐为 `SubsystemLogger` 或 `Logger` 增加：

- `truncated_subsystem_count`
- `dropped_default_fields_count`
- `dropped_runtime_fields_count`

至少要能让测试和 diagnostics 感知到截断发生过。

### 5.2 不建议把所有截断都直接写日志

因为：

- 截断本身发生在日志路径上
- 再写日志容易形成自反馈噪音

更稳的做法是：

- 保留内部状态
- 通过 diagnostics / snapshot / counters 暴露

## 6. Redaction 设计

### 6.1 继续保留启发式 key 匹配

这部分已经有现实价值，应继续保留。

### 6.2 增加显式敏感标记

推荐两种可能方向：

1. `LogField` 扩展敏感性元信息
2. logger API 增加显式敏感字段 helper

比如：

- `LogField.sensitiveString(...)`
- 或在 `LogField` 上增加 `sensitive: bool`

然后 redaction 优先使用显式标记，再回退到 key heuristic。

### 6.3 与 validation/config schema 的关系

长期建议是和 `FieldDefinition.sensitive` 对齐，但当前不必强耦合。

本轮更适合：

- 先在 logging 自己的字段模型里落显式敏感标记
- 后续再做跨模块对齐

当前结论：

- 当前阶段不让 `logging` 直接强依赖 `FieldDefinition`
- 未来若要对齐 `FieldDefinition.sensitive`，建议通过 adapter / helper 层把 schema 的 `sensitive` 信息映射到 `LogField.sensitive`
- 因此当前阶段已经完成“评估是否应对齐”的判断：应对齐，但不应直接强耦合

## 7. 文件 sink 治理设计

### 7.1 增加只读状态接口

推荐为：

- `JsonlFileSink`
- `TraceTextFileSink`

增加只读状态接口，例如：

- `snapshot()`
- `stats()`

最小内容可包括：

- `current_bytes`
- `max_bytes`
- `degraded`
- `dropped_records`

### 7.2 rotation 先做扩展点，不急着完整实现

本轮建议：

- 在代码结构中预留 rotation/retention 扩展点
- 不要求在这一轮把完整 rotation 做完

当前结论：

- 暂不抽共享 `file rotation helper`
- 先保留 `JsonlFileSink` 与 `TraceTextFileSink` 各自的扩展注释与状态接口
- 等 future 真正实现 rotation/retention 时，再根据共同语义决定是否抽共享 helper

## 8. examples 设计

### 8.1 对现有 `logging_demo.zig` 的处理

推荐：

- 保留，但明确标记为 app integration demo

不要再把它当成 logging 主入口示例。

当前结论：

- 这一轮选择“保留并重新分类”
- 当前阶段不重写 `logging_demo.zig`

### 8.2 新增 pure framework 示例

建议新增：

- `logging_basic_demo.zig`
- `logging_redaction_demo.zig`
- `logging_multi_sink_demo.zig`
- `tooling_observability_demo.zig`
- `workflow_observability_demo.zig`

## 9. 最终设计建议

如果把整份设计压缩成一句话，可以写成：

> 这轮日志优化应以“保持现有架构不推翻”为前提，优先补齐并发边界、稳定语义类型、截断可观测与 redaction 表达力，再逐步增强文件治理与 examples 体系。
