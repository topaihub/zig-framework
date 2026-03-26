# framework agent tooling runtime 第一阶段 roadmap

## 1. 目标

本文档定义 `framework` 面向 agent 小工具 / skill backend / workflow CLI 的 **第一阶段** 演进计划。

第一阶段的目标不是一次性做完完整 workflow 平台，而是先建立一个可落地、可测试、可复用的基础执行层，使 `framework` 能：

- 托管 Zig 原生小工具
- 托管 Python / PowerShell 等外部脚本
- 让 CLI、tool、脚本共享同一套运行时主干
- 为第二阶段 workflow engine 奠定稳定基础

## 2. 第一阶段主题

建议第一阶段主题明确为：

> Tool Execution Substrate  
> 即：工具执行基座，而不是完整工作流平台。

原因很简单：

- 现有 kernel 已经足够强
- 现在最缺的是“如何统一执行工具和脚本”
- 先把工具执行基座做实，比先做复杂 workflow DSL 更稳

## 3. 第一阶段范围

第一阶段建议只覆盖三块：

### 3.1 `effects` 最小层

先统一最关键的外部世界访问能力：

- file system
- process runner
- http client
- env / secret access
- clock / timeout helpers

### 3.2 `tooling` 最小层

先建立：

- tool definition
- tool registry
- tool runner
- script host
- command adapter

### 3.3 外部脚本托管协议

先定义并打通：

- JSON stdin/stdout contract
- timeout / cwd / env 注入
- 错误映射
- 日志 / 事件接线

## 4. 第一阶段不做什么

为了避免范围失控，第一阶段建议明确不做：

- 完整 workflow DSL
- checkpoint / resume / persistence
- branch / parallel / wait_event 等复杂 orchestration
- LLM / provider / session 语义
- MCP / bridge / GUI 集成
- 大而全的 plugin ecosystem

这些内容适合留到第二阶段及之后。

## 5. 第一阶段预期产出

若第一阶段完成，`framework` 应至少具备下面这些成果：

### 5.1 原生 Zig 工具可统一注册与执行

例如：

- repo health check
- markdown transformer
- config validator

### 5.2 外部脚本可以被当作统一 tool 执行

例如：

- Python 抓取脚本
- PowerShell 系统脚本

且它们不再是框架外孤立的脚本，而是统一 runtime 里的托管能力。

### 5.3 同一工具可以同时作为：

- CLI command
- testable tool invocation
- 后续 agent tool adapter 的基础

### 5.4 所有工具执行都有统一的：

- validation
- logging / trace
- event emission
- timeout
- structured result

## 6. 第一阶段建议新增模块

### 6.1 `src/effects/`

建议第一阶段只做最小文件集合：

```text
src/effects/
├── root.zig
├── fs.zig
├── process_runner.zig
├── http_client.zig
├── env_provider.zig
└── clock.zig
```

优先级排序：

1. `process_runner.zig`
2. `fs.zig`
3. `env_provider.zig`
4. `clock.zig`
5. `http_client.zig`

原因：

- 脚本托管与本地工具最先依赖 process / fs / env
- HTTP 工具很重要，但不一定是所有第一批工具的 blocker

### 6.2 `src/tooling/`

建议第一阶段只做最小文件集合：

```text
src/tooling/
├── root.zig
├── runtime.zig
├── tool_definition.zig
├── tool_context.zig
├── tool_registry.zig
├── tool_runner.zig
├── script_contract.zig
├── script_host.zig
└── adapters/
    ├── root.zig
    └── command_surface.zig
```

先不要在第一阶段就做：

- `http_surface.zig`
- `stdio_surface.zig`
- `zig_opencode_surface.zig`

这些可以在第二阶段继续长。

## 7. 建议的核心对象

### 7.1 `ToolDefinition`

建议最小字段：

- `id`
- `description`
- `input_schema`
- `execution_kind`
- `authority`
- `handler` 或 `script_spec`

其中 `execution_kind` 至少支持：

- `native_zig`
- `external_json_stdio`

### 7.2 `ToolContext`

建议最小字段：

- `allocator`
- `request`
- `logger`
- `validated_params`
- `effects`
- `event_bus`

### 7.3 `ScriptSpec`

建议最小字段：

- `program`
- `args`
- `cwd`
- `env`
- `timeout_ms`
- `expects_json_stdout`

### 7.4 `ToolingRuntime`

建议组合：

```text
ToolingRuntime
  = AppContext kernel
  + EffectsRuntime
  + ToolRegistry
  + ToolRunner
  + ScriptHost
```

## 8. 推荐实施顺序

