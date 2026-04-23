# framework servicekit runtime host / channel 提取说明

## 1. 目标

本文档记录为什么 `servicekit` 当前阶段只做占位与边界整理，而不直接把完整 channel runtime 或 gateway/service 逻辑下沉到 `framework`。

## 2. 来自 ourclaw 的启发

`ourclaw` 当前已经暴露出 service-oriented runtime 的几个核心角色：

- runtime host
- gateway host
- service manager
- daemon
- heartbeat / cron

这说明 future `servicekit` 很可能会围绕：

- 生命周期
- host 组合
- service-facing orchestration

形成一层中间 kit。

## 3. 来自 nullclaw 的启发

`nullclaw` 在 channel 方向最值得借鉴的，不是直接搬平台接入，而是这些模式：

- `Channel` interface
- `ChannelRegistry`
- dispatch / outbound loop
- supervisor / restart
- health report

这些模式适合后续抽象进 `servicekit`，但当前不应直接进入 kernel。

## 4. 当前边界

当前阶段：

- 允许在 `servicekit` 中预留模块位置
- 允许记录抽象输入
- 允许写说明文档

当前阶段不应：

- 实现完整 channel runtime
- 实现完整 gateway / daemon 产品逻辑
- 把平台接入细节直接搬到 `framework`

## 5. 下一步建议

待：

- `tooling`
- `workflow`
- `service bundle`

进一步稳定后，再继续推进：

- runtime host 抽象
- channel interface / registry / supervisor
- servicekit 组合入口
