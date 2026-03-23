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
  - `24/24` 通过
  - 平均分 `0.9858`
- baseline 已纳入同一套报告：
  - `markitdown`：`22/22` 成功，平均分 `0.7373`
  - `docling`：`15/15` 成功，平均分 `0.6388`
- `image` 已正式纳入评测矩阵，并支持通过 case 级 `cli_args` 固定
  `--ocr force --ocr-backend mock`
- `epub` 已做过一轮专门的输出收敛，当前 quality case 已可通过

这意味着：

- 阶段 0 的“统一基线 + 最小样本集 + baseline 报告”已经基本成立
- 阶段 1 已取得实质进展：`libzip` Dynamic Huffman 已修复并进入严格测试
- `core` 已开始收敛共享文件读取 / 路径 helper，以及 OCR / asset 约定
- AST 共享渲染层已经开始承担表格列宽补齐与换行收敛，属于典型的“一处修复，多格式受益”
- 阶段 2 中 `DOCX / PPTX / XLSX / EPUB` 的第一轮质量补强已经取得结果
- 阶段 3 与阶段 5 已分别启动一轮轻量提质：HTML 的 `<title>` / container 恢复补强，以及 CSV 真实解析语义补强已经进入主线

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

- `src/formats/csv/` 已从简单逗号切分升级到支持 quoted cell、escaped quote、multiline cell 的真实解析语义
- `src/core/file_helpers.mbt` 新增 UTF-8 BOM 清理 helper，`csv/json/text/html` 已统一复用共享读取路径
- `src/ast/renderer.mbt` 已统一表格列宽补齐与单元格换行收敛，这会同时影响 CSV / HTML / XLSX 等共享 `Table` block 的格式
- `src/formats/html/` 已补入 `<title>` 注入和 `div/section/article/main` 容器展开逻辑，常见本地 HTML 的结构恢复质量已明显提升
- 最新 conversion eval 已提升到 `24/24`、平均分 `0.9858`，其中 `csv = 1.0000`、`html = 0.9948`

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

推荐的总体优先级如下：

1. 先做全局基线与共享瓶颈清单
2. 再做 A 组 `DOCX / PPTX / XLSX / EPUB`
3. 然后做 B 组 `HTML / XHTML / URL`
4. 然后做 C 组 `Image / OCR capability`
5. 最后做 D 组 `TXT / CSV / JSON`

如果要进一步细化到组内顺序，建议：

### 6.1 A 组内优先级

1. DOCX
2. XLSX
3. PPTX
4. EPUB

理由：

- `DOCX` 通常最常用，也最能暴露共享 ZIP/XML/资产抽取问题
- `XLSX` 对表格与结构表达要求高，能尽早暴露 AST 和表格渲染边界
- `PPTX` 价值高，但幻灯片语义恢复比 Word/Excel 更主观
- `EPUB` 通常更接近 HTML/包内资源解析，适合作为 Archive 簇后段处理

### 6.2 B 组内优先级

1. 本地 HTML / XHTML 文件
2. URL 抓取与 diagnostics
3. 更复杂 HTML 结构恢复

### 6.3 C 组内优先级

1. Image 直转质量稳定化
2. OCR warning / metadata / diagnostics 统一
3. 为其他格式复用 OCR 能力留标准接口

### 6.4 D 组内优先级

1. CSV
2. JSON
3. TXT

理由是 `CSV` 的结构错误对用户感知最明显，`JSON` 次之，`TXT` 最容易维持基本可用。

## 7. 分阶段执行方案

建议把下一阶段工作拆成五个阶段。

### 阶段 0：全局基线阶段

目标：

- 统一质量评估口径
- 建立格式级样本集
- 明确共享瓶颈与重复代码清单

建议产出：

1. 各格式最小评测样本集
2. 每格式 reference markdown 或结构断言
3. 当前问题台账：
   - 质量问题
   - 性能问题
   - 共享基础设施问题
4. 优化簇路线确认稿

建议关注的基线指标：

- 转换成功率
- 空输出率
- 关键结构命中率
- warning / diagnostics 覆盖度
- 运行耗时
- 资产提取完整度

退出标准：

- 每个格式至少有一组可回归样本
- 已知问题能区分为“共享问题”与“格式局部问题”
- 后续优化顺序不再靠主观印象决定

