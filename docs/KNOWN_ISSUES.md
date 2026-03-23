# Known Issues

这里只记录当前仍然有效、会影响理解或继续开发的问题，不记录已经解决的历史事项。

## 1. PDF 复杂文档已明显增强，但扫描件仍没有内建页渲染 OCR fallback

- 相关文件: `src/formats/pdf/converter.mbt`、`src/formats/pdf/extract_native.mbt`、`src/formats/pdf/extract_bridge.mbt`
- 影响范围: 扫描版 PDF 或几乎没有可提取文本的 PDF

当前 PDF 已经具备：

- `mbtpdf` 默认快速文本提取
- 小型复杂文档的 `pdfminer` bridge fallback
- 页级 route
- 标题 / 列表 / 表格 / code / formula 的结构恢复

但在扫描 PDF、近空文本层 PDF 上，converter 仍然只会给出 diagnostics，不会自动执行“页面渲染 -> OCR -> 结构恢复”的完整 recovery path。

这意味着：

- 文本型和大部分数字化 PDF 现在效果已经明显优于旧实现
- 扫描版 PDF 目前仍只能得到 warning / diagnostics，而不是完整 OCR fallback

## 2. Windows native 构建仍有部分编码告警

- 影响范围: Windows 本地 native 构建输出

当前仓库仍有生成 C 文件相关的 `C4819` 编码 warning。它不影响功能，但会干扰构建输出可读性，后续值得继续清理。
