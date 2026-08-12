# 已知问题解决方案（2026-08-12，v2 对抗评审修订版）

本文针对 `docs/KNOWN_ISSUES.md` 中列出的七项已知问题给出修复方案。本版按
`docs/adversarial_review_report_2026-08-12.md` 的审查意见修订：补充了 PDF 方案 A 的
详细技术设计、XML 修复的影响范围论证、XLSX 归一化的精确规则、Python 解析的边缘
情况策略，并为每项修复给出任务分解、里程碑与验收标准。文末附术语表。

**方法论说明**：文中"第一性原理"具体指——先写出该组件应满足的**最小契约/不变量**
（可判定、可测试的命题），再对照现状找出违背契约的最深一层代码，在该层做最小修复。
每项问题按「契约 → 根因 → 方案 → 任务分解与里程碑 → 验收标准 → 测试计划 → 风险与
回归策略」组织。

---

## 1. PDF 字间空格丢失（broken_spacing）

### 契约

文本抽取必须保留词边界：任何在视觉上产生词级间距的排版位移（`TJ` 数组负调整量、
`Td` 水平分量、`Tw` 词间距），都必须在输出文本中物化为空格字符。

### 根因

位移信息在解析层完好（`third_party/mbtpdf/graphics/pdfops/parse_helpers.mbt:119`
`parse_tj_op` 把数字元素保留为 `PdfObject::Real`），丢失发生在抽取层
`text/pdftext/extract.mbt:80-91` `append_text_array`：遍历时只拼接 `String` 元素，
`Real` 位移被静默丢弃；`OpTd` 的 `tx`、`OpTm`、`OpTw`、`OpTc` 全部忽略
（`OpTm` 甚至不在 match 分支中，extract.mbt:143-172）。下游 `normalize.mbt` 的
`restore_obvious_spacing` 是无词典的文本级启发式，无法判断粘连串的切分点，治本必须
在抽取层。

### 方案 A 详细技术设计（推荐）

在 `src/formats/pdf/` 新增**词距感知抽取器**（新文件 `extract_spacing_native.mbt`，
`targets: ["native"]`），替代对 `PdfText::extract_text()` 的调用。

**与 mbtpdf 的接口边界**（已逐一核实可见性）：

可直接复用的 pub API：

- `@pdfops.Op::parse_operators(pdf, resources, streams)`（graphics/pdfops/parse.mbt:18，pub）——
  content stream → Op 序列，TJ 数字保留为 `Real`。
- `@pdftextlib.PdfText::text_extractor_of_font(font_obj)`（text.mbt:205，pub）与
  `TextExtractor::codepoints_of_text`（text.mbt:316，pub）——字体解码。
- `@pdftextlib.PdfTextUtil::is_unicode / utf8_of_pdfdocstring / utf8_of_codepoints`
  （均 pub）——编码回退。
- `@pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()`、`@pdf.Pdf::lookup_direct /
  direct`（均被 pdftext 包跨包调用，必然为 pub）——页树与对象解析。

必须在本项目内复制的私有逻辑（mbtpdf 中为包内 `fn`，约 170 行）：
`extract_text_from_page`、`append_text_from_streams`（含 Form XObject 递归与 visited
去重）、`lookup_text_extractor`（含字体缓存）。

注意：`PdfText.pdf` 字段是私有的（context.mbt:5-7），但调用方在构造
`PdfText::new(pdf)` 时本就持有 `@pdf.Pdf` 引用，新抽取器直接持有该引用即可，无需
访问私有字段。

`src/formats/pdf/moon.pkg` 需新增 import `bobzhang/mbtpdf/graphics/pdfops`
（其余三个 mbtpdf 包已在 import 列表中）。

**数据流**：

