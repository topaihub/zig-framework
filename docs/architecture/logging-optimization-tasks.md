# framework 日志优化可执行任务清单

## 1. 使用说明

本文档把以下两份文档中的结论收束为施工清单：

- [`logging-optimization-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/logging-optimization-requirements.md)
- [`logging-optimization-design.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/logging-optimization-design.md)

目标：

- 让后续大模型可以直接按清单推进日志优化
- 明确哪些优化应该优先做
- 明确每个优化大致应落在哪些文件

使用原则：

- 优先做前两组：并发安全与语义化记录类型
- 一组内建议按“模型 -> 实现 -> 测试 -> 文档”顺序推进
- 若日志优化与平台主线冲突，以主线 requirements 为准

这意味着本文档不再只是“建议 backlog”，而是 requirement + design 下游的实施清单。

## 2. 第一优先级：并发安全与内存可见性

### 2.1 MemorySink 可见性与读取语义

- [ ] 2.1.1 评估并记录 `MemorySink.latest()` / `recordAt()` 返回内部指针的风险边界
- [ ] 2.1.2 为 `MemorySink` 设计 snapshot 型读取接口，避免长期暴露内部指针
- [ ] 2.1.3 在 [`memory_sink.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/memory_sink.zig) 中实现 `snapshot()` 或等价接口
- [ ] 2.1.4 增加 snapshot 读取测试，覆盖单线程读取
- [ ] 2.1.5 增加 snapshot 读取测试，覆盖并发写入时的稳定读取
- [ ] 2.1.6 评估是否保留 `latest()` / `recordAt()` 作为仅测试用途 API，并在注释中写清楚限制

### 2.2 Console / File / Trace sink 并发策略

- [ ] 2.2.1 明确 [`console_sink.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/console_sink.zig) 的并发写策略
- [ ] 2.2.2 明确 [`file_sink.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/file_sink.zig) 的并发写策略
- [ ] 2.2.3 明确 [`trace_text_file_sink.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/trace_text_file_sink.zig) 的并发写策略
- [ ] 2.2.4 选择方案：逐 sink 自带 mutex，或抽一层统一序列化写入
- [ ] 2.2.5 在选定方案上实现并发保护
- [ ] 2.2.6 为 console sink 增加并发写测试
- [ ] 2.2.7 为 jsonl file sink 增加并发写测试
- [ ] 2.2.8 为 trace text sink 增加并发写测试

## 3. 第二优先级：记录类型语义化

### 3.1 LogRecord 语义类型

- [ ] 3.1.1 在 [`record.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/record.zig) 设计 `kind` / `semantic_class` 字段
- [ ] 3.1.2 评估 request / step / method / summary 四类记录是否应有稳定枚举值
- [ ] 3.1.3 为 `LogRecord.writeJson()` 增加语义类型输出
- [ ] 3.1.4 补齐 `LogRecord` JSON 序列化测试

### 3.2 Trace helper 输出规范

- [ ] 3.2.1 检查 `request_trace` 的输出是否应显式写 `kind=request`
- [ ] 3.2.2 检查 `StepTrace` 的输出是否应显式写 `kind=step`
- [ ] 3.2.3 检查 `MethodTrace` 的输出是否应显式写 `kind=method`
- [ ] 3.2.4 检查 `SummaryTrace` 的输出是否应显式写 `kind=summary`
- [ ] 3.2.5 更新 trace helper 的测试，使其断言稳定类型字段，而不只依赖 `message`

### 3.3 Pretty rendering 规则降耦

- [ ] 3.3.1 重构 [`console_sink.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/console_sink.zig) 中对 request/method/step/summary 的识别逻辑
- [ ] 3.3.2 重构 [`trace_text_file_sink.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/trace_text_file_sink.zig) 中对 request/method/step/summary 的识别逻辑
- [ ] 3.3.3 让专用渲染逻辑优先依赖 `LogRecord.kind`，而不是 message/subsystem 文本猜测
- [ ] 3.3.4 为 pretty console 与 trace text sink 增加渲染回归测试

## 4. 第三优先级：静默截断可观测

### 4.1 SubsystemLogger 容量限制透明化

- [ ] 4.1.1 评估 [`logger.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/logger.zig) 中 `max_subsystem_len` 的实际影响
- [ ] 4.1.2 评估 `max_default_fields` / `max_combined_fields` 的实际影响
- [ ] 4.1.3 设计截断后的可见反馈方式，例如：
  - `truncated_subsystem`
  - `dropped_field_count`
  - 内部 degrade 标志
