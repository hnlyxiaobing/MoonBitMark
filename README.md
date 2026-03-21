# MoonBitMark

MoonBitMark 是一个用 MoonBit 实现的多格式文档转 Markdown 引擎。当前主线以 `engine` 为核心，CLI 只负责参数解析、调用引擎和展示结果。

## 能力概览

支持输入：

- TXT
- CSV
- JSON
- PDF
- HTML / XHTML / URL
- DOCX
- PPTX
- XLSX
- EPUB

统一输出模型：

- `ConvertResult`
- typed diagnostics
- metadata / stats
- `OutputAsset` 资源导出
- `Load -> Detect -> Parse -> Normalize -> Render -> Postprocess` 流水线

## 架构

```text
CLI
  -> engine
     -> detect
     -> converter registry
     -> converter execution
     -> diagnostics / metadata / stats normalization
     -> AST render
     -> asset postprocess
  -> formats/*
     -> HTML / DOCX / EPUB 优先接入 richer AST
```

核心目录：

```text
src/
├── ast/        Document AST 与 Markdown renderer
├── core/       ConvertResult / diagnostics / stats / context
├── engine/     检测、选择、调度、后处理
├── formats/    各格式 converter
├── libzip/     纯 MoonBit ZIP / Deflate
└── xml/        纯 MoonBit XML parser

cmd/main/       CLI 前端
cmd/demo/       engine 直连 demo
```

## AST 现状

当前 AST 已支持 richer inline 语义：

- `Text`
- `Emphasis`
- `Strong`
- `Link`
- `Image`
- `Code`
- `LineBreak`

HTML converter 会直接映射这些 inline 节点；DOCX 会保留 run 级强调、链接、图片与标题语义；EPUB 的 XHTML 内容复用 HTML 的 AST 映射路径。AST 现在也会随 `ConvertResult.document` 回到主链路，供 CLI 与 demo 复用。

## CLI

```text
main.exe [options] <input> [output]

--frontmatter
--plain-text
--no-metadata
--asset-dir <dir>
--diag-json
--detect-only
--dump-ast
--debug
--help
```

说明：

- `--diag-json`：输出 diagnostics / warnings / stats / metadata 的 JSON 视图
- `--detect-only`：只执行识别与 converter 选择，不做转换
- `--dump-ast`：输出 AST JSON，而不是 Markdown
- `--asset-dir`：把 `OutputAsset` 与 Markdown 中的 data URI 图片写入目录并回写相对链接
- `--debug`：在写文件模式下额外输出文本 debug report

## 构建与测试

Windows native 构建依赖：

- MSVC Build Tools 2022

推荐命令：

```bat
scripts\build.bat
scripts\test.bat
```

常用开发命令：

```bash
moon check
moon test
moon fmt
moon info
```

## 输出示例

检测结果：

```bash
main.exe --detect-only demo.docx
```

```text
converter: docx
extension: .docx
filename: demo.docx
```

AST dump：

```bash
main.exe --dump-ast demo.html
```

结构化 diagnostics：

```bash
main.exe --diag-json demo.html
```

## Demo

最小 engine demo 位于 `cmd/demo/`，不经过 CLI 参数层，直接把 `BytesInput` 送入 engine：

```bash
moon run cmd/demo
```

它用于展示：

- engine 与 CLI 已解耦
- `MarkItDown::convert_source(...)` 可以直接服务其他前端
- diagnostics 与 Markdown 输出都可直接复用

## Benchmark

最小 benchmark 脚本位于 `scripts/benchmark.ps1`，说明文档位于 `docs/benchmark.md`。

```powershell
pwsh -File scripts/benchmark.ps1 -InputPath <your-input-file> -Iterations 10
```

## 项目状态

截至 2026-03-18：

- engine 已成为统一入口
- richer AST 已进入 HTML / DOCX / EPUB 主链路
- CLI 已支持 `--diag-json`、`--detect-only` 与 `--dump-ast`
- diagnostics / metadata / stats / AST 已统一为主干协议
- 提供了最小 demo 与 benchmark 脚本
- Windows native 构建与测试已不再依赖 `vcpkg` / `zip.lib` / `libexpat.lib`

## 已知限制

- HTML 不做 JavaScript 渲染
- PDF 当前以文本提取为主，不含 OCR
- DOCX / PPTX / XLSX / EPUB 仍有格式细节待继续补齐
- `src/libzip/deflate.mbt` 的 Dynamic Huffman 仍有已知问题，见 `docs/KNOWN_ISSUES.md`

## 相关文档

- `docs/ProjectOptimization/`
- `docs/benchmark.md`
- `docs/KNOWN_ISSUES.md`
- `tests/test_report/TEST_REPORT.md`
- `AGENTS.md`

## License

Apache-2.0
