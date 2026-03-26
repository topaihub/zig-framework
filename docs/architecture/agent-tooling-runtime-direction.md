# framework 面向 agent 小工具与 workflow 底座的演进方向

## 1. 目标与范围

本文档用于定义 `framework` 的下一阶段定位：  
不是把它做成另一个完整的 agent 产品，而是把它沉淀成一个可复用的 **agent 辅助小工具 / workflow / skill backend / CLI** 运行时底座。

配套阅读：

- [`agent-tooling-runtime-vnext-module-design.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-vnext-module-design.md)
- [`agent-tooling-runtime-phase1-roadmap.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-phase1-roadmap.md)

本文档关注的问题是：

- `framework` 是否适合承载 agent 辅助小工具
- `framework` 与 `zig-opencode` 的边界应如何划分
- 未来哪些能力应进入 `framework`
- 应如何支持 Zig 编写的 skill 脚本、复杂 CLI 和 workflow 逻辑
- 对 Python / PowerShell / 外部脚本应采取什么策略

本文档不覆盖：

- 具体 LLM provider 设计
- session conversation timeline 设计
- prompt / agent profile / model routing 设计
- `zig-opencode` 的产品级 UI 与交互细节

## 2. 背景判断

当前 `framework` 已经具备一个“runtime kernel”的基本轮廓，核心能力包括：

- `AppContext` 统一依赖装配
- `CommandRegistry` / `CommandDispatcher` 统一命令执行入口
- `TaskRunner` 异步任务执行与状态跟踪
- `EventBus` 事件发布、订阅与轮询
- logger / trace / observer / metrics
- config store / config pipeline
- validation / error model / envelope / capability manifest

这些能力说明：

1. `framework` 已经不只是一个空骨架
2. 它已经很适合作为小型工具系统与自动化流程的底层运行时
3. 它当前更像 “runtime kernel”，还不像 “tooling / workflow framework”

因此，下一阶段最关键的不是继续堆业务语义，而是明确：

> `framework` 应该成为什么样的通用底座，才能同时服务 `zig-opencode`、skill backend、workflow CLI 和其他 agent 辅助工具。

## 3. 核心定位

建议将 `framework` 的定位明确为：

> 一个用 Zig 构建的、可观测、可组合、可托管的小工具与 workflow runtime，为 agent tool、skill backend 和 CLI 提供统一底座。

它的理想分层应该是：

```text
framework
  = runtime kernel
  + effects layer
  + workflow engine
  + tool host
  + adapters

zig-opencode
  = session runtime
  + provider runtime
  + prompt / agent runtime
  + TUI / client runtime

tool apps / skill backends
  = commands + workflows + adapters
  built on framework
```

这意味着：

- `framework` 负责“如何安全、可观测、可组合地执行逻辑”
- `zig-opencode` 负责“如何运行 LLM / session / tool-use / agent 语义”
- skill 脚本和 CLI 工具不必自己再发明一套任务、日志、事件、配置和错误模型

## 4. 为什么这个方向成立

如果目标是帮助用户快速开发：

- agent 可调用的小工具
- skill 背后的复杂脚本
- workflow CLI
- 带权限、确认、重试、并行、事件流的自动化逻辑

那么比起直接让大家从零写脚本，`framework` 更适合提供统一底座。

因为这些工具虽然表面不同，本质往往是同一类东西：

- 接收结构化输入
- 做校验
- 执行一组 effect
- 可能触发异步任务
- 可能并行 fan-out
- 可能需要人工确认
- 需要日志、trace、事件和结果封装

也就是说，它们都可以统一建模为：

- `Command`
- `Workflow`
- `Adapter`

若这一层统一起来，则同一套核心逻辑可以同时被：

- CLI 调用
- agent 当作 tool 调用
- HTTP 服务调用
- 未来的 stdio / MCP adapter 调用

这会显著提升复用性。