```
@pdf.Pdf（已有）
  → PdfPageDoc::pages_of_pagetree()           // 逐页
  → Op::parse_operators(pdf, resources, streams)
  → op 循环（新增状态：current_font_size : Double，由 OpTf(name, size) 更新）
      OpTj(text)           → 解码拼接（同现状）
      OpTJ(Array)          → String 元素解码拼接；
                             Real(adj) 元素：若 -adj / font_size ≥ SPACE_RATIO
                             则先写一个空格再拼接
      OpTd(tx, ty)         → ty ≠ 0 换行（同现状）；
                             新增：ty == 0 且 tx / font_size ≥ SPACE_RATIO 时插空格
      OpTw(w)              → 记录词间距，供后续 Tj 内 CJK/拉丁混排判定（二期，M2 可只记录不用）
      OpSingleQuote/DoubleQuote/TStar/OpDo → 同现状
  → String（与现有 extract_text 输出同构，供 route/normalize 无缝接入）
```

`SPACE_RATIO` 为模块级常量，初值 0.25（即位移超过 1/4 字号视为词间隔，与 pdfminer
默认 word_margin 量级一致），M3 用问题 fixture 标定。`font_size` 未知（未遇到
`OpTf`）时退化为固定阈值 2.0pt，保证逻辑全分支有定义。

**错误处理**：与现有 `extract_pdf_native` 相同的 `raise` 传播策略；单页
`parse_operators` 失败时该页回退到旧 `extract_text` 结果并记录 warning，不让单页
解析失败拖垮整篇（与第 2 节 EPUB 的容错契约一致）。

**不采用方案 B（直接改 mbtpdf 库层）的原因**：`AGENTS.md` 约定 vendored mbtpdf
"只做 target/portability 修复"。M4 将最小修复整理为上游 PR，合入后本项目抽取器可
逐步退役。

### 任务分解与里程碑

- **M1（等价迁移）**：复制三个私有函数为 `extract_spacing_native.mbt`，暂不新增任何
  空格逻辑，`extract_native.mbt` 切换到新实现。完成标准：`moon test` 全绿且**无任何
  快照变化**——证明复制是行为等价的。此步隔离了"复制引入的回归"与"新逻辑引入的
  变化"。
- **M2（空格物化）**：加入 `OpTJ`/`OpTd` 空格逻辑与 `SPACE_RATIO` 常量。
  完成标准：新增单元测试通过（见测试计划），全量测试中的快照 diff 仅限问题 fixture
  相关项。
- **M3（标定与路由重估）**：用两个 fixture 标定 `SPACE_RATIO`；复核
  `route.mbt` 的 `looks_like_broken_spacing_token` 阈值与 `extract_native.mbt:190`
  `native_pages_show_broken_spacing` 的 bridge 降级条件。完成标准：两个 eval case
  的 `broken_spacing` flag 不再触发，anchors 指标回升。
- **M4（上游收敛）**：向 bobzhang/mbtpdf 提交最小修复 PR（仅 `append_text_array`
  + `OpTd` 分支）。

### 验收标准

1. `embedded-images-tables.pdf`、`code_and_formula.pdf` 输出中不再出现 ≥12 字符的
   lower→Upper 粘连 token（用 `route.mbt:548` 的判定函数直接度量）。
2. 正常 kerning 不被误拆：以既有通过评测的 PDF fixture（无 broken_spacing 的 case）
   为负样本，输出与 M1 基线 diff 为空。
3. eval：`pdf_embedded_images_tables`、`pdf_code_and_formula` 的 anchors 阈值上调至
   实测值的 90% 并重新启用 `text_order`；`table_compare` 是否启用以实测为准（无坐标
   信息，不承诺）。
4. `moon check`（native + wasm-gc）零警告；新文件不影响 stub 路径。

### 测试计划

- 新增 `extract_spacing_wbtest.mbt`：构造内存 content stream 的单元测试——
  ① `[(The) -250 (plot)] TJ` + 10pt 字号 → 输出含空格；
  ② `[(fi) -30 (ne)] TJ`（正常 kerning）→ 不插空格；
  ③ `Td 8 0` 水平移位 → 插空格；④ 无 `Tf` 的退化分支。
- 负样本回归：现有全部 PDF eval case。
- 覆盖率要求：新增分支（Real 元素、Td 水平分量、无字号退化）均被覆盖，
  `moon test --enable-coverage` + `moon coverage analyze` 核查。

### 风险与回归策略

