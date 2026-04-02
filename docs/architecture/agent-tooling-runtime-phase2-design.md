# framework agent tooling runtime Phase 2 设计

## 1. 目标

本文档基于 [`agent-tooling-runtime-phase2-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-phase2-requirements.md)，说明 phase 2 推荐如何实施。

phase 2 的核心不是“再加更多模块名”，而是让当前 phase 1 已落地的 substrate 真正长成可持续复用的平台中层。

## 2. 设计总判断

phase 2 最合理的总体形态是：

```text
Phase 1
  = Tool Execution Substrate

Phase 2
  = Workflow Hardening
  + Kit Extraction
  + Adapter Expansion
  + Consumer Reuse Hardening
```

也就是说：

- workflow 要从最小 runner 变成可恢复 orchestration substrate
- `agentkit` / `servicekit` 要从占位层变成最小可用 kit
- tooling 要从 command-only 走向可对外消费
- `zig-opencode` / `ourclaw` 要从“最小切片验证”走向“稳定接入模式”

## 3. Phase 2 总体结构

建议 phase 2 的整体结构理解为：

```text
framework
  kernel
  ├─ effects
  ├─ tooling
  ├─ workflow
  ├─ agentkit
  └─ servicekit
```

可以用这个关系图理解：

```text
                  ┌──────────────────────┐
                  │   framework kernel   │
                  │ app/runtime/core/... │
                  └──────────┬───────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
  ┌────────────┐      ┌────────────┐      ┌────────────┐
  │  effects   │      │  tooling   │      │  workflow  │
  └─────┬──────┘      └─────┬──────┘      └─────┬──────┘
        │                   │                   │
        └────────────┬──────┴──────┬────────────┘
                     ▼             ▼
               ┌───────────┐ ┌────────────┐
               │ agentkit  │ │ servicekit │
               └─────┬─────┘ └─────┬──────┘
                     │             │
                     ▼             ▼
               zig-opencode      ourclaw
```

## 4. Workflow 设计

### 4.1 设计目标

phase 2 的 workflow 不应再只是“顺序 step 执行器”，而要成为真实可恢复的 deterministic orchestration substrate。

### 4.2 推荐新增模块

建议在现有 `src/workflow/` 上新增：

- `checkpoint_store.zig`
- `policy.zig`
- `resume.zig`
- `builtin_steps.zig`

保留现有：

- `definition.zig`
- `step_types.zig`
- `runner.zig`
- `state.zig`

### 4.3 推荐新增 step 类型

phase 2 建议新增这些 step：

- `branch`
- `parallel`
- `wait_event`
- `ask_permission`
- `ask_question`

仍然不建议在 phase 2 引入“自由度过高的大 DSL”，而应继续保持：

- typed definition
- explicit step kinds
- deterministic state

### 4.4 checkpoint / resume 模型

建议 phase 2 的 workflow state 结构至少显式记录：

- `run_id`
- `workflow_id`
- `current_step_index`
- `step_status`
- `step_outputs`
- `waiting_reason`
- `terminal_result`

建议先做：

- file-backed 或 memory-backed `CheckpointStore`
- 明确的 `resume(run_id)` 路径

不建议 phase 2 一开始就做：

- 分布式恢复
- 多副本协作
- 动态 DSL replay

### 4.5 并行模型

建议 phase 2 的 `parallel` 采用“有限 fan-out + 聚合结果”模型，而不是过早做复杂 DAG。

建议最小支持：

- fan-out
- wait all
- aggregate results
- fail-fast policy
- continue-on-error policy

## 5. Tooling 与 Adapter 设计

### 5.1 设计目标

phase 2 的 tooling 重点不是再加一个 runner，而是让 tooling 更适合作为“对外消费面”。

### 5.2 推荐新增 adapter

phase 2 最推荐优先做：

- `stdio_surface.zig`

第二优先级：

- `http_surface.zig`

原因：

- `stdio` 最适合 skill backend 与 agent tool host
- `http` 很重要，但更适合在 `stdio` 路径稳定后继续扩

### 5.3 stdio adapter 设计

建议 `stdio_surface` 做这些事：

- 读取 structured request
- 定位 tool / workflow
- 执行
- 输出 structured result
- 统一错误 envelope

不要让 `stdio_surface` 感知：

- app-specific product logic
- UI
- provider/session semantics

### 5.4 工具打包设计

phase 2 建议补一个更稳定的 tool manifest / package 形态，至少表达：

- tool id
- display metadata
- execution kind
- input schema summary
- adapter availability

这会让：

- examples
- stdio export
- future marketplace / plugin

都更容易衔接。

## 6. AgentKit 设计

### 6.1 设计目标

`agentkit` 的目标不是成为完整 agent runtime，而是沉淀真正共享的 agent-oriented substrate。

### 6.2 推荐包含内容

phase 2 中 `agentkit` 建议只做这些：

- provider / model / health / catalog substrate
- provider readiness / selection helper
- shared request / execution metadata contracts
- 与 tooling/workflow 协作的 agent-facing adapter 约定

### 6.3 不建议包含内容

phase 2 中 `agentkit` 不建议直接包含：

- prompt assembly
- session history
- chat transcript
- provider concrete implementations
- category/product policy 本身

### 6.4 与 `zig-opencode` 的关系

`zig-opencode` 应继续保留：

- session runtime
- prompt assembly
- model/category product policy

而 `agentkit` 提供：

- 更稳定的 agent-facing substrate
- 未来多 app 共用的部分

## 7. ServiceKit 设计

### 7.1 设计目标

`servicekit` 的目标是吸收 `ourclaw` 等 service runtime 项目中的共享中层，而不是吸收整个业务平面。

### 7.2 推荐包含内容

phase 2 中 `servicekit` 建议只做这些：

- runtime host substrate
- heartbeat / cron helpers
- service lifecycle facade
- generic service command adapter

### 7.3 不建议包含内容

phase 2 中 `servicekit` 不建议直接包含：

- full gateway product logic
- channel platform specifics
- pairing business semantics
- daemon policy 特化逻辑

### 7.4 与 `ourclaw` 的关系

`ourclaw` 继续保留产品主链，`servicekit` 吸收反复出现的 service runtime substrate。

## 8. Consumer Integration 设计

### 8.1 `zig-opencode`

phase 2 对 `zig-opencode` 的推荐方向：

- 在 builtin tool 之外，开始消费更强的 `workflow`
- 让部分 deterministic orchestration 不再都长在 app 内
- 继续保持 provider/session/prompt 主链不下沉

### 8.2 `ourclaw`

phase 2 对 `ourclaw` 的推荐方向：

- 让 diagnostics / maintenance / runtime host 类能力继续消费 `workflow` 与 `servicekit`
- 把 phase 1 的 command slice 验证推进成更稳定模式

## 9. Developer Experience 设计

### 9.1 示例体系

phase 2 应把 examples 从“几个单点 demo”推进到“能让人模仿”的层次。

建议新增：

- workflow with checkpoint example
- stdio tool example
- service facade example
- agent-facing adapter example

### 9.2 模板/脚手架

phase 2 建议至少提供一种轻量模板，例如：

- native tool template
- script-backed tool template
- workflow-backed command template

### 9.3 文档入口

phase 2 的文档入口建议形成以下层次：

1. requirements
2. design
3. tasks
4. implementation guide
5. examples

## 10. Phase 2 推荐实施顺序

建议顺序如下：

1. workflow hardening
2. `stdio` adapter
3. `agentkit` 最小可用层
4. `servicekit` 最小可用层
5. consumer integration 第二批切片
6. examples / templates / docs

这个顺序的好处是：

- 先把真正的执行 substrate 做强
- 再把对外消费面打开
- 最后再把开发体验做出来

## 11. 风险与控制

### 11.1 风险：workflow 被做成第二个 agent loop

控制方式：

- 明确 step 只能表达 deterministic orchestration
- 明确 prompt/model 不进入 workflow core

### 11.2 风险：`agentkit` / `servicekit` 变成“产品搬家”

控制方式：

- 每个新增模块都回答“共享在哪里”
- 所有 app-specific 逻辑留在 app

### 11.3 风险：adapter 过早扩张

控制方式：

- phase 2 先做 `stdio`
- 不同时铺开所有 adapter

## 12. 最终建议

如果只保留一句设计判断，建议保留这条：

> phase 2 不应追求更多抽象名词，而应把 workflow 做强、把 kit 做实、把 adapter 打开、把消费模式稳定下来。
