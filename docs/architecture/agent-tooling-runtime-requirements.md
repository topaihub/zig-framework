# framework agent tooling runtime vNext 需求定义

## 1. 目标

本文档用于定义 `framework` 下一阶段演进的**需求约束**，作为后续设计细化、任务拆分和大模型实施的上游依据。

它的角色不是解释“怎么做”，而是明确：

- 必须做到什么
- 明确不做什么
- 哪些能力属于 kernel
- 哪些能力属于中层 substrate / kit
- 什么才算第一阶段完成

如果未来的设计文档或 tasks 与本文冲突，以本文为准。

## 2. 背景

当前 `framework` 已经具备通用 runtime kernel 能力，包括：

- `AppContext`
- `CommandRegistry` / `CommandDispatcher`
- `TaskRunner`
- `EventBus`
- logging / trace / observer / metrics
- config / validation / error model / contracts

同时，两个面向未来的重要消费方已经存在：

- [`zig-opencode`](E:/vscode/fuckcode-dev/zig-opencode)
- [`ourclaw`](E:/vscode/fuckcode-dev/ourclaw)

此外，`nullclaw` 提供了大量值得参考的能力边界、interface 和 registry 设计。

因此，`framework` 的下一阶段需求，不是继续堆 kernel，而是把它从“通用底座”推进成“可支撑 AI runtime 产品开发的平台”。

## 3. 目标用户与使用方式

`framework` vNext 的目标用户是：

1. 使用 Zig 构建 AI runtime 产品的开发者
2. 基于 Zig 编写 skill backend / tool backend / workflow CLI 的开发者
3. 需要同时支撑 `opencode-like` coding agent 与 `nullclaw-like` service agent 的 Zig 项目

`framework` 应支持的主要使用方式包括：

- 构建 Zig 原生 CLI 工具
- 构建 agent 可调用的本地工具
- 托管 Python / PowerShell 等外部脚本
- 构建 deterministic workflow
- 为 `zig-opencode` 和 `ourclaw` 提供共用底座能力

## 4. 非目标

为避免范围漂移，以下内容明确不属于当前阶段目标：

- 把 `framework` 做成完整 `zig-opencode`
- 把 `framework` 做成完整 `ourclaw`
- 直接把 `nullclaw` 的全部 provider/channel/tool/runtime 产品功能搬进来
- 在第一阶段引入完整 workflow DSL
- 在第一阶段引入完整 provider runtime
- 在第一阶段引入完整 channel runtime
- 在第一阶段引入 UI / TUI / manager 产品能力

一句话：

> `framework` vNext 的目标是成为平台 substrate，而不是成为所有上层产品的合并版。

## 5. 总体需求

### Requirement 1: framework SHALL 保持通用 kernel 与产品语义分离

`framework` 必须继续保持 kernel 的通用性，不得直接吸收完整 session / prompt / chat / gateway / channel 产品语义。

这意味着：

- kernel 继续承载 command、task、event、observability、config、validation、contracts
- 产品特定语义必须停留在 kit 或 app 层

### Requirement 2: framework SHALL 增长中层 substrate，而不只是继续增长 kernel

下一阶段必须新增中层能力，而不是继续只在 kernel 内增加基础设施。

至少应明确存在的中层方向包括：

- `effects`
- `tooling`
- `workflow`

这些层的作用是把“通用底座”与“具体产品”之间的执行逻辑承接起来。

### Requirement 3: framework SHALL 作为 zig-opencode 与 ourclaw 的共同底座

未来新增的 substrate 设计必须以同时支撑以下两个消费方为约束：

- `zig-opencode`
- `ourclaw`

任何新能力若只服务其中一个项目且无法证明具有通用性，不应直接进入 `framework` kernel。

## 6. Kernel 边界需求

### Requirement 4: kernel SHALL 继续只承载共享基础能力

下列能力属于 kernel 允许范围：

- `core`
- `contracts`
- `config`
- `observability`
- `runtime`
- `app`
- 未来的 `effects`

### Requirement 5: kernel SHALL NOT 直接吸收完整 provider/channel/session 产品逻辑

以下能力不得直接以完整产品形态进入 kernel：

- provider chat/runtime 实现
- channel ingress/egress 平台实现
- session timeline
- prompt assembly
- model routing
- gateway product lifecycle

## 7. Tooling 层需求

### Requirement 6: framework SHALL 优先建设 tool substrate

在 provider / channel / tool 三者中，当前阶段优先级必须是 `tool`。

原因是：

- tool 同时服务 `zig-opencode`、`ourclaw`、skill backend、workflow CLI
- 通用性最高
- 风险最低
- 可作为未来 workflow 与 script host 的基石

### Requirement 7: tooling SHALL 支持 Zig 原生 tool

`framework` 必须支持 Zig 原生实现的工具，并为其提供：

- 统一定义方式
- 统一输入校验
- 统一执行上下文
- 统一日志 / 事件 / 错误模型

### Requirement 8: tooling SHALL 支持外部脚本托管

`framework` 必须支持托管外部脚本，包括但不限于：

- Python
- PowerShell
- Node

托管能力至少应提供：

