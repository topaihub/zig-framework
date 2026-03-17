# framework 日志升级方案：对齐 Rust `tracing` 风格输出

## 1. 文档目的

这份文档不是泛泛讨论“日志应该怎么做”，而是针对一个非常具体的目标：

> 让 `framework` 的日志体系逐步达到你展示的 Rust `tracing` / `tracing-subscriber` 风格体验。

这个目标包括：

- 启动阶段日志像产品一样表达清楚步骤
- 每个请求都有一致的 `trace_id`
- 请求开始/结束自动记录
- 请求日志自动带 `method / path / query / status / duration`
- 存在方法级/步骤级 trace 日志
- 控制台输出更像 Rust `tracing_subscriber::fmt` 的默认风格

同时，这份文档要满足你明确提出的要求：

- **不能只靠现象推测**
- 必须**认真阅读 Rust 日志模块的设计与实现**
- 必须把**需求、设计、tasks** 写在**单独一个文件**里，方便你直接查看和后续驱动实现

---

## 2. 已阅读的参考实现

这次分析不是只根据你贴出来的日志样式判断，而是直接读了 `rust-base-framework` 的关键实现链条。

### 2.1 Rust 入口层

文件：

- `rust-base-framework/crates/bf-api/src/main.rs`

这里确认了三件关键事实：

1. 日志系统在 `main()` 一开始就初始化
2. 通过 `tracing_subscriber::registry().with(...).with(fmt::layer()).init()` 完成全局接线
3. 启动阶段日志本身就是产品体验的一部分，而不是调试残留

典型语义：

- `Starting BF API`
- `Loading configuration...`
- `DI container created`
- `Server listening`
- `Health check / Swagger UI / OpenAPI JSON` 链接输出

这说明 Rust 侧的设计意图不是“只做请求日志”，而是：

> 从应用启动开始，就把日志作为产品控制面的一部分来组织。

### 2.2 Rust 请求级 Trace 层

文件：

- `rust-base-framework/crates/bf-api/src/middleware/trace.rs`

这里的设计意图非常明确：

1. 从请求头提取或生成 `trace_id`
2. 把 `trace_id` 注入 request extensions
3. 创建 request span，字段包括：
   - `trace_id`
   - `method`
   - `path`
   - `query`
4. 自动打：
   - `Request started`
   - `Request completed`
5. 自动记录：
   - `status`
   - `duration_ms`
6. 响应头回写 `X-Trace-Id`

这说明它的核心意图是：

> 请求生命周期日志不应该由 handler 自己记，而应该由统一 middleware 自动生成并贯穿。

### 2.3 Rust 方法级 Trace 层

文件：

- `rust-base-framework/crates/bf-api/src/middleware/auto_trace.rs`
- `rust-base-framework/crates/bf-infrastructure/src/utils/trace_logger.rs`

这里又补了一层和 request middleware 不同的能力：

- handler/service/repository 的方法级 trace
- 性能阈值检查
- 异常类型分类
- `TraceId | Method | Runtime | BeyondThreshold | ExceptionType` 这种更偏运维/排障的日志格式

设计意图不是让业务层 everywhere 手写 begin/end，而是：

- middleware 负责 request 生命周期
- `TraceLogger` 负责方法级性能追踪
- 二者互补，不重复

### 2.4 Rust 日志配置层

文件：

- `rust-base-framework/crates/bf-api/src/config.rs`

这里确认 Rust 侧已经把这些做成配置项：

- `level`
- `format`
- `file_path`

也就是说，它不是只在代码里决定日志长什么样，而是已经开始向“可配置日志产品”推进。

---

## 3. framework 当前日志现状

### 3.1 已有能力

`framework` 现在已经有一套**正确的底层主干**，不是从零开始。

关键文件：

- `framework/src/core/logging/logger.zig`
- `framework/src/core/logging/record.zig`
- `framework/src/core/logging/console_sink.zig`
- `framework/src/core/logging/file_sink.zig`
- `framework/src/core/logging/memory_sink.zig`
- `framework/src/core/logging/multi_sink.zig`
- `framework/src/core/logging/redact.zig`

