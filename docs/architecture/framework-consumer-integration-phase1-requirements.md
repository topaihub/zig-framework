# framework 消费者接入阶段一需求定义

## 1. 目标

本文档定义 `framework` 下一阶段工作的需求约束：  
通过真实消费方接入，验证 `framework` 当前已落地的 substrate 是否真的可被 `zig-opencode` 与 `ourclaw` 消费，而不是只停留在框架内部自洽。

本文档关注：

- 本阶段到底要验证什么
- 哪些接入属于必须项
- 哪些改动明确不做
- 什么样的结果才算“phase 1 接入完成”

## 2. 背景

当前 `framework` 已经完成了一条较完整的第一阶段主线：

- `effects`
- `tooling`
- `script host`
- `command surface`
- `workflow` 最小执行层
- `service bundle` 模式
- `agentkit / servicekit` 预备层

同时也已经形成了消费计划文档：

- [`zig-opencode-consumption-plan.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/zig-opencode-consumption-plan.md)
- [`ourclaw-consumption-plan.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/ourclaw-consumption-plan.md)
- [`consumer-validation-notes.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/consumer-validation-notes.md)

因此，下一阶段的重点不应再是继续抽象层，而应先做**真实消费者接入验证**。

## 3. 非目标

本阶段明确不做：

- 把 `zig-opencode` 的 session / prompt / provider 主链路整体下沉到 `framework`
- 把 `ourclaw` 的 gateway / daemon / channel / pairing 主链路整体下沉到 `framework`
- 一次性把两个消费方全面迁移到 `framework`
- 重写现有大块业务模块
- 在本阶段推进完整 `agentkit` 或 `servicekit`

一句话：

> 这是 consumer integration phase 1，不是 consumer migration phase 1。

## 4. 总体需求

### Requirement 1: phase 1 SHALL 以“最小真实接入”而不是“大规模迁移”为目标

本阶段的目标必须是：

- 选择一个最小但真实的接入点
- 验证 `framework` substrate 的可消费性
- 通过真实接入反向校正 `framework`

而不是追求大面积替换现有消费者内部实现。

### Requirement 2: 本阶段 SHALL 至少覆盖两个消费方中的各一个真实接入点

本阶段必须同时覆盖：

- `zig-opencode`
- `ourclaw`

每个消费者至少需要一个真实接入点。

## 5. zig-opencode 接入需求

### Requirement 3: zig-opencode SHALL 接入一个 framework-backed deterministic tool

`zig-opencode` 必须引入至少一个由 `framework/tooling` 承载的 deterministic builtin tool。

该 tool 应满足：

- 可以从 `zig-opencode` 现有 tool surface 被调用
- 不要求改动 session/provider 主链路
- 不要求立即改变 prompt / model / orchestration 设计

### Requirement 4: zig-opencode 接入 SHOULD 优先复用 framework.ToolingRuntime

该接入应尽量复用：

- `framework.EffectsRuntime`
- `framework.ToolingRuntime`
- `framework.ToolRunner`

而不是在 `zig-opencode` 内再复制一套同样的 deterministic tool substrate。

## 6. ourclaw 接入需求

### Requirement 5: ourclaw SHALL 接入一个 framework-backed deterministic command/tool slice

`ourclaw` 必须引入至少一个由 `framework/tooling` 或 `framework/workflow` 支撑的 deterministic 命令或工具切片。

该切片应满足：

- 可以通过 `ourclaw` 的 command surface 访问
- 能体现 `BusinessServices` / `service bundle` 模式的消费方式
- 不要求改动 gateway / daemon / channel 主链路

### Requirement 6: ourclaw 接入 SHOULD 优先验证 service facade + tooling 的组合

对 `ourclaw` 而言，本阶段更适合验证：

- `framework` 的 service bundle 模式
- `framework/tooling` 的组合使用

而不是直接大规模推进 `servicekit` 或 channel runtime 下沉。

## 7. 边界需求

### Requirement 7: phase 1 接入 MUST 保持 framework 与 app 的边界

本阶段接入不能通过以下方式“偷渡成功”：

- 把 app-specific 逻辑直接塞回 `framework`
- 在消费者里绕开 `framework` 的公共 substrate，直接硬编码特化逻辑
- 因接入而破坏 `zig-opencode` / `ourclaw` 现有产品边界

### Requirement 8: 接入中的补洞 SHOULD 以最小增强为原则

如果真实接入过程中发现 `framework` 还缺某些点，允许补最小增强，但应满足：

- 只补真实接入的 blocker
- 不顺手扩大战场
- 不把 phase 1 变成新一轮平台大重构

## 8. 测试与验证需求

### Requirement 9: 每个消费者接入 MUST 有可执行验证

对 `zig-opencode` 和 `ourclaw` 的接入，都必须有至少一种可执行验证形式：

- 单元测试
- 集成测试
- 最小 smoke 测试

### Requirement 10: framework 主仓与消费方仓都 MUST 保持测试通过

本阶段完成前，至少应满足：

- `framework` 相关测试通过
- 目标消费者仓库的相关测试或 smoke 验证通过

## 9. 完成判定

当以下条件都满足时，可认为 phase 1 完成：

- [ ] `zig-opencode` 已接入至少一个 framework-backed deterministic tool
- [ ] `ourclaw` 已接入至少一个 framework-backed deterministic command/tool slice
- [ ] 两个接入点都通过了最小可执行验证
- [ ] framework 没有因接入被错误产品化
- [ ] phase 1 的新增消费方式已沉淀为文档

## 10. 最终建议

如果把本文压缩成一句话，建议保留这条：

> 下一阶段不应继续优先做抽象，而应通过最小真实消费者接入来验证 `framework` 现有 substrate 的边界与价值。
