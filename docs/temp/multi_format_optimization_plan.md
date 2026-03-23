# MoonBitMark 多格式文档转换整体优化方案

## 0. 文档定位

本文档用于指导 MoonBitMark 在 PDF 阶段性优化之后，如何推进其余输入类型的提质提效工作。覆盖范围包括：

- TXT
- CSV
- JSON
- Image
- HTML / XHTML / URL
- DOCX
- PPTX
- XLSX
- EPUB

本文档不追求一次性定义每个格式的全部细节实现，而是先确定：

1. 优化策略应采用什么总方法
2. 哪些问题应先从全局层解决
3. 哪些格式应按共享能力分组推进
4. 每个阶段的目标、产出与退出标准是什么

## 1. 当前项目状态快照（2026-03-23）

当前仓库已经不是“只有若干独立 converter 的集合”，而是一个带有统一入口和共享能力层的多格式引擎：

- 统一入口位于 `src/engine/`
- 统一结果模型位于 `src/core/`
- 统一文档表示与 Markdown 渲染位于 `src/ast/`
- OCR 能力位于 `src/capabilities/ocr/`
- ZIP 与 XML 基础设施位于 `src/libzip/` 与 `src/xml/`

当前格式支持已经覆盖：

- TXT
- CSV
- JSON
- PDF
- Image
- HTML / XHTML / URL
- DOCX
- PPTX
- XLSX
- EPUB

其中最重要的结构性事实有两点：

1. `DOCX / PPTX / XLSX / EPUB` 并不是四套互不相关的实现，它们共享 `libzip + xml` 基础设施
2. `Image / DOCX / PPTX / EPUB` 已经与 OCR 能力发生耦合，后续 PDF 扫描件恢复也大概率会进一步共享 OCR 能力层

因此，后续优化如果完全按格式逐个孤立推进，会产生明显重复劳动；但如果直接做一轮大而全的系统重构，也会拖慢产出节奏。

截至当前工作区最新状态，基线建设已经明显推进：

- `tests/conversion_eval/` 已覆盖：
  - `csv`
  - `docx`
  - `epub`
  - `html`
  - `image`
  - `json`
  - `pdf`
  - `pptx`
  - `text`
  - `xlsx`
- 当前最新评测结果为：
  - `29/29` 通过
  - 平均分 `0.9894`
- conversion eval 报告已补入：
  - `By Cluster` 视图：`archive / web / ocr`
  - `By Tier` 视图：`smoke / quality / regression / edge`
  - `OCR Evidence` 视图：`attempted / available / forced / fallback used`
- regression 样本已成为常规交付物，当前新增 regression `5/5` 通过
- baseline 已纳入同一套报告：
  - `markitdown`：当前环境 unavailable
  - `docling`：当前环境 unavailable
- `image` 已正式纳入评测矩阵，并支持通过 case 级 `cli_args` 固定
  `--ocr force --ocr-backend mock`
- `epub` 已做过一轮专门的输出收敛，当前 quality case 已可通过

这意味着：

- 阶段 0 的“统一基线 + 最小样本集 + baseline 报告”已经基本成立
- 阶段 1 已取得实质进展：`libzip` Dynamic Huffman 已修复并进入严格测试
- `core` 已开始收敛共享文件读取 / 路径 helper，以及 OCR / asset 约定
- AST 共享渲染层已经开始承担表格列宽补齐与换行收敛，属于典型的“一处修复，多格式受益”
- 阶段 2 中 `DOCX / PPTX / XLSX / EPUB` 的第一轮质量补强已经取得结果
- 阶段 3 与阶段 5 已分别进入第二轮轻量提质：HTML 的正文噪声清理和 failure diagnostics 已继续补强，CSV / JSON / TXT 的收尾与退化策略也已进入主线

## 1.1 阶段完成度判断

基于当前仓库状态，可以把执行进度粗略判断为：

- 阶段 0：基本完成
- 阶段 1：已完成第一轮关键治理，并已继续收敛共享读取 helper、BOM 处理和表格渲染约定
- 阶段 2：已完成第一轮可用补强，但还未进入共享层稳定后的系统提质阶段
- 阶段 3：已有样本与评测覆盖，并已完成一轮 HTML 标题注入与容器展开补强，但复杂 DOM 仍有上限
- 阶段 4：已有 OCR 能力与 metadata 模式，但还未完全能力化收敛
- 阶段 5：已开始第一轮“正确性补强”，CSV 真实解析语义与 TXT/JSON 的 BOM 安全读取已落地，但仍未完成全部退化策略和输出抛光

