# MoonBitMark 最新转换评测解读与提质建议

日期：`2026-03-22`

对应报告：

- `tests/conversion_eval/reports/latest/summary.md`
- `tests/conversion_eval/reports/latest/report.json`

本解读基于最新一次完整评测结果撰写，重点回答三个问题：

1. 当前 MoonBitMark 的转换质量到了什么水平
2. 与 `markitdown`、`docling` 的对比结果说明了什么
3. 接下来应该如何系统性提高文档转换质量

## 一、总览结论

最新报告显示，MoonBitMark 当前已经进入“主体能力可用，剩余问题集中”的阶段，而不再是“很多格式都不稳定”的早期状态。

最新评测结果如下：

- 生成时间：`2026-03-21T17:20:09.120919+00:00`
- Runner：`_build/native/release/build/cmd/main/main.exe`
- Runner 过期状态：`False`
- 通过率：`9/11`
- 平均分：`0.9598`

从格式维度看：

- 已经表现很强：`text`、`docx`、`pptx`、`pdf`
- 表现稳定且可用：`json`、`csv`、`xlsx`
- 仍需重点修复：`html`、`epub`

如果只看这套 benchmark 子集，MoonBitMark 的总体表现已经明显好于此前阶段，并且在多数当前样本上优于 `markitdown` 和 `docling` baseline。

但这并不意味着可以直接宣布“整体质量已经全面超过成熟项目”。原因有两个：

- 当前样本集仍然偏小
- `pdf` 的当前检查更偏锚点和顺序，还不是最深层的结构化对比

因此，更准确的判断是：

- MoonBitMark 当前已经具备很强的基础竞争力
- 主要短板已经从“核心格式普遍失效”收缩为“少数格式的结构化质量和输出抛光还不够”

## 二、关键数据解读

### 1. MoonBitMark 自身结果

各格式最新表现：

- `text`：`0.9969`
- `docx`：`0.9956`
- `pptx`：`0.9959`
- `pdf`：`0.9925`
- `csv`：`0.9763`
- `json`：`0.9619`
- `xlsx`：`0.9545`
- `html`：`0.9159`，未通过
- `epub`：`0.7798`，未通过

失败项只有两个：

- `html_simple_table`
- `epub_winter_sports`

这说明当前项目的主要问题不再是“覆盖面不够”，而是“个别格式还存在明确的质量缺口”。

### 2. 与 baseline 的对比

最新 baseline 汇总：

- `markitdown`：`11/11` 运行成功，平均分 `0.7582`
- `docling`：`8/8` 运行成功，平均分 `0.6301`

需要说明：

- `docling` 并不支持当前评测集中的所有格式，因此只尝试了它真实支持的 `csv/docx/html/pdf/pptx/xlsx`
- `text/json/epub` 没有对 `docling` 记失败，而是显式跳过
- `pdf` baseline 目前没有 reference score，因此只验证它能稳定运行，不拿它做分数横比

### 3. 按格式对比观察

从当前 `report.json` 的逐项结果来看：

- `docx`
  - MoonBitMark：约 `0.9956`
  - markitdown：约 `0.8287`
  - docling：约 `0.6204`
  - 说明：当前 benchmark 上，MoonBitMark 的 DOCX 结果已经非常强

- `pptx`
  - MoonBitMark：约 `0.9959`
  - markitdown：约 `0.6058`
  - docling：约 `0.7181`
  - 说明：当前 PPTX 样本上，MoonBitMark 优势明显

- `xlsx`
  - MoonBitMark：约 `0.9545`
  - markitdown：约 `0.5215`
  - docling：约 `0.2790`
  - 说明：当前 XLSX 样本上，MoonBitMark 已经处于较强位置

- `html`
  - MoonBitMark：`0.9159`
  - markitdown：`0.8643`
  - docling：`0.7543`
  - 说明：MoonBitMark 分数更高，但因为锚点规则未通过，说明“结构和内容主干不错，细节契约未满足”

- `epub`
  - MoonBitMark：`0.7798`
  - markitdown：`0.7221`
  - docling：未参与
  - 说明：MoonBitMark 比当前 `markitdown` baseline 好，但仍未达到自己的通过阈值

因此，这份报告最重要的信号不是“MoonBitMark 很差”，恰恰相反，是：

- 在当前样本集上，MoonBitMark 已经在很多格式上表现很好
- 接下来最值得投入的是把局部失败项打磨到通过线以上

## 三、失败项的详细根因分析

## 1. html_simple_table 为什么没过

该 case 的核心要求是：

- 必须包含：`Simple Table Test`、`Sample Data Table`、`Laptop`、`Summary Statistics`
- 必须不包含：`<table`、`<div`、`function(`

当前结果：

