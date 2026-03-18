# Win11 开发工作站总入口

## 1. 文档目的

这份文档是 `framework/docs/development/` 这一组 Windows 11 开发环境文档的总入口。

它不替代各篇细分文档，而是回答三个问题：

1. **先装什么**
2. **后配什么**
3. **按什么顺序验证**

如果你刚接手这个工作区，最省事的方式不是从某一篇细节文档直接跳进去，而是先把这份总入口走一遍。

## 2. 这套工作站要解决什么

对当前工作区来说，一台好用的 Win11 开发工作站，至少要同时覆盖三类需求：

- Zig 主线开发：`framework`、`ourclaw`、`ourclaw-manager`
- 编辑器语言支持：`zls`、跳转、诊断、补全
- 代理工作流：`OpenCode` / `Oh My OpenCode`、provider、搜索、MCP、GitHub、浏览器能力

所以它不是单纯的“装 Zig”，也不是单纯的“装 OpenCode”，而是一套能把这几类能力串起来的开发台。

## 3. 推荐阅读顺序

建议按下面顺序阅读和配置：

### 第一步：先把 Zig 基础环境装起来

先读：

- `framework/docs/development/win11-scoop-zig-env.md`

这篇负责回答：

- 用 `Scoop` 应该装哪些 Zig 相关工具
- 哪些是必装，哪些是可选
- `zig`、`zls`、`lldb`、`rg`、`fd` 平时怎么用

### 第二步：把编辑器接上 `zls`

再读：

- `framework/docs/development/vscode-zed-zls-setup.md`

这篇负责回答：

- VS Code 怎么接 `zls`
- Zed 怎么接 `zls`
- 如何判断语言服务器是否真的工作

### 第三步：理解 OpenCode / Oh My OpenCode 的依赖边界

最后读：

- `framework/docs/development/win11-oh-my-opencode-dependencies.md`

这篇负责回答：

- OpenCode 核心本体到底依赖什么
- Oh My OpenCode 会不会额外拉很多依赖
- 哪些工具是核心必需，哪些是按功能触发

## 4. 推荐搭建顺序

如果你想一口气搭好环境，建议按这个顺序操作。

### 4.1 安装基础 CLI

先装这批：

```powershell
scoop install git zig zls llvm ripgrep fd jq gh 7zip
```

如果你计划频繁使用 OpenCode 生态和各类本地工具，再补：

```powershell
scoop install nodejs python uv ast-grep
```

### 4.2 确认基础命令都能跑

至少检查：

```powershell
zig version
zls --version
git --version
rg --version
fd --version
gh --version
```

如果还装了增强工具，也建议检查：

```powershell
node --version
python --version
uv --version
sg --version
```

### 4.3 配编辑器

把 VS Code 或 Zed 接上 `zls`，并验证：

- 可以跳转定义
- 可以查找引用
- 能看到实时诊断

### 4.4 配 OpenCode / Oh My OpenCode

确认：

- `opencode --version`
- provider 已能认证/登录
- 如果使用 `oh-my-opencode`，其插件配置已成功写入 `opencode` 配置

### 4.5 再按需补功能型依赖

例如：

- 要浏览器自动化，再补 Playwright
- 要本地 MCP server，再补对应运行时
- 要某语言的完整 LSP，再补对应 SDK / toolchain

## 5. 最小可用方案

如果你现在只想尽快开工，不追求一步到位，可以先做到下面这个程度。

### 5.1 Zig 开发最小集

```powershell
scoop install git zig zls ripgrep fd
```

### 5.2 OpenCode 工作流最小集

```powershell
scoop install opencode git
```

然后再完成：

- provider 登录
- 编辑器接 `zls`

这样已经足够覆盖大部分日常开发与代理协作场景。

## 6. 完整推荐方案

如果你希望 Win11 上的体验尽量接近“完整开发工作台”，建议至少准备：

```powershell
scoop install git zig zls llvm ripgrep fd jq gh 7zip nodejs python uv ast-grep
```

如果你会大量使用 GitHub、MCP、结构化搜索、浏览器自动化，这套会明显更稳。

## 7. 如何判断环境已经成型

你可以用下面这组标准做快速验收。

### 7.1 Zig 侧

- `zig build test --summary all` 能正常跑
- `zls --version` 正常
- 编辑器里 Zig 跳转/诊断正常

### 7.2 OpenCode 侧

- `opencode --version` 正常
- provider 能登录
- 基础会话能正常工作

### 7.3 工具链侧

- `rg` / `fd` / `jq` 能直接在 PowerShell 使用
- 需要时 `gh` 可正常认证
- 需要时 `ast-grep` 可正常运行

### 7.4 工作区侧

至少能在下面三个项目根目录里独立工作：

- `framework/`
- `ourclaw/`
- `ourclaw-manager/`

## 8. Windows 原生还是 WSL2

对当前工作区来说，两种都能用，但建议这样理解：

- **Windows 原生**：可以工作，适合先快速搭起来
- **WSL2**：通常更稳，尤其是在路径、进程、CLI 兼容性、OpenCode 生态工具方面

所以最务实的策略不是一开始就争论哪种“绝对最好”，而是：

1. 先在原生 Win11 上搭最小可用环境
2. 如果后续遇到持续性的兼容问题，再迁到 WSL2

## 9. 文档分工

为了避免重复阅读，可以把这组文档理解成下面的分工：

- `framework/docs/development/win11-dev-workstation.md`
  - 总入口、推荐顺序、验收标准
- `framework/docs/development/win11-scoop-zig-env.md`
  - Zig 工具链与日常命令
- `framework/docs/development/vscode-zed-zls-setup.md`
  - 编辑器如何接 `zls`
- `framework/docs/development/win11-oh-my-opencode-dependencies.md`
  - OpenCode / Oh My OpenCode 的依赖矩阵

## 10. 一句建议

如果你是第一次给这套工作区配环境，最省事的顺序就是：

1. 先装 Zig 工具链
2. 再把编辑器接上 `zls`
3. 再装并配置 OpenCode / Oh My OpenCode
4. 最后再补 MCP、浏览器、GitHub、特定语言 SDK 这些增强依赖

这样不会一上来就把环境复杂度拉满，也更容易定位问题到底出在哪一层。
