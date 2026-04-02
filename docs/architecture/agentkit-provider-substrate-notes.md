# framework agentkit provider substrate 预备说明

## 1. 目标

本文档记录 `agentkit` 当前阶段应该先吸收什么，以及为什么 provider 这一层现在只应先落“契约 + registry + catalog/health”而不应直接落完整 chat runtime。

## 2. 当前策略

当前阶段，`agentkit` 先承载：

- `ModelRef`
- `ProviderAuthKind`
- `ProviderDefinition`
- `ProviderHealth`
- `ProviderModelInfo`
- `ProviderCatalogEntry`
- 最小 `ProviderRegistry`
- provider readiness / selection helper

不直接承载：

- provider chat runtime
- 各家 API 兼容细节
- model routing
- session / tool-use / streaming 产品语义

## 3. 来自 nullclaw 的抽象启发

当前最值得先吸收的是这些模式：

- `Kind`
- `classify`
- `Holder`
- `fromConfig`
- registry 与 runtime 分离

这些模式在 `nullclaw/src/providers/factory.zig` 中非常成熟，但在 `framework` 当前阶段应先以“模式输入”存在，而不是一次性实现完整 provider family。

## 4. 为什么先不做完整 provider runtime

原因有三：

1. provider 对 `zig-opencode` 很关键，但对 `ourclaw` 的共用性没那么高
2. 一旦直接下沉 chat/runtime 语义，`framework` 很容易过快产品化
3. 当前更优先的仍是 `tooling / workflow / service bundle`

## 5. 当前已落地结果

当前 `agentkit` 已经从“只有占位类型”推进到一层最小可用 provider substrate：

- `ModelRef`
- `ProviderAuthKind`
- `ProviderDefinition`
- `ProviderHealth`
- `ProviderModelInfo`
- `ProviderCatalogEntry`
- `ProviderRegistry`
- `isProviderReady(...)`
- `isModelReady(...)`
- `defaultReadyModel(...)`

并且这层能力已经被 `zig-opencode` 的 category model selection 路径消费。

也就是说，`agentkit` 现在已经开始承担：

- provider catalog 的共享契约
- provider readiness / default-model selection 的共享逻辑

## 6. 仍未进入 agentkit 的内容

当前仍明确不进入 `agentkit`：

- provider concrete HTTP runtime
- streaming protocol 实现
- session runtime
- prompt assembly
- category 产品策略本体

## 7. 下一步建议

等到：

- `tooling`
- `workflow`
- `service bundle`

这些主干更稳定后，再继续把 provider runtime 往 `agentkit` 方向推进会更稳。
