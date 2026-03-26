# framework agent tooling runtime 细粒度执行任务清单

## 1. 使用说明

本文档是 [`agent-tooling-runtime-implementation-tasks.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-implementation-tasks.md) 的细粒度执行版。

目标：

- 把平台级任务继续拆到更适合大模型直接执行的粒度
- 让每个任务尽量对应到明确文件、明确行为和明确测试
- 降低“先自己理解、再自己拆任务”的上下文损耗

使用规则：

- 按阶段顺序推进
- 同一阶段内优先从 scaffold -> implementation -> tests -> docs
- 没有通过对应测试前，不进入下一阶段
- 如遇边界冲突，以 [`agent-tooling-runtime-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-requirements.md) 为准

## 2. 阶段 0：施工约束与入口整理

- [x] 2.1 在 `framework/docs/architecture/` 新增一份 `implementation-guardrails.md`，明确 kernel / tooling / workflow / future kit 的边界
- [x] 2.2 在 `implementation-guardrails.md` 中写明当前阶段禁止直接下沉完整 provider/channel/session/gateway 产品逻辑
- [x] 2.3 在 `framework/docs/README.md` 中为 vNext 文档链补充建议阅读顺序
- [x] 2.4 在 `framework/src/root.zig` 中检查现有导出顺序，为后续新增 `effects` / `tooling` / `workflow` 预留位置
- [x] 2.5 为 vNext 模块增长约定一套顶层目录规则，避免新增模块散落到现有目录中

## 3. 阶段 1：Effects 模块骨架

- [x] 3.1 新建 `framework/src/effects/root.zig`
- [x] 3.2 在 `framework/src/effects/root.zig` 中定义 `MODULE_NAME = "effects"`
- [x] 3.3 在 `framework/src/effects/root.zig` 中先导出 `types.zig`
- [x] 3.4 在 `framework/src/effects/root.zig` 中加入 `std.testing.refAllDecls(@This())`
- [x] 3.5 在 `framework/src/root.zig` 中导出 `effects`
- [x] 3.6 为 `framework/src/root.zig` 增加 `effects` 可见性的 smoke test
- [x] 3.7 新建 `framework/src/effects/types.zig`
- [x] 3.8 在 `types.zig` 中定义 effect 级别共用请求/结果基础类型
- [x] 3.9 在 `types.zig` 中定义 effect 级别最小错误分类或错误说明结构
- [x] 3.10 为 `framework/src/effects/root.zig` 和 `types.zig` 增加基础编译测试

## 4. 阶段 2：Process Runner

- [x] 4.1 新建 `framework/src/effects/process_runner.zig`
- [x] 4.2 定义 `ProcessRunRequest`
- [x] 4.3 定义 `ProcessRunResult`
- [x] 4.4 定义 `ProcessRunner` vtable 接口
- [x] 4.5 实现一个默认 `std.process.Child` 驱动的 runner
- [x] 4.6 支持传入 `cwd`
- [x] 4.7 支持传入额外 `env`
- [x] 4.8 支持 stdout/stderr 捕获
- [x] 4.9 支持 exit code 映射
- [x] 4.10 支持 timeout 参数
- [x] 4.11 timeout 超时时返回统一错误
- [x] 4.12 在 `effects/root.zig` 中导出 `process_runner`
- [x] 4.13 增加“成功执行命令”测试
- [x] 4.14 增加“命令不存在”测试
- [x] 4.15 增加“非零退出码”测试
- [x] 4.16 增加“超时”测试
- [x] 4.17 增加“cwd 生效”测试
- [x] 4.18 增加“env 注入生效”测试

## 5. 阶段 3：Filesystem Effects

