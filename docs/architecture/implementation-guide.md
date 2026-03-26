# framework vNext 实施指南

## 1. 目标

本文档用于指导 `framework` vNext 的具体实施方式，重点说明：

- 新增模块之间如何依赖
- 什么时候应写代码，什么时候应先补文档
- 什么时候应该下沉到 `framework`，什么时候应留在 app 层

它是 [`implementation-guardrails.md`](E:/vscode/fuckcode-dev/framework/docs/architecture/implementation-guardrails.md) 的操作化版本。

## 2. 推荐实施顺序

建议遵循：

1. requirements
2. design
3. executable tasks
4. scaffold
5. implementation
6. tests
7. examples
8. docs sync

不要反过来。

## 3. 模块依赖建议

当前 vNext 模块建议遵循以下依赖方向：

- `effects` 只依赖 kernel
- `tooling` 依赖 `effects` + kernel
- `workflow` 依赖 `effects` + `app` + kernel
- `agentkit` 只先吸收 provider substrate，不吸 session/chat runtime
- `servicekit` 只先保留边界，不吸完整 channel/service 产品逻辑

## 4. 什么时候应该停下来补设计

以下情况不应直接继续写代码：

- 发现能力边界不清
- 一个模块开始吸收完整产品语义
- 一个看似通用的能力其实只服务一个 app
- 一个新功能需要突破已有顶层目录边界

这时应先回到：

- requirements
- design
- extraction strategy

## 5. examples 的角色

`framework/examples` 的角色是：

- 提供最小可运行模板
- 验证 substrate 是否真的可消费

它不是产品 demo 仓库。

## 6. 最终建议

如果只保留一句话：

> `framework` vNext 的实施应以“稳定共享 substrate”为核心，而不是以“尽快长成完整产品”为目标。