## 1.2 本轮已落地进展（2026-03-23）

相对上一版快照，本轮已经新增以下已落地主线变化：

- `src/formats/csv/` 已从简单逗号切分升级到支持 quoted cell、escaped quote、multiline cell 的真实解析语义，并补入 delimiter 自动探测与 ragged row diagnostics
- `src/core/file_helpers.mbt` 新增 UTF-8 BOM 清理 helper，`csv/json/text/html` 已统一复用共享读取路径
- `src/ast/renderer.mbt` 已统一表格列宽补齐与单元格换行收敛，这会同时影响 CSV / HTML / XLSX 等共享 `Table` block 的格式
- `src/formats/html/` 已补入 `<title>` 注入、`div/section/article/main` 容器展开以及 `nav/aside/footer` 噪声削减，常见页面正文抽取质量已继续提升
- `src/core/conversion_helpers.mbt` 已统一扩展 OCR metadata 字段，`docx/pptx/xlsx/epub/pdf` 已共享复用
- `src/formats/pdf/` 已接入 page-level OCR fallback 实验线，并通过专门 regression case 记录 OCR 介入证据
- `src/formats/json/` 已统一 pretty-print 与 invalid JSON 退化路径，`src/formats/text/` 已补入段落折行归并
- 最新 conversion eval 已提升到 `29/29`、平均分 `0.9894`，其中 regression `5/5` 全通过

## 2. 总策略结论

MoonBitMark 下一阶段最合适的路线不是：

- 完全逐格式、顺序排队地优化
- 也不是先做一次大规模全局重构再开始提质

推荐路线是：

**先做轻量全局分析，建立统一基线与共享瓶颈清单；再按“共享能力簇”逐组优化；组内再按业务价值和风险逐格式深挖。**

可以概括为三步：

1. 全局摸清地图
2. 按共享基础设施分簇
3. 组内逐格式提质

这是当前项目最优的平衡点，因为它同时兼顾了：

- 避免重复修复同一类问题
- 尽快拿到可见质量提升
- 控制架构改动范围
- 便于建立可回归的测试与评测基线

## 3. 优化目标

### 3.1 质量目标

- 各格式输出应优先提升“结构正确性”和“阅读可用性”，而不是只追求字符串相似
- 对于有明确结构的格式，优先恢复标题、段落、列表、表格、图片和附件关系
- 对于弱结构格式，优先保证内容完整、不误伤、不空输出

### 3.2 性能目标

- 默认路径仍保持轻量，不因少量复杂场景而让全部输入变慢
- 重能力路径只在必要时触发，不默认全量开启
- 共享能力优化应优先选择“一处修复，多格式受益”的方向

### 3.3 工程目标

- 继续保持 `core -> engine -> formats -> ast` 主架构稳定
- 横切能力继续沉淀在 `capabilities/`，不要把能力实现散落进 CLI 或 engine
- 优先收敛重复的文件读取、路径处理、资产输出、warning/diagnostics 模式
- 为每类格式建立可回归的测试样本与评测口径

## 4. 方法论：先建全局基线，再做分簇优化

### 4.1 为什么不能纯逐格式推进

纯逐格式推进的主要问题是：

- `libzip` 的解压实现会同时影响 `DOCX / PPTX / XLSX / EPUB`
- OCR 行为和 warning 逻辑已经在多个格式重复出现
- 资产输出、元数据、diagnostics 模式存在跨格式共性
- 多个 converter 内已出现重复的读取文件、路径处理、`bytes_from_array`、`file_stem` 等辅助逻辑

如果按 `DOCX -> PPTX -> XLSX -> EPUB` 独立推进，很可能在四个地方重复修类似 bug、重复抽类似 helper、重复补类似测试。

### 4.2 为什么也不能先做重型全局重构

当前仓库里仍有很多“格式本地问题”比“全局架构问题”更直接，例如：