- `anchors = 0.75`
- `noise_control = 1.0`
- `markdown_similarity = 0.9614`
- `ast_similarity = 0.85`
- `table_similarity = 1.0`
- 最终只因为 `anchors` 未过而失败

从输出 artifact 看，当前输出是：

- 有 `Sample Data Table`
- 有表格内容
- 有 `Summary Statistics`
- 缺少 `Simple Table Test`

而原始 HTML 文件中，`Simple Table Test` 出现在 `<title>` 中，不在 `<body>` 中。

这意味着失败根因非常明确：

- 当前 HTML 转换器提取了页面标题，但最终 Markdown 渲染没有把 `<title>` 作为正文的一部分落出来
- 也就是说，标题信息在内部存在，但没有进入最终用户可见输出

从实现上看，这个问题也很好对应：

- `src/formats/html/converter.mbt` 中 `extract_title(html)` 会拿到标题
- 但 `html_to_document(html, title)` 只是把标题挂到 `Document.title`
- `html_to_blocks(html)` 只解析 `<body>`，不会把 `<head><title>` 注入为一个块

于是就出现了现在这个现象：

- 评测要求标题锚点出现
- 页面正文也基本正确
- 但最终 Markdown 没有显式包含 `<title>`，导致只丢一个锚点就失败

这类问题的性质：

- 不是内容提取主流程失败
- 不是表格渲染失败
- 是“文档元信息没有正确映射到最终 Markdown”的表示层问题

这是一个高优先级、低复杂度修复点。

### html 的提质方向

建议按下面的顺序处理：

1. 明确 HTML 标题策略
   - 对于本地 HTML 文件，默认把 `<title>` 作为文档首个标题块输出
   - 如果正文第一个 `h1` 与 `<title>` 高度重复，则做去重

2. 调整 `html_to_document`
   - 不要只把标题挂在 `Document.title`
   - 应把标题注入 block 流中，优先作为开头的 `Heading(1, ...)`

3. 建立标题去重逻辑
   - `<title>` 与正文 `h1` 相同或高度近似时，只保留一个
   - 防止修复后引入重复标题

4. 增加 HTML 标题相关回归测试
   - 单独测 `<title>` 存在、正文无标题的情况
   - 测 `<title>` 和 `<h1>` 重复的情况
   - 测 `<title>` 和正文主标题不一致时的保留策略

5. 再进一步清理 HTML 噪声
   - 当前这条 case 已经去掉了 `>` 残留问题
   - 但后续仍建议针对 blockquote、`div` 包裹段落、嵌套 inline 节点继续做格式抛光

## 2. epub_winter_sports 为什么没过

当前结果：

- `anchors = 1.0`
- `noise_control = 1.0`
- `length = 1.0`
- `markdown_similarity = 0.6783`
- `ast_similarity = 0.5426`
- 失败项：`golden_markdown`、`ast_compare`

这组指标很关键，说明 EPUB 不是“没提到内容”，而是：

- 关键信息都提取到了
- 长度也足够
- 但是输出结构与 reference 差距仍然较大

换句话说，问题不在“有没有抽出正文”，而在“抽出来之后的结构组织还不够理想”。

从当前输出 artifact 可以看到几个很明显的结构问题：

### EPUB 当前主要问题 1：前言区和正文区没有分层整理

当前输出包含了大量 Project Gutenberg 的版权说明、前言、目录、插图表等内容，并且直接线性铺开。

这会带来两个后果：

- Markdown 相似度被拉低
- 文档结构层次不清楚，正文开始位置不够明确

reference 明显更偏向“结构化正文视图”，而当前输出更像“把 XHTML 全文粗线性展开”。

### EPUB 当前主要问题 2：章节结构提取不够稳定

输出里出现了大量：

- 全大写标题页
- 目录项
- 内部跳转链接
- 图像说明

这些内容并不是绝对错误，但它们和正文主结构混在一起，导致 AST 相似度明显下降。

也就是说，当前 EPUB 转换器更像是：

- 成功把内容读出来了
- 但没有足够强的“章节语义整理”和“噪声折叠”能力

### EPUB 当前主要问题 3：HTML 到 block 的转换过于通用，缺少 EPUB 语义化特判

`src/formats/epub/converter.mbt` 的核心路径是：

- 解析 container.xml
- 解析 OPF
- 找 spine 中的 XHTML
- 然后直接把 XHTML 丢给 `@html.html_to_blocks(xml_string)`

这意味着 EPUB 的正文结构其实高度依赖 HTML 转换器，而 HTML 转换器当前并不知道：

- 哪些块是目录
- 哪些链接是章节锚点导航
- 哪些图片是封面或插图页
- 哪些内容应该折叠成 metadata，而不是正文正文

这也是 EPUB 当前分数不上不下的核心原因：

- 不是读不到
- 而是读出来后没有 EPUB 专属清洗层

### EPUB 当前主要问题 4：OPF 解析仍然不够鲁棒

