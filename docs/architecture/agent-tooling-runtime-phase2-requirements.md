# framework agent tooling runtime Phase 2 需求定义

## 1. 目标

本文档定义 `framework` 在 phase 1 完成之后的 **phase 2 需求约束**。

phase 1 已经把下面这些能力做成了可运行基座：

- `effects`
- `tooling`
- `script host`
- `command surface`
- 最小 `workflow runner`
- `agentkit / servicekit` 预备层
- 两个真实消费验证

因此，phase 2 的目标不再是“证明方向可行”，而是：

> 把现有 substrate 从“可运行原型”推进到“可持续复用的平台中层”。

本文档关注：

- phase 2 必须解决什么
- 哪些能力应继续下沉
- 哪些能力仍不应进入 `framework`
- 什么结果才算 phase 2 完成

## 2. 背景判断

当前 `framework` 已经具备稳定的 phase 1 内核与中层：

- kernel 继续稳定
- tooling 已可消费
- workflow 已有最小 runner
- `zig-opencode` 和 `ourclaw` 都已经做过最小真实接入

但它距离“真正的平台化”还有几层关键缺口：

- workflow 还不够强
- `agentkit` / `servicekit` 仍偏预备层
- adapter 面还不够完整
- consumer integration 还只是最小切片，不是持续复用模式
- developer experience 还不够成熟

所以，phase 2 的重点必须从“继续补 phase 1”切换为：

- workflow hardening
- kit extraction
- adapter expansion
- consumer reuse hardening
- developer experience

## 3. 非目标

phase 2 明确不做：

- 把 `framework` 变成完整 `zig-opencode`
- 把 `framework` 变成完整 `ourclaw`
- 把 session / prompt / chat / model routing 主链整体搬进 `framework`
- 把 gateway / daemon / channel 平台主链整体搬进 `framework`
- 在 phase 2 一次性完成完整 plugin marketplace
- 做一个“声明式大而全 DSL”但缺少真实消费验证

一句话：

> phase 2 是平台中层强化，不是产品主链迁移。

## 4. Phase 2 主题

建议将 phase 2 的主题明确为：

> Workflow Hardening And Kit Extraction

也就是：

- 把 workflow 从最小 runner 推进到可靠 orchestration substrate
- 把 `agentkit` / `servicekit` 从预留边界推进到最小可用 kit
- 把 `tooling` 扩展到更适合真实 skill backend / CLI / consumer app 消费

## 5. 总体需求

### Requirement 1: phase 2 SHALL 以平台中层强化为目标

phase 2 的主要工作必须继续发生在：

- `workflow`
- `tooling`
- `agentkit`
- `servicekit`
- adapters

而不是继续主要增长 kernel。

### Requirement 2: phase 2 SHALL 优先解决“持续复用”问题，而不是“更多概念占位”

phase 2 新增能力必须优先服务：

- `zig-opencode`
- `ourclaw`
- future skill backend
- future workflow CLI

若一个设计只能增加抽象层次、却不能改善真实复用，则不应优先进入 phase 2。

## 6. Workflow 需求

### Requirement 3: workflow SHALL 从最小 runner 提升为可靠 deterministic orchestration substrate

phase 2 的 workflow 必须支持更接近真实业务流程的控制能力，至少包括：

- `branch`
- `parallel`
- `wait_event`
- `ask_permission`
- `ask_question`
- `checkpoint`
- `resume`

### Requirement 4: workflow SHALL 保持 deterministic，不吸收 agent prompt 语义

即使 phase 2 增强 workflow，它也仍然必须保持：

- deterministic step model
- effect / tool / command 驱动

而不是：

- planner / prompt / model-driven loop engine

### Requirement 5: workflow SHALL 支持持久化运行态

phase 2 必须让 workflow 运行态具备最小持久化能力，至少要能表达：

- 当前 run id
- 当前 step 指针
- step status
- intermediate outputs
- terminal result

### Requirement 6: workflow SHALL 支持中断后恢复

phase 2 必须支持从 checkpoint 或持久化状态恢复运行，而不是每次只能从头执行。

## 7. Tooling 与 Adapter 需求

### Requirement 7: tooling SHALL 新增至少一种适合外部消费的 adapter

phase 1 已完成 `command surface`。phase 2 至少需要再落一类更适合外部消费的 adapter，优先级建议为：

1. `stdio surface`
2. `http surface`

### Requirement 8: stdio adapter SHALL 成为 phase 2 的优先目标

因为 `stdio` 更适合：