- [x] 5.1 新建 `framework/src/effects/fs.zig`
- [x] 5.2 定义文件读取 helper
- [x] 5.3 定义文件写入 helper
- [x] 5.4 定义原子写 helper
- [x] 5.5 定义目录列举 helper
- [x] 5.6 定义文件删除 helper
- [x] 5.7 定义文件移动 / 重命名 helper
- [x] 5.8 定义目录创建 helper
- [x] 5.9 统一路径不存在错误投影
- [x] 5.10 在 `effects/root.zig` 中导出 `fs`
- [x] 5.11 增加“读不存在文件失败”测试
- [x] 5.12 增加“写文件成功”测试
- [x] 5.13 增加“原子写覆盖旧内容”测试
- [x] 5.14 增加“列目录结果稳定”测试
- [x] 5.15 增加“删除文件成功”测试
- [x] 5.16 增加“移动文件成功”测试

## 6. 阶段 4：Env / Clock / HTTP 最小层

- [x] 6.1 新建 `framework/src/effects/env_provider.zig`
- [x] 6.2 定义获取可选环境变量 helper
- [x] 6.3 定义获取必填环境变量 helper
- [x] 6.4 增加 env provider 基础测试
- [x] 6.5 新建 `framework/src/effects/clock.zig`
- [x] 6.6 定义 current time helper
- [x] 6.7 定义 monotonic time helper
- [x] 6.8 定义 sleep helper
- [x] 6.9 定义 deadline / timeout 计算 helper
- [x] 6.10 增加 clock helper 基础测试
- [x] 6.11 新建 `framework/src/effects/http_client.zig`
- [x] 6.12 定义最小 `HttpRequest`
- [x] 6.13 定义最小 `HttpResponse`
- [x] 6.14 定义最小 `HttpClient` vtable 接口
- [x] 6.15 提供一个默认实现或 mock-friendly 协议层
- [x] 6.16 在 `effects/root.zig` 中导出 env/clock/http
- [x] 6.17 至少增加一个基于 injected mock 的 http client 测试

## 7. 阶段 5：EffectsRuntime 组合层

- [x] 7.1 新建 `framework/src/effects/runtime.zig`
- [x] 7.2 组合 `fs`、`process_runner`、`env_provider`、`clock`、`http_client`
- [x] 7.3 定义 `EffectsRuntime.init(...)`
- [ ] 7.4 定义 `EffectsRuntime.deinit(...)`
- [x] 7.5 设计为可注入 mock 实现而非强耦合单例
- [x] 7.6 在 `effects/root.zig` 中导出 `EffectsRuntime`
- [x] 7.7 增加 EffectsRuntime 初始化 smoke test

## 8. 阶段 6：Tooling 模块骨架

- [x] 8.1 新建 `framework/src/tooling/root.zig`
- [x] 8.2 在 `tooling/root.zig` 中定义 `MODULE_NAME = "tooling"`
- [x] 8.3 在 `tooling/root.zig` 中导出 `tool_definition.zig`
- [x] 8.4 在 `tooling/root.zig` 中导出 `tool_context.zig`
- [x] 8.5 在 `tooling/root.zig` 中导出 `tool_registry.zig`
- [x] 8.6 在 `tooling/root.zig` 中导出 `tool_runner.zig`
- [x] 8.7 在 `tooling/root.zig` 中导出 `script_contract.zig`
- [x] 8.8 在 `tooling/root.zig` 中导出 `script_host.zig`
- [x] 8.9 在 `framework/src/root.zig` 中导出 `tooling`
- [x] 8.10 增加 tooling 模块 smoke test

## 9. 阶段 7：ToolDefinition / ToolContext