虽然本次样本已经能把内容跑出来，但当前 `parse_opf` 实现依然存在可维护性风险：

- 对元素名直接用裸字符串判断，如 `metadata`、`item`、`itemref`
- 没有统一的 namespace 归一化

这意味着：

- 当前样本恰好能跑通，不代表所有 EPUB 都稳
- 一旦遇到不同命名空间风格的 OPF，仍有较高概率出现 manifest/spine 丢失问题

所以它不是这次失败的唯一主因，但绝对是后续质量稳定性的隐患。

### EPUB 的提质方向

建议按下面顺序处理：

1. 增加 EPUB 专属正文清洗层
   - 在 `parse_xhtml_blocks` 之后，不要直接把所有 block 全量推入文档
   - 增加 `postprocess_epub_blocks(...)`

2. 优先处理三类噪声
   - 目录区块
   - 版权/法律声明区块
   - 重复封面/插图标题页

3. 强化章节识别
   - 识别 `CHAPTER`、`BOOK`、`PART` 等标题模式
   - 将纯文本大写章节标题规范化为 Markdown heading
   - 对章节开始处做段落切分和去重

4. 处理内部跳转链接
   - 对 `.htm.html#...` 这一类内部链接，优先保留文字，弱化或去掉链接目标
   - 避免目录项和正文一起造成视觉噪声

5. 调整图片策略
   - 封面图可以保留，但建议与正文分开
   - 对插图页和 `[Image unavailable.]` 等占位文案，应建立更清晰的保留/过滤策略

6. 增加 EPUB 结构后处理
   - 合并连续短段
   - 清理孤立全大写块
   - 对元信息、版权说明、目录、正文四个区域做显式分段

7. 提高 OPF 解析鲁棒性
   - 对 `metadata/item/itemref` 做 namespace 归一化
   - 对 `manifest/spine` 丢项增加 warning 和 diagnostic

8. 补专项测试
   - 有目录导航的 EPUB
   - 有封面页和插图页的 EPUB
   - 章节标题全大写的 EPUB
   - 带不同 namespace 写法的 OPF 样本

## 四、当前已经做得好的地方

这份报告里，不应只盯着两个失败项，也要明确当前项目已经在哪些方面建立了明显优势。

### 1. DOCX 已经从短板变成强项

最新结果中，两个 DOCX case 都通过，平均分接近满分。

这很重要，因为 DOCX 往往是复杂格式中的核心竞争点。当前 benchmark 上，MoonBitMark 的 DOCX 表现已经明显强于 `markitdown` 和 `docling`。

这意味着接下来在 DOCX 上的工作重点应从“修功能”转为：

- 增加覆盖面
- 强化复杂样本
- 防止回归

### 2. XLSX 当前表现已经很好

`xlsx_test_01` 当前不但通过，而且分数很高。

这说明：

- workbook 关系解析
- shared strings
- 多 sheet 渲染

这些关键能力至少在当前 benchmark 上已经建立起不错的可靠性。

后续应做的是扩样本，而不是立刻大改主逻辑。

### 3. PPTX 当前结果很亮眼

PPTX 样本当前分数接近满分，而且显著高于 baseline。

这说明 MoonBitMark 在：

- 幻灯片顺序
- 标题和正文分组
- 主体文本保留

这些方面已经做得相当不错。

### 4. PDF 当前样本非常强，但证据深度仍需加强

PDF 两个样本都过，分数也很高。

但当前 PDF 主要依赖：

- 锚点检查
- 长度检查
- 顺序检查

后续如果要更有说服力，需要再补：

- 表格型 PDF
- 复杂布局 PDF
- reference-backed 的结构比较

## 五、接下来如何提高文档转换质量

下面给出一个从“立刻见效”到“系统升级”的详细路线图。

## 第一阶段：先把当前 2 个失败项修掉

目标：

- 把通过率从 `9/11` 提高到 `11/11`

### 阶段 1-A：修 HTML 标题锚点问题

改动建议：

- 文件：`src/formats/html/converter.mbt`
- 重点函数：
  - `extract_title`
  - `html_to_document`
  - `html_to_blocks`

实施策略：

1. 将 `<title>` 转为首个 Heading block
2. 如果正文首个 `h1` 与标题重复，则只保留一个
3. 保持 `Document.title` 继续存在，供 metadata 使用

预期收益：

- `html_simple_table` 很大概率直接过线
- 还能提升 standalone HTML 的人类可读性

### 阶段 1-B：修 EPUB 结构化不足问题

改动建议：

- 文件：`src/formats/epub/converter.mbt`
- 新增一层：
  - `postprocess_epub_blocks`
  - `normalize_epub_heading`
  - `is_epub_boilerplate_block`
  - `is_epub_toc_block`

实施策略：

