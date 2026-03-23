# OCR Support

## 当前实现

OCR 是一个独立能力层，入口在 `src/capabilities/ocr/`，通过 `ConvertContext.ocr` 注入各 converter，而不是由 CLI 或单个格式私自拼接逻辑。

相关代码：

- `src/capabilities/ocr/types.mbt`
- `src/capabilities/ocr/provider.mbt`
- `src/formats/image/converter.mbt`
- `src/formats/docx/converter.mbt`
- `src/formats/pptx/converter.mbt`
- `src/formats/epub/converter.mbt`
- `src/formats/pdf/converter.mbt`

## CLI 选项

```text
--ocr <off|auto|force>
--ocr-lang <lang>
--ocr-images
--ocr-backend <auto|mock|tesseract>
--ocr-timeout <ms>
```

## 当前支持范围

- 独立图片文件 OCR
- DOCX / PPTX / EPUB 嵌图 OCR 补充
- PDF 实验性 page-level OCR fallback
- PDF 当前已有 `mbtpdf` + `pdfminer` bridge 的文本提取/回退链路；OCR 只在恢复路径上补充证据，不重排文本主路径

## Backend 机制

MoonBit 侧通过 `scripts/ocr/bridge.py` 调外部 backend：

- `auto`: 自动选择可用 backend
- `mock`: 测试用固定输出
- `tesseract`: 强制调用系统里的 `tesseract`

推荐做法：

- 自动化测试优先用 `mock`
- 本地手工验收再用 `tesseract`

## 行为原则

- OCR 不应破坏原始转换结果。
- backend 缺失或执行失败时，优先产生 warning / diagnostics，而不是直接让整个转换失败。
- 嵌图 OCR 只是补充内容，不替代原始正文解析。
- metadata / diag JSON 统一输出 `ocr_mode`、`ocr_backend`、`ocr_lang`、`ocr_timeout`、`ocr_images`。
- 消费层应尽量回写 `ocr_attempted`、`ocr_available`、`ocr_provider`、`ocr_fallback_used` 等证据字段。

## 当前限制

- PDF OCR 仍偏实验线；当前更适合受控测试或 mock backend 验证，不等价于成熟版面 OCR。
- 不提供 bbox、版面分析或表格结构 OCR。
- 不主动对 HTML 外链图片做 OCR。