- [x] 9.1 新建 `framework/src/tooling/tool_definition.zig`
- [x] 9.2 定义 `ToolExecutionKind`
- [x] 9.3 定义 `ToolDefinition`
- [x] 9.4 为 `ToolDefinition` 加入 `id`
- [x] 9.5 为 `ToolDefinition` 加入 `description`
- [x] 9.6 为 `ToolDefinition` 加入 `authority`
- [x] 9.7 为 `ToolDefinition` 加入输入 schema 字段
- [x] 9.8 为 `ToolDefinition` 加入 native handler 或 script spec 挂点
- [x] 9.9 新建 `framework/src/tooling/tool_context.zig`
- [x] 9.10 定义 `ToolContext`
- [x] 9.11 让 `ToolContext` 包含 allocator
- [x] 9.12 让 `ToolContext` 包含 request metadata
- [x] 9.13 让 `ToolContext` 包含 logger
- [x] 9.14 让 `ToolContext` 包含 validated params
- [x] 9.15 让 `ToolContext` 包含 event bus
- [x] 9.16 让 `ToolContext` 包含 `EffectsRuntime`
- [x] 9.17 增加 ToolDefinition / ToolContext 基础测试

## 10. 阶段 8：Tool Registry

- [x] 10.1 新建 `framework/src/tooling/tool_registry.zig`
- [x] 10.2 定义 `ToolRegistry`
- [x] 10.3 支持 register
- [x] 10.4 支持 duplicate detection
- [x] 10.5 支持 find by id
- [x] 10.6 支持 list all
- [x] 10.7 支持 count
- [x] 10.8 增加“重复注册失败”测试
- [x] 10.9 增加“按 id 查找成功”测试
- [x] 10.10 增加“list / count 稳定”测试

## 11. 阶段 9：Native Tool Runner

- [x] 11.1 新建 `framework/src/tooling/tool_runner.zig`
- [x] 11.2 定义 `ToolExecutionResult`
- [x] 11.3 定义 `ToolExecutionEnvelope` 或统一返回模型
- [x] 11.4 为 native Zig tool 建立执行入口
- [x] 11.5 在执行前接入 validation
- [x] 11.6 在执行前接入 authority 检查
- [x] 11.7 在执行时创建带 trace 的 logger 子域
- [x] 11.8 在执行前后发出 event bus 事件
- [ ] 11.9 将错误映射到现有 error model
- [x] 11.10 增加“native tool 成功执行”测试
- [x] 11.11 增加“validation 失败”测试
- [x] 11.12 增加“authority 不足”测试
- [x] 11.13 增加“tool 内部错误映射”测试

## 12. 阶段 10：Tool Helper 样板降低

- [x] 12.1 新建 `framework/src/tooling/native_interface.zig` 或等价 helper 文件
- [x] 12.2 引入类似 `nullclaw` 的 `ToolVTable(T)` helper
- [x] 12.3 引入类似 `assertToolInterface(T)` helper
- [x] 12.4 用一个最小 native tool 验证 helper 能工作
- [x] 12.5 为 helper 增加编译期断言测试

## 13. 阶段 11：Script Contract

- [x] 13.1 新建 `framework/src/tooling/script_contract.zig`
- [x] 13.2 定义 `ScriptRequest`
- [x] 13.3 定义 `ScriptResult`
- [x] 13.4 定义成功输出的 JSON 形状
- [x] 13.5 定义错误输出的 JSON 形状
- [x] 13.6 定义 stdout 非 JSON 时的失败语义
- [x] 13.7 定义 stderr 的记录策略
- [ ] 13.8 增加 script contract 编解码测试

## 14. 阶段 12：Script Host

- [x] 14.1 新建 `framework/src/tooling/script_host.zig`
- [x] 14.2 定义 `ScriptSpec`
- [x] 14.3 支持 `program`
- [x] 14.4 支持 `args`
- [x] 14.5 支持 `cwd`
- [x] 14.6 支持 `env`
- [x] 14.7 支持 `timeout_ms`
- [x] 14.8 支持 `expects_json_stdout`
- [x] 14.9 通过 `effects.process_runner` 执行脚本
- [x] 14.10 将 `ToolContext` 映射为 `ScriptRequest`
- [x] 14.11 解析 stdout 为 `ScriptResult`
- [x] 14.12 对 stderr 发出结构化日志
- [x] 14.13 将脚本 host 接入统一 event bus
- [x] 14.14 增加“成功脚本”测试
- [x] 14.15 增加“超时脚本”测试
- [x] 14.16 增加“stdout 非 JSON”测试
- [x] 14.17 增加“退出码非零”测试

