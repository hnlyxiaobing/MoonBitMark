# PDF Recovery / OCR Optimization Plan

## Goal

在不破坏现有 MoonBitMark 架构的前提下，补齐 PDF recovery/OCR 的真实短板，并确保针对扫描 PDF / 近空文本层 PDF 的转换效果和可观察性优于本地 `MarkItDown` baseline。

## Findings

### Current MoonBitMark strengths

- `mbtpdf` 主路径已经很强，普通可提取文本 PDF 的质量显著高于 `MarkItDown`
- 已有 page route、`pdfminer` fallback、结构恢复、OCR capability layer 和 diagnostics 基础设施
- CLI 和 eval harness 已有 `--ocr-*` 参数、`--diag-json` 和 conversion-eval 入口

### Current MoonBitMark weaknesses before this round

- PDF OCR 只在“整份文档全部 recovery 页”时才尝试，mixed PDF 无法真正恢复
- recovery 注入把整份 OCR 文本复制到每个 recovery 页，没有页级对齐能力
- OCR bridge 对 PDF 仍按整份文件处理，没有真正的页渲染 / 页级 OCR 路径
- diagnostics 把 OCR recovery 混同为 text fallback，出现 `fallback provider: mbtpdf` 这类误导信息
- conversion-eval 虽然支持 baseline 对比，但默认只看当前 Python，导致本地已安装的 `markitdown/docling` baseline 可能被误报 unavailable

### MarkItDown comparison

本地 baseline 代码确认 `MarkItDown` 的 PDF 路径本质上是：

- `pdfminer.high_level.extract_text(local_path)`
- 无页级 route
- 无 recovery-only / mixed recovery 判定
- 无 bridge-backed PDF OCR fallback

因此在扫描 PDF、近空文本层 PDF、多页 recovery 的场景下，MoonBitMark 只要把页级 OCR recovery 打通，就能明显超过 `MarkItDown`。

## Implemented plan

1. 保持架构边界不变
   - 继续使用 `src/capabilities/ocr/` + `scripts/ocr/bridge.py`
   - 不把 Python / OCR 逻辑塞回 MoonBit 主链

2. 为 PDF bridge 增加页渲染能力
   - OCR bridge 新增 PDF 输入分支
   - 通过 `pypdfium2 + PIL` 渲染指定 PDF 页
   - 支持 recovery 页号定向 OCR
   - 当前 Python 缺依赖时自动委托到本机 baseline venv

3. 打通 mixed PDF recovery
   - 只要 route 中存在 recovery 页，就允许 PDF OCR recovery 介入
   - 不再要求整份文档必须全部 recovery 才能尝试 OCR

4. 修正页级注入
   - OCR bridge 返回页分隔 marker
   - MoonBit PDF converter 只替换 recovery 页，并按页对齐注入
   - 避免“一份 OCR 文本复制到所有 recovery 页”的旧问题

5. 修正 observability 语义
   - `pdf_text_fallback_used` 只表示 `pdfminer` 之类的 text fallback
   - OCR recovery 使用现有 `ocr_fallback_used`
   - diagnostics 不再把 OCR recovery 误报为 text fallback provider

6. 补强验证
   - 新增 PDF recovery whitebox tests
   - 新增 `tests/ocr/pdf_ocr_force_smoke.ps1`
   - 新增 `pdf_scanned_multi_page_mock_ocr` conversion-eval case
   - baseline harness 自动发现 baseline venv，重新打通 `MarkItDown` / `Docling` 对比

## Verification target

- MoonBitMark 对单页和多页扫描 PDF mock recovery 均可稳定产出正文
- mixed / recovery 页逻辑有 whitebox test 覆盖
- OCR smoke、PDF smoke、conversion-eval 全部通过
- conversion-eval baseline 报告能直接显示 MoonBitMark 高于 `MarkItDown`

## Residual limits

- 仍无 bbox/layout OCR 协议
- 仍不是完整版面理解系统
- 真实 OCR 上限仍取决于 backend（例如是否安装 `tesseract`）
