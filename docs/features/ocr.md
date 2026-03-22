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
- PDF 在启用 OCR 时会给出明确 diagnostics，但当前没有内建页渲染 OCR fallback

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

## 当前限制

- 不支持内建 PDF 页渲染。
- 不提供 bbox、版面分析或表格结构 OCR。
- 不主动对 HTML 外链图片做 OCR。