- CSV 主路径已覆盖引号、转义和多行单元格，剩余问题主要在 dialect 自动探测和复杂退化策略
- HTML 仍以轻量结构恢复为主，但 `<title>` 注入与常见容器展开已经落地；复杂 DOM 场景上限仍然清晰
- Image 的核心问题主要在 OCR 结果组织与质量控制

这类问题不需要等待一次大规模重构完成后再处理。

因此，正确顺序应是：

- 先做小范围全局治理，只解决会跨格式反复出现的问题
- 再把主要精力投入具体格式簇的质量提升

## 5. 优化分组建议

建议将后续工作拆成四个优化簇，而不是按文件后缀单线程排队。

### 5.1 A 组：Office / Archive 簇

覆盖：

- DOCX
- PPTX
- XLSX
- EPUB

共享基础：

- `src/libzip/`
- `src/xml/`
- Archive entry 读取与解压
- 资产提取
- 部分 OCR 接入

这是优先级最高的一组，因为它们共享基础设施最多，一处修复通常会同时改善整组格式。

### 5.2 B 组：Web 文档簇

覆盖：

- HTML
- XHTML
- URL

共享关注点：

- 输入检测与抓取
- HTML 清洗
- DOM 到 AST 的结构恢复
- metadata 与 diagnostics

这组的价值在于：

- 用户感知强
- 结构输出质量提升空间明显
- 与 Office 簇耦合较低，便于并行推进

### 5.3 C 组：OCR / 图像簇

覆盖：

- Image
- 以及后续需要 OCR fallback 的格式能力接入

共享关注点：

- OCR backend 接入与可用性判断
- OCR warning / diagnostics 标准化
- OCR 文本分段与后处理
- 图片资产与识别文本的组织方式

这组应作为明确的 capability 方向推进，而不是只把它当作单个 Image converter 的局部逻辑。

### 5.4 D 组：轻结构文本簇

覆盖：

- TXT
- CSV
- JSON

共享关注点：

- 输入稳健性
- 弱结构数据到 Markdown 的可读性映射
- 边界输入处理
- 轻量但稳定的 diagnostics

这组通常实现成本低，但也最容易被长期搁置。建议放在前两组稳定后集中做一轮补强。

## 6. 优先级建议

原始规划里的“先基线、再 Archive、再 Web、再 OCR、最后轻结构文本”在立项阶段是合理的，但基于当前仓库状态，下一阶段已经不应继续沿用那套从零开始的排序。

当前更合理的排序原则是：

1. 先做已经有主干但仍需要增强洞察力和 regression 纪律的部分
2. 先做一处修复能影响多个格式的共享层
3. 在单格式提质时，优先做当前最可能继续拉高真实质量的格式
4. 把高不确定性能力线放到共享层稳定之后推进

基于这个原则，推荐把下一阶段总顺序改为与执行清单一致的版本：

1. `T0` 评测与回归增量增强
2. `T1` Archive 共享层收口
3. `T2` EPUB 第二轮提质
4. `T3` OCR 共享层收口
5. `T4` HTML / URL 第二轮提质
6. `T5` `DOCX / XLSX / PPTX` 定向提质
7. `T6` PDF OCR fallback 实验线
8. `T7` Image / OCR 消费层收口
9. `T8` `TXT / CSV / JSON` 轻结构文本簇收尾
10. `T9` 工程化收口

这个顺序与原始规划最大的区别在于：

- 阶段 0 不再是“先重新搭一整套基线”，而是对现有 eval 做增量增强
- Archive 簇共享层仍然是最重要的杠杆点，但单格式先后顺序应改为 `EPUB` 优先
- HTML 已经完成一轮提质，因此当前应作为第二轮结构恢复任务处理
- OCR 当前更适合先做共享约定收口，而不是一开始就铺开复杂 capability 设计
- PDF OCR fallback 应视为高价值实验线，而不是当前全项目的最高前置阻塞
- `CSV / JSON / TXT` 已经有第一轮正确性补强，不应再被当作“尚未开始”的末位大项

如果要进一步细化到组内顺序，建议：

### 6.1 Archive 簇内优先级

1. `EPUB`
2. `DOCX`
3. `XLSX`
4. `PPTX`

理由：