## 15. 阶段 13：Script-backed Tool 接入

- [x] 15.1 让 `ToolDefinition` 支持 `external_json_stdio`
- [x] 15.2 在 `ToolRunner` 中接入脚本型 tool 分支
- [x] 15.3 让脚本型 tool 与 native tool 共用统一 envelope / error / event / logging 主干
- [x] 15.4 增加“script-backed tool 成功执行”测试
- [ ] 15.5 增加“script-backed tool 错误映射”测试

## 16. 阶段 14：ToolingRuntime 组合层

- [x] 16.1 新建 `framework/src/tooling/runtime.zig`
- [x] 16.2 组合 `framework.AppContext`
- [x] 16.3 组合 `EffectsRuntime`
- [x] 16.4 组合 `ToolRegistry`
- [x] 16.5 组合 `ToolRunner`
- [x] 16.6 组合 `ScriptHost`
- [x] 16.7 定义 `ToolingRuntime.init(...)`
- [x] 16.8 定义 `ToolingRuntime.deinit(...)`
- [x] 16.9 在 `tooling/root.zig` 中导出 `ToolingRuntime`
- [x] 16.10 增加 `ToolingRuntime` 初始化 smoke test

## 17. 阶段 15：Command Surface

- [x] 17.1 新建 `framework/src/tooling/adapters/root.zig`
- [x] 17.2 新建 `framework/src/tooling/adapters/command_surface.zig`
- [x] 17.3 设计从 `ToolDefinition` 到 `CommandDefinition` 的映射
- [x] 17.4 支持 tool id -> command method 的命名规则
- [x] 17.5 支持 tool input schema -> command params schema 的映射
- [x] 17.6 让 command surface 复用 `ToolRunner`
- [x] 17.7 为 command surface 增加“通过 dispatcher 执行 tool”测试
- [x] 17.8 为 command surface 增加“tool 与 command 返回一致”测试

## 18. 阶段 16：垂直切片 A - Zig 原生工具

- [ ] 18.1 在 `framework/examples/` 设计一个 `repo-health-check` 示例
- [ ] 18.2 为该示例定义 input schema
- [ ] 18.3 用 `ToolVTable` helper 实现其 native tool
- [ ] 18.4 让它通过 `ToolRegistry` 注册
- [ ] 18.5 让它通过 command surface 暴露成 command
- [ ] 18.6 为其添加 example 文档
- [ ] 18.7 为其添加集成测试

## 19. 阶段 17：垂直切片 B - Script-backed 工具

- [ ] 19.1 选择一个最小外部脚本场景，例如 `script-markdown-fetch`
- [ ] 19.2 为该场景定义 `ScriptSpec`
- [ ] 19.3 将 Python 或 PowerShell 示例脚本接入统一 script contract
- [ ] 19.4 将其注册成 script-backed tool
- [ ] 19.5 让它通过 command surface 暴露
- [ ] 19.6 为其添加 example 文档
- [ ] 19.7 为其添加集成测试

## 20. 阶段 18：Workflow 模块骨架

- [ ] 20.1 新建 `framework/src/workflow/root.zig`
- [ ] 20.2 在 `workflow/root.zig` 中定义 `MODULE_NAME = "workflow"`
- [ ] 20.3 新建 `framework/src/workflow/definition.zig`
- [ ] 20.4 新建 `framework/src/workflow/step_types.zig`
- [ ] 20.5 新建 `framework/src/workflow/runner.zig`
- [ ] 20.6 新建 `framework/src/workflow/state.zig`
- [ ] 20.7 在 `framework/src/root.zig` 中导出 `workflow`
- [ ] 20.8 增加 workflow 模块 smoke test

## 21. 阶段 19：Workflow 最小执行能力