当前已具备：

1. `Logger -> LogRecord -> Sink` 主干
2. 结构化日志记录模型
3. `trace_id / span_id / request_id` 注入能力
4. `child()` 子系统路径
5. `pretty / compact / json` 三种 console style
6. file sink / memory sink / multi sink
7. 敏感信息脱敏

### 3.2 当前真实限制

它虽然已经有了“日志引擎”，但离 Rust `tracing` 那种体验还有明显差距：

1. **默认运行态装配不足**
   - 当前更偏 memory sink
   - 不是一启动就天然得到漂亮的 console/file 日志

2. **pretty 格式过于原始**
   - 现在是：`ts_unix_ms | level | subsystem | message`
   - 不是：`ISO8601 + LEVEL + target + message`

3. **没有 request trace middleware**
   - 虽然 logger 能接受 `trace_id`
   - 但没有统一层自动创建 request span，并自动打 started/completed

4. **没有方法级 TraceLogger / 阈值日志层**
   - Rust 那个 `TraceLogger` 的角色，在 `framework` 里还没有对应实现

5. **字段渲染不够像 tracing**
   - 当前 JSON 里 `fields` 是数组
   - 便于底层结构化，但不够适合人看，也不够像 tracing 常见消费方式

### 3.3 现状判断

一句话：

> `framework` 现在已经有 60%~70% 的底层能力，但还没有完成“日志产品化接线”。

所以问题不是“能不能做到”，而是：

- 现在还没做到
- 但路径非常清晰

---

## 4. 需求（Requirements）

### Requirement 1：统一日志主干继续保留

系统必须继续保留当前 `Logger -> LogRecord -> Sink` 主干，不允许为追求 Rust 风格而推翻现有结构。

### Requirement 2：控制台输出必须达到更接近 Rust `tracing` 的体验

至少需要：

- ISO8601 时间戳
- 明确的 `level`
- 明确的 `target/subsystem`
- 可读的字段输出

### Requirement 3：请求生命周期必须自动记录

HTTP / bridge / CLI 等入口都应逐步具备：

- `Request started`
- `Request completed`
- `trace_id`
- `duration_ms`
- `status`
- `method/path/query`

### Requirement 4：方法级性能追踪必须存在

系统应提供类似 `TraceLogger` 的 Zig 版本，用于：

- 方法执行时间
- 阈值判断
- 异常类型记录

### Requirement 5：日志配置必须可产品化

日志级别、格式、输出策略不能只存在代码里，应能逐步纳入 `config`。

### Requirement 6：升级必须优先服务当前主线系统

日志升级应优先服务：

- `ourclaw` 的 CLI / HTTP / bridge / control-plane
- 不能只做一套漂亮但没人接线的 logger

---

## 5. 设计（Design）

## 5.1 总体设计原则

### 原则 1：不重写，只增强

当前 `framework` 的日志底座是对的，不需要重写。

要做的是：

- 升级 formatter
- 增加 middleware / helper
- 改善默认装配
- 让 `ourclaw` 真正接起来

### 原则 2：把“日志能力”和“日志接线”分层

这次升级必须分成三层：

1. **Log Core**
2. **Request Trace Layer**
3. **Method Trace Layer**

### 原则 3：先做体验闭环，再做遥测生态

本轮目标不是 OpenTelemetry 平台，而是：

- 本地开发看得清
- 服务运行看得清
- 请求与方法链路能追

---

## 5.2 分层设计

### 层 A：Log Core（继续在 `framework/src/core/logging/*`）

本层继续保留当前结构，只做增强：

- 时间戳格式升级
- pretty 格式升级
- 字段渲染优化
- file/console 默认装配能力增强

### 层 B：Request Trace Layer（新增）

本层负责：

- 生成/提取 `trace_id`
- 创建 request 生命周期上下文
- 自动记录：
  - started
  - completed
  - duration

优先接入：

- HTTP adapter
- bridge adapter
- CLI adapter

