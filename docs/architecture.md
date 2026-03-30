# MoonBitMark Architecture

## 项目定位

MoonBitMark 是一个以 `src/engine/` 为统一入口的多格式文档转 Markdown 引擎。CLI 只是前端壳层，负责参数解析、调用引擎和输出结果。

外部依赖边界另见 `docs/architecture/external_dependencies.md`。

## 主链路

```text
input path / url
  -> engine.detect
  -> converter registry
  -> concrete converter
  -> AST / metadata / diagnostics / assets
  -> renderer / postprocess
  -> ConvertResult
```

统一结果由 `src/core/types.mbt` 中的 `ConvertResult` 承载，当前字段包括：

- `markdown`
- `document`
- `metadata`
- `diagnostics`
- `warnings`
- `assets`
- `stats`

## 关键目录

```text
src/
├── ast/              Document AST 与 Markdown renderer
├── capabilities/     横切能力层，目前包含 OCR
├── core/             ConvertResult、context、diagnostics、stats、共享 helper
├── engine/           detect、converter registry、统一调度
├── formats/          各格式 converter
├── libzip/           纯 MoonBit ZIP / Deflate
├── mcp/              MCP 协议、传输与 handler
└── xml/              纯 MoonBit XML parser

cmd/
├── main/             CLI 前端
├── demo/             直接调用 engine 的最小示例
└── mcp-server/       MCP server 入口
```

## 当前支持的输入

- TXT
- CSV
- JSON
- PDF
- Image
- HTML / XHTML / URL
- DOCX
- PPTX
- XLSX
- EPUB

## 当前共享层职责

### `src/core/`

当前 `core` 已经不只是结果类型集合，还承担了几类跨格式 helper：

- 文件读取与路径辅助
- UTF-8 BOM 清理
- 资产 placeholder 与 OCR metadata helper
- warning / diagnostics 的共享约定

### `src/ast/`

AST 负责统一 Markdown 渲染策略。当前除了 richer inline 语义外，还承担：

- 表格列宽补齐
- 单元格内换行转 `<br>`
- 各格式共享的 Markdown 输出收敛

这意味着 CSV、HTML、XLSX 等只要落到 `Table` block，就会复用同一套渲染行为。

## 两类重要扩展点

### Converter

新增格式时优先沿用现有模式：

1. 在 `src/formats/<format>/` 下实现 `accepts()` 和 `convert()`。
2. 让 converter 返回统一的 `ConvertResult`。
3. 在 engine 的默认注册表中接入。

### Capability

横切能力不要直接塞进 CLI 或单个 converter。像 OCR 这类能力应放在 `src/capabilities/`，通过 `ConvertContext` 透传到各 converter。

## 当前格式状态

### 轻结构文本簇

- CSV 已补到 quoted / escaped / multiline 语义，不再只是按逗号切分。
- TXT / JSON 已统一走共享文本读取路径，并在进入 converter 前清理 UTF-8 BOM。

### Web 文档簇

- HTML / XHTML / URL 仍是轻量结构恢复路径。
- 当前已支持常见标题、段落、列表、表格、引用和代码块恢复。
- URL 输入现在会优先提取 `<article>` / `<main>` 主内容，并继续过滤明显的导航、侧栏和页脚噪声。
- HTML 链接和图片会结合输入 URL 与 `<base href>` 解析相对地址，并过滤 `javascript:` / `vbscript:` 这类不安全 scheme。
- lazy image 属性（如 `data-src` / `srcset`）和带 `rowspan` / `colspan` 的表头现在会做额外归一化，减少丢图和错列表头。
- `<title>` 会在正文首块不重复时注入 Markdown。
- `div / section / article / main / header / figure` 容器会被展开，而不是整体压扁成单段落。
- 表格单元格当前会优先保留可读纯文本，避免把 `strong/em/link` 语义直接泄漏成 Markdown 标记。
- HTML 仍不做 JavaScript 渲染，也没有完整 DOM / CSS 语义。

### Office / Archive 簇

- DOCX / PPTX / XLSX / EPUB 继续共享 `libzip + xml` 基础设施。
- `src/libzip/deflate.mbt` 已覆盖 `Stored / Fixed Huffman / Dynamic Huffman` 三条路径。
- 共享容器层已经稳定，但各格式局部结构细节仍在持续补强。
- 第二阶段已补到：DOCX 编号标题间距与首段标题提升、XLSX 默认不再把 embedded asset gallery 直接拼进主 Markdown、EPUB 已补媒体控件去噪、Project Gutenberg boilerplate 清理和章节正文块级提取。

### PDF

- PDF 主路径已拆成 `route -> extraction -> normalize -> structure -> assembly -> diagnostics` 的多文件管线。
- 默认快速路径仍是 `mbtpdf`。
- 小型复杂文档可按启发式升级到 `pdfminer` bridge fallback。
- PDF OCR 仍是恢复路径，不是成熟页渲染引擎。
- route diagnostics 现在会带上 structured / recovery 页数与 flag summary，便于区分“主路径强”与“恢复路径介入”的真实原因。

### MCP

- `cmd/mcp-server` 当前是实验性 STDIO MCP 入口。
- 第一阶段只核验了 `initialize`、`tools/list` 和 `tools/call` 的最小闭环。