建议任务拆分：

1. 为每个格式建立最小 fixture 清单
2. 明确每个 fixture 的目标结构与失败判定标准
3. 统一记录：
   - 是否成功转换
   - 是否空输出
   - warnings 数量
   - diagnostics 类型
   - 主要结构是否命中
4. 形成第一版问题台账，并按“共享问题 / 局部问题”两栏分类

建议代码落点：

- `tests/conversion_eval/`
- `src/formats/<format>/*_test.mbt`
- `src/formats/<format>/*_wbtest.mbt`
- 必要时补 `docs/temp/` 下的评测记录文档

建议交付物：

- 非 PDF 格式 fixture 清单
- 第一版按格式汇总的成功率与风险表
- 第一版共享问题列表

### 阶段 1：共享基础设施治理

目标：

- 解决会跨格式重复消耗开发时间的问题

优先事项：

1. 修复 `libzip` Dynamic Huffman 并补严格回归测试
2. 统一文件读取 / `Bytes` 构造 helper
3. 统一路径处理、`file_stem`、扩展名辅助逻辑
4. 统一资产输出与 metadata 约定
5. 收敛重复的 OCR warning / provider metadata 模式

退出标准：

- Archive 簇的公共缺陷数量明显下降
- 至少一批重复 helper 被收敛到共享位置
- 修改共享层后，不会引入明显 API 混乱

建议任务拆分：

1. 修复并验证 `libzip` Dynamic Huffman
2. 抽取共享 helper：
   - 读取整个文件为 `Bytes`
   - `bytes_from_array`
   - `file_stem`
   - 扩展名与路径辅助函数
3. 统一输出资产的命名、placeholder、metadata 约定
4. 统一 OCR metadata 字段名和 warning 语义
5. 明确哪些 helper 应进入 `core`、哪些应保留在格式簇内部

建议代码落点：

- `src/libzip/`
- `src/xml/`
- `src/core/`
- `src/engine/`
- 受影响的 `src/formats/docx/`
- 受影响的 `src/formats/pptx/`
- 受影响的 `src/formats/xlsx/`
- 受影响的 `src/formats/epub/`

建议交付物：

- 修复后的 archive 共享测试
- 第一版共享 helper 收敛结果
- 共享 metadata / diagnostics 约定说明

### 阶段 2：Office / Archive 簇提质

目标：

- 显著提升 `DOCX / PPTX / XLSX / EPUB` 的结构质量与稳定性

重点方向：

1. DOCX
   - 段落、标题、列表、超链接、图片占位更稳定
   - 关系文件解析与媒体抽取更稳健
2. XLSX
   - sheet 组织更清晰
   - 表格头、空行、空列、sharedStrings 行为更稳定
   - 图片与嵌入资源输出策略更明确
3. PPTX
   - 幻灯片顺序、文本块拼装、标题识别更稳定
   - 图片与附件展示策略更一致
4. EPUB
   - spine 顺序、章节层级、资源抽取更清晰
   - 与 HTML 簇的结构恢复逻辑适度对齐

退出标准：

- Office / Archive 簇的成功率与样本质量均明显提升
- 大多数问题从“无法转换”转为“可转换但可继续优化”
- 共享 ZIP/XML 问题不再反复阻塞单格式开发

建议任务拆分：

1. `DOCX`
   - 清点当前不稳定 block 类型
   - 细化标题、列表、超链接、图片占位规则
   - 强化 relationships 和媒体抽取异常路径
2. `XLSX`
   - 处理 workbook / rels / worksheet 主链路
   - 强化 shared strings、空行空列、sheet 标题组织
   - 明确图片和嵌入对象的渲染策略
3. `PPTX`
   - 提升 slide 标题和正文块拼装
   - 调整图片与附件画廊策略
   - 细化解析 warning
4. `EPUB`
   - 强化 OPF / manifest / spine 解析
   - 优化章节顺序、资源路径拼接和图片插入策略

建议代码落点：

- `src/formats/docx/`
- `src/formats/xlsx/`
- `src/formats/pptx/`
- `src/formats/epub/`
- 与之对应的测试文件

建议交付物：