- `EPUB` 仍是当前最值得继续深挖的 Archive 格式之一，而且它能同时检验 `libzip + xml` 与 HTML 式结构恢复的上限
- `DOCX` 依旧是最重要的 Office 主路径之一，但现阶段更适合在共享层继续收口之后做定向问题清理
- `XLSX` 受共享表格渲染收益明显，放在 `DOCX` 之后做针对性提升更划算
- `PPTX` 仍然重要，但标题恢复、文本块拼装和画廊策略的主观性更高，适合作为后续定向提质项

### 6.2 Web 簇内优先级

1. 本地 `HTML / XHTML`
2. `URL` 获取与 diagnostics
3. 更复杂 DOM 的结构恢复

### 6.3 OCR 簇内优先级

1. OCR warning / metadata / diagnostics 收口
2. Image 主路径稳定化
3. 为其他格式复用 OCR 能力留轻量接口
4. PDF OCR fallback 实验线

这里刻意不把 `bbox / confidence / fusion pipeline` 作为当前硬前置，因为仓库现有 OCR bridge 还没有演化到那一层抽象；下一阶段重点应是把当前已经存在的 `available / provider / text / warnings` 路径整理稳定。

### 6.4 轻结构文本簇内优先级

1. `CSV` 退化策略与 dialect 继续补强
2. `JSON` 输出收敛
3. `TXT` 空白与段落边界收尾

理由是 `CSV` 的结构错误对用户感知仍然最明显，但它已不再是“先从零修解析”，而是进入解析完成后的收尾和退化策略阶段。

## 7. 分阶段执行方案

建议把下一阶段工作拆成与执行清单一一对应的 `T0 ~ T9` 十个执行阶段。这样在计划文档和执行文档之间不再需要做“阶段编号换算”。

### T0：评测与回归增量增强

目标：

- 保持现有 conversion eval 主路径稳定
- 增强按簇观察问题与回归定位的能力

重点方向：

1. 在不重写现有 report 主结构的前提下，补充 Archive / Web / OCR 相关簇视图
2. 把“修真实 bug 必补 regression case”固化成常态
3. 继续增强 AST 视角，但不把“重设计 AST 评测协议”当作前置阻塞

退出标准：

- 报告里能稳定看见按簇汇总结果
- 新修问题都能留下回归证据
- 不破坏当前稳定的 `24/24` 主路径

### T1：Archive 共享层收口

目标：

- 继续把 Archive 簇的共性问题压到共享层解决

重点方向：

1. 继续收敛 `libzip + xml + file/path/asset helper`
2. 统一 Archive diagnostics 词汇
3. 统一资产命名、引用路径和 placeholder 约定

退出标准：

- Archive 簇的重复 helper 继续下降
- 单格式提质不再频繁被共享层缺陷打断
- 共享层改动的接口影响保持可控

### T2：EPUB 第二轮提质

目标：

- 把 EPUB 从“已可用”推进到“结构稳定、噪声更低”

重点方向：

1. 强化 `OPF / manifest / spine` 的 namespace 鲁棒性
2. 增加目录页、版权页、封面页等 EPUB 专属后处理
3. 弱化内部跳转链接噪声
4. 补充 `toc-heavy`、`image-rich` 等 edge case

退出标准：

- EPUB 在 `markdown_similarity` 与 `ast_similarity` 上继续稳定提高
- 不再明显依赖“样本刚好适配当前实现”

### T3：OCR 共享层收口

目标：

- 把当前已存在的 OCR 能力路径整理稳定，而不是过度设计下一层能力模型

重点方向：

1. 统一 `available / provider / text / warnings` 路径
2. 收敛 backend 缺失、空结果、stderr 异常时的 diagnostics
3. 让 OCR config、provider 与 warnings 在多格式里有一致语义

退出标准：

- OCR 相关 metadata 和 diagnostics 在多格式间保持一致
- 共享入口可复用，但没有被提前抽象成过重 capability

### T4：HTML / URL 第二轮提质

目标：

- 在已完成 `<title>` 注入与容器展开的基础上，继续提升结构恢复质量

重点方向：

1. 提升列表、表格、引用块、代码块恢复
2. 明确 `script / style / comment / body` 清洗边界
3. 拆分本地 HTML 与 URL 获取失败时的 diagnostics 路径
4. 为复杂 DOM 的逐步结构化处理留演进空间

退出标准：

