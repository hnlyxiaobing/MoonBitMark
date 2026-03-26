# Known Issues

这里只记录当前仍然有效、会影响理解或继续开发的问题，不记录已经解决的历史事项。

## 1. PDF 扫描件仍缺真正的 page-rendering OCR backend

- 相关文件: `src/formats/pdf/converter.mbt`、`src/formats/pdf/route.mbt`、`src/formats/pdf/diagnostics.mbt`
- 影响范围: 扫描版 PDF、混合文本/扫描 PDF、近空文本层 PDF

当前 PDF 已经具备：

- `mbtpdf` 默认快速文本提取
- 小型复杂文档的 `pdfminer` bridge fallback
- 页级 route
- 标题 / 列表 / 表格 / code / formula 的结构恢复
- 基于 OCR 配置的恢复性正文注入路径

但当前仍然缺少真正的**页面渲染 -> 页级 OCR -> 结构恢复**后端，因此扫描 PDF 仍有明显边界：

- 现有 recovery 更接近“实验性补救路径”，还不是成熟的 page-rendering pipeline
- mixed 文档里被标记为 recovery 的页面仍可能只能给出 diagnostics / warning
- 全扫描 PDF 的正文恢复效果仍依赖外部 OCR backend 和当前 bridge 能力

## 2. Windows native 构建仍有部分编码告警

- 影响范围: Windows 本地 native 构建输出

当前仓库仍有生成 C 文件相关的 `C4819` 编码 warning。它不影响功能，但会干扰构建输出可读性，后续值得继续清理。