### 层 C：Method Trace Layer（新增）

本层对应 Rust `TraceLogger` 的角色，但不要求一模一样。

它负责：

- 单步骤耗时
- 阈值判断
- 异常类型
- 结构化性能字段

优先接入：

- `config_runtime_hooks`
- provider request
- onboarding / doctor / remediation
- node/device 控制面

---

## 5.3 关键设计点

### 设计点 A：Pretty 输出要先像 Rust

建议目标输出形态：

```text
2026-03-17T05:46:35.654Z INFO config/write: config field updated path="gateway.port" requires_restart=true
```

比现在多出来的关键点：

- ISO8601 时间
- `LEVEL` 位置固定
- subsystem 更像 target
- 字段平铺展示

### 设计点 B：请求日志自动生成

不要让每个 handler 手工写：

- `Request started`
- `Request completed`

应该统一在适配层生成。

### 设计点 C：步骤级 trace helper

需要一个 Zig 版本的 step trace helper，用于：

- `start`
- `finish`
- `duration_ms`
- `threshold`
- `exception_type`

### 设计点 D：默认装配要能直接跑出效果

如果 logger 再强，但默认不接到 console/file，用户依然感知不到。

所以必须把：

- 开发态 console
- 可选 file sink
- `logging.level/format` 配置

真正接起来。

---

## 6. 任务（Tasks）

### Task 1：升级 `ConsoleSink.pretty` 输出格式

目标：

- 时间戳从毫秒整数升级为 ISO8601
- `pretty` 更接近 Rust `tracing` 风格

涉及文件：

- `framework/src/core/logging/console_sink.zig`
- `framework/src/core/logging/record.zig`

### Task 2：补 request trace middleware/helper

目标：

- 自动创建 request trace
- started/completed 自动日志
- 自动带 `trace_id / duration_ms`

优先接入：

- `ourclaw/src/interfaces/http_adapter.zig`
- `ourclaw/src/interfaces/bridge_adapter.zig`
- `ourclaw/src/interfaces/cli_adapter.zig`

### Task 3：补步骤级 trace helper

目标：

- 做 Zig 版 `TraceLogger` / step trace helper

优先落点：

- `framework/src/observability/*`
- `ourclaw/src/runtime/config_runtime_hooks.zig`
- `ourclaw/src/commands/*`

### Task 4：补默认 logger 装配

目标：

- 开发态默认接 console pretty
- 支持 file/json fan-out
- 让 `logging.level/format` 真正生效

### Task 5：接通 ourclaw 关键入口

目标：

- 把 HTTP / bridge / CLI / control-plane 命令统一接上新日志能力

优先接入：

- `status.all`
- `onboard.*`
- `diagnostics.*`
- `gateway.remote.*`
- `device.*`
- `node.*`

### Task 6：补文档与 contract 说明

目标：

- 让新增日志格式和语义不只停留在代码里

更新：

- `framework/docs/architecture/logging.md`
- `ourclaw/docs/contracts/log-record.md`

---

## 7. 一句话结论

`framework` 现在**已经具备日志主干**，但还没有到你贴的 Rust `tracing` 那种成熟体验。

不是做不到，而是还差：

1. formatter 升级
2. request middleware
3. 方法级 trace helper
4. 默认装配与主线接线

也就是说：

> 这不是“重写日志系统”的问题，而是“把已有日志主干真正接成产品级体验”的问题。

---

## 8. 下一阶段增强（新增）

这一节对应你刚才明确点名的三项后续目标：

1. request span 文本渲染
2. `TraceLogger` 风格的方法级告警输出
3. `logging.format` 真正接 runtime config 生效

这三项在前一版文档中还没有被明确写成单独需求/设计/tasks，这里补齐。

### 8.1 新增需求

#### Requirement 7：请求日志应具备可读的 span 风格渲染

系统必须支持比当前 `trace=... request=...` 更接近 Rust `tracing` 的请求上下文展示方式，例如：

- `request{trace_id=... method=GET path=/health query=None}: ...`

要求：

