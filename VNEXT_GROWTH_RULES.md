# framework vNext 目录增长规则

本文件用于约束 `framework` vNext 期间的目录增长方式，避免在快速迭代中让源码结构失控。

## 允许的 `src/` 顶层目录

当前允许的顶层目录只有：

- `app/`
- `config/`
- `contracts/`
- `core/`
- `observability/`
- `runtime/`
- `effects/`
- `tooling/`
- `workflow/`
- `agentkit/`
- `servicekit/`

除上述目录外，不应新增新的 `src/<name>/` 顶层目录。

## 新模块增长规则

1. 新顶层模块必须先有 `root.zig`
2. 新顶层模块必须在 `src/root.zig` 中预留或导出
3. 新顶层模块必须同时补至少一个 smoke test
4. 新顶层模块若承载中层平台能力，必须同步补 `docs/architecture/` 文档

## 当前阶段禁止直接下沉的产品能力

当前阶段不应直接把以下完整产品逻辑下沉到 `framework`：

- 完整 provider chat runtime
- 完整 channel runtime
- session timeline
- prompt assembly
- model/category routing
- gateway/daemon/service 产品逻辑
- UI / TUI 产品交互逻辑

## 当前阶段优先级

当前阶段优先推进：

1. `effects`
2. `tooling`
3. `workflow` 最小层
4. `agentkit` / `servicekit` 预备层

一句话：

> 先稳定增长 shared substrate，不要让 `framework` 在目录层面提前变成产品总仓。