- 常见 HTML 页面能更稳定输出可读 Markdown
- URL 场景失败信息足够清晰
- 第二轮 HTML 回归样本开始形成

### T5：`DOCX / XLSX / PPTX` 定向提质

目标：

- 在共享层继续稳定之后，对剩余 Office 主格式做定向问题清理

重点方向：

1. `DOCX`：标题、列表、超链接、媒体与 relationships 异常路径
2. `XLSX`：sheet 组织、shared strings、空行空列、表格输出
3. `PPTX`：slide 标题识别、正文块拼装、图片与附件画廊策略

退出标准：

- 三个格式的主要问题从“主路径不稳”继续转向“输出细节仍可优化”
- 与 Archive 共享层的边界更清晰，不再反复回流到局部补丁

### T6：PDF OCR fallback 实验线

目标：

- 在不扰动现有 PDF 主路径的前提下，验证扫描件恢复路径的有效性

重点方向：

1. 明确何时进入 OCR fallback
2. 把 fallback 结果与现有 PDF 主路径做可比较评估
3. 保持该能力可关闭、可实验、可回归

退出标准：

- 能以小规模样本证明 fallback 的收益或局限
- 不把 PDF 原有强主路径拖入不必要的不稳定状态

### T7：Image / OCR 消费层收口

目标：

- 让 Image 格式把共享 OCR 能力消费得更稳定、更可预测

重点方向：

1. 稳定有无 OCR backend 时的行为
2. 明确图片展示、识别文本与 diagnostics 的关系
3. 补足 Image 主路径的回归和 warning 断言

退出标准：

- Image 主路径在 mock / real backend 场景下行为可预测
- 与 OCR 共享层的边界清晰

### T8：轻结构文本簇收尾

目标：

- 在第一轮正确性补强落地后，完成 `TXT / CSV / JSON` 的剩余收尾工作

重点方向：

1. `CSV`：dialect、退化策略、表头与复杂单元格映射
2. `JSON`：pretty-print 与 metadata / code block 边界
3. `TXT`：空白、段落切分与边界输入处理

退出标准：

- 轻结构文本簇主要问题稳定落在“输出抛光”而不是“解析错误”
- 维持低成本但有效的回归覆盖

### T9：工程化收口

目标：

- 把前面几轮提质沉淀成稳定的工程约束，而不是一次性优化痕迹

重点方向：

1. 清理仍然游离在各 converter 内部的重复 helper
2. 明确 diagnostics、asset、OCR、共享读取等约定的归属边界
3. 收敛文档、评测说明和任务清单，避免文档再次分叉

退出标准：

- 文档、代码结构、测试入口三者对当前主线状态的描述一致
- 新一轮提质可以在更低协作成本下继续推进

## 8. 每类格式的主要优化关注点

### 8.1 TXT

- 编码与 BOM 处理
- 空行与段落切分
- 超长段落与过度压缩空白的平衡

### 8.2 CSV

- CSV 主路径已经是正规的 quoted / escaped / multiline 解析，后续重点转向 dialect 与退化策略
- 引号、转义、空单元格、多行单元格
- 表头识别与 Markdown 表格退化策略

### 8.3 JSON

- 保持原始数据完整性
- 更稳定的 pretty-print 与 fenced code block 输出
- metadata 与正文的边界

### 8.4 Image

- OCR 可用性检查
- OCR 空结果处理
- 图片展示与识别文本的组织方式

### 8.5 HTML / XHTML / URL

- 常见块级语义恢复
- 表格与引用块
- 清洗规则边界
- URL 失败诊断与超时控制

### 8.6 DOCX

- 标题/段落/列表恢复
- 超链接与媒体
- Word relationship 解析
- 嵌入图片 OCR 的位置与展示策略

### 8.7 PPTX

- 幻灯片顺序
- 文本框合并与标题识别
- 图片与附件画廊
- OCR 对图片内容的补强

### 8.8 XLSX

- workbook / rels / worksheet 解析稳定性
- sharedStrings
- 表格区域组织
- 图片与嵌入对象导出

### 8.9 EPUB

- OPF / manifest / spine 稳定解析
- XHTML 内容块恢复
- 章节组织
- 资源提取与图片 OCR

## 9. 测试与评测方案

