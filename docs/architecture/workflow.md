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
- `branch`
- `parallel`
- `wait_event`
- `ask_permission`
- `ask_question`

## 3. 与 tooling 的关系

`workflow` 应该建立在：

- `effects`
- `app.CommandDispatcher`
- `tooling`

之上，而不是脱离这些能力单独再造一套执行器。

## 4. 当前限制

当前仍未实现：

- 完整 DSL
- persistent workflow state
- parallel fan-out

这些属于后续阶段。

## 5. Phase 2 Batch A 已落能力

当前 phase 2 Batch A 已经补上：

- `WorkflowStepStatus`
- `WorkflowCheckpoint`
- `WorkflowCheckpointStore`
- `MemoryCheckpointStore`
- `WorkflowRunner.runWithCheckpoint(...)`
- `WorkflowRunner.resumeRun(...)`

当前恢复语义是：

- 从“下一个未完成 step”继续
- 已完成 step 不重跑
- terminal run 不允许 resume

需要特别说明：

- 当前 `MemoryCheckpointStore` 的目标是把 checkpoint / resume API 与状态模型定型
- 它不等于 durable file-backed persistence 已完整完成
- durable file-backed checkpoint 仍属于后续批次

## 6. Phase 2 Batch B 已落能力

当前 phase 2 Batch B 已经补上最小控制流能力：

- `branch`
- `parallel`
- `wait_event`
- `ask_permission`
- `ask_question`

当前语义是：

- `branch`
  - 基于前一步 `last_output_json` 做条件判断
  - 在当前 step 内执行 `on_true / on_false` 目标
- `parallel`
  - 支持受限 target fan-out
  - 在有 `TaskRunner` 时可并发执行
- `wait_event`
  - 无匹配事件时进入 `waiting`
  - 恢复后继续用保存的 cursor 查找新事件
- `ask_permission` / `ask_question`
  - 通过可注入 handler 驱动
  - `pending` 时进入 `waiting`

需要明确的是：

- 这仍然不是完整 DSL
- `branch` 目前不是 arbitrary jump 机制
- `parallel` 目前是受限 target 集合，而不是通用 DAG
- `ask_permission` / `ask_question` 当前依赖注入 handler，而不是完整产品 runtime

## 7. 当前价值

虽然还是最小版，但它已经证明：

- workflow 不是纯文档抽象
- 它已经能接上 logger / event bus / task runner
- 它已经开始具备最小可恢复状态
- 它已经开始具备最小控制流与 human-in-the-loop 能力
- 后续完全可以作为 `ourclaw` 的 deterministic command pipeline substrate