## 5. `framework` 与 `zig-opencode` 的边界

这个边界必须尽早定清楚，否则 `framework` 很容易演化成 “`zig-opencode` 的核心包”，从而失去通用性。

### 5.1 应进入 `framework` 的能力

这些能力与具体 agent 产品语义无关，应该下沉到 `framework`：

- deterministic workflow 编排
- 命令与工具注册
- 统一 schema / validation / error / envelope
- 异步任务与状态机
- 事件发布、订阅与等待
- 统一 observability
- effect abstraction
- 权限门、确认门、人工交互门
- CLI / HTTP / stdio / tool adapter
- 外部脚本托管与执行包装

### 5.2 不应进入 `framework` 的能力

这些能力与具体 AI 产品语义强相关，应继续留在 `zig-opencode` 或业务层：

- LLM provider 抽象
- prompt assembly
- conversation timeline
- model/category routing
- agent profile / planner / oracle / worker 语义
- TUI 聊天产品逻辑

一句话概括：

`framework` 应该知道“任务、工作流、工具执行”；  
但不应该知道“对话、人格、模型策略”。

## 6. 适合支持的目标场景

未来 `framework` 最适合优先支撑这些场景：

### 6.1 Skill backend

例如：

- URL 抓取与 Markdown 转换
- 文档解析与结构化抽取
- repo 扫描、补丁生成、代码重写
- 配置迁移与验证
- issue / PR / changelog 自动生成

这些能力通常是 deterministic 的，适合被 agent 当作工具使用。

### 6.2 Workflow CLI

例如：

- 一键项目初始化
- 代码库检查 / 修复流水线
- release / changelog / version bump 工作流
- 文档生成 / 索引更新 / 依赖健康检查

这类 CLI 和 skill backend 的底层结构往往高度一致，只是入口不同。

### 6.3 `oh-my-openagent` 风格的流程逻辑

可以借鉴的是：

- 任务编排
- 验证循环
- 并行 fan-out
- 失败重试与继续
- 人工确认
- 事件驱动 continuation

但不应直接把其 agent 产品语义整体搬进 `framework`。

## 7. 建议新增的三层能力

当前 `framework` 已有 kernel，但若要更好承载小工具与 workflow，建议新增以下三层。

### 7.1 `effects/`：effect 抽象层

目标是让工具逻辑不直接散落地依赖 stdlib 或平台命令，而是通过统一 effect surface 执行外部世界交互。

建议最小 effect 集包括：

- file system
- http client
- process runner
- env / secret access
- temp workspace
- clock / sleep

价值：

- tool / workflow 逻辑更稳定
- 更容易 mock 与测试
- 更容易在 CLI、HTTP、agent tool 中复用
- 更方便后续做权限与审计

### 7.2 `workflow/`：通用工作流引擎

目标不是做 AI loop，而是做 deterministic orchestration。

建议最小 step 类型：

- `command`
- `shell`
- `http`
- `branch`
- `parallel`
- `retry`
- `wait_event`
- `ask_permission`
- `ask_question`
- `emit_event`

有了这层之后，就能自然表达很多 agent 辅助工具中的复杂逻辑，而不必把所有东西都硬编码在一个命令里。

### 7.3 `tooling/`：tool host 与 adapter 层

目标是让同一个核心逻辑被不同入口消费。

建议支持的核心单元：

- `CommandDefinition`
- `ToolDefinition`
- `WorkflowDefinition`

并允许导出为：

- CLI command
- HTTP route
- stdio tool
- `zig-opencode` builtin tool adapter
- 未来 MCP / bridge adapter

这样 “skill 脚本” 与 “CLI 工具” 就不再是两套平行体系，而是同一个 runtime 的不同入口。

## 8. Polyglot 策略：不要强制一切都写 Zig

虽然整体方向可以 Zig-first，但 `framework` 不应假设所有能力都必须原生 Zig 实现。

更现实的策略是：

