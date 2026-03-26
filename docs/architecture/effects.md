# framework effects 模块设计

## 1. 目标

`effects` 模块负责抽象对外部世界的访问，使上层 `tooling`、`workflow`、future kits 不必直接散落依赖 stdlib 或平台命令。

当前已落最小能力包括：

- process runner
- filesystem
- env provider
- clock
- http client
- effects runtime 组合层

## 2. 模块职责

`effects` 负责：

- 统一能力接口
- 统一 request/result 形态
- 更容易 mock 的测试入口
- future 权限与审计的基础

## 3. 当前组成

- `types.zig`
- `process_runner.zig`
- `fs.zig`
- `env_provider.zig`
- `clock.zig`
- `http_client.zig`
- `runtime.zig`

## 4. 设计意图

这层并不是通用 util 集，而是 platform substrate：

- tool 可以直接消费
- workflow 可以直接消费
- 未来 app-specific runtime 也可以选择性消费

## 5. 当前限制

当前仍是最小版：

- `http_client` 的 native timeout 语义仍可继续增强
- 还没有 secret provider / temp workspace
- 还没有统一权限模型

## 6. 后续方向

建议后续继续补：

- secret provider
- temp workspace
- 更稳定的 http timeout 语义
- 与 policy / audit 的接线
