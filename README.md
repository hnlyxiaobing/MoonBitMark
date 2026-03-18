# MoonBitMark

MoonBitMark 是一个用 MoonBit 实现的文档转换引擎，目标是以纯 MoonBit 方式提供接近 `MarkItDown` 核心体验的多格式转 Markdown 能力。

当前项目已经从“CLI 里硬编码分支调用各 converter”推进到“前端调用 engine，engine 统一做识别、选择、转换、诊断与后处理”的架构。主链路可用，核心改造已进入收口阶段。

## 当前状态

截至 2026-03-18，整体改造进度可以概括为：

- P0 已基本完成：engine 已接管主流程，CLI 已降级为前端，所有主 converter 已统一返回 `ConvertResult`
- P1 大部分已完成：AST / renderer 已接入 HTML、DOCX、EPUB，并已推广到 text/csv/json/pdf/pptx/xlsx，stats / metadata / 注册表已落地
- P2 部分完成：已支持 frontmatter 输出，`asset_output_dir` 已能统一落盘 `OutputAsset` 与 Markdown 中的 `data:image/*;base64,...`，并回写相对链接
- 当前 `moon check` 可通过，且已无已知 warning / error

## 已实现输入格式

| 输入类型 | 状态 | 当前行为 |
|------|------|------|
| TXT | 已实现 | 直接读取文本 |
| CSV | 已实现 | 转为 Markdown 表格 |
| JSON | 已实现 | 包装为 `json` 代码块 |
| PDF | 已实现 | 基于 `bobzhang/mbtpdf` 提取文本并做基础后处理 |
| HTML | 已实现 | 支持本地 HTML 与 URL 输入 |
| DOCX | 已实现 | 通过 `libzip` + `xml` 提取正文、标题、基础列表与 metadata |
| PPTX | 已实现 | 通过 `libzip` + `xml` 提取幻灯片文本，并补充 typed diagnostics |
| XLSX | 已实现 | 支持多工作表、共享字符串，输出 Markdown 表格 |
| EPUB | 已实现 | 提取书籍元数据与 spine 文本内容 |

## 当前架构

```text
CLI / Frontend
  -> src/engine
     -> 输入识别 / converter 注册 / converter 选择
     -> 统一 ConvertContext / ConvertResult
     -> typed diagnostics / error 透传
     -> AST render / output postprocess
     -> asset_output_dir data URI 资源落盘
  -> src/formats/*
```

核心职责分层：

- `cmd/main/`：参数解析、调用 engine、写输出
- `src/engine/`：输入识别、转换器注册、结果归一化、错误/诊断合并、输出后处理
- `src/core/`：`ConvertResult`、`ConvertContext`、typed diagnostics/error 等核心类型
- `src/ast/`：统一 AST 与 Markdown renderer
- `src/formats/*/`：各格式 adapter / parser / converter

## 当前 CLI

主 CLI 已支持：

```text
main.exe <input> [output]
  --frontmatter
  --plain-text
  --no-metadata
  --asset-dir <dir>
  --debug
  --help
```

说明：

- `--frontmatter`：输出带 YAML frontmatter 的 Markdown
- `--plain-text`：输出纯文本模式
- `--no-metadata`：关闭 metadata 输出
- `--asset-dir <dir>`：将 Markdown 中的 `data:image/*;base64,...` 资源落盘到指定目录，并把链接改写为相对路径
- `--debug`：输出调试信息

## 使用方式

### 构建

推荐在 Windows + MSVC 环境下构建：

```bat
scripts\build_msvc.bat
```

或手动执行：

```bash
moon build --target native --release
```

### 运行

```bash
_build/native/release/build/cmd/main/main.exe input.txt
_build/native/release/build/cmd/main/main.exe input.docx output.md
_build/native/release/build/cmd/main/main.exe --frontmatter input.epub output.md
_build/native/release/build/cmd/main/main.exe --asset-dir assets input.html output.md
```

### 校验与开发

```bash
moon check
moon test
moon test src/engine
moon fmt
moon info
```

推荐在提交前执行：

```bash
moon info
moon fmt
moon check
```

## 与上游 MarkItDown 的差距

MoonBitMark 当前已经覆盖一批核心文档格式，但还不是完整对齐上游生态的替代品。

| 能力 | 上游 MarkItDown | 当前 MoonBitMark |
|------|------|------|
| TXT / CSV / JSON | 支持 | 支持 |
| PDF / HTML / DOCX / PPTX / XLSX / EPUB | 支持 | 支持 |
| typed diagnostics / engine 统一调度 | 有成熟实现 | 已完成主链路 |
| 图片 OCR / EXIF | 支持或可插件化 | 未实现 |
| 音频转写 | 支持 | 未实现 |
| 特殊 URL converter | 支持 | 未实现 |
| ZIP 遍历转换 | 支持 | 未实现 |
| 插件体系 | 支持 | 仅内部注册表，未开放为外部插件机制 |
| MCP 服务 | 独立维护 | 当前仓库仍为实验代码 |

## 当前边界与剩余缺口

- HTML：不支持 JavaScript 渲染
- PDF：以文本提取为主，不包含 OCR
- DOCX / PPTX / XLSX / EPUB：已统一接入 typed failure 主链路，且原生图片与附件已进入 `assets` 导出模型
- `asset_output_dir`：当前可统一处理 converter 产出的 `OutputAsset` 与 Markdown 内嵌 data URI 图片
- MCP：源码仍在仓库，但未作为正式发布能力接入主模块

## 项目结构

```text
src/
├── ast/        Document AST 与 Markdown renderer
├── core/       ConvertResult / ConvertContext / diagnostics 等核心类型
├── engine/     统一引擎与主转换流水线
├── libzip/     纯 MoonBit ZIP / Deflate 实现
├── xml/        纯 MoonBit XML 解析器
├── formats/    各格式 converter
└── mcp/        MCP 实验代码

cmd/
├── main/       CLI 前端
└── mcp-server/ MCP 实验入口
```

## 关键改造成果

- CLI 已不再直接分支判断格式，而是统一调用 engine
- `ConvertResult` / `ConvertContext` / typed diagnostics 已成为主链路模型
- archive 类格式的关键失败路径已能生成统一 `phase/source/hint` 诊断信息
- HTML、DOCX、EPUB 已接入 AST / renderer 主链路，text/csv/json/pdf/pptx/xlsx 也已接入
- `asset_output_dir` 已落地为真实资源落盘流程，而不是保留字段
- 项目历史 warning 已集中清理，当前 `moon check` 已无已知 warning / error

## 相关文档

- [架构改造方案与进度](docs/Project%20architecture%20transformation.md)
- [架构改造经验总结](docs/Architecture%20refactor%20lessons%20learned.md)
- [远程推送记录](docs/Remote%20push%20log.md)
- [已知问题](docs/KNOWN_ISSUES.md)
- [开发指南](AGENTS.md)

## 依赖

- `moonbitlang/async`
- `bobzhang/mbtpdf`

## 许可证

MIT
