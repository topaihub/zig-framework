# Win11 下通过 Scoop 搭建 Zig 开发环境

## 1. 文档目的

这份文档面向本工作区成员，说明如何在 **Windows 11** 上通过 **Scoop** 搭建一套可用于 `framework` / `ourclaw` / `ourclaw-manager` 的 Zig 开发环境。

目标不是装一堆泛用工具，而是装出一套对当前工作区真正有用、可直接开始开发与调试的环境。

如果你想先看总入口和推荐顺序，先读：

- `framework/docs/development/win11-dev-workstation.md`

如果你还想把 `OpenCode / Oh My OpenCode` 一起配成完整开发工作台，可以继续读：

- `framework/docs/development/win11-oh-my-opencode-dependencies.md`

## 2. 推荐工具清单

### 2.1 必装

这些工具建议默认安装：

| 工具 | Scoop 包名 | 用途 |
| --- | --- | --- |
| Zig 编译器 | `zig` | `build / test / run / fmt` 主工具 |
| Zig 语言服务器 | `zls` | 编辑器补全、跳转、诊断 |
| Git | `git` | 拉代码、查看 diff、提交与切换分支 |
| LLVM 工具链 | `llvm` | 提供 `lldb`、`clang` 等调试/辅助工具 |
| ripgrep | `ripgrep` | 全仓文本搜索，替代慢速搜索 |
| fd | `fd` | 快速按文件名/路径查找文件 |
| 7-Zip | `7zip` | 通用解压，Windows 下几乎必备 |

### 2.2 推荐但可选

这些不是 Zig 本身必须，但日常开发很好用：

| 工具 | Scoop 包名 | 用途 |
| --- | --- | --- |
| just | `just` | 统一封装常用开发命令 |
| jq | `jq` | 格式化/过滤 JSON 输出 |
| gh | `gh` | GitHub CLI，查 PR / issue / release 更方便 |
| hyperfine | `hyperfine` | 简单 benchmark，对比不同命令耗时 |

## 3. 安装前提

如果你还没有 Scoop，先按 Scoop 官方方式安装。安装完成后，先确认：

```powershell
scoop --version
```

建议先把 bucket 更新到最新：

```powershell
scoop update
```

## 4. 一次性安装命令

### 4.1 核心环境

```powershell
scoop install git zig zls llvm ripgrep fd 7zip
```

### 4.2 可选增强工具

```powershell
scoop install just jq gh hyperfine
```

## 5. 安装完成后的自检

建议逐条确认：

```powershell
zig version
zls --version
git --version
lldb --version
rg --version
fd --version
```

如果这些命令都能直接执行，说明基础环境已经可用。

如果想看实际 shim 路径，可以用：

```powershell
where zig
where zls
where lldb
```

## 6. 这些工具分别怎么用

### 6.1 `zig`

最常用：

```powershell
zig build
zig build test --summary all
zig build run
zig fmt src tests
zig test src\some_file.zig
```

说明：

- `zig build`：跑 `build.zig` 定义的默认构建
- `zig build test --summary all`：最常用的全量测试命令
- `zig build run`：运行 `build.zig` 里定义的可执行入口
- `zig fmt`：格式化 Zig 源码
- `zig test xxx.zig`：只跑单文件测试，适合快速回归

### 6.2 `zls`

`zls` 一般不是手工频繁执行，而是交给编辑器调用。

典型作用：

- 代码补全
- 跳转定义
- 悬停类型信息
- 实时诊断
- rename / references

如果编辑器识别不到 `zls`，通常只要把 `where zls` 找到的路径配置进去即可。

### 6.3 `lldb`

当你要调试 Zig 程序时可用：

```powershell
zig build
lldb .\zig-out\bin\your-app.exe
```

常见用法：

- `run`
- `bt`
- `breakpoint set --name main`
- `frame variable`

如果只是日常开发，不一定每天都用到 `lldb`；但遇到原生运行时问题时，它很有价值。

### 6.4 `ripgrep`

用于全文搜索：

```powershell
rg "snapshotJson" ourclaw
rg "session.summary" ourclaw\src
```

### 6.5 `fd`

用于按文件名找文件：

```powershell
fd memory_runtime
fd prompt_assembly ourclaw\src
```

### 6.6 `just`（可选）

如果后续工作区增加了 `justfile`，可以把常用命令统一成：

```powershell
just test
just fmt
just smoke
```

当前如果仓库里还没有 `justfile`，这一步可以先不启用。

### 6.7 `jq`（可选）

适合看命令返回的 JSON：

```powershell
some-command | jq
some-command | jq .summaryText
```

## 7. 编辑器建议

### 7.1 VS Code

建议安装 Zig 扩展，并确保它实际使用的是 Scoop 安装的 `zls`。

更细的编辑器配置说明见：

- `framework/docs/development/vscode-zed-zls-setup.md`

最关键的是两点：

1. 打开 Zig 工程根目录
2. 确认扩展能找到 `zls`

### 7.2 Zed / 其他编辑器

只要编辑器支持配置 Zig LSP，一般都可以直接复用 Scoop 安装的 `zls`。

如果编辑器报“找不到语言服务器”，优先检查：

- `zls --version` 是否正常
- `where zls` 是否有结果
- 编辑器里配置的路径是否指向 Scoop shim

## 8. 在本工作区里的日常使用方式

### 8.1 进入不同子项目

本工作区当前主线有三个 Zig 项目：

- `framework/`
- `ourclaw/`
- `ourclaw-manager/`

通常在各自目录里执行：

```powershell
cd E:\vscode\ourclaw-dev\framework
zig build test --summary all
```

```powershell
cd E:\vscode\ourclaw-dev\ourclaw
zig build test --summary all
```

```powershell
cd E:\vscode\ourclaw-dev\ourclaw-manager
zig build test --summary all
```

### 8.2 推荐工作流

建议按下面顺序工作：

1. 用 `fd` / `rg` 找文件与调用点
2. 用编辑器 + `zls` 做跳转和诊断
3. 小改动先跑单文件测试或相邻模块测试
4. 收口前跑 `zig build test --summary all`
5. 需要定位原生问题时再上 `lldb`

## 9. 常见问题

### 9.1 `zls` 找不到

先执行：

```powershell
zls --version
where zls
```

如果命令行能跑，但编辑器不能跑，通常是编辑器没有拿到正确路径。

### 9.2 `zig` 或 `zls` 升级后行为异常

可以尝试：

```powershell
scoop update zig zls
scoop reset zig zls
```

### 9.3 想看某个包到底装在哪

```powershell
scoop prefix zig
scoop prefix zls
scoop prefix llvm
```

## 10. 一句建议

对这个工作区来说，**最小够用且最稳的 Win11 Zig 环境** 通常就是：

```powershell
scoop install git zig zls llvm ripgrep fd 7zip
```

然后记住三类命令就够了：

- 构建测试：`zig build test --summary all`
- 代码搜索：`rg` / `fd`
- 编辑器诊断：`zls`

这套就已经足够支持当前 `framework + ourclaw + ourclaw-manager` 主线开发。