- 原生 Zig command / workflow：一等公民
- 外部 Python / Node / PowerShell 脚本：可托管能力
- 值得长期沉淀的脚本，再逐步迁移到 Zig

这是因为：

- 某些任务适合 Zig
- 某些任务适合 PowerShell
- 某些任务依赖 Python 生态

若强制 “全 Zig”，反而会降低实际可用性与迭代速度。

### 8.1 适合优先 Zig 化的脚本

- 文件扫描与重写
- Markdown / patch / diff / codegen
- JSON / YAML / HTTP API 工具
- deterministic validator / converter
- 本地索引、缓存、repo 工具
- 长期维护的 CLI

### 8.2 适合保留其他语言的脚本

- 浏览器自动化
- HTML 抓取特别重的逻辑
- 重度依赖 SaaS SDK 的集成脚本
- 强平台胶水逻辑
- 快速试验类工具

推荐原则：

- Zig：做长期资产和核心工具
- PowerShell：做 Windows 平台胶水
- Python：做生态型 / 浏览器型集成

## 9. 推荐目录演进

当前顶层模块：

- `src/core/`
- `src/config/`
- `src/observability/`
- `src/runtime/`
- `src/app/`
- `src/contracts/`

建议继续保留现有结构，并在其上新增：

```text
src/
├── app/
├── config/
├── contracts/
├── core/
├── observability/
├── runtime/
├── effects/
├── workflow/
└── tooling/
```

建议职责如下：

- `effects/`
  - 文件、HTTP、进程、环境、secret、time 的统一 effect surface
- `workflow/`
  - workflow definition、runner、checkpoint、policy
- `tooling/`
  - tool registry、tool manifest、adapter、external script host

这样既不会破坏当前 kernel 的稳定性，也能让未来的 tool / workflow 能力有自然落点。

## 10. 推荐演进顺序

建议按以下顺序推进：

1. 明确 `framework` 的目标定位为 runtime kernel + workflow/tool host
2. 先补 `effects` 层
3. 再补 `workflow` 层
4. 再补 `tooling` / adapter / external script host
5. 最后让 `zig-opencode` 消费这些能力

顺序上要尽量避免：

- 先把 AI 特定语义塞进 `framework`
- 先做产品壳而没有稳定 runtime contract
- 先强推 “全 Zig” 而忽略 polyglot reality

## 11. 第一阶段最值得做的事

如果只做第一阶段，我建议聚焦下面几件事：

### 11.1 明确 effect surface

先统一：

- 文件访问
- HTTP 请求
- 进程执行
- 环境变量与 secret 读取

这会直接提升 skill backend 与 CLI 的复用性。

### 11.2 做最小 workflow runner

先不追求复杂 DSL，只支持：

- 顺序执行
- retry
- parallel
- emit_event
- ask_permission

这样已经足够支撑很多 agent 辅助小工具。

### 11.3 做 external script host

允许把 Python / PowerShell 脚本包装成统一 command/tool：

- 定义输入输出协议
- 接入日志、事件、错误和超时
- 让它们能挂进 dispatcher / task runner

这会让你当前已有 skills 脚本体系立即受益，而不用等全部 Zig 化。

## 12. 最终建议

综合来看，建议把 `framework` 的长期目标明确成：

> 一个面向 agent 辅助小工具、skill backend、workflow CLI 的 Zig runtime 底座。

其核心价值不在于替代所有上层产品，而在于统一：

- command
- workflow
- observability
- effects
- adapters

并通过 polyglot host 策略，逐步把值得长期沉淀的工具逻辑迁移到 Zig。

这样做的结果是：

- `framework` 会越来越像一个真正可复用的底座
- `zig-opencode` 会变成该底座上的一个大型消费方
- 未来的 skill 脚本和小工具不再是零散脚本，而是统一 runtime 里的能力

这条路线是成立的，而且和当前 `framework` 的演进方向是顺的。
