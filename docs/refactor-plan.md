# zig-framework 拆分规划

## 现状

11 个模块，10544 行代码，全部在一个仓库里。

```
core/           6034 行  ← 包含 logging（已独立为 zig-logging）和 validation
config/         1962 行
tooling/        1925 行
runtime/        1782 行
effects/        1346 行
observability/  1239 行
app/            1129 行
workflow/        510 行
contracts/       193 行
agentkit/        152 行
servicekit/       20 行  ← 空壳
```

## 问题

### 1. core/logging 和 zig-logging 重复

`core/logging/` 有 11 个文件（sink、logger、console_sink、file_sink 等），和已经独立发布的 `zig-logging` 仓库完全重复。两份代码，两个地方维护，迟早会分叉。

### 2. 巨型 root.zig

root.zig 有 219 行，全是 `pub const Xxx = module.Xxx` 的平铺导出。每加一个类型就要在这里加一行。容易遗漏，也让使用方不知道类型属于哪个模块。

### 3. 模块间耦合

依赖关系分析：

```
core（logging + validation + error）
  ↑
  ├── observability（依赖 core/logging）
  ├── config（依赖 observability）
  ├── app（依赖 core/logging、observability、runtime）
  ├── runtime（依赖 observability）
  ├── effects（独立，无跨模块依赖）
  ├── tooling（依赖 core、effects、runtime）
  ├── workflow（依赖 core、effects、runtime）
  ├── contracts（独立）
  ├── agentkit（独立）
  └── servicekit（空壳）
```

`tooling` 是耦合最重的模块——同时依赖 core、effects、runtime。如果要拆，它是最难拆的。

### 4. effects 是天然独立的

`effects/` 包含 ProcessRunner、FileSystem、EnvProvider、Clock、HttpClient——全是外部副作用的 vtable 接口 + 原生实现。它不依赖框架内任何其他模块。这和 zig-logging 一样，是天然可以独立发布的组件。

## 拆分方案

### 阶段一：去重（最小改动，最大收益）

**把 core/logging 替换为 zig-logging 依赖。**

- 删除 `src/core/logging/` 整个目录（11 个文件，约 2000 行）
- 在 `build.zig.zon` 中添加 `zig-logging` 依赖
- `core/root.zig` 改为 re-export zig-logging 的类型
- root.zig 的 logging 相关导出不变（保持 API 兼容）

收益：去掉 2000 行重复代码，logging 只维护一份。
风险：低。只是换了 import 来源，对外 API 不变。

### 阶段二：拆出 effects 为独立库

**创建 `zig-effects` 仓库。**

```
zig-effects/
├── src/
│   ├── core/
│   │   ├── types.zig          ← EffectRequestContext, EffectStatus 等
│   │   ├── process_runner.zig ← ProcessRunner vtable 接口
│   │   ├── fs.zig             ← FileSystem vtable 接口
│   │   ├── env_provider.zig   ← EnvProvider vtable 接口
│   │   ├── clock.zig          ← Clock vtable 接口
│   │   └── http_client.zig    ← HttpClient vtable 接口
│   ├── infra/
│   │   ├── native_process.zig ← NativeProcessRunner
│   │   ├── native_fs.zig      ← NativeFileSystem
│   │   ├── native_env.zig     ← NativeEnvProvider
│   │   ├── native_clock.zig   ← NativeClock
│   │   └── native_http.zig    ← NativeHttpClient
│   ├── runtime.zig            ← EffectsRuntime（组合所有接口）
│   └── root.zig
```

和 zig-logging 一样的模式：core/ 放接口，infra/ 放实现。

收益：
- effects 可以被其他项目独立使用（不需要整个 framework）
- lnk-v2 的 Fs/Vcs 接口可以直接用 zig-effects 的 FileSystem/ProcessRunner
- 可测试性提升（mock 接口）

### 阶段三：拆出 observability 为独立库

**创建 `zig-observability` 仓库。**

依赖 zig-logging。包含 Observer vtable、MultiObserver、LogObserver、FileObserver、MetricsObserver、TraceScope、RequestTrace、StepTrace、MethodTrace、SummaryTrace。

这个模块依赖 core/logging，拆出后改为依赖 zig-logging。

### 阶段四：精简 framework

拆完后 framework 变成：

```
framework/
├── src/
│   ├── core/
│   │   ├── error.zig          ← AppError（保留）
│   │   ├── validation/        ← 校验系统（保留）
│   │   └── root.zig           ← re-export zig-logging
│   ├── contracts/             ← Envelope, CapabilityManifest（保留）
│   ├── config/                ← 配置系统（保留）
│   ├── app/                   ← 命令分发（保留）
│   ├── runtime/               ← AppContext, EventBus, TaskRunner（保留）
│   ├── tooling/               ← 工具系统（保留）
│   ├── workflow/              ← 工作流（保留）
│   ├── agentkit/              ← Provider 注册（保留）
│   └── servicekit/            ← 删除（空壳）
├── build.zig.zon              ← 依赖 zig-logging, zig-effects, zig-observability
```

framework 从"什么都有"变成"只有框架层"，基础组件通过依赖引入。

### 阶段五：精简 root.zig

把 219 行的平铺导出改为命名空间导出：

```zig
// 之前：219 行平铺
pub const LogLevel = core.logging.LogLevel;
pub const LogField = core.logging.LogField;
// ... 200+ 行

// 之后：命名空间
pub const logging = @import("zig-logging");
pub const effects = @import("zig-effects");
pub const observability = @import("zig-observability");
pub const core = @import("core/root.zig");
pub const config = @import("config/root.zig");
// ...
```

使用方从 `framework.LogLevel` 变成 `framework.logging.LogLevel`。Breaking change，但更清晰。

## 优先级

| 阶段 | 改动量 | 收益 | 风险 | 建议 |
|------|--------|------|------|------|
| 一：去重 logging | 小 | 高（去 2000 行重复） | 低 | **立即做** |
| 二：拆 effects | 中 | 高（独立可复用） | 低 | 第二步 |
| 三：拆 observability | 中 | 中 | 中（依赖链调整） | 第三步 |
| 四：精简 framework | 小 | 中（删空壳） | 低 | 随时 |
| 五：精简 root.zig | 小 | 高（可维护性） | 中（breaking change） | 和阶段四一起 |

## 不拆的

- **config/** — 和 framework 的 validation、pipeline 深度耦合，拆出来意义不大
- **app/** — 命令分发是框架核心，不该独立
- **runtime/** — AppContext、EventBus、TaskRunner 是框架骨架
- **tooling/** — 依赖太多（core + effects + runtime），拆出来反而更复杂
- **workflow/** — 依赖 runtime + effects，且只有 510 行，不值得单独建仓库

## 拆完后的依赖图

```
zig-logging（独立库，已发布）
     ↑
zig-effects（独立库，待创建）
     ↑
zig-observability（独立库，待创建，依赖 zig-logging）
     ↑
framework（框架层，依赖以上三个）
     ↑
ourclaw / 其他应用（依赖 framework）
```

每一层只依赖下面的层，不反向依赖。
