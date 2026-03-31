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

## 2. Windows native 构建的 `C4819` 仍是待复现债务，不是本轮阻塞项

- 影响范围: Windows 本地 native 构建输出

当前结论更精确：

- 这类 `C4819` 编码 warning 曾经出现过，属于构建输出整洁度问题
- 本轮在本地重新执行 `moon build --target native --release` 时没有复现
- 因为还没有稳定复现源，所以这项工作被降级为“待复现后再修”的下一轮债务，而不是当前功能阻塞项

后续处理顺序：

1. 只要在 CI 或本地再次稳定复现，就先记录具体生成文件和终端/代码页环境
2. 再决定是修生成 C 文件编码、工具链环境，还是仅补构建脚本中的编码约束
