# 从 nullclaw 与 ourclaw 到 framework 的抽象提取策略

## 1. 目标

本文档用于回答一个非常具体的问题：

> 在继续建设 `framework` 的过程中，应该从 `nullclaw` 和 `ourclaw` 吸收什么，哪些不该吸收，先后顺序又应该如何安排。

本文档的目标不是做功能盘点，而是为 `framework` 的后续平台化演进提供抽象提取策略。

它主要回答三个问题：

1. `nullclaw` 里哪些 interface / registry 模式值得真正抽进 `framework`
2. `ourclaw` 里哪些现状已经在提醒 `framework` 缺哪几层
3. 当前 `framework` 应该先吸收 provider / channel / tool 中的哪一类设计，而不是一起吞

## 2. 核心结论

可以先把结论写得非常明确：

### 2.1 应吸收的是“能力边界组织方式”，不是产品功能面

`nullclaw` 最值得学习的，不是它“有 50+ providers / 19 channels / 30+ tools”，而是它如何把这些能力做成清晰的一等接口、registry、factory 与 runtime 边界。

### 2.2 `ourclaw` 已经在暴露 `framework` 缺失的中间层

`ourclaw` 现在的很多代码并不是问题本身，而是在提醒：

- `framework` 已经有 kernel
- 但还缺 `tooling`
- 还缺 `workflow`
- 还缺 `servicekit`
- 还缺更高层的 runtime composition pattern

### 2.3 优先吸收 `tool`，而不是先吸收 `provider` 或 `channel`

当前最适合优先进入 `framework` 的，不是 channel，也不是完整 provider runtime，而是 tool 这一层的接口、注册、执行和托管模式。

建议优先级：

1. `tool`
2. `provider` 的契约与 registry 形态
3. `channel`

## 3. 应从 nullclaw 吸收什么

### 3.1 统一的 Zig interface 形态

`nullclaw` 在这些文件中展现了非常一致的 interface 设计风格：

- `nullclaw/src/providers/root.zig`
- `nullclaw/src/channels/root.zig`
- `nullclaw/src/tools/root.zig`

它们的共同特征是：

- `ptr: *anyopaque`
- `vtable: *const VTable`
- 对外提供强类型 helper 方法

这个模式非常值得成为 `framework` 的标准能力接口风格。

应吸收：

- 通用的 vtable interface 组织方式
- 接口类型与具体实现分离的纪律
- 对外暴露统一 helper method 的习惯

不应直接吸收：

- 具体 provider / channel / tool 的产品语义
- 某个产品里的一次性字段设计

### 3.2 registry 与 runtime 分离

`nullclaw` 的大量子系统都体现出这样一个很重要的思想：

- registry 管元数据、查找、定义、已注册能力
- runtime 管真实执行、生命周期、状态、IO

这个思想是高度通用的，特别适合进入 `framework`。

推荐作为 `framework` 的通用模式：

```text
Definition
Registry
Runtime
Status / Health / Catalog
```

### 3.3 classify / factory / holder 模式

`nullclaw/src/providers/factory.zig` 最值得学习的，不是里面那张大表本身，而是其抽象套路：

- `Kind`
- `classify`
- `Holder`
- `fromConfig`
- 兼容层与核心实现分开

这套模式非常适合沉淀成 `framework` 中的通用 capability factory pattern。

适合未来应用于：

- provider
- external script host
- workflow step backend
- runtime adapter

### 3.4 tool helper 套路

`nullclaw/src/tools/root.zig` 对 `framework` 的价值非常高，因为它几乎天然适合抽象成通用 tooling substrate。

尤其值得吸收的包括：

- `Tool`
- `ToolResult`
- `ToolSpec`
- `ToolVTable(T)`
- `assertToolInterface`
- `defaultTools` / `allTools` 这种组合方式

这套模式的优点是：

- Zig 原生工具容易写
- 类型边界清晰
- 测试友好
- 便于 future script-backed tool 与 native tool 共存

### 3.5 构建时能力裁剪思路

`nullclaw/build.zig` 中存在很强的 feature selection 思路，这一点也值得保留。

不建议现在就把 `nullclaw` 的构建裁剪系统整体搬进 `framework`，但应保留下面这个思维：

> 能力应尽量是可裁剪的，而不是默认所有产品都背负全部能力。

这对未来的：

- `tooling kit`
- `agent kit`
- `service kit`

都很重要。

## 4. 不应从 nullclaw 直接下沉什么

为了防止 `framework` 被做成产品合集，下面这些内容不建议直接下沉：

- giant provider table
- channel 产品行为本身
- agent / session / conversation 产品语义
- 完整 message bus 产品语义
- 具体平台接入实现
- `nullclaw` 的完整 gateway / daemon / voice / hardware 业务面

一句话：

> 要抽的是“接口、registry、factory、execution 边界”，不是“把产品模块整体搬进 framework”。

## 5. ourclaw 正在提醒 framework 缺什么

`ourclaw` 的代码已经很明确地暴露出 `framework` 的下一阶段缺口。

### 5.1 巨型业务 AppContext 说明缺少中层组合层

`ourclaw/src/runtime/app_context.zig` 非常重要。

它说明：

- `framework.AppContext` 已经能做 kernel 装配
- 但真实业务项目仍然需要一个更高层的组合层来装配 provider/channel/tool/memory/agent/runtime host 等能力

这提示 `framework` 缺：

- `ToolingRuntime`
- `WorkflowRuntime`
- `ServiceKit` 或类似的组合层

### 5.2 CommandServices 说明缺少 service bundle pattern

