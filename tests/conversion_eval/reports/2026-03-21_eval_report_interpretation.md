# MoonBitMark 转换评估报告解读

日期：`2026-03-21`

依据文件：

- `tests/conversion_eval/reports/latest/summary.md`
- `tests/conversion_eval/reports/latest/report.json`
- `tests/conversion_eval/reports/latest/artifacts/*`

## 一、总体结论

从最新一次评估结果看，MoonBitMark 目前已经在 `text`、`json`、`csv`、`html`、`pdf` 这些格式上建立了比较扎实的基础能力，`pptx` 也已经进入“基本可用”的阶段；但在 `docx`、`epub`、`xlsx` 这三类复杂容器格式上，转换质量仍然明显落后于成熟项目应有的水平。

本次报告的关键数字如下：

- 报告生成时间：`2026-03-21T14:27:28.552083+00:00`
- 通过率：`7/11`
- 平均分：`0.7072`
- 报告状态：`provisional`
- runner 过期：`true`

这里最需要注意的是：这份报告使用的是过期的可执行文件，报告本身已经明确标记为 `provisional`。因此，这份结果适合用来判断方向、识别短板、安排修复优先级，但还不能作为最终质量结论。

## 二、当前 MoonBitMark 的质量水平

如果按格式分层来看，当前质量水平大致可以这样判断：

- `text`、`json`、`csv`、`html`：基础转换质量已经比较高
- `pdf`：在当前纳入评测的两个样本上表现很强
- `pptx`：主流程基本通了，但结构保真度还不够稳定
- `docx`、`epub`、`xlsx`：还没有达到可与成熟项目正面对比的水平

这说明 MoonBitMark 已经不是“只能处理玩具样本”的阶段了。对于简单文本类、轻结构类以及当前选取的 PDF 样本，项目已经有较强竞争力。但如果讨论“整体文档转换质量能否媲美 MarkItDown 和 Docling”，目前答案仍然是否定的，主要卡在 `docx/xlsx/epub`。

## 三、与 MarkItDown 和 Docling 的差距

这次最新报告里，`markitdown` 和 `docling` 两个 baseline 都没有真正跑起来，因此没有得到同样样本、同样指标下的直接分数对比。也就是说，这次不能严谨地说“MoonBitMark 比 MarkItDown 低多少分”或者“比 Docling 低多少分”。

但从报告暴露出来的问题类型来看，差距已经足够明确，主要集中在以下几个方面：

- 复杂容器格式能力不足  
  `docx`、`xlsx`、`epub` 恰恰是成熟项目通常比较稳定的格式，而 MoonBitMark 目前在这些格式上还存在“输出为空”或“正文缺失”的问题。

- 结构保真度不稳定  
  MoonBitMark 在简单格式上已经能做到不错的文本召回，但标题层级、列表语义、工作簿结构、长文档正文遍历等能力还不够稳。

- 评测证据深度还不够  
  当前 `pdf` 分数很高，但样本数量少，且更多依赖锚点和顺序检查，还没有像成熟项目那样建立更深的结构化参考比对。

- 输出抛光程度仍有差距  
  即使在已通过的 `csv`、`html` 等格式上，artifact 中仍能看到 Markdown 噪声或格式粗糙的问题，说明“语义正确”和“输出足够干净”之间还有距离。

所以，当前最准确的判断是：MoonBitMark 已经在部分格式上接近可用甚至较强，但离“整体质量媲美 MarkItDown / Docling”还有明显差距，而且差距非常集中，不是全面落后，而是集中落在 `docx/xlsx/epub` 这些关键格式上。

## 四、按格式的根因分析清单

下面的清单刻意区分三类信息：

- 报告已经确认的现象
- 结合当前代码实现可以提出的高概率根因
- 后续应执行的验证或修复动作

### 1. text

状态：`通过`，分数 `0.9969`

现象：

- 锚点、长度、Markdown 相似度、结构相似度、文本顺序全部通过
- 是当前评测体系里最稳定的格式之一

判断：

