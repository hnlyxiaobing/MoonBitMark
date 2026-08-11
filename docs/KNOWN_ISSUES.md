# Known Issues

这里只保留当前仍然会影响使用或开发判断的问题。

## OCR 仍是 bridge-backed 可选能力

- 位置：`src/capabilities/ocr/`、`scripts/ocr/bridge.py`
- 影响：OCR 依赖 Python 和可用 backend，不是纯 MoonBit 内建能力。

当前 OCR 只适合作为恢复路径：

- 图片 OCR 依赖 bridge 和 backend 可用性。
- PDF OCR 只做页级文本恢复，不提供成熟的版面理解、bbox 或表格结构恢复。
- backend 缺失、超时或 bridge 失败时，预期行为是产生 diagnostics / warnings，而不是保证成功。

## Windows native release 构建依赖 MSVC

- 位置：`scripts/build.bat`
- 影响：Windows 上的原生 release 构建不能脱离 MSVC 环境。

这不是 bug，但它是一个明确的运行边界。如果构建环境没有 `cl.exe` 或没有正确加载 MSVC 环境，`moon build --target native --release` 不会按预期工作。

## 部分 PDF 的字间空格丢失（broken_spacing）

- 位置：`src/formats/pdf/extract_native.mbt`（mbtpdf 原生抽取路径）
- 影响：某些 producer 生成的 PDF（如 `embedded-images-tables.pdf`、`code_and_formula.pdf`）抽出的文本丢失字间空格（"Theplotofinhibitor…"），密集表格也无法恢复。路由启发式已能识别并打出 `broken_spacing` flag，但仍保留原生抽取结果。
- 评测侧处理：`pdf_embedded_images_tables`、`pdf_code_and_formula` 两个 case 用 `thresholds` 钉住当前质量地板（anchors 0.5 / 0.75 等），`table_compare`、`text_order` 在空格修复前不可度量而暂时关闭。修复抽取后应上调阈值并重新启用这些检查。

## 大型富媒体 EPUB 的 spine 遍历不完整

- 位置：`src/formats/epub/`
- 影响：`simple.epub`（31MB，含视频）转换输出相对 OPF spine 提前结束，内容召回约 0.16；精选锚点全部命中。
- 评测侧处理：`epub_simple_shared_culture` 以 `thresholds.golden_markdown = 0.25` 钉住地板，完整 spine 遍历修复后上调。

## XLSX 偏移子表的布局语义与评测 reference 不一致

- 位置：`src/formats/xlsx/` 与 `tests/conversion_eval/scripts/run_eval.py` 的 xlsx reference builder
- 影响：转换器把 sheet 内偏移的子表压缩对齐，builder 按绝对列位填充；单元格内容完全一致（precision/recall = 1.0），但表格形状指标分叉。
- 评测侧处理：`xlsx_test_01` 以 `thresholds.table_compare = 0.4` 钉住地板；两者布局语义统一后上调。

## Windows 下 `@process.run("python")` 的解析依赖父进程环境

- 位置：`moonbitlang/async` 进程派生（OCR / PDF bridge 调用链）
- 影响：pyenv-win 的 shims 目录只有无扩展名 shim 和 `python.bat`，没有 `python.exe`。CLI 被某些父进程（如 Git Bash）直接 spawn 时，bridge 调用报 `The system cannot find the file specified`，OCR 静默不可用；被 python/pwsh spawn 时正常。评测 harness 从 python 派生 CLI，不受影响。
- 变通：确保 PATH 中有真实的 `python.exe`，或从 python/pwsh 上下文调用 CLI。

## PDF fallback bridge 返回的 JSON 与解析器 schema 不一致

- 位置：`scripts/pdf/bridge.py` 与 `src/formats/pdf/extract_bridge.mbt`
- 影响：fallback 抽取时 bridge 输出触发 `PDF bridge returned invalid JSON: JsonDecodeError((/provider, String::from_json: expected string))` 警告；fallback 未真正启用，仅影响诊断信息完整性。
