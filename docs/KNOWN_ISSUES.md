# Known Issues

这里只保留当前仍然会影响使用或开发判断的问题。

## OCR 仍是 bridge-backed 可选能力

- 位置：`src/capabilities/ocr/`、`scripts/ocr/bridge.py`
- 影响：OCR 依赖 Python 和可用 backend，不是纯 MoonBit 内建能力。

当前 OCR 只适合作为恢复路径：

- 图片 OCR 依赖 bridge 和 backend 可用性。
- PDF OCR 只做页级文本恢复，不提供成熟的版面理解、bbox 或表格结构恢复。
- backend 缺失、超时或 bridge 失败时，预期行为是产生 diagnostics / warnings，而不是保证成功。

健壮性现状（2026-08-12 起）：Python 解释器经 `src/python/` 的 resolver 显式解析
（可用 `MOONBITMARK_PYTHON` 覆盖），bridge 脚本路径按可执行文件位置探测
（可用 `MOONBITMARK_OCR_BRIDGE` / `MOONBITMARK_PDF_BRIDGE` 覆盖），失败诊断已按
"脚本缺失 / Python 缺失 / spawn 失败 / 依赖缺失 / 超时 / backend 缺失"分层并附
remedy。

## Windows native release 构建依赖 MSVC（环境要求）

- 位置：`scripts/build.bat`
- 影响：Windows 上的原生 release 构建不能脱离 MSVC 环境。

这不是 bug，而是运行边界。`scripts/build.bat` 会按 `MOONBITMARK_VCVARS64` →
vswhere → 常见安装路径枚举的顺序探测 vcvars64，并在加载后预检 `cl.exe`；环境不
满足时会尽早失败并给出指向 Visual Studio Build Tools 下载页的提示。

## PDF 抽取的已知残留

- 位置：`src/formats/pdf/extract_spacing_native.mbt`（词距感知原生抽取路径）
- 影响：字间空格恢复（TJ 位移 / Td 水平移动物化）已覆盖主要场景，但仍有残留：

  - `OpTm` 定位产生的词间间隙未恢复（`Tm` 的 e 分量含已排文本宽度，无字宽信息
    无法精确换算），每个问题 fixture 残留约 ≤3 个粘连 token。
  - `OpTw`（词间距）/ `OpTc`（字间距）仍忽略。
  - 无坐标/bbox 输出，密集表格结构不可恢复，`pdf_embedded_images_tables` case 的
    `table_compare` 保持关闭。

- 固化副本继承的上游 mbtpdf 问题：含重复 object 定义的 PDF（如 `code_and_formula.pdf`）页树
  遍历会丢页（第 2 页"Formula"一节缺失），导致该 case 的 `text_order` 暂未启用；
  修复需上游处理，见 `docs/solution_plan_2026-08-12.md` 第 1 节 M4。仓库内联的
  `third_party/mbtpdf` 只跟随 target/portability 修复，不做行为改动。
## EPUB HTML 兜底路径的媒体元素处理（二期项）

- 位置：`src/formats/html/converter.mbt`、`src/formats/epub/converter.mbt`
- 影响：spine XHTML 的 XML 解析路径已修复（tokenizer 支持 DOCTYPE/CDATA），良构
  XHTML 不再触发该问题；但 HTML 兜底路径遇到 `<video>/<audio>/<hgroup>` 等未知
  标签时仍会把剩余内容压成一个段落。二期方案：EPUB 侧在调用兜底前预处理剥离
  媒体元素、展开 `hgroup`，不改动 `@html` 公共行为。
## Word 二进制（.doc/.wps）转换的已知残留

- 位置：`src/formats/doc/converter.mbt`、`src/ole2/cfb.mbt`（0.4.0 新增）
- 影响：Word 97-2003 二进制（.doc）与 WPS Writer 二进制（.wps）已可转换为
  Markdown（标题 / 段落 / 简单 pipe 表格 / SummaryInformation 元数据），但受
  FIB/FKP/PAPX 子集解析限制，仍有以下残留：

  - **字符级格式不恢复**：仅恢复段落样式 `istd` 到内置 Heading 1-9 的映射，
    run 级 bold/italic/underline/字号/颜色均丢弃。
  - **字段代码不展开**：`Plcffld` 未解析，页码、TOC、超链接、交叉引用等字段
    显示为原始结果文本（Word 已缓存的结果），不解析域代码本身。
  - **图片 / OLE 嵌入对象不提取**：内嵌图片（PIC 字段 / Escher 记录）与嵌入
    对象被忽略，转换结果只含文本。
  - **批注与修订标记不解析**：注解字符（0x05）与 track changes 标记不还原。
  - **页眉页脚 / 脚注尾注**：hdrftr / footnotes 分区未提取。
  - **合并单元格与嵌套表格**：pipe 表格按单元格段落顺序渲染，`gridSpan` /
    `vMerge` 合并信息不处理。
  - **非 cp1252 的 8-bit piece 会乱码**：8-bit piece 固定按 cp1252 解码；
    中文等使用 UTF-16LE piece 的文档正常，但以 GBK 存储的 8-bit piece 会乱码
    （诚实降级，不静默丢弃）。
