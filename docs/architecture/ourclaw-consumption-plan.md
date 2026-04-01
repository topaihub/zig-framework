# framework 对 ourclaw 的消费计划

## 1. 目标

本文档用于说明 `ourclaw` 未来如何消费 `framework` 当前已经落地的：

- `effects`
- `tooling`
- `workflow`
- `business services pattern`

并明确哪些能力适合继续下沉到 `framework`，哪些应保留在 `ourclaw`。

## 2. 当前判断

`ourclaw` 当前最适合消费 `framework` 的方向包括：

- `tooling`
- `workflow`
- `business services pattern`

它当前不适合立即交给 `framework` 的方向包括：

- gateway host
- service manager / daemon
- channel runtime
- 配对与长期运行控制面

这些更接近 future `servicekit`，但现在还不适合一口气下沉。

## 3. 推荐第一批接入点

### 3.1 tool registry / tool runner

`ourclaw` 的最小工具面很适合逐步迁移到 `framework/tooling` 模型，尤其是 deterministic 工具和 script-backed helper。

### 3.2 command services

`ourclaw` 当前的 `CommandServices` 已经在提示一种标准模式。  
后续可逐步让它参考 `framework/docs/architecture/business-services-pattern.md` 的方式，继续收敛为更稳定的 service facade。

### 3.3 workflow

对于：

- diagnostics pipeline
- remediate / preview / apply
- runtime maintenance

这类 deterministic orchestration，后续适合尝试消费 `framework/workflow`，而不是在 `ourclaw` 内继续散落实现。

## 4. 最小真实场景建议

推荐一个最小真实验证场景：

> 选择 `ourclaw` 中一个 deterministic command 流程（例如 diagnostics 或 config side-effect 相关路径），尝试以 `framework/workflow` 或 `framework/tooling` 的方式重写最小 slice。

这个场景能验证：

- `framework` 的中层 substrate 是否真的足够
- `ourclaw` 是否能减少自己重复的 runtime glue

## 5. 当前边界结论

一句话总结：

> `ourclaw` 适合优先把 deterministic tooling、workflow 和 service facade 模式继续交给 `framework`，但 gateway / daemon / channel 等 service runtime 产品能力仍应暂时保留在 `ourclaw`。

## 6. Phase 1 已实现切片

当前已经完成一个最小真实接入：

- 在 `ourclaw/src/framework_integration/*` 中新增薄桥接层
- 在 `CommandServices` 中暴露 framework tooling bridge
- 新增 `diagnostics.repo_health` 命令，通过 service facade 调用 `framework.RepoHealthCheckTool`

这次接入验证了：

- `BusinessServices` / `CommandServices` 确实适合作为 framework substrate 的消费面
- `ourclaw` 可以通过薄桥接层消费 `framework.ToolingRuntime`
- 接入不需要改 gateway / daemon / channel 主链路

这次接入没有做的事：

- 不把 service manager、runtime host、pairing、channel runtime 下沉到 `framework`
- 不把 `ourclaw` 原有 command surface 大规模迁移成 framework commands