- Office / Archive 簇样本集的阶段性质量报告
- 每个格式至少一个稳定主路径回归测试
- 一批真实样本下的 warning / diagnostics 收敛结果

### 阶段 3：Web 文档簇提质

目标：

- 提升 HTML / XHTML / URL 的结构恢复与用户可读性

重点方向：

1. 提升标题、段落、列表、表格、引用块恢复
2. 明确 script/style/comment 清洗边界
3. 区分本地文件与 URL 获取失败时的 diagnostics
4. 逐步从“字符串扫描式解析”走向更可维护的轻量结构化处理

退出标准：

- 常见 HTML 页面能稳定给出可读 Markdown
- URL 场景失败信息足够清晰
- HTML 结构恢复的回归测试基本成型

建议任务拆分：

1. 梳理当前支持的块级 HTML 标签及缺口
2. 明确预处理边界：
   - `script`
   - `style`
   - comments
   - body 提取
3. 提升列表、表格、引用块、代码块的结构恢复
4. 拆分本地文件与 URL 的 diagnostics 路径
5. 为复杂 HTML 留出逐步结构化重构空间，避免继续堆字符串分支

建议代码落点：

- `src/formats/html/converter.mbt`
- `src/formats/html/converter_wbtest.mbt`
- 对应 HTML fixture

建议交付物：

- 常见 HTML 页面样本的参考输出
- 本地 HTML 与 URL 两条失败路径的 diagnostics 断言
- HTML 结构恢复差距清单

### 阶段 4：OCR / Image 能力治理

目标：

- 把 OCR 从“单格式附属逻辑”整理为更稳定的 capability

重点方向：

1. 统一 OCR backend 检测、availability、warning 与 metadata
2. 提升 OCR 文本分段与标题组织
3. 明确图片资产输出、识别文本与 diagnostics 的关系
4. 为未来 PDF 扫描件 recovery path 预留稳定接口

退出标准：

- Image 转换在有无 OCR backend 的场景下表现可预测
- OCR 相关 metadata 和 diagnostics 在多格式间保持一致
- 能力层可被其他格式复用，而不是复制粘贴

建议任务拆分：

1. 梳理当前 OCR config、provider、warning 的实际使用点
2. 明确统一字段：
   - `ocr_mode`
   - `ocr_backend`
   - `ocr_provider`
   - `ocr_embedded_image_count`
3. 收敛 OCR backend 缺失、空结果、stderr 异常的 diagnostics
4. 调整 OCR 文本分段和标题组织策略
5. 为其他格式调用 OCR 的公共入口做轻量约束

建议代码落点：

- `src/capabilities/ocr/`
- `src/formats/image/`
- 受 OCR 影响的 `src/formats/docx/`
- 受 OCR 影响的 `src/formats/pptx/`
- 受 OCR 影响的 `src/formats/epub/`

建议交付物：

- OCR 统一约定文档或注释约定
- Image 主路径的稳定回归测试
- 多格式 OCR metadata 对齐结果

### 阶段 5：轻结构文本簇补强

目标：

- 以较低成本完成 `TXT / CSV / JSON` 的“正确性补强”

重点方向：

1. CSV
   - 支持引号、逗号转义、多行单元格等更真实输入
   - 表格输出更稳健
2. JSON
   - 保持内容完整
   - 优化代码块、缩进、metadata 呈现
3. TXT
   - 段落切分、空白处理、编码与边界输入更稳健

退出标准：

- 轻结构文本簇的主要问题从“解析错误”转为“格式美化问题”
- 这些格式的回归测试成本保持低而有效

建议任务拆分：

1. `CSV`
   - 引入更真实的 CSV 解析语义
   - 处理引号、逗号转义、多行单元格
   - 对不能稳定映射为 GFM table 的情况定义退化策略
2. `JSON`
   - 统一 pretty-print 输出
   - 明确 metadata 和正文 code block 的边界
3. `TXT`
   - 强化 BOM、空白和段落切分
   - 避免过度“聪明”的结构推断

建议代码落点：

- `src/formats/csv/`
- `src/formats/json/`
- `src/formats/text/`
- 各自测试文件

建议交付物：

- 更真实输入下的 CSV 回归测试
- JSON / TXT 的稳定输出样本
- 轻结构文本簇的小规模性能对比

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




