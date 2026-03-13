# MoonBitMark

用 MoonBit 编写的文档转 Markdown 工具，目标是复刻并逐步逼近上游 `MarkItDown` 的核心文档转换能力，同时保持纯 MoonBit 实现路径。

## 当前状态

当前主模块已经恢复到可维护状态：

- `moon check` 可以通过
- 在 Windows + MSVC 环境下，`moon test` 可以通过
- 主 CLI `cmd/main` 可用
- `src/mcp/` 与 `cmd/mcp-server/` 目前保留为实验代码，但不参与主模块构建

## 当前已实现功能

主 CLI 当前支持这些输入：

| 输入类型 | 状态 | 当前行为 |
|------|------|------|
| TXT | 已实现 | 直接读取文本 |
| CSV | 已实现 | 转为 Markdown 表格 |
| JSON | 已实现 | 包装为 `json` 代码块 |
| PDF | 已实现 | 基于 `bobzhang/mbtpdf` 提取文本，并做基础后处理 |
| HTML | 已实现 | 支持本地 HTML 文件 |
| URL | 已实现 | 支持 `http://` / `https://`，交给 HTML 转换器 |
| DOCX | 已实现 | 通过 `libzip` + `xml` 提取段落、标题、简单列表文本 |
| PPTX | 已实现 | 通过 `libzip` + `xml` 提取幻灯片文本 |
| XLSX | 已实现 | 支持多工作表、共享字符串，输出 Markdown 表格 |
| EPUB | 已实现 | 提取书籍元数据和 spine 文本内容 |

## 与上游 MarkItDown 的差距

本项目当前只覆盖了上游 `MarkItDown` 的一部分核心能力，主要差距如下：

| 能力 | 上游 MarkItDown | 当前 MoonBitMark |
|------|------|------|
| PDF / DOCX / PPTX / XLSX / HTML / EPUB | 支持 | 支持 |
| TXT / CSV / JSON | 支持 | 支持 |
| XML 文件转换 | 支持文本类输入的一部分 | 尚未作为独立输入格式接入 CLI |
| ZIP 遍历转换 | 支持 | 未实现 |
| 图片 OCR / EXIF | 支持或可通过插件支持 | 未实现 |
| 音频转写 | 支持 | 未实现 |
| YouTube / RSS / Bing / Wikipedia 等特殊 URL 转换器 | 支持 | 未实现 |
| Outlook `.msg` / 旧版 `.xls` / notebook 等 | 支持 | 未实现 |
| 插件体系 | 支持 | 未实现 |
| MCP 服务 | 上游作为独立包维护 | 当前仓库仅保留实验代码，未作为正式可发布能力 |

换句话说，MoonBitMark 当前更接近一个“纯 MoonBit 文档转换器核心子集”，而不是完整对齐上游全部生态能力。

## 当前实现边界

- PDF：以文本提取为主，不含 OCR。
- HTML：不支持 JavaScript 渲染。
- DOCX：当前以文本提取为主，不保留完整富文本样式。
- PPTX：当前以文本提取为主，不处理动画、图片等复杂元素。
- XLSX：不做公式计算，不完整支持复杂样式。
- EPUB：以元数据和正文文本提取为主。
- MCP：源码仍在仓库中，但未接入当前主模块构建。

## 已完成的工程修复

这次整理后，项目有这些关键修复：

- 修正了 README 中已经失真的版本、状态和构建说明。
- 修正了 `moon.mod.json` 中过时的项目描述。
- 清理了会让主模块构建直接失败的 MCP 包配置。
- 将未完成的 MCP 子项目从主模块构建图中移除，避免影响 `moon check` / `moon test`。
- 保留 `src/mcp/` 代码用于后续拆分独立模块，而不是继续污染主转换器模块。
- 在本机 Windows 用户环境中切换到了 MSVC 编译链，避免 `moonbitlang/async` 测试阶段错误落到 MinGW。

## Windows 构建说明

当前项目在 Windows 下应使用 MSVC，而不是 MinGW。

本机现已验证可用的 MSVC 路径为：

```text
C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\HostX64\x64\cl.exe
```

如果你刚修改过环境变量，记得重新打开终端再执行 `moon` 命令。

## 使用方式

### 构建

推荐使用项目脚本：

```bat
scripts\build.bat
scripts\build.bat --debug
```

或直接运行：

```bash
moon build --target native --release
```

### 测试

推荐使用项目脚本：

```bat
scripts\test.bat
scripts\test.bat --update
```

或直接运行：

```bash
moon test
moon test --update
```

### 转换文件

```bash
_build/native/release/build/cmd/main/main.exe input.txt
_build/native/release/build/cmd/main/main.exe input.docx output.md
_build/native/release/build/cmd/main/main.exe https://example.com output.md
```

### CLI 支持的输入

```text
.txt .csv .json .pdf .html .htm .docx .pptx .xlsx .epub
http://...
https://...
```

## 项目结构

```text
src/
├── core/       核心类型和转换逻辑
├── libzip/     纯 MoonBit ZIP / Deflate 实现
├── xml/        纯 MoonBit XML 解析器
├── formats/    各格式转换器
│   ├── text/
│   ├── csv/
│   ├── json/
│   ├── pdf/
│   ├── html/
│   ├── docx/
│   ├── pptx/
│   ├── xlsx/
│   └── epub/
└── mcp/        MCP 实验代码（当前不参与主模块构建）
```

## 开发命令

```bash
moon check
moon test
moon test --update
moon fmt
moon info
```

## 依赖

- `moonbitlang/async`
- `bobzhang/mbtpdf`

## 许可证

MIT