- skill backend
- agent tool host
- 本地 helper process
- future MCP-like bridge

### Requirement 9: tooling SHALL 支持更稳定的 tool packaging 形态

phase 2 应该让工具不只是“注册后运行”，还要具备更稳定的打包与消费面，例如：

- tool manifest
- grouped export
- stable naming / metadata
- example template

## 8. AgentKit 需求

### Requirement 10: agentkit SHALL 从占位层提升为最小可用 kit

phase 2 中 `agentkit` 至少应具备：

- provider / model / health / catalog substrate
- 共享 provider selection helper
- shared agent-oriented execution contracts

### Requirement 11: agentkit SHALL NOT 吸收完整 session/chat runtime

`agentkit` 在 phase 2 不应直接包含：

- complete session timeline
- prompt assembly
- full provider API implementations
- category/product semantics

它应是“agent-oriented shared kit”，不是“zig-opencode core”。

## 9. ServiceKit 需求

### Requirement 12: servicekit SHALL 从占位层提升为最小可用 service runtime kit

phase 2 中 `servicekit` 至少应具备：

- runtime host substrate
- heartbeat / cron style runtime helpers
- service lifecycle orchestration contracts

### Requirement 13: servicekit SHALL NOT 在 phase 2 吸收完整 channel/gateway 产品主链

phase 2 可以吸收：

- runtime host
- lifecycle helper
- generic service command facade

但不应直接吸收：

- channel platform specifics
- gateway product semantics
- pairing 业务逻辑

## 10. Consumer Integration 需求

### Requirement 14: phase 2 SHALL 将 consumer integration 从“最小切片”推进到“稳定消费模式”

phase 1 已证明消费可行。phase 2 必须继续证明：

- `zig-opencode` 可稳定消费 `framework` 的 agent-oriented substrate
- `ourclaw` 可稳定消费 `framework` 的 workflow/service-oriented substrate

### Requirement 15: 每个消费方 SHALL 至少增加一个新的真实消费切片

建议：

- `zig-opencode`：workflow-backed deterministic flow 或更多 framework-backed builtin tools
- `ourclaw`：workflow/servicekit-backed diagnostics / maintenance / runtime host slice

## 11. Developer Experience 需求

### Requirement 16: phase 2 SHALL 提供更稳定的开发入口

phase 2 必须改善“如何基于 framework 开新工具/流程”的体验，至少应包括：

- 约定清晰的模块入口
- 更完整的 examples
- 至少一种可复制模板
- 明确的 implementation guide

### Requirement 17: phase 2 SHALL 让外部用户更容易理解“从哪里开始”

未来如果你希望 Zig 用户快速开发类似 `nullclaw` / `opencode` 的东西，那么 phase 2 至少要把：

- 哪些模块是 kernel
- 哪些模块是 kit
- 如何写一个 tool
- 如何写一个 workflow
- 如何把它暴露成 CLI / stdio

说明清楚。

## 12. Observability 与 Compatibility 需求

### Requirement 18: phase 2 SHALL 保持 workflow/tooling/kit 与 observability 完整接线

phase 2 的新增能力必须继续接入：

- logger
- trace
- event bus
- task runner
- structured errors

### Requirement 19: phase 2 SHALL 保持边界可解释

每新增一个能力，都必须能回答：

- 为什么属于 kernel / workflow / tooling / agentkit / servicekit
- 为什么不属于 app-specific logic

否则不应直接下沉。

## 13. 验收需求

### Requirement 20: phase 2 完成时，workflow MUST 支持真实可恢复流程

至少应存在一条真实示例或测试，证明 workflow 能：

- 持久化状态
- 中断后恢复
- 跑过多 step 流程

### Requirement 21: phase 2 完成时，framework MUST 提供至少一个新的外部消费 adapter

至少应有：

- `stdio`
  或
- `http`

其中之一作为真实可运行 adapter。

### Requirement 22: phase 2 完成时，agentkit 与 servicekit MUST 都有最小真实消费验证

不能只有模块存在，而没有真实消费方验证。

### Requirement 23: phase 2 完成时，至少存在一条“从模板到运行”的清晰开发路径

也就是说：

- 新人可以依照文档和 example
- 做出一个 tool / workflow / adapter-backed 小工具

## 14. 最终建议

如果把 phase 2 的需求压缩成一句话，建议保留这条：

> phase 2 的目标不是继续证明 framework 能跑，而是把它推进成一个具有更强 workflow、最小可用 kit、稳定消费模式与基本开发体验的平台中层。
