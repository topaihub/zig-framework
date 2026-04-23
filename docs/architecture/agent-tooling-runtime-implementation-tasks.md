# framework agent tooling runtime 可执行任务清单

## 1. 使用说明

本文档将 `framework` vNext 的 requirement、direction、module design、phase roadmap 收束成一份可执行任务清单。

使用原则：

- 按分组顺序推进，不建议跳组施工
- 同一组内可以局部并行，但必须保持依赖顺序
- 若任务与 requirement 冲突，以 [`agent-tooling-runtime-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-requirements.md) 为准
- 若任务需要进一步设计细节，以 [`agent-tooling-runtime-vnext-module-design.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-vnext-module-design.md) 为准

状态约定：

- `[x]` 已完成或已有稳定前置文档
- `[ ]` 待实施

## 2. 文档与范围基线

- [x] 2.1 补齐 `framework` 平台定位、requirements、module design、phase roadmap、提取策略文档
- [x] 2.2 在 `framework/docs/README.md` 中建立统一入口
- [x] 2.3 在 `framework/docs/architecture/` 新增一份“施工约束”说明，明确 implementation 时的边界判断与禁区
- [x] 2.4 在 `framework` 根目录确定 vNext 期间的目录增长规则，约束新模块只能落到既定顶层目录

## 3. Effects 基座

- [x] 3.1 新建 `src/effects/root.zig` 并在 `src/root.zig` 中导出 `effects`
- [x] 3.2 定义 `src/effects/types.zig`，抽出通用 request/result/error 契约
- [x] 3.3 实现 `src/effects/process_runner.zig`，支持 cwd、env、timeout、stdout/stderr 捕获
- [x] 3.4 为 `process_runner` 补齐测试，覆盖成功、非零退出码、超时、缺失命令
- [x] 3.5 实现 `src/effects/fs.zig`，支持读、写、列目录、原子写、删除、移动等最小文件能力
- [x] 3.6 为 `fs` 补齐测试，覆盖路径不存在、原子写、覆盖写、递归目录场景
- [x] 3.7 实现 `src/effects/env_provider.zig`，统一读取环境变量与必填变量
- [x] 3.8 实现 `src/effects/clock.zig`，统一 current time、monotonic time、sleep、deadline helper
- [ ] 3.9 实现 `src/effects/http_client.zig` 最小版，支持 GET/POST、header、body、timeout
- [x] 3.10 设计 `EffectsRuntime` 组合入口，把 fs/process/env/clock/http 统一装配起来

## 4. Tooling 核心模型

- [x] 4.1 新建 `src/tooling/root.zig` 并在 `src/root.zig` 中导出 `tooling`
- [x] 4.2 实现 `src/tooling/tool_definition.zig`，定义 `ToolDefinition`
- [x] 4.3 实现 `src/tooling/tool_context.zig`，定义 `ToolContext`，接入 logger、event bus、effects、validated params
- [x] 4.4 实现 `src/tooling/tool_registry.zig`，支持注册、查找、列举、重复检测
- [x] 4.5 实现 `src/tooling/tool_runner.zig`，统一 native Zig tool 的校验、执行、错误映射、观测接线
- [ ] 4.6 设计 `ToolExecutionResult` / `ToolExecutionEnvelope`，与现有 contracts/error model 对齐
- [x] 4.7 引入类似 `nullclaw` 的 `ToolVTable(T)` / `assertToolInterface(...)` helper，降低定义工具的样板代码
- [x] 4.8 为 tool registry + runner + helper 补齐单元测试

## 5. External Script Host

- [x] 5.1 实现 `src/tooling/script_contract.zig`，定义 JSON stdin/stdout 协议
- [x] 5.2 实现 `src/tooling/script_host.zig`，支持 `external_json_stdio`
- [x] 5.3 支持向脚本注入 cwd、env、timeout、request metadata
- [x] 5.4 脚本 host 接入 `effects.process_runner`
- [x] 5.5 对脚本 stdout 做 JSON 校验，并将解析错误映射到统一错误模型
- [x] 5.6 对脚本 stderr 做结构化日志桥接
- [x] 5.7 为脚本 host 补齐测试，覆盖成功脚本、超时脚本、无效 JSON 输出、非零退出脚本
- [x] 5.8 设计最小脚本 manifest / spec 结构，使脚本型 tool 可被注册到 `ToolRegistry`

## 6. ToolingRuntime 组合层

- [x] 6.1 实现 `src/tooling/runtime.zig`，把 `framework.AppContext`、`EffectsRuntime`、`ToolRegistry`、`ToolRunner`、`ScriptHost` 组合起来
- [x] 6.2 明确 `ToolingRuntime` 与 `framework.runtime.AppContext` 的边界，避免 giant AppContext
- [x] 6.3 为 `ToolingRuntime` 增加最小初始化测试与 smoke test
- [x] 6.4 为 future `zig-opencode` 和 `ourclaw` 预留消费入口，但先不引入产品语义

## 7. Command Surface 集成

