# MoonBitMark Architecture

## 项目定位

MoonBitMark 是一个以 `engine` 为统一入口的多格式文档转 Markdown 引擎。CLI 只是前端壳层，负责参数解析、调用引擎和输出结果。

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

统一结果由 `src/core/types.mbt` 中的 `ConvertResult` 承载，包含：

- `markdown`
- `document` AST
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
├── core/             ConvertResult、context、diagnostics、stats
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

## 两类重要扩展点

### Converter

新增格式时优先沿用现有模式：

1. 在 `src/formats/<format>/` 下实现 `accepts()` 和 `convert()`
2. 让 converter 返回统一的 `ConvertResult`
3. 在 engine 的默认注册表中接入

### Capability

横切能力不要直接塞进 CLI 或单个 converter。像 OCR 这类能力应放在 `src/capabilities/`，通过 `ConvertContext` 透传到各 converter。

## 当前架构边界

- HTML 不做 JavaScript 渲染。
- PDF 已经从单文件流程重排为 `route -> extraction -> assembly -> diagnostics` 的多文件管线，当前主路径位于 `src/formats/pdf/` 下的 `converter.mbt`、`route.mbt`、`extract_native.mbt`、`extract_bridge.mbt`、`normalize.mbt`、`structure.mbt`、`assemble.mbt`、`diagnostics.mbt`。
- PDF 当前默认能力仍以文本提取为主：
  - `mbtpdf` 是默认快速路径
  - 小型复杂文档可按启发式升级到 `pdfminer` bridge fallback
  - 已有页级 route、结构恢复、table/code/formula 启发式和 metadata / diagnostics 闭环
- PDF 仍然不包含内建页渲染 OCR fallback；扫描件恢复仍需后续 capability 层补齐。
- `src/libzip/deflate.mbt` 现在已覆盖 `Stored / Fixed Huffman / Dynamic Huffman` 三条路径，继续作为 Office / EPUB 容器解压的共享基础设施。
