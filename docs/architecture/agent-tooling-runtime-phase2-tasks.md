# framework agent tooling runtime Phase 2 任务清单

## 1. 使用说明

本文档把 phase 2 的需求与设计收束成可执行任务。

上游文档：

- [`agent-tooling-runtime-phase2-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-phase2-requirements.md)
- [`agent-tooling-runtime-phase2-design.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/agent-tooling-runtime-phase2-design.md)

使用原则：

- 按分组顺序推进
- 同组内可局部并行，但不要跨组跳依赖
- 若任务与 requirements 冲突，以 requirements 为准

状态约定：

- `[ ]` 待实施
- `[x]` 已完成

## 2. Phase 2 基线

- [ ] 2.1 发布 phase 2 requirements / design / tasks 文档
- [ ] 2.2 在 `framework/docs/README.md` 中加入 phase 2 阅读入口
- [ ] 2.3 在 implementation guide 中补 phase 2 的边界约束摘要

## 2A. 阶段拆分说明

建议将 phase 2 明确拆成：

- `Phase 2A`
  - workflow hardening
  - `stdio_surface`
- `Phase 2B`
  - `agentkit`
  - `zig-opencode` 第二批接入
- `Phase 2C`
  - `servicekit`
  - `ourclaw` 第二批接入

后续若继续拆更细任务，应优先按这三个子阶段展开。

## 3. Workflow Hardening

- [x] 3.1 为 `src/workflow/step_types.zig` 增加 `branch` step
- [x] 3.2 为 `src/workflow/step_types.zig` 增加 `parallel` step
- [x] 3.3 为 `src/workflow/step_types.zig` 增加 `wait_event` step
- [x] 3.4 为 `src/workflow/step_types.zig` 增加 `ask_permission` step
- [x] 3.5 为 `src/workflow/step_types.zig` 增加 `ask_question` step
- [ ] 3.6 新建 `src/workflow/checkpoint_store.zig`
- [ ] 3.7 扩展 `src/workflow/state.zig`，记录 run id / step status / waiting reason / terminal result
- [ ] 3.8 扩展 `src/workflow/runner.zig`，支持 checkpoint 保存
- [ ] 3.9 扩展 `src/workflow/runner.zig`，支持 resume from checkpoint
- [x] 3.10 为 workflow hardening 补齐测试：branch / parallel / wait_event / checkpoint / resume

## 4. Workflow 示例与验证

- [ ] 4.1 新增一个多 step workflow 示例，覆盖 `command + retry + branch`
- [ ] 4.2 新增一个 checkpoint/resume 示例
- [ ] 4.3 新增一个 human-in-the-loop 示例，覆盖 `ask_permission` 或 `ask_question`
- [ ] 4.4 为这些示例补 README 说明

## 5. Tooling Adapter Expansion

- [ ] 5.1 在 `src/tooling/adapters/` 新建 `stdio_surface.zig`
- [ ] 5.2 定义 stdio request / response contract
- [ ] 5.3 支持通过 stdio 执行 native tool
- [ ] 5.4 支持通过 stdio 执行 script-backed tool
- [ ] 5.5 支持通过 stdio 执行 workflow-backed tool
- [ ] 5.6 为 `stdio_surface` 补齐测试：success / invalid request / invalid output / timeout
- [ ] 5.7 视实施情况评估是否补 `http_surface.zig` 最小版本

## 6. Tool Packaging And Templates

- [ ] 6.1 设计并实现最小 tool manifest 结构
- [ ] 6.2 为 native tool 提供模板示例
- [ ] 6.3 为 script-backed tool 提供模板示例
- [ ] 6.4 为 workflow-backed tool 提供模板示例
- [ ] 6.5 在 examples 和 docs 中说明“从模板到运行”的最小路径

## 7. AgentKit 最小可用层

- [ ] 7.1 明确 `agentkit` 的公开 root 导出面
- [ ] 7.2 提炼 provider/model/health/catalog 的共用契约到 `agentkit`
- [ ] 7.3 增加 provider readiness / selection helper
- [ ] 7.4 增加 agent-oriented execution metadata 契约
- [ ] 7.5 为 `agentkit` 补一组不依赖 `zig-opencode` 产品语义的测试
- [ ] 7.6 写一份 `agentkit` 边界文档，明确它不包含 session/prompt/chat 主链

## 8. ServiceKit 最小可用层

- [ ] 8.1 明确 `servicekit` 的公开 root 导出面
- [ ] 8.2 提炼 runtime host substrate 到 `servicekit`
- [ ] 8.3 提炼 heartbeat / cron helper 到 `servicekit`
- [ ] 8.4 提炼 generic service lifecycle facade 到 `servicekit`
- [ ] 8.5 为 `servicekit` 补一组不依赖 `ourclaw` 产品主链的测试
- [ ] 8.6 写一份 `servicekit` 边界文档，明确它不包含 channel/gateway/pairing 产品主链

## 9. Consumer Integration 第二批切片

- [ ] 9.1 为 `zig-opencode` 选择一个 workflow-backed deterministic slice 作为 phase 2 消费验证
- [ ] 9.2 在 `zig-opencode` 中接入 phase 2 workflow 能力
- [ ] 9.3 为 `zig-opencode` 的新接入补 smoke test
- [ ] 9.4 为 `ourclaw` 选择一个 servicekit/workflow-backed slice 作为 phase 2 消费验证
- [ ] 9.5 在 `ourclaw` 中接入 phase 2 servicekit/workflow 能力
- [ ] 9.6 为 `ourclaw` 的新接入补 smoke test

## 10. Docs And Examples Hardening

- [ ] 10.1 为 workflow hardening 新增 architecture 文档
- [ ] 10.2 为 `stdio_surface` 新增单独文档
- [ ] 10.3 为 `agentkit` 新增单独文档
- [ ] 10.4 为 `servicekit` 新增单独文档
- [ ] 10.5 更新 README 阅读顺序，让 phase 1 和 phase 2 文档链清晰分层

## 11. Final Verification

- [ ] 11.1 运行 framework 全量 `zig build test`
- [ ] 11.2 运行至少一个 workflow checkpoint/resume 场景
- [ ] 11.3 运行至少一个 stdio adapter 场景
- [ ] 11.4 完成 `zig-opencode` phase 2 消费验证
- [ ] 11.5 完成 `ourclaw` phase 2 消费验证
- [ ] 11.6 回填 phase 2 任务状态和边界结论文档
