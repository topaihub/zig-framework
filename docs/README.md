# framework docs

## 角色

`framework/docs/` 负责解释 **共享 Zig 底座能力**，而不是 claw 业务本身。

如果一个能力满足下面任一条件，就优先归到这里：

- 不依赖 claw 业务语义
- `ourclaw` 与 `ourclaw-manager` 都可能复用
- 更适合作为统一底座，而不是业务层专题

## 当前重点能力

- `framework/docs/architecture/logging.md`
- `framework/docs/architecture/logging-tracing-design.md`
- `framework/docs/architecture/logging-usage-guide.md`
- `framework/docs/architecture/validation.md`
- `framework/docs/architecture/runtime-pipeline.md`
- `framework/docs/architecture/agent-tooling-runtime-direction.md`
- `framework/docs/architecture/agent-tooling-runtime-vnext-module-design.md`
- `framework/docs/architecture/agent-tooling-runtime-phase1-roadmap.md`
- `framework/docs/development/win11-dev-workstation.md`
- `framework/docs/development/win11-scoop-zig-env.md`
- `framework/docs/development/vscode-zed-zls-setup.md`
- `framework/docs/development/win11-oh-my-opencode-dependencies.md`

## 与 ourclaw docs 的关系

- `framework/docs/`：解释底座能力本身
- `ourclaw/docs/architecture/`：解释 `ourclaw` 如何消费这些底座能力

## 目录说明

- `architecture/`
  - 长期有效的底座设计文档
- `development/`
  - 开发环境与工具使用说明
- `examples/`
  - 最小可运行示例，适合验证底座能力和日志效果
- `wechat-series/`
  - 公众号/内容稿件素材，不作为技术主入口

## 默认阅读方式

如果你想知道“框架到底提供了什么能力”，先读这里；
如果你想知道“ourclaw 怎样使用这些能力”，再读 `ourclaw/docs/architecture/`。