- 阈值经验性：双 fixture 标定 + 负样本不变双重约束；阈值只升不降地保守调整。
- 输出变化波及 `route.mbt` 全链路启发式：M3 显式复核，eval 全量回归。
- 复制代码与 mbtpdf 上游漂移：M4 上游 PR 是收敛路径；在此之前在文件头注释标明
  复制来源与版本。

---

## 2. 大型富媒体 EPUB 内容召回过低（约 0.16）

### 契约

解析容错：单个无法识别的元素只影响自身，不得拖垮所在文档的其余内容；每个 spine
item 的失败被隔离并产生诊断。

### 根因（已实证的缺陷链）

1. `src/xml/tokenizer.mbt:61-89`：`<!` 后只认 `<!--` 和 `<![CDATA[`，
   `<!DOCTYPE html>` 抛 `SyntaxError` → `parse_xml` 整体失败。附带 bug：:71 的
   CDATA 检测 `xml[pos + 2] == '!'` 永假（应为 `'['`），CDATA 同样报错。
2. 兜底 `@html.html_to_blocks` 不认 `<video>/<audio>/<hgroup>`，解析失败时
   `plain_text_fragment(remaining)` 把剩余全文压成一个段落。
3. EPUB 噪声过滤器 `is_epub_reader_notice`（`src/formats/epub/converter.mbt:1385`）
   发现巨段含阅读器提示语，整段连同正文一并删除。

spine 循环本身从未中断，"提前结束"是逐 item 内容丢失的累积。

### 方案

1. **XML 层（核心修复）**：tokenizer 跳过 `<!DOCTYPE …>`；修正 CDATA 判断。
   DOCTYPE 跳过需处理内部子集：扫描到 `>` 为止，但若先遇到 `[`（内部子集
   `<!DOCTYPE root [ ... ]>`），需跳过匹配的 `]` 之后再找 `>`，避免子集内含 `>`
   时截断。
2. **可观测性**：`parse_xhtml_blocks` 返回空时 push warning。
3. **兜底加固（二期，不在本次范围）**：EPUB 侧预处理剥离 `<video>/<audio>`、展开
   `<hgroup>`，不改 `@html` 公共行为。

### 影响范围与向后兼容论证（评审意见 #2）

`src/xml` 被四个包依赖（已核实各 `moon.pkg`）：`src/formats/{xlsx,docx,pptx,epub}`。

- **DOCTYPE 跳过**：只改变"此前整体解析失败"的文档的行为（此前抛 `SyntaxError`，
  调用方走失败/兜底路径）；对不含 DOCTYPE 的文档，tokenizer 行为逐字节不变。
  OOXML（DOCX/PPTX/XLSX）的部件 XML 通常无 DOCTYPE，EPUB XHTML 通常有——修复的
  受益面主要是 EPUB，对其余三格式是净增的容错能力。
- **CDATA 修复**：同理，此前含 CDATA 的文档整体失败，修复后才可能解析成功；不存在
  "旧行为被改变"的兼容面，只有"失败变成功"。
- 结论：两处修复均为**纯增量容错**，无向后兼容风险，但需全量回归确认无意外
  交互（见测试计划）。

### 任务分解与里程碑

- **M1**：tokenizer 修复（DOCTYPE 跳过含内部子集 + CDATA 判断）+ 单元测试。
  完成标准：新增测试通过，`moon test` 全量绿（快照 diff 仅限 EPUB 相关）。
- **M2**：EPUB 空解析 warning。完成标准：构造一个无有效 block 的 spine item，
  输出 diagnostics 含 warning。
- **M3**：快照/golden 刷新与阈值上调。

### 验收标准

1. `simple_shared_culture.epub` 实测：p10 恢复 h1/h2/正文段，p20–p50 恢复 video 后
   段落，p60 恢复 transcript 主体；召回显著高于 0.16。
2. `epub_simple_shared_culture` case 的 `thresholds.golden_markdown` 从 0.25 上调至
   实测值的 90%。
3. DOCX/PPTX/XLSX 三格式的全部 eval case 指标无退化（容忍 ±0.01 浮点噪声）。

