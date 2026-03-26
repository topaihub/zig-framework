# framework 面向 zig-opencode 与 ourclaw 的平台定位

## 1. 目标

本文档用于明确 `framework` 的最终平台定位，回答下面几个关键问题：

- `framework` 是否适合作为 `zig-opencode` 与 `ourclaw` 的共同底座
- 如果适合，应该共用到哪一层
- 是否需要对 `framework` 做进一步拆分
- 如何避免 `framework` 变成一个过度膨胀的单体框架

本文档是在以下目标前提下形成的：

1. 未来继续基于 `framework` 开发 `zig-opencode`
2. 未来继续基于 `framework` 开发 `ourclaw`
3. 最终希望打造一个 Zig 平台，帮助用户快速开发类似 `nullclaw` 和 `opencode` 的 AI runtime 产品

配套阅读：

- [`agent-tooling-runtime-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-requirements.md)
- [`agent-tooling-runtime-implementation-tasks.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-implementation-tasks.md)
- [`agent-tooling-runtime-direction.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-direction.md)
- [`agent-tooling-runtime-vnext-module-design.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-vnext-module-design.md)
- [`agent-tooling-runtime-phase1-roadmap.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-phase1-roadmap.md)
- [`nullclaw-and-ourclaw-extraction-strategy.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/nullclaw-and-ourclaw-extraction-strategy.md)

## 2. 核心结论

结论可以先写得非常明确：

> 这条路线是成立的，但前提不是把 `framework` 做成一个单体超级框架。

更合适的方向是：

> 把 `framework` 做成一个面向 AI runtime 的 Zig 平台，包含通用 kernel 与若干可选 kit，用来支撑 `zig-opencode`、`ourclaw` 以及未来的 Zig 工具与 runtime 产品。

换句话说：

- `zig-opencode` 继续基于 `framework` 发展：合适
- `ourclaw` 继续基于 `framework` 发展：合适
- 但若让 `framework` 本身直接同时变成 “nullclaw 框架 + opencode 框架 + 所有 agent 框架”，则不合适

## 3. 为什么这个目标成立

`zig-opencode` 与 `ourclaw` 看起来差异很大，但它们共享的底层其实非常多：

- command dispatch
- task runner
- event bus
- logging / trace / observer
- config / validation / error model
- effect execution
- tool host
- workflow substrate
- security gates
- structured contracts

这说明：

1. `framework` 作为共同底座不是空想，而是有现实基础
2. 两个应用虽然产品形态不同，但底层 execution substrate 明显可共享
3. 真正需要解决的问题，不是“要不要共用 `framework`”，而是“共用到哪一层”

## 4. 不应追求的目标

为了避免方向跑偏，需要先明确什么目标不应该追求。

### 4.1 不应把 `framework` 做成所有产品能力的总和

不建议把这些都直接塞进 `framework`：

- session timeline
- prompt assembly
- model/category routing
- full provider/chat semantics
- gateway product logic
- channel product logic
- service/daemon 产品级行为
- UI / TUI 产品交互逻辑

如果这样做，`framework` 会变成：

- `nullclaw` 的简化版
- `zig-opencode` 的核心包
- `ourclaw` 的业务主仓

最后谁都无法真正稳定复用。

### 4.2 不应把“平台”误做成“单一产品骨架”

`nullclaw-like` 与 `opencode-like` 不是同一种产品：

- 前者更偏 service agent / integration runtime
- 后者更偏 coding agent / session runtime

它们共享底层很多能力，但不意味着它们应该共享同一个产品骨架。

## 5. 推荐的平台分层

建议将整体体系明确拆成三层：

```text
Layer 1: Kernel
Layer 2: Kits
Layer 3: Apps
```

### 5.1 Kernel 层

这应该是当前 `framework` 最稳定的内核部分。

建议包含：

- `core`
- `contracts`
- `config`
- `observability`
- `runtime`
- `app`
- 未来的 `effects`

这一层应保持通用，不带强产品语义。

### 5.2 Kit 层

这是最值得尽快补出来的概念层。

它的作用是：

- 避免所有能力都直接进 kernel
- 把“适合一类产品复用”的能力做成中层套件
- 让 `zig-opencode` 与 `ourclaw` 各自拿自己需要的组合

建议至少存在三类 kit：

#### `tooling / workflow kit`

两边共用，负责：

- tool host
- script host
- workflow runner
- adapters

#### `agent kit`

更偏 `zig-opencode`，负责：

- session-like execution substrate
- stream / chunk / tool-use shared helpers
- provider request / response / model-side通用契约

注意：  
这里是 “agent runtime kit”，不是完整 `zig-opencode` 语义。

#### `service / integration kit`

更偏 `ourclaw`，负责：

- runtime host
- gateway-facing runtime helpers
- channel/service/integration substrate
- pairing / cron / heartbeat 这类更接近 service runtime 的通用能力

### 5.3 App 层

真正的产品层应该继续由独立应用承担：

- `zig-opencode`
- `ourclaw`