`ourclaw/src/domain/core/services.zig` 的 `CommandServices` 是一个很强的信号。

它表明：

- `framework.CommandContext` 足够做底层 dispatch
- 但大规模业务命令仍需要一个稳定的服务聚合面

这说明 `framework` 缺：

- service bundle / services facade 模式
- 更标准化的业务依赖注入方式

### 5.3 大量手工注册命令说明缺少命令模块组织层

`ourclaw/src/commands/root.zig` 手工注册了大量命令。

这不是设计错误，但它提醒：

- `framework` 目前有 command model
- 但缺 command module / command set / bulk registration helper

未来如果不补这一层，业务仓库会越来越重。

### 5.4 最小 provider/channel/tool registry 说明缺少 generic capability substrate

`ourclaw` 现在有自己的：

- `providers`
- `channels`
- `tools`

但这些模块大量是在做“基础 registry 骨架”。

这说明 `framework` 还缺一层通用能力：

- generic capability registry substrate
- generic health/status/catalog surface
- native capability 与 external capability 共存的统一模式

### 5.5 runtime host / daemon / gateway host 说明缺少 servicekit

`ourclaw/src/runtime/runtime_host.zig` 以及相关 runtime 文件表明：

- 长期运行型 runtime 有自己的一套组合逻辑
- gateway、heartbeat、cron、service manager 并不适合塞回 kernel

这强烈提示未来需要：

- `servicekit`

而不是继续把所有运行时能力塞进 `framework.runtime.AppContext`

### 5.6 agent runtime / tool orchestrator / stream output 说明缺少 tooling/workflow/agentkit

`ourclaw/src/domain/core/agent_runtime.zig`、`tool_orchestrator.zig`、`stream_output.zig` 一起说明：

- 业务项目正在自己长 execution substrate
- 这层比 kernel 更高，但又没有必要全部成为产品私有逻辑

这说明 `framework` 未来应补：

- `tooling`
- `workflow`
- 某种更偏 `zig-opencode` 的 `agentkit`

## 6. 为什么应优先吸收 tool，而不是 provider 或 channel

### 6.1 `tool` 的通用性最高

`tool` 这一层几乎同时服务：

- `zig-opencode`
- `ourclaw`
- skill backend
- workflow CLI
- script host

这意味着：

- 复用面最大
- 风险最低
- 收益最直接

### 6.2 `provider` 的共用性不如 tool 高

provider 对 `zig-opencode` 非常关键，但对 `ourclaw` 未必同等关键。  
因此 provider 更适合先沉淀成：

- 契约层
- registry / health / model catalog 层

而不是一开始就沉淀成完整 runtime 层。

### 6.3 `channel` 最产品化

channel 往往涉及：

- webhook
- polling
- ws gateway
- account routing
- ingress / egress
- typing / staged send
- platform 细节

这些都更接近 `servicekit` 或 `ourclaw` 方向的共用层，不适合先进入通用 `framework`。

## 7. 推荐的吸收顺序

建议按下面的顺序推进。

### Phase 1：吸收 tool

目标：

- 从 `nullclaw` 提取 tool interface / registry / helper 模式
- 在 `framework` 落 `tooling/`
- 同时打通 native Zig tool 与 external script host

推荐吸收内容：

- `Tool`
- `ToolDefinition`
- `ToolContext`
- `ToolResult`
- `ToolSpec`
- `ToolVTable(T)`
- `ToolRegistry`
- script-backed tool 托管协议

### Phase 2：补中层 runtime 组合能力

目标：

- 从 `ourclaw` 反推中层缺失
- 在 `framework` 引入 `workflow/` 与 `service bundle pattern`
- 为 future `servicekit` 打基础

推荐吸收内容：

- service bundle / facade pattern
- runtime composition pattern
- tool orchestration 通用逻辑
- stream / event / task 的组合式执行模型

### Phase 3：吸收 provider 的契约与注册模式

目标：

- 为 `zig-opencode` 准备更稳定的 provider substrate

推荐先吸收：

- provider definition
- provider registry
- provider catalog / health / model info
- classify / holder / factory pattern

不建议在此阶段一并吸收：

- 全量 provider 实现
- 各家 API 细节

### Phase 4：最后考虑 channel

目标：

- 在 `servicekit` 语义更清楚后，再从 `nullclaw` 抽 channel interface / registry / dispatch 思想

不建议现在就做，是因为 channel 太容易把 `framework` 带向强产品化。

## 8. 与 framework 现有规划的对应关系

这套提取策略与现有平台规划是对齐的。

建议映射为：

```text
framework
  kernel
    core / contracts / config / observability / runtime / app

  shared middle layer
    effects / tooling / workflow

  product-oriented kits
    agentkit / servicekit
```

其中：

- `tool` 优先进入 `tooling`
- `provider` 更适合未来进入 `agentkit`
- `channel` 更适合未来进入 `servicekit`

## 9. 最终建议

如果把整个策略压缩成一句话，建议保留这条判断：

> `framework` 现在最该从 `nullclaw` 吸收到的，不是 provider，也不是 channel，而是 tool 这一层的接口、注册、执行和托管模式；而 `ourclaw` 已经在强烈提示，`framework` 下一步缺的是 `tooling / workflow / servicekit` 这些中层，而不是更多 kernel 基础设施。

这条判断对后续演进很重要，因为它能帮助 `framework` 避免两种坏结果：

1. 只做 kernel，不长中层，导致业务仓库自己到处重复
2. 一口气吞下 provider/channel/session/gateway，导致 framework 过度产品化

保持这个节奏，`framework` 才更可能真正成为长期平台资产。
