# Known Issues

这里只保留当前仍然会影响使用或开发判断的问题。

## 0.4.3 及更早的发布版本在消费者侧无法编译（请使用 >= 0.4.4）

- 位置：mooncakes registry 上的 `hnlyxiaobing/moonbitmark` 历史版本
- 影响：引用 `*@0.4.3` 及更早版本的模块 `moon check --target native` 直接失败。逐版本
  实测（独立消费者模块，仅依赖 registry 版本）：

  | 依赖版本 | 结果 |
  | --- | --- |
  | 0.3.0 / 0.4.0 / 0.4.1 / 0.4.2 / 0.4.3 | `Failed with 0 warnings, 7 errors` |
  | 0.4.4 | 0 error / 0 warning |

  7 个错误全部来自下载到 `.mooncakes/bobzhang/mbtpdf/` 的源码
  （`document/pdftree/pdftree.mbt:157`、`font/pdfcmap/pdfcmap.mbt:150,366`、
  `font/pdfglyphlist/pdfglyphlist.mbt:3650`、`syntax/pdfgenlex/pdfgenlex.mbt:198,200,209`），
  内容为 ``Value parse_int / parse_double not found in package `strconv` ``。- 原因：这些版本的 PDF 支持依赖 registry 版 `bobzhang/mbtpdf@0.1.2`（上游最新，
  2026-01-28），而该版本仍调用当前工具链已从 `moonbitlang/core/strconv` 移除的
  `parse_int` / `parse_double`（相关 API 已迁至 `@string`）。本仓库内能通过是因为
  `moon.work` 曾把 mbtpdf 重定向到打过补丁的 `third_party/mbtpdf`，消费者拿不到该重定向。
- 现状：**0.4.4 起已把 `third_party/mbtpdf` 内联进本模块**并重写导入路径，不再依赖
  registry 版 mbtpdf；消费者侧 `moon check --target native` 为 0 error / 0 warning，
  且可实际完成 PDF → Markdown 转换。
- 处置限制：mooncakes 不提供模块所有者自助 yank 单个版本的能力。CLI 只有
  `moon deprecate`，它作用于整个模块的所有版本（`--reason` 标记 / `--undo` 撤销），
  会把 0.4.4 一起标记，且官方文档明确说明"Deprecation does not affect version
  selection"；网页端（`moonbitlang/mooncakes.io`）的 yank 相关代码仅为只读展示
  （`decode_yanked`、`yanked_banner`、`version_selector.current_yanked`），无所有者入口。
- 建议：新项目直接使用 `>= 0.4.4`（`moon view hnlyxiaobing/moonbitmark` 的 Latest
  已是 0.4.4，默认解析不会命中 0.4.3）；只有显式 pin 旧版本或沿用旧 lockfile 的项目
  会踩到该问题。若要彻底隐藏 0.4.3，需向 mooncakes 维护方申请管理员级 yank。

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
