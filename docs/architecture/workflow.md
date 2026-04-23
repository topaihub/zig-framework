# framework workflow 模块设计

## 1. 目标

`workflow` 模块负责提供 deterministic orchestration substrate。

它不是完整 agent loop，也不是完整 DSL，而是：

- 顺序执行
- retry
- shell/command/emit_event 组合
- future orchestration 的基础

## 2. 当前已落能力

当前已落：

- `WorkflowDefinition`
- `WorkflowStep`
- `WorkflowStatus`
- `WorkflowRunResult`
- `WorkflowRunner`

并已支持：

- `command`
- `shell`
- `emit_event`
- `retry`

## 3. 与 tooling 的关系

`workflow` 应该建立在：

- `effects`
- `app.CommandDispatcher`
- `tooling`

之上，而不是脱离这些能力单独再造一套执行器。

## 4. 当前限制

当前仍未实现：

- 完整 DSL
- checkpoint / resume
- persistent workflow state
- parallel fan-out

这些属于后续阶段。

## 5. 当前价值

虽然还是最小版，但它已经证明：

- workflow 不是纯文档抽象
- 它已经能接上 logger / event bus / task runner
- 后续完全可以作为 `ourclaw` 的 deterministic command pipeline substrate
