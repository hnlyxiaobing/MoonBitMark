# MoonBitMark

MoonBitMark 是一个用 MoonBit 实现的文档转 Markdown 工具。当前主入口是 CLI；MCP 提供实验性的本地服务接口。

当前共享链路已经包含：

- 统一 engine / converter registry
- 共享 normalize passes
- semantic section tree / role / provenance 派生
- PDF 页级 OCR fallback 恢复链路
- 面向 MCP 与 eval 的结构化 diagnostics / explanations
- MCP normalizer 决策轨迹与 baseline compare debug 解释

## 支持的输入

- TXT
- CSV
- JSON
- PDF
- 图片：`png`、`jpg`、`jpeg`、`bmp`、`gif`、`tif`、`tiff`、`webp`
- HTML / XHTML
- URL：`http://...`、`https://...`
- DOCX
- PPTX
- XLSX
- EPUB

## 快速开始

基础校验：

```bash
moon check
moon test
```

Windows 原生构建：

```bat
scripts\build.bat
```

或在已配置 MSVC 的环境中手动构建：

```bash
moon build --target native --release
```

运行 CLI：

```bash
_build/native/release/build/cmd/main/main.exe <input> [output]
```

示例：

```powershell
_build\native\release\build\cmd\main\main.exe tests\conversion_eval\fixtures\inputs\html\simple_table.html
_build\native\release\build\cmd\main\main.exe --diag-json tests\conversion_eval\fixtures\inputs\pdf\multi_page.pdf
_build\native\release\build\cmd\main\main.exe --dump-ast tests\conversion_eval\fixtures\inputs\html\simple_table.html
```

## CLI 选项

- `--frontmatter`
- `--plain-text`
- `--no-metadata`
- `--asset-dir <dir>`
- `--ocr <off|auto|force>`
- `--ocr-lang <lang>`
- `--ocr-images`
- `--ocr-backend <auto|mock|tesseract>`
- `--ocr-timeout <ms>`
- `--diag-json`
- `--detect-only`
- `--dump-ast`
- `--dump-raw-ast`
- `--dump-normalized-ast`
- `--dump-semantic`
- `--debug`

其中：

- `--diag-json` 输出结构化 diagnostics、stats 和 metadata。
- `--dump-ast` 输出统一 AST 的 strict JSON。
- `--dump-raw-ast` 输出 normalize 之前的原始 AST。
- `--dump-normalized-ast` 输出共享 normalize passes 之后的 AST。
- `--dump-semantic` 输出派生得到的 semantic section tree / role / provenance。
- MCP `response_mode=json` 会进一步暴露 explanations，其中包括 heading / table / OCR / uncertainty，以及 normalizer 决策轨迹与 baseline compare debug。
- `--detect-only` 只做检测，不执行转换。

## 项目结构

```text
src/
├── ast/              统一 AST 与 Markdown 渲染
├── capabilities/     横切能力层，目前包含 OCR
├── core/             结果类型、diagnostics、共享 helper
├── engine/           检测与统一调度
├── formats/          各格式转换器
├── libzip/           纯 MoonBit ZIP / Deflate
├── mcp/              MCP 协议、handler 与传输
├── normalize/        共享结构归一化 passes
├── semantic/         Section tree / role / provenance 派生层
└── xml/              纯 MoonBit XML parser

cmd/
├── main/             CLI 入口
├── demo/             最小示例
├── mcp-server/       MCP STDIO 入口
└── mcp-http-server/  MCP HTTP 入口
```

## 开发与验证

常用命令：

```bash
moon check
moon test
moon test --enable-coverage
moon coverage analyze
moon info
moon fmt
```

质量回归：

```bash
python tests/conversion_eval/scripts/run_eval.py run
```

最小性能基准：

```powershell
pwsh -File scripts/benchmark.ps1 -InputPath <input-file> -Iterations 10
```

MCP smoke tests：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_ocr_mcp_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_resources_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_prompts_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_security_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_security_smoke.ps1
```

OCR smoke tests：

```powershell
powershell -ExecutionPolicy Bypass -File tests/ocr/ocr_force_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/ocr/ocr_backend_missing.ps1
powershell -ExecutionPolicy Bypass -File tests/ocr/ocr_timeout_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/ocr/pdf_ocr_force_smoke.ps1
```

## 运行边界

- CLI 是当前主公共入口。
- DOCX、PPTX、XLSX、EPUB 的容器解析依赖仓库内的 `libzip + xml`。
- OCR 是可选能力，依赖 `python scripts/ocr/bridge.py` 和可用 backend。
- PDF 主路径使用 MoonBit 包 `bobzhang/mbtpdf`，必要时可按页触发 OCR fallback，并把恢复页信息写回 metadata / diagnostics / eval；当前已补到页级恢复、linewise normalization 和一类常见 OCR 空格分列表格重建。
- MCP 仍是实验性接口，默认以本地 STDIO 或 loopback HTTP 使用为前提。
- Windows native release 构建依赖 MSVC。

## 文档

- [`docs/architecture.md`](docs/architecture.md)：当前架构、模块职责和外部依赖边界。
- [`docs/codex_development_guide.md`](docs/codex_development_guide.md)：面向 Codex 的自主开发指引和优先级路线图。
- [`docs/mcp.md`](docs/mcp.md)：MCP 入口、工具面和运行时限制。
- [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md)：当前仍有效的已知问题。

## 许可证

Apache-2.0
