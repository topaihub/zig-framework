# framework 日志优化需求定义

## 1. 目标

本文档用于定义 `framework` 日志优化这一轮的**需求约束**，确保后续大模型在实施日志优化时，不只是“根据建议写代码”，而是有明确的目标、边界与验收标准。

本文档优先回答：

- 这一轮日志优化必须解决什么
- 哪些问题是优先级最高的
- 哪些内容明确不做
- 什么时候可以认为“日志底座已达到更稳的可复用状态”

若后续设计或任务文档与本文冲突，以本文为准。

## 2. 背景

当前 `framework/src/core/logging` 已经形成了一套可工作的日志底座，核心特征包括：

- 结构化 `LogRecord`
- `Logger / SubsystemLogger / LogSink` 分层
- `MemorySink / ConsoleSink / JsonlFileSink / TraceTextFileSink / MultiSink`
- trace 上下文自动注入
- request / method / summary trace 分层

从 [`logging-reuse-evaluation.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/logging-reuse-evaluation.md) 的判断看，这套设计已经可以继续复用，但在继续服务：

- `tooling`
- `workflow`
- `ourclaw`
- `zig-opencode`

之前，仍需要一轮明确的优化。

## 3. 非目标

本轮日志优化明确不以以下内容为目标：

- 引入完整 OpenTelemetry
- 引入远程日志收集后端
- 一次性重写整个 logging 子系统
- 让日志系统承载 GUI 展示逻辑
- 在当前阶段做异步日志队列大重构

一句话：

> 本轮目标是增强现有日志底座的稳定性和可复用性，而不是推翻重写。

## 4. 总体需求

### Requirement 1: 日志系统 SHALL 继续保持结构化中心模型

本轮优化不得破坏以 `LogRecord` 为中心的结构化模型。

允许增强：

- 字段
- 语义类型
- snapshot API
- 渲染策略

不允许退化为以自由文本为主的日志系统。

### Requirement 2: 日志系统 SHALL 继续服务平台级复用

本轮优化必须以未来继续支撑这些场景为前提：

- `tooling`
- `workflow`
- `ourclaw`
- `zig-opencode`

即，优化方向必须偏平台底座，而不是只针对某个单一应用。

## 5. 并发与可见性需求

### Requirement 3: sink 并发策略 MUST 明确

所有核心 sink 的并发写入策略必须明确，至少包括：

- `MemorySink`
- `ConsoleSink`
- `JsonlFileSink`
- `TraceTextFileSink`

“没有显式并发策略”不应继续被视为可接受状态。

### Requirement 4: MemorySink 读取接口 MUST 提供稳定读取能力

`MemorySink` 不能长期依赖仅返回内部元素指针的读取方式作为主要读取 API。

它必须提供至少一种更稳定的读取方式，例如：

- snapshot
- clone
- immutable copy view

以支撑更高并发或更长期的消费场景。

## 6. 语义化记录需求

### Requirement 5: request / step / method / summary 记录 MUST 具备稳定语义类型

日志系统不能长期只依赖：

- `subsystem`
- `message`
- 某些约定字段名

去猜测记录类型。

至少以下四类记录必须具备稳定语义：

- request
- step
- method
- summary

### Requirement 6: 专用 pretty 渲染 MUST 优先依赖稳定语义，而不是文本猜测

控制台和 trace 文本 sink 的专用渲染逻辑，应该优先依赖稳定类型信息，而不是 message / subsystem 的自由文本组合。

## 7. 截断与退化可观测性需求

### Requirement 7: 静默截断 MUST 变为可观测行为

当前 subsystem / field 数量的静默截断，必须变成可观测行为。

至少需要让下列情况可被发现：

- subsystem 被截断
- 字段被丢弃
- sink 进入 degraded 状态

## 8. Redaction 需求

### Requirement 8: Redaction MUST 同时支持启发式规则与显式标记

本轮优化后，日志 redaction 不能只依赖字段名启发式。

应满足：

- 保留当前启发式规则作为兜底
- 支持显式敏感字段标记
- 显式标记优先级高于启发式判断

## 9. 文件 sink 治理需求

### Requirement 9: 文件 sink 状态 MUST 可被上层读取

`JsonlFileSink` 与 `TraceTextFileSink` 的关键状态，必须能被 diagnostics 或上层系统读取，例如：

- 当前大小
- 是否 degraded
- dropped count

### Requirement 10: 未来 rotation / retention MUST 有明确扩展入口

即便本轮不完整实现 rotation，也需要在设计和代码层明确 future 扩展入口，避免之后推翻现有 file sink 形态。

## 10. examples 体系需求

### Requirement 11: examples MUST 区分 pure framework demo 与 app integration demo

`framework/examples` 中的日志示例，必须清晰区分：

- 纯 framework 用法示例
- 应用集成示例

不能让使用者误以为使用 logging 必须依赖 `ourclaw` 一类应用上下文。

### Requirement 12: examples MUST 覆盖基础日志、redaction、多 sink、tooling/workflow observability

后续 examples 至少应能覆盖：

- 基础 logger + sink 用法
- redaction
- multi-sink
- tooling observability
- workflow observability

## 11. 完成判定

可认为本轮日志优化完成时，至少应满足：

- [ ] sink 并发策略明确且有测试
- [ ] `MemorySink` 拥有稳定读取 API
- [ ] request/step/method/summary 具备稳定语义类型
- [ ] pretty 渲染不再主要依赖自由文本猜测
- [ ] 截断与 degrade 状态可被观测
- [ ] redaction 支持显式敏感标记
- [ ] 文件 sink 状态可被 diagnostics 消费
- [ ] examples 体系区分 pure framework demo 与 app integration demo

## 12. 最终建议

如果把本文压缩成一句话，建议保留这条：

> 本轮日志优化的目标不是重写 logging，而是把当前已可复用的日志底座提升到更适合平台级持续复用的状态。