- 该格式已经可以视为当前项目的稳定格式

后续动作：

- 将 `text` 保留为控制组格式，在后续重构其他转换器时持续回归

### 2. json

状态：`通过`，分数 `0.9619`

现象：

- 内容保持基本完整
- Markdown code fence 行为稳定
- 当前样本下已经接近目标质量线

判断：

- JSON 转换链路整体是可靠的

后续动作：

- 增加更复杂的嵌套 JSON 样本，确认在更大 payload 下仍然无损

### 3. csv

状态：`通过`，分数 `0.9763`

现象：

- 内容召回和表格比对都通过
- 当前样本下功能层面已经可用
- 但 artifact 里仍然能看到 Markdown 表格格式较粗糙

判断：

- CSV 的核心内容提取已经没问题
- 当前问题主要不在“有没有提到内容”，而在“表格 Markdown 是否够干净”

高概率根因：

- 表格渲染器对表头、分隔行、尾部换行、空列处理还不够严格

后续动作：

- 收紧 Markdown 表格输出格式
- 如果项目后续更强调“输出抛光”，应增加更严格的格式类断言

### 4. html

状态：`通过`，分数 `0.9778`

现象：

- 标题、正文、表格都提取成功
- 结构比较通过
- artifact 中仍出现零散的 `>` 残留行

判断：

- HTML 主链路已经通了
- 当前主要问题是输出清理不够彻底，而不是内容召回失败

高概率根因：

- HTML 转 Markdown 的块级整理逻辑，对 blockquote 或容器类节点处理后留有噪声

后续动作：

- 清理 HTML 解析后的多余 `>` 行和类似残留
- 把这些噪声项加入 `must_not_include`，让评测能更真实反映抛光程度

### 5. pdf

状态：`通过`，平均分 `0.9925`

现象：

- 两个 PDF case 全部通过
- `pdf_right_to_left` 的非空和锚点检查通过
- `pdf_multi_page` 的锚点、长度、顺序检查通过

判断：

- 在当前样本集上，PDF 是 MoonBitMark 的强项之一

限制：

- 当前 PDF 评测证据还不够深，只能说明“这两个样本表现很好”
- 还不能据此直接宣称 PDF 整体已经达到 MarkItDown 或 Docling 的同档水平

后续动作：

- 增加 reference-backed 的 PDF 结构和表格 case
- 在更多 PDF 类型上扩大样本覆盖后，再做更强结论

### 6. pptx

状态：`通过`，分数 `0.8982`

现象：

- 幻灯片顺序和主要文本分组基本正确
- 实际输出可读，不是空结果
- `markdown_similarity=0.8447`、`ast_similarity=0.6833`

判断：

- PPTX 已经进入“基本可用”阶段
- 但当前更像是“文本抓出来了”，还不是“结构保真度很高”

高概率根因：

- 对标题块、项目符号层级、页面局部结构的表达还比较粗

后续动作：

- 改进 slide title、bullet group、slide-local structure 的语义表达
- 增加更多复杂 PPTX 样本后再判断是否可视为生产可用

### 7. docx

状态：`失败`，平均分 `0.2337`

现象：

- 两个 DOCX case 都失败
- `docx_unit_test_headers` 和 `docx_unit_test_lists` 的 artifact 基本是空输出
- 失败项覆盖 `anchors`、`golden_markdown`、`ast_compare`、`text_order`
- 这是内容提取失败，不是简单的 Markdown 格式偏差

判断：

- DOCX 是当前最严重的核心质量短板之一
- 由于本次 runner 过期，首先必须排除“旧二进制掩盖新实现”的因素

高概率根因：

- 第一层高概率原因：测试 runner 过期，当前报告可能没有真正反映最新 DOCX 实现
- 如果重新构建后仍然为空输出，则问题更可能位于 `src/formats/docx/converter.mbt` 中 XML 事件到 AST block 的转换链路，而不是 ZIP 打开阶段
- 也就是说，失败形态更像“文档被读到了，但段落没有落成输出 block”，而不是“压根打不开文档”