- [ ] 4.1.4 在 `SubsystemLogger.emit(...)` 中落地至少一种反馈机制
- [ ] 4.1.5 增加字段溢出测试
- [ ] 4.1.6 增加 subsystem 截断测试

## 5. 第四优先级：Redaction 增强

### 5.1 现有启发式规则整理

- [ ] 5.1.1 梳理 [`redact.zig`](E:/vscode/fuckcode-dev/framework/src/core/logging/redact.zig) 当前的 safe/strict 规则覆盖范围
- [ ] 5.1.2 为已有规则补充更完整测试，覆盖漏判与误判边界

### 5.2 显式敏感字段标记

- [ ] 5.2.1 设计日志字段级的显式敏感标记方式
- [ ] 5.2.2 评估是否应与 `FieldDefinition.sensitive` 对齐
- [ ] 5.2.3 在 `LogField` 或 logger helper 层增加显式敏感标记能力
- [ ] 5.2.4 让 redaction 逻辑优先尊重显式标记，再回退到启发式规则
- [ ] 5.2.5 增加显式敏感字段 redaction 测试

## 6. 第五优先级：文件 sink 治理

### 6.1 文件 sink 状态暴露

- [ ] 6.1.1 统一 `JsonlFileSink` 与 `TraceTextFileSink` 的 degrade / dropped / current_bytes 状态字段语义
- [ ] 6.1.2 增加只读 snapshot/status API，供 diagnostics 层消费
- [ ] 6.1.3 为 sink 状态增加测试

### 6.2 rotation / retention 预备设计

- [ ] 6.2.1 在 `file_sink.zig` 中补一份注释或设计占位，说明 future rotation 入口
- [ ] 6.2.2 在 `trace_text_file_sink.zig` 中补一份注释或设计占位，说明 future rotation 入口
- [ ] 6.2.3 评估是否需要抽共享的 file rotation helper

## 7. 第六优先级：examples 体系修正

### 7.1 现有 example 整理

- [ ] 7.1.1 评估 [logging_demo.zig](E:/vscode/fuckcode-dev/framework/examples/logging_demo.zig) 是否保留在 framework examples 中
- [ ] 7.1.2 若保留，明确它属于 “app integration demo”，不是 “logging primary demo”
- [ ] 7.1.3 若不保留，迁移或重写为纯 framework 版本

### 7.2 建议新增示例

- [ ] 7.2.1 新增 `logging_basic_demo.zig`
- [ ] 7.2.2 新增 `logging_redaction_demo.zig`
- [ ] 7.2.3 新增 `logging_multi_sink_demo.zig`
- [ ] 7.2.4 新增 `tooling_observability_demo.zig`
- [ ] 7.2.5 新增 `workflow_observability_demo.zig`
- [ ] 7.2.6 更新 [examples/README.md](E:/vscode/fuckcode-dev/framework/examples/README.md) 中的日志示例说明

## 8. 第七优先级：与 tooling / workflow 的集成验证

- [ ] 8.1 为 `ToolRunner` 增加一组日志与事件断言测试
- [ ] 8.2 为 `ScriptHost` 增加一组 stderr / failure trace 测试
- [ ] 8.3 为 `WorkflowRunner` 增加 request/step/method/summary trace 组合示例或测试
- [ ] 8.4 在日志文档中增加 “tooling / workflow 如何接日志” 的说明

## 9. 完成判定

可认为日志优化这一轮“达到可复用加强版”时，至少应满足：

- [ ] 9.1 sink 并发策略已经明确且有测试
- [ ] 9.2 request/method/step/summary 记录具备稳定语义类型
- [ ] 9.3 静默截断可被观察到
- [ ] 9.4 redaction 支持显式敏感字段
- [ ] 9.5 文件 sink 状态可被 diagnostics 消费
- [ ] 9.6 examples 体系能正确区分 pure framework demo 与 app integration demo
