# framework 对 zig-opencode 与 ourclaw 的消费验证说明

## 1. 目标

本文档记录当前阶段对 `framework` 新 substrate 的消费验证结论。

这里的“验证”目前仍以：

- 消费计划
- 最小场景选择
- 边界判断

为主，而不是强行要求立刻改动 `zig-opencode` 或 `ourclaw` 主线代码。

## 2. 当前结论

### 2.1 zig-opencode

当前最适合先消费：

- `framework/effects`
- `framework/tooling`
- `framework/workflow`

最适合的最小场景：

- deterministic builtin tool
- script-backed helper
- repo / workspace health 风格工具

### 2.2 ourclaw

当前最适合先消费：

- `framework/tooling`
- `framework/workflow`
- `framework` 的 business services pattern

最适合的最小场景：

- deterministic command pipeline
- diagnostics / preview / apply
- config side-effect 相关的结构化流程

## 3. 不应错误下沉的能力

当前最容易看似通用、但实际上仍应留在 app 层的能力包括：

- `zig-opencode` 的 session / prompt / provider 主链路
- `ourclaw` 的 gateway / daemon / channel / pairing 主链路
- 任何高度产品化、强运行态语义的整块模块

## 4. 当前阶段的意义

当前这组消费验证文档的意义是：

- 先把正确的接入方向说清楚
- 避免后续大模型把“看起来能下沉”的产品能力错误地下沉到 `framework`

这比一开始就大改两个消费方主仓更稳。
