# framework 外部脚本协议设计

## 1. 目标

本文档说明 `framework/tooling/script_contract.zig` 与 `script_host.zig` 当前采用的最小脚本协议。

其作用是让：

- Python
- PowerShell
- Node

等外部脚本，可以被统一托管为 script-backed tool。

## 2. 当前协议

### 输入

脚本从 stdin 接收 JSON：

- `tool_id`
- `request_id`
- `trace_id`
- `params_json`

### 输出

脚本向 stdout 输出 JSON：

- `ok`
- `output_json`
- `error_code`
- `error_message`

## 3. 当前约束

- 非零退出码 -> process failed
- stdout 非 JSON -> invalid output
- stderr 不参与结果协议，但会桥接到日志

## 4. 设计意图

这个协议的目标不是做一个通用 RPC，而是做一个最小、稳、适合 tool host 的脚本协议。

## 5. 当前限制

当前协议仍是最小版：

- 没有版本字段
- 没有 stream/chunk 协议
- 没有 richer metadata

但它已经足够支撑第一批 script-backed tools。