- [x] 7.1 新建 `src/tooling/adapters/root.zig`
- [x] 7.2 实现 `src/tooling/adapters/command_surface.zig`
- [x] 7.3 支持把一个 `ToolDefinition` 暴露成 framework command
- [x] 7.4 确保 command 调用与 tool 调用复用同一核心执行逻辑，而不是复制执行分支
- [x] 7.5 为 command surface 增加测试，验证 tool 和 command 两种入口的输出一致
- [ ] 7.6 为 command surface 增加 authority / risk policy 接口预留

## 8. 第一批垂直切片

- [x] 8.1 新增一个 Zig 原生示例工具，例如 `repo-health-check`
- [x] 8.2 让 `repo-health-check` 同时支持 direct tool 调用和 command surface 调用
- [x] 8.3 新增一个 script-backed 示例工具，例如 `script-markdown-fetch`
- [x] 8.4 让 `script-markdown-fetch` 通过统一脚本协议运行一个 Python 或 PowerShell 脚本
- [x] 8.5 为这两个垂直切片补齐 examples 文档，作为后续用户模板

## 9. Workflow 基础层

- [x] 9.1 新建 `src/workflow/root.zig` 并在 `src/root.zig` 中导出 `workflow`
- [x] 9.2 实现 `src/workflow/definition.zig`，定义 workflow / step 基础模型
- [x] 9.3 实现 `src/workflow/step_types.zig`，先支持 `command`、`shell`、`retry`、`emit_event`
- [x] 9.4 实现 `src/workflow/runner.zig` 最小版，支持顺序执行和 retry
- [x] 9.5 实现 `src/workflow/state.zig`，记录运行态、step 指针、终态结果
- [x] 9.6 为 workflow runner 补齐测试，覆盖顺序执行、重试成功、重试失败
- [x] 9.7 将 workflow 执行接到现有 task runner / event bus / logger
- [ ] 9.8 暂不实现完整 DSL、checkpoint、resume、parallel fan-out，只保留结构预留

## 10. Service Bundle 与 Runtime Composition

- [x] 10.1 抽象出可复用的 service bundle / services facade 模式，吸收 `ourclaw` 的 `CommandServices` 思想
- [x] 10.2 为业务项目提供“如何把 services 挂到 framework.CommandContext.user_data”的标准模式
- [x] 10.3 设计一个小型组合层示例，证明业务项目不必把所有依赖都塞回 `framework.AppContext`
- [x] 10.4 补一份文档说明 kernel / tooling runtime / business services 三层关系

## 11. Provider Substrate 预备层

- [x] 11.1 新建 `src/agentkit/` 或预留 `agentkit` 目录，仅放最小占位 root
- [x] 11.2 抽象 provider definition / provider health / provider model info 的共用契约
- [x] 11.3 吸收 `nullclaw` 的 `Kind` / `classify` / `Holder` / `fromConfig` 思路，先写成通用模式说明或基础类型
- [x] 11.4 先做 provider registry / catalog / health 的最小模型，不做完整 chat runtime
- [ ] 11.5 评估这层应该落在 `tooling`、`agentkit` 还是更晚阶段，形成边界说明

## 12. Channel / ServiceKit 预备层

- [x] 12.1 新建 `src/servicekit/` 或预留 `servicekit` 目录，仅放最小占位 root
- [x] 12.2 从 `ourclaw/runtime_host` 提炼最小 runtime host 抽象需求
- [x] 12.3 从 `nullclaw/channels/root.zig` 和 `channels/dispatch.zig` 提炼 channel 的 interface / registry / supervisor 模式说明
- [x] 12.4 明确 channel 当前阶段不进入 kernel 的约束文档
- [x] 12.5 为 future `servicekit` 留下 gateway / daemon / heartbeat / cron 组合边界

## 13. 与 zig-opencode / ourclaw 的消费验证

- [x] 13.1 为 `zig-opencode` 写一份消费计划，说明未来如何使用 `framework/tooling`
- [x] 13.2 为 `ourclaw` 写一份消费计划，说明未来如何使用 `framework/tooling`、`workflow`、`service bundle`
- [x] 13.3 从两个项目里各挑一个最小真实场景，验证 `framework` 新 substrate 是否真的可复用
- [x] 13.4 记录那些“看似通用但其实仍应留在 app 层”的能力，避免错误下沉

## 14. 文档与规范收尾

- [x] 14.1 新增一份 `framework` vNext 的 implementation guide，说明新增模块之间的依赖规则
- [x] 14.2 为新增 `effects` / `tooling` / `workflow` 模块补齐 architecture 文档
- [x] 14.3 为外部脚本托管协议补一份单独文档，给 future skill backend 使用
- [x] 14.4 对 README 和 architecture index 做最终整理，给后续大模型一个稳定阅读入口

## 15. 第一阶段完成判定

- [x] 15.1 `effects` 最小层存在并可被真实代码消费
- [x] 15.2 Zig 原生 tool 能通过统一 runner 执行
- [x] 15.3 外部脚本能通过统一 script host 托管
- [x] 15.4 command surface 已打通
- [x] 15.5 至少两个垂直切片可运行
- [x] 15.6 tests 覆盖成功、失败、timeout、invalid output 等关键路径
- [x] 15.7 文档、requirements、design、tasks 保持同步
