# framework vNext 实施约束

## 1. 目标

本文档用于约束 `framework` vNext 的实施边界，防止后续实现阶段出现：

- kernel 与 kit 边界混淆
- 直接把产品逻辑塞进 `framework`
- 目录无序增长
- 在没有 requirement 约束的情况下过度抽象

本文档服务于 implementation 阶段，而不是替代 requirements / design。

## 2. 文档优先级

当实施阶段遇到文档冲突时，优先级如下：

1. [`agent-tooling-runtime-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-requirements.md)
2. [`implementation-guardrails.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/implementation-guardrails.md)
3. [`agent-tooling-runtime-executable-tasks.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-executable-tasks.md)
4. [`agent-tooling-runtime-vnext-module-design.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-vnext-module-design.md)
5. 其他 supporting 文档

## 3. 当前允许增长的顶层模块

vNext 期间，`framework/src/` 允许存在的顶层目录只有：

- `core/`
- `contracts/`
- `config/`
- `observability/`
- `runtime/`
- `app/`
- `effects/`
- `tooling/`
- `workflow/`
- `agentkit/`
- `servicekit/`

除以上目录外，不应新增新的顶层模块目录。

## 4. 当前阶段的边界

### 4.1 可以进入 kernel 的内容

当前允许继续增强的 kernel 能力包括：

- command dispatch
- task lifecycle
- event bus
- logging / trace / observer / metrics
- config / validation / error / contracts
- effect abstraction

### 4.2 不允许直接进入 kernel 的内容

当前阶段不得直接把下面这些完整产品语义下沉进 kernel：

- provider chat runtime
- channel ingress / egress 平台实现
- session timeline
- prompt assembly
- model routing
- gateway 产品逻辑
- daemon / service 产品逻辑
- UI / TUI 产品逻辑

## 5. 当前阶段的优先级

当前阶段优先级明确如下：

1. `effects`
2. `tooling`
3. `script host`
4. `command surface`
5. `workflow` 最小层
6. `service bundle`
7. `agentkit` / `servicekit` 预备层

不允许跳过前四项，直接去实现完整 provider 或 channel runtime。

## 6. 关于 provider / channel / tool 的实施约束

### 6.1 `tool`

当前最优先进入 `framework` 的能力类别是 `tool`。

允许实施：

- tool interface
- tool registry
- tool runner
- native Zig tool
- external script-backed tool
- tool adapters

### 6.2 `provider`

当前阶段只允许实施 provider 的：

- definition
- registry
- catalog
- health/model info
- classify / holder / factory pattern

当前阶段不允许实施：

- 全量 provider runtime
- 各家 API 具体接入
- session / streaming / provider orchestration 产品逻辑

### 6.3 `channel`

当前阶段不允许将完整 channel runtime 下沉进 `framework`。

只允许：

- 提炼 interface 模式
- 提炼 registry / supervisor / dispatch 思想
- 形成 future `servicekit` 的设计输入

## 7. 目录增长规则

实施时应遵守以下规则：

1. 新增模块必须有 `root.zig`
2. 新增顶层模块必须在 `framework/src/root.zig` 中预留或导出
3. 新增模块必须带 smoke test
4. 新增复杂模块必须同步补 architecture 文档
5. 先有 scaffold，再有 implementation，再有 tests，再有 examples/docs

## 8. 何时需要停下来补设计

若出现以下情况，应该先补设计或 requirement，而不是继续写代码：

1. 无法判断某能力属于 kernel、shared substrate 还是 future kit
2. 一个能力明显只服务 `zig-opencode` 或 `ourclaw` 中某一个，且通用性不足
3. 一个模块需要引入新的顶层目录
4. 一个功能需要直接引入完整 provider/channel/session/gateway 产品语义

## 9. 实施完成的最低标准

每个阶段完成前，至少应满足：

1. 新增代码能通过编译
2. 新增测试通过
3. 文档入口可发现
4. 未破坏现有 kernel 的边界

## 10. 一句话约束

如果只保留一句实施约束，建议保留这条：

> 当前阶段先把 `framework` 做成稳定的 tool execution substrate，不要把它提前做成完整 AI 产品 runtime。
