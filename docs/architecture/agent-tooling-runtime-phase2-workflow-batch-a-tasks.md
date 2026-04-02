# framework Phase 2 Workflow Batch A 任务清单

## 1. 目标

本文档把 phase 2 里最优先的 `workflow` 主轴进一步拆成 Batch A。

Batch A 的主题非常明确：

> Checkpoint / Resume Foundation

也就是：

- 不先做全部新 step
- 不先做 stdio adapter
- 先把 workflow 从“只能一次性跑完的 runner”推进到“能保存状态、能恢复”的最小 substrate

对应上游文档：

- [`agent-tooling-runtime-phase2-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-phase2-requirements.md)
- [`agent-tooling-runtime-phase2-design.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-phase2-design.md)
- [`agent-tooling-runtime-phase2-tasks.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-phase2-tasks.md)

## 2. 为什么 Batch A 先做这个

phase 2 的真正分水岭不是再多几个 step 类型，而是：

- workflow 有没有可恢复状态
- workflow 能不能支撑更长生命周期的 deterministic orchestration

如果没有 checkpoint / resume：

- `parallel`
- `wait_event`
- `ask_permission`
- `ask_question`

这些能力即使加上，也仍然像“更复杂的 runner”，不像真正的平台 substrate。

## 3. Batch A 范围

Batch A 只覆盖以下内容：

- `CheckpointStore`
- `WorkflowRunState` 扩展
- `WorkflowRunner` 的 save / resume 主路径
- 最小测试和 example

Batch A 明确不做：

- `parallel`
- `wait_event`
- `ask_permission`
- `ask_question`
- `stdio_surface`
- `agentkit`
- `servicekit`

额外边界说明：

- Batch A 的 `MemoryCheckpointStore` 目标是把 checkpoint / resume 的 API、状态模型和 runner 接口定型
- Batch A 不应被视为“durable workflow persistence 已完整完成”
- 若需要跨进程 durable file-backed checkpoint，应进入 Batch B 或之后的阶段

## 4. 文件级任务拆分

### 4.1 状态模型

- [x] 4.1.1 扩展 [`src/workflow/state.zig`](E:/vscode/fuckcode-dev/framework/src/workflow/state.zig)，新增 `WorkflowStepStatus`
- [x] 4.1.2 扩展 [`src/workflow/state.zig`](E:/vscode/fuckcode-dev/framework/src/workflow/state.zig)，定义 `WorkflowCheckpoint`
- [x] 4.1.3 让 `WorkflowCheckpoint` 至少包含：
  - `run_id`
  - `workflow_id`
  - `workflow_status`
  - `current_step_index`
  - `step_statuses`
  - `last_output_json`
  - `last_error_code`
  - `waiting_reason`
- [x] 4.1.4 为新的 state 类型补齐 clone / deinit / stable text helper

### 4.2 Checkpoint Store

- [x] 4.2.1 新建 [`src/workflow/checkpoint_store.zig`](E:/vscode/fuckcode-dev/framework/src/workflow/checkpoint_store.zig)
- [x] 4.2.2 定义 `WorkflowCheckpointStore` 抽象接口
- [x] 4.2.3 先实现一个 `MemoryCheckpointStore`
- [ ] 4.2.4 可选实现一个最小 `FileCheckpointStore`，如果不做文件版，要在文档里说明留待 Batch B
- [x] 4.2.5 为 checkpoint store 补齐测试：save / load / update / missing run id

### 4.3 WorkflowRunner 挂接

- [x] 4.3.1 扩展 [`src/workflow/runner.zig`](E:/vscode/fuckcode-dev/framework/src/workflow/runner.zig)，让 `WorkflowRunner` 依赖可选 `checkpoint_store`
- [x] 4.3.2 为 `WorkflowRunner` 新增 `runWithCheckpoint(...)`
- [x] 4.3.3 在每个 step 完成后保存 checkpoint
- [x] 4.3.4 在 run 终态时保存 terminal checkpoint
- [x] 4.3.5 新增 `resume(run_id)` 或等价入口
- [x] 4.3.6 `resume` 只要求从“下一个未完成 step”继续，不要求复杂 replay

### 4.4 Run ID 与 Resume 语义

- [x] 4.4.1 明确 `run_id` 的生成策略
- [x] 4.4.2 确定 `workflow_id` 与 `run_id` 的关系
- [x] 4.4.3 明确恢复语义：
  - 已完成 step 不重跑
  - 当前 step 失败后允许再次进入
  - terminal run 不允许 resume
- [x] 4.4.4 把这些语义写进 [`workflow.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/workflow.md) 或新的 phase 2 workflow 文档

### 4.5 测试

- [x] 4.5.1 为 `state.zig` 新增 checkpoint state 测试
- [x] 4.5.2 为 `checkpoint_store.zig` 新增 save/load/update 测试
- [x] 4.5.3 为 [`src/workflow/runner.zig`](E:/vscode/fuckcode-dev/framework/src/workflow/runner.zig) 新增“顺序执行时生成 checkpoint”测试
- [x] 4.5.4 为 [`src/workflow/runner.zig`](E:/vscode/fuckcode-dev/framework/src/workflow/runner.zig) 新增“从 checkpoint 恢复继续执行”测试
- [x] 4.5.5 为 [`src/workflow/runner.zig`](E:/vscode/fuckcode-dev/framework/src/workflow/runner.zig) 新增“terminal run 无法 resume”测试

### 4.6 示例与文档

- [x] 4.6.1 新增一个 workflow checkpoint example
- [x] 4.6.2 让 example 明确展示：
  - 第一次执行
  - 读取 checkpoint
  - 恢复执行
- [x] 4.6.3 在 [`examples/README.md`](E:/vscode/fuckcode-dev/framework/examples/README.md) 增加该示例说明
- [x] 4.6.4 在 [`workflow.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/workflow.md) 补 phase 2 checkpoint/resume 小节

## 5. 建议的施工顺序

建议按下面顺序做：

1. 扩 state
2. 做 memory checkpoint store
3. 把 runner 接上 checkpoint save
4. 再做 resume
5. 补测试
6. 补 example / docs

不要反过来先写 example。

## 6. Batch A 完成判定

当下面条件都满足时，可认为 Batch A 完成：

- [x] `WorkflowCheckpoint` 类型稳定存在
- [x] `MemoryCheckpointStore` 可用
- [x] `WorkflowRunner` 能保存 checkpoint
- [x] `WorkflowRunner` 能从 checkpoint 恢复
- [x] tests 覆盖 save/load/resume/terminal guard
- [x] 至少 1 个 checkpoint example 可运行