### 测试计划

- `src/xml/` tokenizer 单元测试：① `<!DOCTYPE html>` 跳过；② 带内部子集的
  `<!DOCTYPE r [ <!ENTITY x "a>b"> ]>` 不截断；③ `<![CDATA[a < b]]>` 正确产出
  文本事件；④ 非法 `<!foo` 仍报错（容错不扩大到无界）。
- 全量：`moon test --update` 后人工核对 EPUB 快照 diff；DOCX/PPTX/XLSX 快照应
  零变化（若有变化，逐一确认是容错增强而非语义改变）。
- 噪声过滤器回归：核对 `is_epub_reader_notice` 在"独立小段落"输入形态下仍精确
  删除提示语且不误删正文。

### 风险与回归策略

- 噪声过滤器输入形态变化：M3 人工核对全部 EPUB 快照。
- Gutenberg 特判路径（winter_sports）不走 XML 解析，确认不受影响。

---

## 3. XLSX 偏移子表的布局语义分叉

### 契约

转换器契约：输出对人可读的 Markdown（region 切分 + 压缩对齐是增值，保留）。
评测契约：指标比较**语义内容**而非偶然的布局表示——单元格内容 precision/recall
已为 1.0 时，形状指标不应仅因表示差异而失分。

### 根因

转换器（`src/formats/xlsx/converter.mbt`）4-连通 BFS 划 region + 包围盒压缩；
reference builder（`tests/conversion_eval/scripts/run_eval.py:633`
`build_xlsx_reference`）sheet 级单表 + 绝对列位填充。附带 quirk：
`extract_sheet_data`（converter.mbt:465）忽略 `<row r="N">` 行号，未写出 `<row>`
的空行被压缩，垂直相邻子表被 BFS 粘连合并。

### 方案

**改动 1（converter，行号修复）**：`extract_sheet_data` 按 `<row r="N">` 绝对行号
放置，缺失行补空行。消除 region 粘连 quirk，使子表切分与 producer 是否写出空行
解耦。

**改动 2（评测侧，归一化 + 配对，精确规则）**：在 `run_eval.py` 中
`parse_markdown_tables` 之后、`table_pair_score` 之前，对 output 与 reference 两侧
每张表执行 `normalize_table`：

```
normalize_table(T):
  repeat:
    1. 删除所有单元格均为空串的行
    2. 删除所有数据行（含表头）均为空串的列
  until 不动点
  若结果为空表（0 行或 0 列），从表列表中移除
```

边界情况：

- 全空表：移除，不参与配对（两侧一致处理）。
- 单行/单列退化表：正常参与，不做特殊处理。
- 表头语义不变：归一化只删全空行/列，不重选表头。

配对策略（`table_similarity` 的 greedy 配对扩展）：归一化后若两侧表数量不等，
允许**多对一配对**——内容重合度最高的一组小表可共同匹配一张大表（对应
"converter 3 个 region vs reference 1 张 sheet 大表"的情形）；cell token F1 按配对
组聚合计算，shape 分在配对组内比较。实现分两小步：先上 `normalize_table`（预期
解决前导/尾随空行列的形状分叉），若 `xlsx_test_01` 实测仍失真再启用多对一配对。

**worked example**（sheet2 实际布局：主表 A1:D9、右子表 G5:I9、下子表 C14:E18）：
行号修复后 converter 产出 3 张压缩表；reference 是 1 张 9 列宽表（G–I 列前有绝对
空列）。`normalize_table` 裁不掉大表**中间**的空列（只裁首尾），形状仍分叉——这正
是需要多对一配对的场景；配对后 cell F1 = 1.0 主导得分，shape 在组内收敛。

**否决方向**：builder 镜像 converter 启发式（双语言维护 drift 风险）；converter 改
绝对布局单表（毁掉用户向价值）。

### 任务分解与里程碑

- **M1**：converter 行号修复 + `moon test --update`（wbtest 快照
  `converter_wbtest.mbt:83` 预期变化，人工核对 region 切分正确）。
