# Known Issues

这里只记录当前仍然有效、会影响理解或继续开发的问题，不记录已经解决的历史事项。

## 1. PDF OCR 仍是 bridge-backed recovery path，不是完整版面理解系统

- 相关文件: `src/formats/pdf/converter.mbt`、`src/capabilities/ocr/provider.mbt`、`scripts/ocr/bridge.py`
- 影响范围: 扫描版 PDF、混合文本/扫描 PDF、近空文本层 PDF

当前 PDF 已经具备：

- `mbtpdf` 默认快速文本提取
- 小型复杂文档的 `pdfminer` bridge fallback
- 页级 route
- 标题 / 列表 / 表格 / code / formula 的结构恢复
- recovery 页定向 OCR（可对 mixed 文档中的 recovery 页单独介入）
- Python bridge 下的 PDF 页渲染 -> 页级 OCR 恢复路径

但当前边界仍然清晰：

- OCR 仍依赖 Python bridge 和可用 backend，不是纯 MoonBit runtime 内建能力
- 当前只做页级文本恢复，没有 bbox / reading-order / table cell / formula layout 的 OCR 协议
- 扫描 PDF 的最终结构质量仍取决于 OCR backend 输出质量，复杂版面还不是成熟 layout engine

## 2. Windows native 构建仍有部分编码告警

- 影响范围: Windows 本地 native 构建输出

当前仓库仍有生成 C 文件相关的 `C4819` 编码 warning。它不影响功能，但会干扰构建输出可读性，后续值得继续清理。
