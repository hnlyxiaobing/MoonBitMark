# Image Fixtures

这些图片样本由 `fixtures/source_manifest.json` 从 benchmark 仓库同步。

当前主要用途：

- 把 `image` 正式纳入 `conversion_eval` 的格式覆盖范围
- 使用 `--ocr force --ocr-backend mock` 做稳定、可重复的 OCR smoke / edge 评测

如需测试真实 OCR backend，请在独立 case 中显式声明对应 CLI 参数，并接受评测环境差异会提高波动性。