- **M2**：`normalize_table` 落地 + eval 重跑。
- **M3**（视 M2 结果）：多对一配对扩展。
- **M4**：阈值上调、golden refresh。

### 验收标准

1. `xlsx_test_01` 的 `table_compare` 实测值显著高于当前 0.44，阈值从 0.4 上调至
   实测值的 90%。
2. `xlsx_stanley_cups` case 无退化。
3. 行号修复后 region 切分对"空行是否写出 `<row>` 元素"不敏感（构造两种写法的
   等价 fixture 各跑一次，region 数量一致）。

### 测试计划

- converter：wbtest 覆盖 `<row r="5">` 跳行、缺失行补空。
- 评测侧：`normalize_table` 的 Python 单元测试（若 harness 无测试框架，则以
  doctest 或独立脚本断言）：全空表移除、仅首列空、中间空列保留。
- 数据准备：复用 `test_01.xlsx`；为行号不敏感性构造的等价 fixture 用脚本生成
  （同一 sheet XML，一种省略空行 `<row>`，一种写出）。

### 风险与回归策略

- golden 文件入库，builder/指标改动后 `--refresh` 并逐行审查 diff。
- 配对策略改动影响所有含表格的 case（docx/pdf 等也走 table 指标）：eval 全量回归，
  非 xlsx case 指标不应变化（归一化对无空行列的表是恒等变换）。

---

## 4. PDF fallback bridge JSON schema 不一致

### 契约

跨进程边界遵循健壮性原则：消费者宽容处理等价表示（`null` 与 `""` 对可选字符串
语义等价），不因表示差异整体放弃 fallback。

### 现状与方案

bridge 侧已在提交 e625524 修复（可选字段发 `""` 代替 `null`），`KNOWN_ISSUES.md`
条目已过时。剩余工作：

1. **复测关闭**：用一个能触发 fallback 的 PDF（native 抽取质量差 + pdfminer 可用）
   验证 `invalid JSON` 警告消失、fallback 结果被采用，然后从 `KNOWN_ISSUES.md`
   移除条目。
2. **解码加固（小改）**：`extract_bridge.mbt` `parse_pdf_bridge_response` 解码成功后
   把 `Some("")` 归一为 `None`，消除 `""`/`None` 语义漂移（当前依赖
   `available=false` 时不消费 provider 的隐式契约，脆弱）。

### 验收标准

- fallback 路径无 `invalid JSON` 警告；`normalize.mbt:11` 的 `Some("pdfminer")`
  匹配行为不变。
- 手工向 bridge 输出注入 `"provider": null`（旧版输出重放），确认不再崩溃而是
  降级为 warning —— 若选择自定义 `FromJson` 容忍 `null` 则直接通过。

---

## 5. OCR 作为 bridge-backed 可选能力

### 契约

OCR 是架构性可选能力：失败路径只产生 diagnostics，绝不抛错中断转换（image/pdf/
epub/docx/pptx converter 与 `apply_ocr_metadata` 均依赖此契约，必须保持）。可改进
的是诊断**可定位性**与脚本路径的**位置无关性**。

### 方案

1. **脚本路径解析**：`src/capabilities/ocr/provider_native.mbt:53` 的相对路径
   `scripts/ocr/bridge.py` 改为：优先 `MOONBITMARK_OCR_BRIDGE` 环境变量；否则基于
   可执行文件位置向上探测 `scripts/ocr/bridge.py`；再退化到 CWD 相对路径（现状）。
   同样处理 `scripts/pdf/bridge.py` 的调用点。
2. **诊断分层**：spawn 失败 / 输出 JSON 缺失 / JSON 解析失败 / backend 缺失 /
   超时，在 warning 文案中明确区分并给出对应 remedy。

### 验收标准与测试

- 从非仓库根目录运行 CLI 处理图片：OCR 正常或产生准确诊断。
- 分别模拟 Python 缺失 / tesseract 缺失 / 超时三种故障，warning 文案可区分。
- 全部既有 OCR 相关测试（含 mock backend 路径）无退化。

---

## 6. Windows 下 `@process.run("python")` 解析失败

### 契约

