# Win11 下 OpenCode / Oh My OpenCode 的依赖说明

## 1. 文档目的

这份文档专门回答一个很容易混淆的问题：

> **OpenCode / Oh My OpenCode 到底需不需要额外安装很多库、CLI 和底层工具？**

如果你想先看整套 Win11 开发工作站应该按什么顺序搭，先读：

- `framework/docs/development/win11-dev-workstation.md`

短答案是：

- **OpenCode 核心本体依赖不重**
- **Oh My OpenCode 也不是一个独立运行时**
- 真正会把依赖面拉大的，主要是 **LSP / MCP / GitHub / 浏览器自动化 / 特定 provider** 这类按功能触发的能力

这份文档面向 **Windows 11** 用户，重点说明哪些依赖是：

1. **核心必需**
2. **OpenCode 已内置/已打包**
3. **推荐手动安装**
4. **按功能触发才需要**

补充说明：

- `OpenCode` 在 **Windows 原生环境** 下可以运行
- 但官方整体倾向仍是：**想要更稳的开发体验时，优先考虑 WSL2**

## 2. 先分清 OpenCode 和 Oh My OpenCode

### 2.1 OpenCode 是什么

`OpenCode` 是核心代理运行时/CLI，本体负责：

- 会话
- provider 接入
- 工具调用
- 插件加载
- MCP 集成
- Web/TUI/桌面入口

### 2.2 Oh My OpenCode 是什么

`Oh My OpenCode`（也常见为 `oh-my-opencode`）不是替代 `OpenCode` 的独立运行时，而是 **挂在 OpenCode 之上的增强层**。

它主要补的是：

- 更强的 agent 编排
- 更多策略化 prompt / planner / reviewer / subagent 配置
- 更激进的并行搜索与工具使用方式
- 一些功能的预接线与默认配置

所以判断依赖时，要分两层：

- `OpenCode` 本体是否能跑
- `Oh My OpenCode` 想启用的增强能力是否需要额外工具

## 3. 核心结论

### 3.1 如果你只想“跑起来”

最小前提通常只有：

- `opencode`
- 至少一个可用的 provider 登录/凭据
- 一个正常可用的终端环境

这时你并不需要先手工安装一整套检索/LSP/MCP 工具。

如果只是先验证“能不能跑”，完全可以先走最小安装。

如果后续你在 Windows 原生环境里持续碰到路径、权限、进程或工具兼容性问题，再考虑切到 `WSL2`，通常比继续堆补丁更省时间。

### 3.2 如果你想“把能力用满”

当你想完整使用以下能力时，依赖面就会扩大：

- `LSP`
- `MCP server`
- GitHub 集成
- 浏览器自动化
- 特定语言工具链
- 特定 provider 的认证链/本地服务

这时就不再是“一个二进制就够”，而是一套开发工作台。

## 4. 依赖矩阵

### 4.1 核心必需

| 依赖 | 是否必须 | 说明 |
| --- | --- | --- |
| `opencode` | 是 | OpenCode 本体，必须先安装 |
| 至少一个 provider 凭据 | 是 | 没有模型可用时，基本无法正常工作 |
| 终端环境 | 是 | OpenCode 的 CLI/TUI 依赖终端运行 |

### 4.2 安装阶段常见依赖

| 依赖 | 是否运行期必须 | 说明 |
| --- | --- | --- |
| `bunx` / `npx` | 否 | 常用于安装 `oh-my-opencode` |
| `bun` / `nodejs` | 不一定 | 更多是安装器和部分生态工具依赖，不代表每次运行都要依赖 |

也就是说：

- 安装 `oh-my-opencode` 时，经常会用到 `bunx` 或 `npx`
- 但安装文档明确说明：**安装完成后 CLI 本身不再要求 Bun/Node 运行时**

### 4.3 OpenCode 已内置/已打包的部分能力

基于当前机器可见证据，`OpenCode` 至少会随安装打包一部分工具，而不是全部要求你手装。

本机已确认存在：

- `rg.exe`
- `zls.exe`

这说明两件事：

1. **不是所有搜索能力都要求你先手装 `ripgrep`**
2. **不是所有 LSP 相关能力都要求你先单独装 `zls`**

但要注意：

> **“打包了一部分工具” 不等于 “所有语言、所有场景都完全不依赖外部工具链”。**

## 5. 按功能触发的依赖

这部分才是你最关心的“底层检索工具到底还要不要额外装东西”。

### 5.1 LSP / 语言智能

`OpenCode` 可以接入 LSP，但很多语言的完整能力仍依赖本机对应的 SDK、编译器或语言服务器。

典型例子：

- Zig：`zig`、有时也会涉及 `zls`
- Go：`go`
- Java：JDK
- .NET：`.NET SDK`
- Rust：`rust-analyzer` / Rust toolchain

这类依赖不是 OpenCode 核心硬依赖，而是：

> **你要对某门语言启用更完整的 LSP/诊断/跳转能力时才需要。**

### 5.2 MCP Server

`MCP` 是最典型的“功能型依赖面”。

要点很简单：

- `OpenCode` 支持接 MCP
- 但具体某个 MCP server 怎么跑，依赖的是 **那个 server 自己的运行时**

举例：

