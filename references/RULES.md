# zig-framework 开发规则

## 红线

1. **不放产品语义** — 人格/记忆策略/路由策略/审批策略留在 hermes-zig
2. **不反向依赖 hermes-zig** — 依赖方向：hermes-zig → zig-framework → zig-logging
3. **接口设计以 hermes-zig 实际需求为准** — 先读 hermes-zig 对应代码再设计，不凭空发明
4. **新增模块先判断是底座还是产品逻辑** — 通用能力放 framework，产品特定放 hermes-zig
5. **每一步结束必须 `zig build` 通过** — 不允许中间状态编译不过
6. **不引入新的第三方依赖** — 除非明确要求

## 验证命令

```bash
zig fmt --check src/
zig build
zig build test
```

三个命令都必须通过才能提交。

## 架构

```
zig-framework/src/
├── core/           错误模型 + 校验 + 安全基础检查
│   ├── error.zig
│   ├── validation/
│   └── security/   路径/注入/环境变量/URL 安全检查
├── contracts/      Envelope + CapabilityManifest
├── config/         配置系统（加载/解析/存储/管线）
├── observability/  Observer + Trace + Metrics
├── runtime/        AppContext + EventBus + TaskRunner + Streaming
├── effects/        FS/Process/Env/Clock/HTTP vtable 接口
├── tooling/        ToolRegistry + ToolRunner + ScriptHost + MCP
├── workflow/       WorkflowDefinition + WorkflowRunner
├── agentkit/       ProviderRegistry + LlmProvider + AgentRuntime
├── app/            命令分发
└── servicekit/     空壳，暂不删除
```

## 依赖关系

```
hermes-zig（产品层）
    ↓ 依赖
zig-framework（共享底座）
    ↓ 依赖
zig-logging（日志组件）
```

## 模块职责边界

| 模块 | 放什么 | 不放什么 |
|------|--------|---------|
| agentkit | LLM Provider vtable、Agent Runtime 骨架、ProviderRegistry | 具体 provider 实现（Anthropic/OpenAI） |
| core/security | 路径遍历检查、注入扫描、环境变量过滤、URL 安全检查 | 审批策略、权限策略、审计日志 |
| tooling/mcp | MCP 协议解析、消息格式、基础 client/server | 工具发现逻辑、具体业务逻辑 |
| effects | FS/Process/Env/HTTP 的可测试 vtable 抽象 | 具体业务文件操作 |
| runtime | AppContext、EventBus、TaskRunner、Streaming | Agent Loop 逻辑 |

## 文档索引

- `docs/architecture/` — 架构设计文档
- `docs/development/` — 开发环境配置
- `examples/` — 使用示例