进程派生不隐式依赖父进程环境：调用方显式解析出解释器的真实绝对路径再 spawn。
（`moonbitlang/async@0.20.4` 在 Windows 把 `"python"` 硬拼 `.exe` 后直接
`CreateProcessW`，不做 PATHEXT 匹配；pyenv-win shims 目录无 `python.exe`。async 是
固定版本外部依赖，不在本仓库修改。）

### 方案：Python 解释器解析策略（含边缘情况）

新增公共 helper（如 `src/core/python_resolver_native.mbt` + stub），
`resolve_python() -> String?` 按以下**固定优先级**返回第一个验证通过的候选，
验证方式是以候选路径执行 `--version` 并能正常退出、输出可解析且版本 ≥ 3.8：

1. `MOONBITMARK_PYTHON` 环境变量（显式覆盖，最高优先级；设置了但不可运行则直接
   报错并提示，不再 fallback——显式配置错误应快速失败）。
2. 激活的虚拟环境：`VIRTUAL_ENV/Scripts/python.exe`、`CONDA_PREFIX/python.exe`。
   优先于系统 PATH，因为 bridge 依赖（pdfminer/pypdfium2）通常装在 venv 里。
3. PATH 中逐目录探测 `python.exe` 真实文件（`fs` 存在性检查），**跳过 pyenv-win
   shims 目录**（识别特征：目录下存在 `pyenv`/`pyenv.bat` 或无扩展名 shim）。对
   每个候选跑 `--version` 验证——shim 目录即便意外混入也无法通过验证。
4. `py.exe -3`（Pylauncher，pyenv 与官方安装器均兼容）。
5. pyenv-win 直探：`%PYENV_ROOT%\versions\*\python.exe`（及默认
   `%USERPROFILE%\.pyenv\pyenv-win\versions\*`），多版本共存时取**版本号最高**者。

边缘情况决策（评审意见 #4）：

- **多版本共存**：不追求"最新"，追求"第一个可运行且 ≥3.8"；仅 pyenv 直探分支
  取最高版本（该分支本身就是兜底）。backend 可用性（pdfminer 等）不在 resolver
  职责内，仍由 bridge.py 自检并在 warnings 中报告——resolver 只保证"有一个能跑
  的 Python"。
- **虚拟环境检测**：即上述第 2 条；不尝试激活 venv，直接使用其解释器绝对路径。
- **缓存**：进程内缓存解析结果，避免同一转换运行内重复探测。
- **禁止路径**：不传 `python.bat`（CreateProcessW 不能执行 bat），不用 `cmd /c`
  包装（引入转义与注入面）。
- 解析失败：返回 `None`，两处调用点产生明确诊断"未找到可用的 Python 解释器，
  请安装 Python ≥3.8 或设置 MOONBITMARK_PYTHON"。

应用到两处调用点：`src/capabilities/ocr/provider_native.mbt:82`、
`src/formats/pdf/extract_bridge.mbt:26`。

### 验收标准与测试

- pyenv-win 环境下从 Git Bash 直接 spawn CLI：OCR 与 PDF bridge 均可用。
- 从 python/pwsh 上下文回归：无退化。
- 设置 `MOONBITMARK_PYTHON` 指向无效路径：快速失败且诊断明确。
- 单测：候选优先级排序（用临时目录构造伪 `python.exe` 与伪 shim 目录）、
  版本解析、`None` 路径。版本比较逻辑（`>=3.8`、最高版本选择）用纯函数单测覆盖。

---

## 7. Windows native release 构建依赖 MSVC

### 契约

MSVC 是既定运行边界（`moonpkg.json` 固定 `cc: cl.exe`，async 的 FFI C 源必须经它
编译），不可消除；可改进的是**尽早失败 + 可操作指引**。

### 方案

增强 `scripts/build.bat` 前置检查：

1. `cl.exe` 存在性预检，缺失时输出指向 Visual Studio Build Tools 下载页的提示并
   以非零码退出；
2. vcvars64 探测从单一硬编码路径扩展为：环境变量 `MOONBITMARK_VCVARS64` →
   `vswhere`（若可用）→ BuildTools/Community/Professional 常见安装路径枚举。

