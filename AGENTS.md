# framework Agent Instructions

## 目标

`framework` 是共享 Zig 基础能力，不是某个单一应用的临时代码。

大模型在这个仓库里工作时，必须优先沉淀“可复用能力”，而不是只为单个调用点拼接一次性逻辑。

## 日志与追踪规范

新增或修改日志相关代码时，必须按下面的层次组织：

1. `request_trace`
2. `MethodTrace`
3. `StepTrace`
4. `SummaryTrace`
5. 普通结构化日志

### 语义要求

- `ME` = Method
- `RT` = Run Time，总执行时间，毫秒
- `BT` = Beyond Threshold，是否超过阈值，输出 `Y / N`
- `ET` = Exception Type 分类码，不是原始异常类名

`ET` 当前约定：

- `N`：无异常
- `V`：验证异常
- `B`：业务异常
- `A`：认证/授权异常
- `S`：系统异常

### 禁止事项

不要做这些事：

- 把普通 `Duration` 直接改名成 `RT`
- 把原始异常类名直接塞进 `ET`
- 在没有阈值判断的前提下使用 `BT`
- 只生成摘要日志，不保留详细链路日志

### 文件日志约定

本框架当前同时支持：

- `TraceTextFileSink`
  - 适合本地调试、grep、调用链排查
- `JsonlFileSink`
  - 适合机器采集、日志平台、后处理

默认思路：

- 给人看的调试文件优先 `TraceTextFileSink`
- 给机器吃的日志优先 `JsonlFileSink`

## 代码修改要求

如果新增日志能力，大模型必须同步做这些事：

1. 更新导出入口
2. 增加最小可运行示例
3. 增加单元测试
4. 更新对应文档

## 示例优先级

日志能力相关修改完成后，至少要保证：

- `framework/examples/` 下有可参考示例
- `framework/docs/architecture/logging-usage-guide.md` 有使用说明
- 如果语义有新增，必须写清楚，不允许靠调用方猜
