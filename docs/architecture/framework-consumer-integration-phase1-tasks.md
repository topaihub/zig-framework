# framework 消费者接入阶段一任务清单

## 1. 使用说明

本文档是下一阶段的执行清单，基于：

- [`framework-consumer-integration-phase1-requirements.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/framework-consumer-integration-phase1-requirements.md)
- [`framework-consumer-integration-phase1-design.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/framework-consumer-integration-phase1-design.md)

目标是：

- 用最小真实接入验证 `framework` 的 substrate 能力
- 不把 phase 1 扩大成全面迁移

## 2. zig-opencode 接入

- [x] 2.1 为 `zig-opencode` 选定一个 framework-backed deterministic tool 作为 phase 1 切片
- [x] 2.2 优先评估 `repo.health_check` 是否适合作为该切片
- [x] 2.3 在 `zig-opencode` 中新增最小 framework 接入层
- [x] 2.4 在接入层中装配或访问 `framework.ToolingRuntime`
- [x] 2.5 把所选 framework tool 适配为 `zig-opencode` builtin tool
- [x] 2.6 为该接入补最小测试或 smoke 验证
- [x] 2.7 记录这次接入中哪些能力仍不应下沉到 `framework`

## 3. ourclaw 接入

- [x] 3.1 为 `ourclaw` 选定一个 deterministic command/tool slice 作为 phase 1 切片
- [x] 3.2 优先评估 diagnostics / repo health / maintenance preview 类切片
- [x] 3.3 在 `ourclaw` 中新增最小 framework 接入层或桥接层
- [x] 3.4 在 `CommandServices` 或邻近层中接入 `framework.ToolingRuntime`
- [x] 3.5 让目标 command/tool slice 通过 service facade 调用 framework substrate
- [x] 3.6 为该接入补最小测试或 smoke 验证
- [x] 3.7 记录这次接入中哪些能力仍应留在 `ourclaw`

## 4. framework 侧最小补洞

- [x] 4.1 若消费者接入暴露真实 blocker，仅补最小必要增强
- [x] 4.2 补洞时记录其属于 kernel、shared substrate、future kit、还是 app-only concern
- [x] 4.3 避免顺手扩大战场到 provider/channel/session/gateway 主链路

## 5. 文档与回填

- [x] 5.1 为 `zig-opencode` 的实际消费方式补文档
- [x] 5.2 为 `ourclaw` 的实际消费方式补文档
- [x] 5.3 更新 `consumer-validation-notes.md`
- [x] 5.4 记录接入后的边界校正结论

## 6. 完成判定

- [x] 6.1 `zig-opencode` 真实接入已完成
- [x] 6.2 `ourclaw` 真实接入已完成
- [x] 6.3 两个接入点都有可执行验证
- [x] 6.4 framework 未因本轮接入而错误产品化