后续优化不建议只靠人工阅读输出判断。建议建立三层验证：

### 9.1 格式级 whitebox / blackbox 测试

- 关键 parser helper 的 whitebox test
- converter 主路径 blackbox test
- 典型 warning / diagnostics 的断言

### 9.2 样本级参考输出

- 为每种格式准备代表性 fixture
- 对稳定结构使用 `assert_eq` 或结构断言
- 对输出变化较大的内容使用 snapshot

### 9.3 横向评测

- 建立按格式汇总的成功率与质量报告
- 对 Office / HTML / OCR 三大方向保留对比基线
- 对性能保留固定样本、固定命令、固定输出口径

### 9.4 建议的样本设计

每个格式的样本至少应覆盖三类：

1. 正常主路径样本
2. 边界/异常样本
3. 能代表该格式主要结构价值的样本

建议最小覆盖如下：

- `TXT`
  - 普通段落文本
  - 含 BOM 文本
  - 空文件或极短文本
- `CSV`
  - 简单二维表
  - 带引号与逗号的单元格
  - 含空列或多行单元格的表
- `JSON`
  - 对象 + 数组混合
  - 深层嵌套 JSON
  - 大体量但结构规则的 JSON
- `Image`
  - 可清晰 OCR 的图片
  - OCR 结果为空的图片
  - backend 缺失场景
- `HTML / XHTML`
  - 标准文章页
  - 列表 / 表格 / 引用混合页
  - 噪声较多的页面
- `DOCX`
  - 标题 + 列表 + 图片的常规文档
  - 关系文件较复杂的文档
  - 嵌入图片较多的文档
- `PPTX`
  - 标准标题页 + 正文页
  - 图片较多的演示文稿
  - 文本框分散的演示文稿
- `XLSX`
  - 单 sheet 简单表格
  - 多 sheet
  - 含 shared strings 与图片的工作簿
- `EPUB`
  - 线性章节型 EPUB
  - 含图片资源 EPUB
  - 资源引用相对复杂 EPUB

### 9.5 建议的验收指标

建议每个阶段至少记录下面这些指标：

- `success_rate`
- `empty_output_rate`
- `warning_count`
- `diagnostic_count`
- `asset_extract_rate`
- `avg_runtime_ms`

对于不同格式，再增加 1 到 2 个关键结构指标：

- `DOCX`
  - 标题命中率
  - 图片占位命中率
- `XLSX`
  - sheet 命中率
  - 表格区域命中率
- `PPTX`
  - 幻灯片顺序正确率
  - 标题识别命中率
- `HTML`
  - 块级结构命中率
  - 表格恢复命中率
- `Image`
  - OCR 非空返回率
  - backend 缺失诊断正确率
- `CSV`
  - 行列数一致性
  - 引号单元格解析正确率

### 9.6 建议的性能验证口径

性能验证建议沿用仓库已有的 [`docs/benchmark.md`](/D:/MySoftware/MoonBitMark/docs/benchmark.md) 思路，但补充固定样本集与归档方式：

1. 每类格式至少选 1 个固定 benchmark 样本
2. 固定使用 native release CLI
3. 固定执行次数，例如 `5` 或 `10`
4. 记录：
   - 单轮耗时
   - 平均耗时
   - 是否输出成功
5. 对重大优化阶段保留前后对比记录

不建议在当前阶段引入非常重的长期性能平台，先保证“同机、同样本、同命令可复现”。

## 10. 推荐的近期工作清单

如果只看接下来一到两个开发周期，建议先做下面这些事：

1. 继续扩充“非 PDF 格式”的评测样本，尤其补 Archive 簇边界 case
2. 收敛剩余共享 helper，尤其补完 Image 侧与 message/path 小工具
3. 继续统一 OCR metadata / diagnostics 约定，为 Image 与后续 PDF recovery 共用
4. 先推进 `DOCX` 与 `XLSX` 两个高价值格式的第二轮提质
5. 完成一轮 HTML 本地文件结构恢复补强
6. 评估 `URL` 与 `Image` 的下一轮质量/可维护性上限

### 10.1 建议的首轮执行顺序

如果按实际落地顺序拆分，推荐按下面的节奏推进：

