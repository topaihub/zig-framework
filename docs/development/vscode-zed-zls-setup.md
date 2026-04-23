# VS Code / Zed 如何配置 `zls`

## 1. 文档目的

这份文档专门说明：在 **Windows 11 + Scoop** 环境下，怎样让 **VS Code** 和 **Zed** 正确接入 `zls`，从而获得 Zig 的补全、跳转、引用查询和实时诊断能力。

如果你想先看整套开发工作站的搭建顺序，先读：

- `framework/docs/development/win11-dev-workstation.md`

如果你还没装好 Zig 基础环境，先读：

- `framework/docs/development/win11-scoop-zig-env.md`

如果你还在配置 `OpenCode / Oh My OpenCode` 的整体工具链，也建议一起看：

- `framework/docs/development/win11-oh-my-opencode-dependencies.md`

## 2. 先确认 `zls` 本身可用

不要先怪编辑器，先确认命令行能跑。

在 PowerShell 里执行：

```powershell
zls --version
where zls
```

预期结果：

- `zls --version` 能输出版本号
- `where zls` 能返回类似 `E:\scoop\shims\zls.exe` 的路径

如果这两步都不通，先不要继续配编辑器，先回去修 Scoop 安装。

## 3. VS Code 配置方式

### 3.1 安装扩展

在 VS Code 扩展市场安装 Zig 扩展。

只要扩展支持 Zig LSP，它最终都需要调用 `zls`，所以关键不在“装了扩展没有”，而在“扩展是不是找到了正确的 `zls`”。

### 3.2 最小可用配置

如果扩展能自动找到 `zls`，通常不需要额外配置。

如果自动发现失败，可以在工作区或用户级 `settings.json` 里显式指定：

```json
{
  "zig.zls.path": "E:\\scoop\\shims\\zls.exe"
}
```

如果你不确定路径，直接用下面命令查：

```powershell
where zls
```

然后把返回值填进去。

### 3.3 推荐的 VS Code 检查项

配置完成后，建议确认下面几件事：

1. 打开的是 Zig 工程根目录，而不是只打开某一个零散文件
2. `OUTPUT` / `Problems` 里没有 “failed to start zls” 之类错误
3. 打开 `.zig` 文件时能看到补全
4. `Go to Definition` 和 `Find References` 能正常工作

### 3.4 常见问题

#### 问题 1：扩展已装，但没有补全

通常先查这三件事：

- `zls --version` 是否正常
- `where zls` 是否有结果
- `zig.zls.path` 是否指向 Scoop shim，而不是一个失效旧路径

#### 问题 2：升级后突然失效

可以按这个顺序处理：

1. 重新执行 `zls --version`
2. 重新执行 `where zls`
3. 重启 VS Code
4. 如仍异常，再检查 `settings.json` 里是不是还写着旧路径

## 4. Zed 配置方式

### 4.1 基本原则

Zed 的核心思路和 VS Code 一样：

- 打开 Zig 工程目录
- 让 Zig 语言支持接到 `zls`

如果 Zed 能自动发现 `zls`，通常不需要手动干预。

### 4.2 显式指定 `zls`

如果自动发现失败，可以在 Zed 的配置中为 Zig 指定语言服务器路径。

思路就是把 `where zls` 查到的路径显式写进去，例如：

```json
{
  "lsp": {
    "zls": {
      "binary": {
        "path": "E:\\scoop\\shims\\zls.exe"
      }
    }
  }
}
```

不同版本的 Zed 设置项名字可能会有轻微差异，但核心不变：**让 Zig 对应的 LSP 最终调用 Scoop 安装的 `zls.exe`**。

如果你看到的是旧格式或新版格式，也按同样原则改，不要被配置结构的细节卡住。

### 4.3 推荐的 Zed 检查项

配置好后，至少确认：

- 打开 `.zig` 文件时有语法高亮和补全
- 跳转定义正常
- 诊断会随代码变化刷新
- 不再出现 “language server not found” 一类提示

## 5. 如何判断 `zls` 真的接上了

无论是 VS Code 还是 Zed，都不要只看“没报错”。

建议做 4 个动作：

1. 在某个 `const foo = ...` 上试 `Go to Definition`
2. 对函数名试 `Find References`
3. 故意写一个明显错误，确认会出现诊断
4. 改回正确代码，确认诊断会消失

只要这四步成立，基本就说明 `zls` 已经真正工作，而不是“装了但没接上”。

## 6. 适用于本工作区的建议

本工作区里常见的 Zig 工程根目录有：

- `framework/`
- `ourclaw/`
- `ourclaw-manager/`

建议不要只打开单个子目录下的零散源码文件，而是直接打开对应项目根目录。这样 `zls` 更容易拿到正确的构建上下文。

推荐做法：

- 改 `framework` 时，打开 `framework/`
- 改 `ourclaw` 时，打开 `ourclaw/`
- 改 `ourclaw-manager` 时，打开 `ourclaw-manager/`

如果你把整个 `ourclaw-dev/` 工作区一起打开，也可以，但当某些编辑器对多工程 Zig 工作区支持不稳定时，优先回到“一个项目根目录一个窗口”的方式。

## 7. 最小排障清单

如果编辑器里的 Zig 体验不正常，先按这个顺序排：

```powershell
zig version
zls --version
where zig
where zls
```

然后再检查：

1. 编辑器是否打开了正确的项目根目录
2. `zls` 路径是否写成了旧路径
3. 编辑器是否需要重启
4. Scoop 升级后 shim 是否仍然有效

## 8. 一句建议

对 Win11 + Scoop 来说，配置 `zls` 最稳的办法通常不是折腾复杂插件设置，而是：

1. 先确保 `zls --version` 正常
2. 用 `where zls` 拿到实际路径
3. 编辑器自动发现失败时，再显式把这个路径写进去

这样最直接，也最不容易被环境变量、旧配置和多版本残留干扰。
