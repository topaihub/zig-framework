# framework agentkit provider substrate 预备说明

## 1. 目标

本文档记录 `agentkit` 当前阶段应该先吸收什么，以及为什么 provider 这一层现在只应先落“契约 + registry + catalog/health”而不应直接落完整 chat runtime。

## 2. 当前策略

当前阶段，`agentkit` 先承载：

- `ProviderDefinition`
- `ProviderHealth`
- `ProviderModelInfo`
- 最小 `ProviderRegistry`

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

## 5. 下一步建议

等到：

- `tooling`
- `workflow`
- `service bundle`

这些主干更稳定后，再继续把 provider runtime 往 `agentkit` 方向推进会更稳。
