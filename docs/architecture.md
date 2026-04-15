# MoonBitMark Architecture

MoonBitMark 以 `src/engine/` 为统一入口，把不同输入转换为统一 AST、Markdown 和结构化 diagnostics。CLI 是主入口；MCP 是实验性的本地服务接口。

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

统一结果由 `src/core/types.mbt` 中的 `ConvertResult` 承载，核心字段包括：

- `markdown`
- `document`
- `metadata`
- `diagnostics`
- `warnings`
- `assets`
- `stats`

## 目录职责

```text
src/
├── ast/              统一 AST 与 Markdown 渲染
├── capabilities/     横切能力层，目前包含 OCR
├── core/             结果类型、上下文、diagnostics、共享 helper
├── engine/           格式检测与统一调度
├── formats/          各格式转换器
├── libzip/           纯 MoonBit ZIP / Deflate
├── mcp/              MCP 协议、handler 与传输
└── xml/              纯 MoonBit XML parser

cmd/
├── main/             CLI 入口
├── demo/             engine 最小示例
├── mcp-server/       MCP STDIO 入口
└── mcp-http-server/  MCP HTTP 入口
```

## 模块边界

### `src/core/`

负责共享结果协议和跨格式通用能力：

- 文件读取与路径辅助
- UTF-8 BOM 清理
- diagnostics / warning 约定
- 资产与 OCR 相关的共享 metadata helper

### `src/ast/`

负责统一 Markdown 输出收敛：

- 标题、段落、列表、引用、代码块
- 表格列宽补齐
- 单元格内换行转 `<br>`

只要格式转换器产出相同 AST，最终 Markdown 行为就会收敛到同一套渲染规则。

### `src/capabilities/ocr/`

OCR 是横切能力，不直接绑死在 CLI 或单个格式里，而是通过 `ConvertContext` 透传给各转换器。

## 格式簇

### 轻结构文本

- TXT、CSV、JSON 走较轻的解析路径。
- CSV 处理 quoted、escaped 和 multiline 单元格。

### Web 文档

- HTML、XHTML、URL 支持标题、段落、列表、表格、引用和代码块的基础恢复。
- URL 输入会优先提取主内容，并解析相对链接与图片地址。
- 不做 JavaScript 渲染，也不实现完整 DOM / CSS 语义。

### Office / Archive

- DOCX、PPTX、XLSX、EPUB 共享 `libzip + xml` 基础设施。
- `libzip` 已覆盖 stored、fixed Huffman 和 dynamic Huffman 三条解压路径。

### PDF

- PDF 管线拆分为 route、extract、normalize、structure、assemble 和 diagnostics。
- 默认路径使用 `bobzhang/mbtpdf`。
- 必要时可以走 Python bridge fallback。
- OCR 只作为恢复路径介入，不是完整版面理解系统。

## 外部依赖边界

| 能力 | 默认路径 | 外部依赖 |
| --- | --- | --- |
| TXT / CSV / JSON / HTML / DOCX / PPTX / XLSX / EPUB 容器解析 | 纯 MoonBit | 无 |
| PDF 提取 | MoonBit 包 | `bobzhang/mbtpdf` |
| PDF fallback | 可选 bridge | `python scripts/pdf/bridge.py` |
| OCR | 可选 bridge | `python scripts/ocr/bridge.py`，backend 为 `mock`、`tesseract` 或 `auto` |
| MCP STDIO / HTTP | 本地服务 | 无额外运行时，但受环境变量限制 |
| Windows native release build | 原生构建 | MSVC |

## MCP 运行时边界

- `MOONBITMARK_MCP_ALLOWED_ROOTS`：限制可访问文件根目录。
- `MOONBITMARK_MCP_ALLOW_HTTP`：控制是否允许 `http://` 和 `https://` 输入。
- `MOONBITMARK_MCP_ENABLE_OCR`：控制 MCP 是否允许 OCR。
- `MOONBITMARK_MCP_MAX_OUTPUT_CHARS`：限制返回 Markdown 长度。
- `MOONBITMARK_MCP_MAX_UPLOAD_BYTES`：限制上传文档大小。
- `MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL`：控制 HTTP server 是否允许非 loopback 绑定。

## 验证入口

- 基础验证：`moon check`、`moon test`
- 覆盖率：`moon test --enable-coverage`、`moon coverage analyze`
- 质量评测：`python tests/conversion_eval/scripts/run_eval.py run`
- CLI smoke：`tests/cli/*.ps1`
- OCR smoke：`tests/ocr/*.ps1`
- MCP smoke：`tests/integration/mcp*_smoke.ps1`