- 至少在 `pretty` 输出模式支持 span 风格渲染
- started/completed 两条请求日志应共享同一 span 上下文
- 不得破坏现有 JSON/compact 模式

#### Requirement 8：方法级 trace 必须支持阈值告警风格输出

系统必须支持一种比当前 `Step completed` 更适合运维/排障的输出方式，用于表达：

- 方法名
- `trace_id`
- `duration_ms`
- 是否超过阈值
- 异常类型/错误码

要求：

- 当前 `StepTrace` 可以继续保留
- 但需要新增一层更接近 Rust `TraceLogger` 语义的可选渲染或 helper
- 至少能在关键路径输出 `beyond_threshold` / `error_code` 风格日志

#### Requirement 9：日志格式必须真正受 runtime config 驱动

系统必须让 `logging.format` 不再只是文档约定或未来规划，而是真正影响：

- console style
- 是否输出 json
- 后续 file sink/pretty/compact 的切换

要求：

- config write 后能够影响运行中的 logger 装配
- 至少支持 `pretty / compact / json` 三种模式切换
- 不要求首轮就支持所有 sink 热切换，但格式切换必须生效

### 8.2 新增设计

#### 设计 A：Request Span Renderer

在 `ConsoleSink.pretty` 之上增加一层 span 风格渲染规则：

- 如果 `subsystem == "request"`
- 且存在 `trace_id/method/path` 字段
- 则优先渲染成 span-like 文本前缀，而不是简单字段平铺

建议目标样式：

```text
2026-03-17T05:46:42.611Z  INFO request{trace_id=04634c7997c84d19 method=GET path=/swagger-ui/ query=None}: Request started
2026-03-17T05:46:42.612Z  INFO request{trace_id=04634c7997c84d19 method=GET path=/swagger-ui/ query=None}: Request completed status=200 duration_ms=0
```

这不是完整 span tree，只是**更好的 pretty 呈现层**。

#### 设计 B：TraceLogger 风格方法追踪层

当前 `StepTrace` 适合表达通用步骤生命周期，但还不够像 Rust 的 `TraceLogger`。

下一阶段建议新增：

- `MethodTrace` 或 `TraceLoggerStyle`
- 专门面向：
  - handler
  - usecase/service
  - provider request
  - node invoke
  - config hook

建议字段：

- `trace_id`
- `method`
- `duration_ms`
- `threshold_ms`
- `beyond_threshold`
- `error_code` / `exception_type`

输出级别策略：

- 正常路径可 `info/debug`
- 超阈值或异常可 `warn`

#### 设计 C：Runtime-configured Logging Format

当前 `AppContext` 已支持默认装配，但 `logging.format` 还没有真的驱动 logger style。

下一阶段设计建议：

1. 在 `field_registry` 中将 `logging.format` 明确为 runtime 可生效字段
2. 在 `config_runtime_hooks` 中把 `logging.format` 解析到具体 `ConsoleStyle`
3. 让 console sink style 可在 runtime 下被更新

首轮目标：

- `pretty`
- `compact`
- `json`

### 8.3 新增任务

#### Task 7：实现 request span 文本渲染

目标：

- 在 `ConsoleSink.pretty` 中，为请求日志增加 span-like 前缀渲染

涉及文件：

- `framework/src/core/logging/console_sink.zig`
- `framework/src/core/logging/record.zig`

完成标准：

- request started/completed 的 pretty 输出不再只是字段平铺
- 至少能稳定渲染 `trace_id / method / path / query`

#### Task 8：实现 `TraceLogger` 风格的方法级告警输出

目标：

- 在 `framework/observability` 中补方法级 trace helper 或 `StepTrace` 的扩展渲染

优先接入：

- `config_runtime_hooks`
- `node.invoke`
- provider request

完成标准：

- 至少一个入口能输出 `beyond_threshold / error_code` 风格告警日志

#### Task 9：让 `logging.format` 真正影响 runtime logger style

目标：

- `config.set logging.format` 后，console style 真正切换

涉及文件：

