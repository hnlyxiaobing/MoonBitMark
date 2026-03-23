# MoonBitMark

MoonBitMark 是一个用 MoonBit 实现的多格式文档转 Markdown 引擎。当前主线以 `src/engine/` 为统一入口，CLI 负责参数解析和结果展示，各格式 converter 统一返回 `ConvertResult`。

## 能力概览

当前支持输入：

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

统一输出模型：

- `markdown`
- `document` AST
- `metadata`
- `diagnostics`
- `warnings`
- `assets`
- `stats`

当前值得注意的质量能力：

- `src/ast/renderer.mbt` 会统一渲染 Markdown，并对表格行做列宽补齐。
- `src/core/file_helpers.mbt` 提供共享文本读取和 UTF-8 BOM 清理 helper。
- CSV 已支持引号、转义引号、空单元格和多行单元格。
- HTML 会恢复常见块级结构，并在必要时把 `<title>` 注入到 Markdown 顶部。
- OCR 作为 capability 注入，当前覆盖独立图片和 DOCX / PPTX / EPUB 嵌图补充。
- Office / EPUB 容器继续共用 `libzip + xml` 基础设施。
- conversion eval 现在同时输出 `By Format / By Cluster / By Tier / OCR Evidence`，便于看共享层回归。

## 架构概览

```text
input path / url
  -> engine.detect
  -> converter registry
  -> concrete converter
  -> AST / metadata / diagnostics / assets
  -> renderer / postprocess
  -> ConvertResult
```

核心目录：

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
├── demo/             直接调用 engine 的最小示例
├── main/             CLI 前端
└── mcp-server/       MCP server 入口
```

## 当前验证状态

截至 `2026-03-23`，最新一轮本地转换评测结果为：

- `24/24` 通过
- 平均分 `0.9858`
- `html` 平均分 `0.9948`
- `csv` 平均分 `1.0000`
- `archive` 簇与 `ocr` 簇都会在最新评测摘要里单独汇总

这轮结果对应：

- HTML 标题注入和容器展开已进入主路径
- CSV 真实解析语义已补齐到 quoted / escaped / multiline 级别
- 共享表格渲染层已经统一收敛到 `src/ast/renderer.mbt`

最新评测摘要位于 `tests/conversion_eval/reports/latest/summary.md`。

## CLI

```text
main.exe [options] <input> [output]

--frontmatter
--plain-text
--no-metadata
--asset-dir <dir>
--ocr <off|auto|force>
--ocr-lang <lang>
--ocr-images
--ocr-backend <backend>
--ocr-timeout <ms>
--diag-json
--detect-only
--dump-ast
--debug
--help
```

说明：

- `--diag-json`：输出 diagnostics / warnings / stats / metadata 的 JSON 视图。
- `--detect-only`：只执行识别与 converter 选择，不做转换。
- `--dump-ast`：输出 AST JSON，而不是 Markdown。
- `--asset-dir`：把 `OutputAsset` 与 Markdown 中的 data URI 图片写入目录并回写相对链接。
- `--ocr`：配置 OCR 策略；`force` 会尽可能执行，`auto` 只在原生文本明显不足时触发。
- `--ocr-images`：为 DOCX / PPTX / EPUB 已提取图片资产追加 OCR 结果。
- `--ocr-backend`：可选 `auto`、`mock`、`tesseract`。
- `--ocr-lang` / `--ocr-timeout`：分别控制 OCR 语言和超时；这些字段会回写到 metadata / diag JSON。
- `--debug`：在写文件模式下额外输出文本 debug report。

## 构建与测试

Windows native 构建推荐：

```bat
scripts\build.bat
scripts\test.bat
```

常用开发命令：

```bash
moon check
moon test
moon info
moon fmt
```

最小 demo：

```bash
moon run cmd/demo
```

## 质量评测与 Benchmark

转换质量回归入口：

```bash
python tests/conversion_eval/scripts/run_eval.py run
```

如果需要从外部 benchmark 仓库同步或刷新 reference：

```bash
python tests/conversion_eval/scripts/run_eval.py prepare --benchmark-root <benchmark-repo> --refresh-references
python tests/conversion_eval/scripts/run_eval.py run --benchmark-root <benchmark-repo>
```

单文件本地性能对比继续使用：

```powershell
pwsh -File scripts/benchmark.ps1 -InputPath <your-input-file> -Iterations 10
```

更多说明见 `docs/benchmark.md`。

回归纪律：

- 共享层 bug 优先补 `regression` case，而不是只人工看一次输出。
- OCR / Archive / Web 的横切改动，都应该能在 `summary.md` 的簇汇总里看到影响范围。

## 当前限制

- HTML 仍然是轻量结构恢复路径，不做 JavaScript 渲染，也没有完整 DOM / CSS 语义。
- HTML 标题去重目前以规范化后的精确匹配为主，像 `Title - Site` 这种近似标题仍可能重复。
- PDF OCR fallback 目前仍是实验线，主要用于 `mock`/受控 backend 验证，不等价于完整页渲染 OCR。
- Office / EPUB 各格式仍有细节可继续补强，但共享容器层已经稳定在当前主线上。

## 相关文档

- `docs/README.md`
- `docs/architecture.md`
- `docs/development.md`
- `docs/features/mcp.md`
- `docs/features/ocr.md`
- `docs/benchmark.md`
- `docs/KNOWN_ISSUES.md`
- `AGENTS.md`

## License

Apache-2.0