- 某个 MCP server 用 Node 写的 → 你需要 `nodejs`
- 某个 MCP server 用 Python 写的 → 你需要 `python` 或 `uv`
- 某个 MCP server 需要 Docker → 你需要 `docker`
- 某个 MCP server 要 OAuth / API Key → 你还需要额外认证

所以这里真正的结论是：

> **MCP 不是“OpenCode 自己的依赖”，而是“你启用的 MCP server 的依赖”。**

### 5.3 GitHub 集成

如果你要用：

- GitHub agent
- PR / issue 相关流程
- `/opencode` 一类 GitHub 工作流

那你会依赖：

- GitHub 认证
- Token / 权限
- 有时也会想配 `gh`

这里推荐装：

- `git`
- `gh`

### 5.4 浏览器自动化

如果你要使用浏览器自动化相关能力，比如：

- Playwright
- browser skill
- 网页登录/抓取/截图

那么依赖通常会落在：

- `playwright` 运行时
- 浏览器二进制
- 某些插件自己的安装命令

这同样不是 OpenCode 核心强制依赖，而是启用浏览器能力后的附加依赖。

### 5.5 Web 搜索 / 检索能力

这部分最容易误解。

很多“搜索能力”其实分成两种：

#### A. OpenCode 内建或已接通的搜索能力

例如：

- 内置 web search
- 文档检索
- 代码搜索接口

这类能力很多时候更依赖：

- 网络访问
- provider / 平台侧能力
- 配置开关

而不一定要求你再手装一个本地 CLI。

#### B. 本地仓库搜索能力

例如：

- `ripgrep`
- `fd`
- `ast-grep`
- 本地文件扫描
- AST 工具

这类更接近“本地开发工具链”。

其中有些可能随 `OpenCode` 一起打包，有些则建议你自己装，原因不是“没它就不能跑”，而是：

- 手工排障更方便
- 终端里你自己也能直接用
- 不依赖 OpenCode 内部私有路径

其中 `ast-grep` 值得单独提一下：它不是 OpenCode 核心硬依赖，但在结构化检索、批量改写和重构类任务里很常见，属于典型的生态增强工具。

## 6. 对 Windows 11 的实际建议

### 6.1 只求最小可用

如果你只想先把 `OpenCode + Oh My OpenCode` 用起来，建议至少确保：

```powershell
scoop install opencode git
```

然后完成 provider 登录/认证。

### 6.2 追求稳定实用的开发工作台

如果你希望它在 Windows 上更像一个完整开发工作台，建议补齐：

```powershell
scoop install git gh ripgrep fd jq nodejs python uv 7zip
```

如果你还想补强结构化代码检索/改写能力，建议再装：

```powershell
scoop install ast-grep
```

如果你主要做 Zig，再补：

```powershell
scoop install zig zls llvm
```

### 6.3 为什么明明有些工具已内置，还建议手装

因为“OpenCode 内置工具”和“你系统里可直接使用的工具”是两回事。

手动安装的价值在于：

- 你自己在 PowerShell 里也能直接排障
- 编辑器、脚本、其他工具也能直接复用
- 不用依赖 `OpenCode` 的内部安装目录

比如：

- `rg`
- `fd`
- `jq`
- `gh`
- `ast-grep`

这些就算 OpenCode 某些场景能替你兜底，单独装在系统里依然很值。

## 7. Oh My OpenCode 的真实依赖判断方式

如果你以后还想判断“某个能力到底是不是额外依赖”，可以按下面思路看：

### 7.1 看它是核心能力，还是插件/技能能力

- 核心能力：优先看 `OpenCode` 官方文档
- 插件/技能能力：优先看 `oh-my-opencode` 或对应插件文档

### 7.2 看它依赖的是“本体”，还是“外部服务”

常见分法：

- 依赖本地 CLI
- 依赖语言 SDK
- 依赖远端 API
- 依赖 OAuth
- 依赖浏览器/桌面运行时

### 7.3 看它是不是“按功能触发”

这是最关键的一步。

很多能力不是“默认全开全依赖”，而是：

- 你没启用，就不需要
- 你一启用，就要补对应运行时

## 8. 一张简化版判断表

| 能力 | 默认必须 | 常见额外依赖 |
| --- | --- | --- |
| OpenCode CLI 本体 | 是 | 无 |
| Provider 调用 | 是 | API Key / OAuth / 订阅 |
| Oh My OpenCode 插件 | 否（相对 OpenCode） | 安装期常用 `bunx` / `npx` |
| 本地代码搜索 | 否 | `ripgrep`、`fd`、AST 工具 |
| LSP | 否 | 语言工具链 / SDK / 语言服务器 |
| MCP | 否 | 对应 MCP server 自己的运行时 |
| GitHub 能力 | 否 | `git`、`gh`、GitHub 认证 |
| 浏览器自动化 | 否 | Playwright / 浏览器二进制 |
| 桌面端 | 否 | Windows 上可能涉及 WebView2 |

## 9. 一句结论

对 Windows 11 来说，最准确的说法不是：

> “Oh My OpenCode 需要很多底层库。”

而是：

> **OpenCode 核心依赖很轻；Oh My OpenCode 会把更多高级能力接进来，而这些高级能力会按功能触发对应的外部依赖。**

如果你只想启动它，不重；
如果你想把检索、LSP、MCP、GitHub、浏览器、provider 生态全用满，就应该把它当成一套完整开发工作台来配。