### 验收标准

- 无 MSVC 环境：秒级失败、提示清晰；有 MSVC 环境：构建通过。
- `KNOWN_ISSUES.md` 该条目改写为"环境要求"小节（边界说明而非 issue）。

---

## 实施顺序、里程碑与全局验收

| 阶段 | 内容 | 里程碑出口标准 |
|---|---|---|
| P0-a | #4 bridge schema 复测 + 解码加固 | fallback 无 invalid JSON 警告，条目关闭 |
| P0-b | #2 XML tokenizer 修复（M1）+ EPUB warning（M2） | tokenizer 单测通过，全量测试绿，EPUB 召回实测达标，阈值上调 |
| P0-c | #3 行号修复（M1）+ 归一化（M2） | wbtest 快照核对通过，`xlsx_test_01` table_compare 实测回升 |
| P1-a | #6 Python resolver（两处接入） | Git Bash/pwsh/python 三上下文 OCR 均可用 |
| P1-b | #1 词距感知抽取器（M1→M3） | M1 零快照变化；M3 broken_spacing flag 不再触发，阈值上调 |
| P2 | #5 OCR 路径与诊断；#7 build.bat 预检 | 诊断分层文案落地，无行为回归 |
| 二期 | #2 EPUB 兜底媒体预处理；#1 带坐标 span 流（表格恢复）；#1 M4 上游 PR | 另行立项 |

全局纪律（每项修复的 Definition of Done）：

1. `moon check` 在 native 与 wasm-gc 双 target 零错误零警告；
2. `moon test` 绿（快照更新必须 `moon test --update` 后人工逐 diff 核对）；
3. 对应 eval case 重跑，阈值上调至实测值 90%，golden 如需 refresh 必须审查 diff；
4. 修复一项即从 `KNOWN_ISSUES.md` 移除一项；
5. 收尾 `moon info && moon fmt`，检查 `.mbti` diff 符合预期；
6. vendored mbtpdf 只限 target/portability 修复，功能修复走上游 PR。

依赖关系：#1 M3 依赖 P0-a 完成（bridge fallback 可用才能对照验证降级路径）；
#3 M3 依赖 M2 实测结果；其余各项相互独立，可并行。

---

## 术语表

- **TJ / Tj**：PDF content stream 的文本绘制操作符。`Tj` 绘制单个字符串；`TJ` 绘制
  数组，数组中数字元素表示字形间位移调整量（负数 = 拉大间距，单位 1/1000 em）。
- **Td / TD / Tm / Tw / Tc / Tf**：PDF 文本状态/定位操作符：相对定位、文本矩阵、
  词间距、字间距、字体与字号设置。
- **Form XObject**：PDF 中可复用的内容块，`Do` 操作符调用；文本可能嵌套在其中，
  抽取需递归进入。
- **broken_spacing flag**：`src/formats/pdf/route.mbt` 的路由启发式标记，token ≥12
  字符且含 lower→Upper 或 letter→digit 边界时计数，用于识别字间空格丢失。
- **spine / OPF / manifest**：EPUB 结构：OPF 是包描述文件，manifest 列出全部资源，
  spine 定义阅读顺序（itemref 指向 manifest 项）。
- **region（XLSX）**：转换器对 sheet 内 4-连通非空单元格聚类得到的子表区域，输出时
  按包围盒压缩对齐。
- **golden / thresholds**：conversion_eval 的基准文件与通过阈值；`thresholds.*` 钉住
  当前质量地板，修复后应上调。
- **shim（pyenv-win）**：版本管理器放在 PATH 中的转发脚本（无扩展名文件 +
  `python.bat`），不是真实解释器；`CreateProcessW` 无法执行。
- **PATHEXT**：Windows shell（cmd.exe）的可执行扩展名匹配机制；`CreateProcessW`
  API 不实现该机制。
- **vcvars64.bat**：MSVC 环境初始化脚本，加载 `cl.exe` 所需的环境变量。
- **wbtest / `_wbtest.mbt`**：MoonBit 白盒测试文件，可访问包内私有定义。