这些是 framework 的消费方，而不是 framework 自己的一部分。

## 6. 推荐的代码组织方式

在当前单工作区阶段，建议按“代码组织拆层”，而不是立刻“仓库物理拆分”。

建议的未来形态如下：

```text
fuckcode-dev/
├── framework/
│   ├── src/core/
│   ├── src/contracts/
│   ├── src/config/
│   ├── src/observability/
│   ├── src/runtime/
│   ├── src/app/
│   ├── src/effects/
│   ├── src/tooling/
│   ├── src/workflow/
│   ├── src/agentkit/
│   └── src/servicekit/
├── zig-opencode/
└── ourclaw/
```

其中：

- `tooling` / `workflow` 是真正的共用层
- `agentkit` 偏 `zig-opencode`
- `servicekit` 偏 `ourclaw`

## 7. 是否需要拆分 `framework`

### 7.1 概念上：需要拆分

如果继续演进，`framework` 不能只停留在现在的 kernel 结构。  
它需要明确分化出：

- 通用 kernel
- 共用 tooling/workflow 层
- 面向不同 runtime 形态的 kit

### 7.2 仓库上：暂时不建议立即拆成多个 repo

现阶段不建议过早把它物理拆成多个仓库，原因包括：

1. 接口还没有完全稳定
2. 你当前仍在依赖大模型快速迭代
3. 跨 repo 联动会提高试错成本
4. 目前仍处于识别“哪些能力真正可共享”的阶段

因此更现实的策略是：

- 先在一个工作区中把边界拆清楚
- 等 `zig-opencode` 和 `ourclaw` 对某些 kit 的依赖模式稳定后，再决定是否要做物理拆仓

## 8. 推荐重新定义目标表述

不建议将目标直接表述为：

> 一个 Zig 框架，帮助用户快速开发类似 nullclaw 和 opencode 的东西

这个说法太大，也太容易让 `framework` 被做成怪物。

更建议改写为：

> 一个面向 AI runtime 的 Zig 平台：  
> 提供通用 kernel、tooling/workflow kit、agent kit、service kit，使 Zig 用户能够更快构建 `opencode-like` coding agent 和 `nullclaw-like` service agent。

这个表述的好处是：

- 承认 `nullclaw-like` 与 `opencode-like` 并不是同一种产品
- 明确共用的是平台，而不是同一个产品骨架
- 允许中间层 kit 的存在

## 9. 对三类项目的角色定义

### 9.1 `framework`

定位：

- AI runtime 平台内核
- 承载共享 kernel 与共享 kits

不应承担：

- 完整 session 产品语义
- 完整 gateway / channel 产品语义
- UI/TUI 产品语义

### 9.2 `zig-opencode`

定位：

- coding-agent app
- `framework` 的 agent-oriented 消费方

更偏：

- session
- provider/tool loop
- model routing
- prompt / TUI / client

### 9.3 `ourclaw`

定位：

- service / integration runtime app
- `framework` 的 service-oriented 消费方

更偏：

- command surface
- gateway / service / daemon
- integration runtime
- system-facing orchestration

## 10. 一个重要判断：平台，而不是合并版产品

若只保留一个最关键的设计判断，建议保留这一条：

> `framework` 应该成为 Zig AI runtime 的平台内核，而不是 `nullclaw` 或 `opencode` 的合并版。

这条判断之所以重要，是因为它会直接约束后续设计：

- 该下沉的是通用 substrate
- 不是把所有能力面直接并入 framework
- 该抽的是共用 kit
- 不是把两个产品都做成 framework 的 profile

## 11. 对未来演进的建议

### 11.1 优先继续做“结构化拆层”

下一步更值得做的是：

1. 补 `effects`
2. 补 `tooling`
3. 补 `workflow`
4. 再识别哪些 agent/service 能力应该进入 `agentkit` / `servicekit`

### 11.2 暂时不要急着把所有 `nullclaw` 能力往下搬

未来真正值得吸收的，不是 `nullclaw` 的全量功能，而是：

- interface / registry 模式
- capability 边界
- factory / catalog 组织方式
- 构建裁剪思路

### 11.3 让 `ourclaw` 与 `zig-opencode` 成为真实试验田

与其先抽象，不如继续把：

- `zig-opencode`
- `ourclaw`

都作为 `framework` 的消费方来演进。  
哪些能力反复出现、反复被需要，再考虑下沉成 kit。

## 12. 最终建议

综合来看，建议把 `framework` 的平台目标总结为：

> 一个面向 AI runtime 的 Zig 平台，提供通用 kernel、tooling/workflow substrate 和面向不同 runtime 形态的 kit，用来支撑 `zig-opencode`、`ourclaw` 以及未来 Zig 用户构建 `nullclaw-like` 与 `opencode-like` 产品。

这条路线是合理的，而且和当前仓库结构也并不冲突。  
真正要做的不是否定 `framework`，而是继续把它从“通用 kernel”演进成“结构清晰的平台”。