- [ ] 21.1 在 `step_types.zig` 中定义 `command` step
- [ ] 21.2 在 `step_types.zig` 中定义 `shell` step
- [ ] 21.3 在 `step_types.zig` 中定义 `retry` step
- [ ] 21.4 在 `step_types.zig` 中定义 `emit_event` step
- [ ] 21.5 在 `runner.zig` 中实现顺序执行
- [ ] 21.6 在 `runner.zig` 中实现 retry
- [ ] 21.7 在 `runner.zig` 中接入 logger / event bus / task runner
- [ ] 21.8 增加“顺序执行成功”测试
- [ ] 21.9 增加“retry 成功”测试
- [ ] 21.10 增加“retry 最终失败”测试

## 22. 阶段 20：Service Bundle / Services Facade

- [ ] 22.1 新建 `framework/docs/architecture/business-services-pattern.md`
- [ ] 22.2 从 `ourclaw` 的 `CommandServices` 提炼一个通用 service bundle 模式
- [ ] 22.3 设计一个小型 `ExampleServices`，说明如何挂到 `CommandContext.user_data`
- [ ] 22.4 增加 service bundle 示例测试
- [ ] 22.5 明确 `framework.AppContext` 与业务 services facade 的边界

## 23. 阶段 21：Provider Substrate 预备层

- [ ] 23.1 新建 `framework/src/agentkit/root.zig` 占位
- [ ] 23.2 定义 `ProviderDefinition` 最小契约
- [ ] 23.3 定义 `ProviderHealth` 最小契约
- [ ] 23.4 定义 `ProviderModelInfo` 最小契约
- [ ] 23.5 设计 provider registry 最小模型
- [ ] 23.6 记录 `Kind / classify / Holder / fromConfig` 通用模式到文档
- [ ] 23.7 明确当前阶段不实现完整 provider chat runtime

## 24. 阶段 22：Channel / ServiceKit 预备层

- [ ] 24.1 新建 `framework/src/servicekit/root.zig` 占位
- [ ] 24.2 从 `ourclaw/runtime_host` 提炼 runtime host 抽象需求
- [ ] 24.3 从 `nullclaw/channels/root.zig` 提炼 channel interface 模式说明
- [ ] 24.4 从 `nullclaw/channels/dispatch.zig` 提炼 supervisor / dispatch loop 模式说明
- [ ] 24.5 形成 channel 当前阶段“不进入 kernel”的约束说明

## 25. 阶段 23：消费方验证

- [ ] 25.1 为 `zig-opencode` 编写一份 `framework/tooling` 消费方案
- [ ] 25.2 为 `ourclaw` 编写一份 `framework/tooling` / `workflow` 消费方案
- [ ] 25.3 在 `zig-opencode` 中选一个 future tool 场景做消费验证草案
- [ ] 25.4 在 `ourclaw` 中选一个 future script/tool 场景做消费验证草案
- [ ] 25.5 记录那些不应下沉到 framework 的能力，避免误抽象

## 26. 阶段 24：文档与规范收尾

- [ ] 26.1 新增 `effects` 模块设计文档
- [ ] 26.2 新增 `tooling` 模块设计文档
- [ ] 26.3 新增 `script contract` 文档
- [ ] 26.4 新增 `workflow` 最小版设计文档
- [ ] 26.5 更新 docs index 与建议阅读顺序

## 27. 第一阶段完成判定

- [ ] 27.1 `effects` 模块已存在并有最小测试覆盖
- [ ] 27.2 native Zig tool 已可注册和执行
- [ ] 27.3 script-backed tool 已可托管和执行
- [ ] 27.4 command surface 已打通
- [ ] 27.5 至少 2 个垂直切片可运行
- [ ] 27.6 workflow 最小 runner 可运行
- [ ] 27.7 service bundle pattern 已沉淀为示例与文档
- [ ] 27.8 requirement / design / roadmap / tasks / docs index 已同步