- `framework/src/runtime/app_context.zig`
- `ourclaw/src/runtime/config_runtime_hooks.zig`
- `ourclaw/src/config/field_registry.zig`

完成标准：

- `logging.format=pretty/compact/json` 能影响运行中 logger 输出

---

## 9. 当前文档状态说明

截至现在：

- 原始 Task 1 ~ Task 6 已经开始实施并已推进多项
- 本节补的是你后来明确要求的“下一步增强项”
- 后续继续开发时，应优先按本节新增的 Task 7 ~ Task 9 往下做

---

## 10. 进一步增强：Trace Context Propagation（新增）

这一节对应一个在实际运行中已经暴露出来的关键缺口：

> 现在 request started/completed 日志已经有 `trace_id`，但下层 `StepTrace` 日志还不能自动继承同一个 `trace_id`，因此还不能像 Rust `tracing` 那样一眼看出“这个方法日志属于哪个请求”。

### 10.1 新增需求

#### Requirement 10：请求级 `trace_id` 必须自动向下传播到步骤级日志

系统必须支持从 request 入口创建 trace scope，并让同一请求内的步骤级日志自动继承：

- `trace_id`
- `request_id`
- 可选 `span_id`

要求：

- `StepTrace` 不应要求业务代码每次手工传入 `trace_id`
- HTTP / bridge / CLI 入口创建的 request trace 应自动影响后续 logger 输出

#### Requirement 11：Logger 必须支持运行中的 trace scope provider

`Logger` 不能只停留在“可接受 provider”这一层，而必须真正接到一个运行中的上下文提供器，用来读取当前请求 scope。

#### Requirement 12：多层调用日志必须可关联到单一请求

最终输出中，至少应能看到：

- request started/completed
- middleware step
- service/usecase step

这些日志共享同一个 `trace_id`，从而支持人和机器进行完整链路关联。

### 10.2 新增设计

#### 设计 A：Thread-local Trace Scope

增加一个运行时 trace scope 机制，最小可行方案为：

- 线程本地存储当前 `TraceContext`
- request 入口在开始时 `enter`
- request 完成时 `exit`
- `Logger` 默认从当前 scope 中读取上下文

这样：

- request 日志不需要手工重复传 `trace_id`
- `StepTrace` 也不需要额外参数，即可自动继承上下文

#### 设计 B：RequestTrace 与 Scope 绑定

`request_trace.begin()` 除了生成 started 日志之外，还必须：

- 安装当前 `TraceContext`
- 让同线程内的 logger 能自动感知它

`request_trace.complete()` 或显式结束时则解除绑定。

#### 设计 C：StepTrace 自动继承上下文

`StepTrace` 本身不负责生成新的 `trace_id`，而是依赖 logger 的上下文传播机制自动拿到：

- `trace_id`
- `request_id`
- `span_id`

从而在 pretty / json / compact 输出中都能自然出现。

### 10.3 新增任务

#### Task 10：实现 trace context propagation

目标：

- 增加真正可运行的 trace scope/provider
- 让 request trace 进入作用域
- 让 logger 自动读到当前 trace context

涉及文件：

- `framework/src/core/logging/logger.zig`
- `framework/src/observability/request_trace.zig`
- 新增 `framework/src/observability/trace_scope.zig`（或等价文件）

完成标准：

- request started/completed 与同请求内的 step 日志共享同一 `trace_id`
- 不要求业务代码手工把 `trace_id` 传给 `StepTrace`

#### Task 11：验证多层调用 trace 贯通

目标：

- 用最小可运行 demo 或单元测试证明：
  - request
  - middleware step
  - service step
 共享同一 `trace_id`

完成标准：

- 真实运行输出中可以直接观察到多层日志共享同一个 `trace_id`

### 10.4 状态说明

这部分在当前文档中属于**新增增强项**，在本节补齐之前并没有形成正式 requirement/design/task。

从现在开始，后续继续做方案 B 时，应优先按这里的 `Requirement 10 ~ 12` 与 `Task 10 ~ 11` 推进。