- cwd 注入
- env 注入
- timeout
- stdout/stderr 捕获
- exit code 处理
- 统一结果映射

### Requirement 9: tooling SHALL 统一 native tool 与 script-backed tool 的执行主干

无论工具是 Zig 原生还是外部脚本，其执行主干都应复用同一套：

- request validation
- execution context
- logging / trace
- event emission
- structured result

## 8. Workflow 层需求

### Requirement 10: workflow SHALL 服务 deterministic orchestration，而不是完整 agent loop

`framework` 的 workflow 层必须聚焦 deterministic orchestration，不应在当前阶段被定义为完整 AI loop 引擎。

### Requirement 11: workflow SHALL 建立在 tool substrate 之上

workflow 不应先于 tool substrate 独立生长。

工作流中的实际动作，应尽量建立在：

- command
- tool
- script host
- effects

这些已稳定能力之上。

### Requirement 12: 第一阶段 SHALL NOT 引入完整 workflow DSL

第一阶段可以为 workflow 预留结构，但不要求完成：

- branch
- parallel
- checkpoint
- persistence
- resume
- wait_event

等完整编排面。

## 9. Provider 与 Channel 需求

### Requirement 13: provider 只应先吸收契约与 registry 形态

当前阶段 `framework` 可以开始吸收 provider 的：

- definition
- registry
- catalog / health / model info
- classify / holder / factory pattern

但不要求吸收：

- 全量 provider runtime
- 各家 API 集成细节

### Requirement 14: channel 不应作为第一批下沉重点

channel 层当前不应作为 `framework` 第一阶段的主要吸收对象。

其原因是：

- channel 过于产品化
- 强依赖外部平台语义
- 更适合未来进入 `servicekit`

## 10. Kit 层需求

### Requirement 15: framework SHALL 为未来 kit 分层预留结构

`framework` 未来必须允许形成至少两类 kit：

- `agentkit`
- `servicekit`

但在当前阶段，这两个 kit 可以先以“边界预留”的方式存在，不要求立即完整实现。

### Requirement 16: 新能力下沉时 SHALL 先判断其属于 kernel、shared substrate 还是 future kit

未来每新增一类能力时，必须先判断它属于：

1. kernel
2. shared substrate
3. future kit
4. app-specific logic

禁止在未做边界判断时直接下沉到 `framework`。

## 11. 第一阶段实施范围需求

### Requirement 17: 第一阶段 SHALL 以 Tool Execution Substrate 为主题

第一阶段的主题必须明确为：

> Tool Execution Substrate

即优先把工具执行基座做实，而不是优先做 provider runtime 或 channel runtime。

### Requirement 18: 第一阶段 SHALL 至少交付 effects 最小层

第一阶段必须至少交付这些 effect 抽象：

- file system
- process runner
- env access
- clock / timeout helpers

HTTP client 可进入第一阶段，但优先级可低于 process / fs / env。

### Requirement 19: 第一阶段 SHALL 至少交付 tooling 最小层

第一阶段必须至少交付：

- `ToolDefinition`
- `ToolRegistry`
- `ToolContext`
- `ToolRunner`
- `ScriptHost`
- `command_surface`

### Requirement 20: 第一阶段 SHALL 交付外部脚本统一协议

第一阶段必须定义并落地至少一种脚本托管协议，建议为：

- JSON stdin
- JSON stdout
- structured error handling

## 12. 验收需求

### Requirement 21: 第一阶段完成时，framework MUST 能注册并执行 Zig 原生 tool

必须至少存在一个示例或测试，证明 Zig 原生 tool 可以：

- 注册
- 校验输入
- 执行
- 返回结构化结果

### Requirement 22: 第一阶段完成时，framework MUST 能托管至少一种外部脚本

必须至少存在一个示例或测试，证明外部脚本可以：

- 被统一 host 调用
- 注入 cwd/env
- 受 timeout 控制
- 返回结构化结果

### Requirement 23: 第一阶段完成时，tool execution MUST 接入 observability

所有工具执行必须接入：

- logger / trace
- event bus
- error model

### Requirement 24: 第一阶段完成时，tool execution MUST 能被 command surface 消费

至少需要证明：

- 同一个工具可被包装成 command method
- command 调用与 tool 调用共用核心逻辑

## 13. 文档与后续任务需求

### Requirement 25: 需求、设计与 tasks 必须保持分层

后续若继续推进 `framework` vNext，必须保持以下文档层次：

- requirements：定义必须做到什么
- design：定义怎么组织模块和边界
- tasks：定义按什么顺序施工

禁止直接从高层设计跳到实现，而没有 requirements 约束。

### Requirement 26: 后续 tasks SHALL 以本需求文档为上游

未来若生成 `framework` 的实施 tasks，应以本文作为上游约束，而不是只根据方向文档或模块设计图直接拆任务。

## 14. 最终建议

如果将本文压缩成一句话，建议保留这一条：

> `framework` vNext 的第一目标，不是继续增长 kernel，也不是吸收完整 provider/channel/session 产品逻辑，而是先把 tool execution substrate 做成可复用、可托管、可被 `zig-opencode` 与 `ourclaw` 同时消费的中层平台能力。

这条需求若守住，后续的设计和 tasks 才更不容易漂。
