# framework 消费者接入阶段一设计

## 1. 目标

本文档基于 [`framework-consumer-integration-phase1-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/framework-consumer-integration-phase1-requirements.md)，说明下一阶段推荐如何实施最小真实接入。

重点不是“怎么全面迁移”，而是：

- 选什么切片
- 通过什么方式接进去
- 哪些地方必须保持边界

## 2. 设计总判断

本阶段不应选择“大而关键”的主链路，而应选择：

- deterministic
- 易验证
- 低耦合
- 不会误导平台边界

的切片。

## 3. zig-opencode 接入设计

### 3.1 推荐接入对象

推荐在 `zig-opencode` 中引入一个 framework-backed deterministic builtin tool，优先级如下：

1. `repo.health_check`
2. `script.markdown_fetch`

其中更推荐先做：

- `repo.health_check`

原因：

- 完全 deterministic
- 不依赖 provider/session 语义
- 更能验证 `framework/tooling` 是否真的足够通用

### 3.2 推荐接入方式

推荐方式是：

- 在 `zig-opencode` 内增加一个薄适配层
- 由适配层持有或访问 `framework.ToolingRuntime`
- 将 `framework` 中的 tool 适配到 `zig-opencode` 现有 builtin tool surface

不推荐方式：

- 把 `framework` 的 tool 代码直接复制进 `zig-opencode`
- 在 `zig-opencode` 里重新做一套 deterministic tool host

### 3.3 当前不应做的事

在 `zig-opencode` 端，本阶段不应：

- 重写 session runtime
- 改 provider runtime
- 改 prompt assembly
- 改 model/category routing

## 4. ourclaw 接入设计

### 4.1 推荐接入对象

推荐在 `ourclaw` 中选择一个 deterministic command/tool slice 作为接入点，例如：

- diagnostics 类命令
- repo / workspace health 检查类命令
- maintenance / preview / apply 类的最小切片

建议优先找：

- 不直接触碰 gateway / daemon / channel 主链路
- 能体现 `BusinessServices` + `framework/tooling`

### 4.2 推荐接入方式

推荐方式是：

- 在 `ourclaw` 的 `CommandServices` 或其邻近层中接入 `framework.ToolingRuntime`
- 由命令处理器通过 service facade 使用该 runtime

这能够验证：

- `framework` 的 service bundle 模式
- `ourclaw` 是否真的可以少写一层 runtime glue

### 4.3 当前不应做的事

在 `ourclaw` 端，本阶段不应：

- 把 channel runtime 下沉进 `framework`
- 把 runtime host / daemon / pairing 直接塞进 `servicekit`
- 做大规模 command 迁移

## 5. 代码组织建议

### 5.1 framework 侧

本阶段主要允许做两类增强：

- 为消费者接入补最小 blocker
- 为接入方式补文档与 adapter 说明

不应继续在 `framework` 主仓内大规模新造平台层。

### 5.2 zig-opencode / ourclaw 侧

推荐各自新增一个“接入层”或“桥接层”，而不是直接把 framework 调用撒到各处业务代码里。

例如：

- `zig-opencode/src/framework_integration/*`
- `ourclaw/src/framework_integration/*`

或其它等价命名。

## 6. 推荐的最小验证组合

### zig-opencode

- 一个 framework-backed builtin tool
- 一组 direct tool / integration tests

### ourclaw

- 一个 framework-backed command/tool slice
- 一组 command-level tests

## 7. 最终建议

如果压缩成一句话：

> phase 1 应优先验证“framework 是否能被真实消费”，而不是优先验证“framework 还能抽象出多少层”。