### Milestone 1: Effects substrate

先建立最小 effect layer。

本阶段目标：

- 定义 process runner 抽象
- 定义 file system helper 抽象
- 定义 env access helper
- 保证这些能力可 mock / 可测试

完成标准：

- 至少一个原生 Zig command 使用 `effects` 而不是直接散落调用 stdlib

### Milestone 2: Tool model

建立最小 tool model。

本阶段目标：

- 新增 `ToolDefinition`
- 新增 `ToolRegistry`
- 新增 `ToolContext`
- 新增 `ToolRunner`

完成标准：

- 一个 Zig 原生 tool 能被注册、校验、执行并返回结构化结果

### Milestone 3: Script host

打通外部脚本托管。

本阶段目标：

- 定义 JSON stdin/stdout contract
- 新增 `ScriptHost`
- 接入 timeout / cwd / env / exit code handling
- 将脚本结果映射到统一 envelope / error model

完成标准：

- 一个 Python 脚本和一个 PowerShell 脚本都能通过同一 `ToolRunner` 被调用

### Milestone 4: Command adapter

把 tool 挂入现有 command model。

本阶段目标：

- 新增 `command_surface`
- 能把 `ToolDefinition` 暴露成 command
- 复用现有 `CommandDispatcher`

完成标准：

- 同一个工具既能以 tool 形式执行，也能以 command method 形式执行

### Milestone 5: Docs + examples + tests

本阶段目标：

- 增加最小示例
- 增加托管脚本例子
- 补齐集成测试
- 形成第一批使用规范文档

完成标准：

- 新人可以照示例做出一个 Zig tool 和一个 script-backed tool

## 9. 建议的第一批参考垂直切片

为了避免第一阶段只停留在抽象层，建议用两个最小垂直切片来逼设计落地。

### 9.1 `repo-health-check`

一个 Zig 原生工具，执行：

- 遍历目录
- 检查 git / config / file layout
- 输出结构化诊断

价值：

- 验证 `ToolDefinition`
- 验证 `effects.fs`
- 验证 `command_surface`

### 9.2 `script-markdown-fetch`

一个外部脚本托管工具，执行：

- 调用 Python 或 PowerShell 脚本
- 接收 JSON stdout
- 返回统一结果

价值：

- 验证 `ScriptHost`
- 验证 timeout / cwd / env
- 验证 polyglot strategy

如果以后要把 `markdown-proxy` 的某部分接进来，这会是很自然的第一批实验对象。

## 10. 第一阶段验收标准

建议以以下标准作为阶段完成判断：

### 10.1 Runtime 能力

- `framework` 能注册并执行 Zig 原生 tool
- `framework` 能托管并执行外部 JSON-stdio 脚本
- 所有工具执行都接入 logger / event bus / task runner

### 10.2 结构一致性

- tool 执行结果使用统一 envelope / error model
- tool 输入经过统一 validation
- command adapter 与 tool execution 共用核心逻辑

### 10.3 示例与测试

- 至少 1 个 Zig 原生 tool 示例
- 至少 1 个外部脚本 tool 示例
- 至少 1 组集成测试覆盖 timeout / failure / invalid output

## 11. 第一阶段风险与注意事项

### 11.1 不要过早做复杂 workflow

第一阶段最容易犯的错误是：

- 一上来就做完整 workflow DSL
- 然后在没有稳定 tool substrate 的情况下陷入抽象过度

建议克制。

### 11.2 不要把 script host 做成临时拼接器

如果只是“能跑脚本”但没有：

- schema
- structured result
- timeout
- error mapping
- event/logging

那么它仍然只是 framework 外部的裸脚本包装。

### 11.3 不要让 `AppContext` 失控

第一阶段尽量采用组合层方式引入 `ToolingRuntime`，而不是把所有东西都直接塞进 `runtime.AppContext`。

## 12. 第二阶段预告

若第一阶段顺利完成，第二阶段就可以顺势引入：

- 最小 workflow runner
- `parallel` / `retry` / `emit_event`
- tool-backed workflow
- stdio / HTTP adapter
- `zig-opencode` builtin tool adapter

也就是说：

第一阶段负责把“工具执行基座”做实；  
第二阶段才负责把“复杂编排能力”做强。

## 13. 最终建议

如果只用一句话描述第一阶段，我建议这样定义：

> 先把 `framework` 做成一个可以稳定托管 Zig 工具和外部脚本的统一执行基座。

这一步一旦做好，后面的 workflow、agent tool、skill backend 和 CLI 体系都会自然长出来，而且方向会更稳。