后续动作：

- 先重建 native runner，并重新跑整套评测
- 如果 DOCX 仍然为空：
  - 对 `extract_blocks_from_docx_xml`
  - 对段落开始、run 处理、段落收尾
  - 对 heading/list 判定路径
    做逐步插桩和断点式验证
- 为这两个 benchmark fixture 增加显式回归测试

优先级判断：

- DOCX 应视为当前第一优先级质量缺陷

### 8. epub

状态：`失败`，分数 `0.3482`

现象：

- 标题、作者、语言等元信息被提取出来了
- 但正文提取严重不足
- artifact 显示输出几乎只剩 metadata，缺少正文主体
- 这是 spine/content traversal 问题，不是简单 Markdown 渲染问题

判断：

- EPUB 不是“完全打不开”，而是“书籍元信息能出来，但章节正文没真正遍历出来”

高概率根因：

- `src/formats/epub/converter.mbt` 中 `parse_opf` 对元素名直接用 `metadata`、`item`、`itemref` 等裸名字判断，没有做 namespace 标准化
- 如果实际 OPF 使用 namespaced 元素，metadata 可能还能部分读到，但 manifest/spine 遍历会悄悄丢失内容文档
- 这与当前现象高度一致：元信息存在，正文大量缺失

后续动作：

- 对 OPF 解析补 namespace 归一化
- 为 namespaced OPF 的 `item` / `itemref` 加回归测试
- 验证 XHTML 章节文件是否真的被遍历并进入 `html_to_blocks` 阶段

优先级判断：

- EPUB 属于第二梯队修复项，但优先级略低于 DOCX 和 XLSX

### 9. xlsx

状态：`失败`，分数 `0.1675`

现象：

- 最新 XLSX artifact 基本为空
- `anchors`、`golden_markdown`、`ast_compare`、`table_compare` 全部失败
- 这同样是核心提取失败，不是表格格式不漂亮这么简单

判断：

- XLSX 是另一个严重短板
- 和 DOCX 一样，也要先排除过期 runner 的影响

高概率根因：

- `src/formats/xlsx/converter.mbt` 里 `parse_workbook_sheets` 只读取 `evt.attributes.get("r:id")`
- 如果 XML 解析器对 namespace 前缀有归一化或丢失行为，就可能导致 sheet relationship id 没被正确读到
- 一旦 `r:id` 没拿到，后续 worksheet path 就找不到，最终表现就是“转换成功返回，但输出为空”
- 这个失效模式与当前报告高度一致

后续动作：

- 先重建 runner，再重跑 XLSX case
- 如果仍失败：
  - 插桩 sheet discovery
  - 插桩 relationship mapping
  - 插桩 worksheet path lookup
- 增加“sheet 非空发现”的回归断言

优先级判断：

- XLSX 应与 DOCX 一起列为最高优先级修复项

## 五、建议的修复顺序

建议按以下顺序处理：

1. 先重建 runner，重新跑完整评测，去掉 `provisional` 状态
2. 修 `docx`
3. 修 `xlsx`
4. 修 `epub`
5. 再处理 `html/csv/pptx` 的输出抛光问题
6. 最后补强 `pdf` 的评测深度，再决定是否可以对外宣称与 MarkItDown / Docling 同档

## 六、最终判断

MoonBitMark 当前已经具备了比较扎实的基础转换能力，尤其是在 `text/json/csv/html/pdf` 上，已经不属于早期原型阶段。`pptx` 也已经从“不可用”进入“基本可用”。

但如果问题是“当前 MoonBitMark 的整体文档转换质量，是否已经能媲美 MarkItDown 和 Docling”，结论仍然是否定的。阻塞点并不分散，而是高度集中在 `docx/xlsx/epub` 三类复杂格式上。

只要这三类格式还存在“空输出”“正文缺失”“结构无法保真”的问题，MoonBitMark 就还不能算达到成熟项目同档水平。相反，一旦这三类格式补上，MoonBitMark 的整体质量会出现一次明显跃迁。
