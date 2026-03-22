# Known Issues

这里只记录当前仍然有效、会影响理解或继续开发的问题，不记录已经解决的历史事项。

## 1. `libzip` Dynamic Huffman 解压仍不稳定

- 相关文件: `src/libzip/deflate.mbt`
- 影响范围: 依赖 ZIP 容器解压的格式，尤其是部分 PPTX / DOCX / XLSX / EPUB 样本

当前 `Stored` 和 `Fixed Huffman` 路径可用，但 `Dynamic Huffman` 仍有缺陷。仓库里的 `src/libzip/zip_easy_test.mbt` 也明确把动态 Huffman 校验保留为非严格验证。

这意味着：

- 某些 Office / EPUB 文件可能无法正常解压或转换失败
- 排查这类问题时，应先确认样本是否走到了 Dynamic Huffman 分支

## 2. PDF 复杂文档已明显增强，但扫描件仍没有内建页渲染 OCR fallback

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

## 3. Windows native 构建仍有部分编码告警

- 影响范围: Windows 本地 native 构建输出

当前仓库仍有生成 C 文件相关的 `C4819` 编码 warning。它不影响功能，但会干扰构建输出可读性，后续值得继续清理。