1. 在现有基线之上继续补 Archive / OCR 边界样本
2. 继续完成共享 helper 和 OCR 约定的尾部收敛
3. 并行推进 `DOCX` 和 `XLSX`
4. 在 Archive 簇共享层稳定后，推进 HTML 本地文件主路径
5. 最后整理 OCR capability 和轻结构文本簇补强

这个顺序的原因是：

- 能尽早锁定共享 bug
- 能尽快在高价值格式上看到收益
- 不会因为一次大规模重构而冻结全部开发

### 10.2 建议的 4 周里程碑

如果按四周节奏规划，可以采用下面的里程碑：

#### 第 1 周

- 完成非 PDF 样本清单
- 建立第一版格式基线
- 输出共享问题台账

#### 第 2 周

- 优先处理 `libzip` 与共享 helper
- 开始 `DOCX` 主路径补强
- 开始 `XLSX` 主路径补强

#### 第 3 周

- 收敛 `DOCX / XLSX` 第一轮问题
- 推进 `PPTX / EPUB` 的阻塞项
- 开始 HTML 结构恢复补强

#### 第 4 周

- 整理 OCR metadata / diagnostics
- 补强 `CSV / JSON / TXT`
- 输出阶段性评测结果与下一轮计划

### 10.3 建议的任务管理方式

建议在执行时把任务拆成三层：

1. `共享层任务`
   - `libzip`
   - `xml`
   - `ocr`
   - `core / engine` 中的共性约定
2. `格式簇任务`
   - Archive
   - Web
   - OCR / Image
   - 轻结构文本
3. `格式内任务`
   - parser
   - asset
   - metadata
   - diagnostics
   - tests

这样拆的好处是：

- 更容易识别真正的阻塞点
- 更容易并行开发
- 更容易避免把共享问题伪装成单格式问题

## 11. 不建议当前阶段做的事

以下事项建议暂缓，避免分散主线精力：

- 为所有格式同时做大规模架构重写
- 在没有评测基线前，凭感觉大量调整 Markdown 输出规则
- 把 OCR、网络抓取、外部 bridge 逻辑继续散落到各个 converter
- 在 `TXT / CSV / JSON` 上过早做高复杂度工程化，而忽视更高价值的 Archive 与 HTML 簇

## 12. 最终建议

MoonBitMark 下一阶段应采用的总路线可以固定为：

**先全局分析，后按共享能力分簇推进，组内再逐格式深挖。**

更具体地说：

1. 先补齐全局基线和问题台账
2. 先攻共享基础设施最重的 Archive 簇
3. 再推进 HTML / URL 这条高感知价值链
4. 再把 OCR 能力整理成更稳定的横切能力
5. 最后集中补强 TXT / CSV / JSON

这样推进的好处是：

- 能避免重复劳动
- 能更快形成可见成果
- 能把架构演进控制在必要范围内
- 能为后续继续扩展格式和能力保留清晰路径

## 13. 附：阶段与目录映射

为了避免方案执行时重新讨论“应该改哪里”，这里给出推荐的目录映射。

### 13.1 共享层

- `src/libzip/`
- `src/xml/`
- `src/core/`
- `src/engine/`
- `src/capabilities/ocr/`

### 13.2 Archive 簇

- `src/formats/docx/`
- `src/formats/pptx/`
- `src/formats/xlsx/`
- `src/formats/epub/`

### 13.3 Web 簇

- `src/formats/html/`

### 13.4 OCR / Image 簇

- `src/formats/image/`
- `src/capabilities/ocr/`

### 13.5 轻结构文本簇

- `src/formats/text/`
- `src/formats/csv/`
- `src/formats/json/`

### 13.6 测试与评测

- `tests/conversion_eval/`
- `src/formats/<format>/*_test.mbt`
- `src/formats/<format>/*_wbtest.mbt`

## 14. 附：方案执行时的判断原则

后续在实际优化过程中，建议始终用下面几条原则做取舍：

1. 如果一个问题同时影响多个格式，优先按共享层处理
2. 如果一个优化只能改善单格式局部观感，但会明显拉高全局复杂度，暂缓
3. 如果一个格式已经“可用”，但共享层仍阻塞其他格式，优先去疏通共享层
4. 如果一个格式的主要问题可通过补样本和测试暴露，不要先重构
5. 任何输出规则改动，都尽量先补回归样本再改实现