1. 在 XHTML 转 block 后做后处理
2. 折叠或剔除目录导航噪声
3. 把章节标题规范成 heading
4. 将封面/版权/目录/正文分段
5. 减少正文中的内部链接噪声

预期收益：

- `markdown_similarity` 提升
- `ast_similarity` 提升
- `epub_winter_sports` 有较大机会过线

## 第二阶段：把“能过”提升成“输出更漂亮”

目标：

- 不是只追求通过，而是让输出质量更适合真实用户使用

### 1. 做统一的 Markdown 后处理层

建议新增统一的后处理模块，对所有格式共享：

- 合并多余空行
- 清理孤立标点和空白缩进
- 收紧表格前后空行
- 把明显重复标题做去重
- 对孤立链接、残缺强调、图片占位做标准化

这类工作不应散落在各转换器里，而应有一个统一的“渲染后清洗层”。

### 2. 建立“结构优先”的输出规范

建议明确项目的输出优先级：

1. 标题层级正确
2. 列表结构正确
3. 表格结构正确
4. 阅读顺序正确
5. Markdown 样式尽量干净

原因是：

- 用户可以容忍某些强调符号风格差异
- 但不会容忍章节顺序错乱、目录和正文混杂、表格结构损坏

### 3. 强化噪声过滤能力

很多转换质量问题，并不是“没提出来”，而是“提了太多不该出现的东西”。

建议建立统一的噪声类型：

- 导航噪声
- 模板噪声
- 版权噪声
- 脚本/样式噪声
- 内部锚点链接噪声
- 图像占位噪声

然后让每个格式转换器都显式决定：

- 保留
- 降级为 metadata
- 从正文移除

## 第三阶段：提升评测体系本身的区分力

现在的评测体系已经比初始阶段强很多，但仍可以继续提高，让它更能推动质量进步。

### 1. 为 PDF 增加 reference-backed case

当前 PDF 结果很强，但缺少深结构比较。

建议新增：

- 带复杂标题层级的 PDF
- 带表格的 PDF
- 带双栏或版面扰动的 PDF

### 2. 增加“输出抛光”类断言

例如：

- 是否保留了应输出的 `<title>`
- 是否出现明显残留的内部锚点
- 是否出现连续重复标题
- 是否出现大量全大写噪声块

### 3. 分离“内容正确”和“排版美观”两个维度

建议后续报告中单独给出：

- 内容分
- 结构分
- 输出抛光分

这样更利于判断到底该修解析逻辑，还是该修渲染/清洗逻辑。

## 第四阶段：建立持续提质机制

如果目标是“长期超过 baseline，而不是某次样本偶然赢”，需要建立持续机制。

### 1. 为每个重点格式建立最小回归集

建议至少保证：

- HTML：标题、表格、导航噪声
- EPUB：目录、章节、封面、版权页
- DOCX：标题、列表、图片、链接
- XLSX：多 sheet、空单元格、shared strings
- PPTX：标题页、列表页、图片页

### 2. 每次提质都要求两类验证

- 当前 case 是否通过
- 是否拉高了 baseline 相对优势或至少不退化

### 3. 用报告驱动开发，而不是只看单次输出

建议把每次修复都映射到具体指标：

- HTML 标题修复：提升 anchors
- EPUB 章节整理：提升 markdown_similarity / ast_similarity
- PDF 深结构：增加 table_similarity / ast_compare

这样每次优化都是可量化的。

## 六、明确的优先级建议

如果只看“投入产出比”，我建议按下面顺序做：

### 第一优先级

- 修 HTML `<title>` 未进入正文的问题
- 修 EPUB 的正文结构后处理与噪声折叠

原因：

- 这是当前仅剩的两个失败项
- 修复后最有希望把 `9/11` 提升到 `11/11`

### 第二优先级

- 为 PDF 增加更深的 reference-backed case
- 增加 HTML / EPUB 的专项回归样本

原因：

- 让当前“看起来很强”的结果变得更有说服力

### 第三优先级

- 做统一 Markdown 后处理层
- 做统一噪声分类和过滤策略

原因：

- 这会决定 MoonBitMark 最终输出是否真的足够干净、专业、稳定

## 七、最终判断

基于最新报告，可以给出一个比较清晰的判断：

- MoonBitMark 当前已经不是追赶阶段的早期原型
- 在当前样本集上，项目已经具备较强竞争力
- `docx/pptx/xlsx` 这几类复杂格式的表现，已经是明显亮点
- 当前最主要的剩余问题，集中在：
  - HTML 标题元信息落地
  - EPUB 的结构整理与噪声控制

因此，接下来的工作重点不应该再是“大面积重写所有格式”，而应该是：

- 以最小而精准的修复，把剩余两个失败项推过线
- 再通过更深的样本和更细的评测，把“局部优秀”打磨成“整体稳定优秀”
