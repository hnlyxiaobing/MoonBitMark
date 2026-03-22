# MoonBitMark PDF 提质提效开发方案

## 0. 当前状态快照（2026-03-22）

这份文档仍保留为 PDF 提质的阶段性开发记录，但其中大量“待做项”已经在当前代码中落地。最新状态如下：

- PDF 管线已经从早期的单文件全文后处理，重排为 `route -> extraction -> assembly -> diagnostics` 的多文件实现
- 当前核心文件已经拆分为：
  - `converter.mbt`
  - `route.mbt`
  - `extract_native.mbt`
  - `extract_bridge.mbt`
  - `normalize.mbt`
  - `structure.mbt`
  - `assemble.mbt`
  - `diagnostics.mbt`
  - `model.mbt`
- `mbtpdf` 仍是默认快速路径，`pdfminer` bridge 作为小型复杂文档的 fallback provider
- 当前已经具备：
  - 页级 route
  - fallback provider 记录与 diagnostics
  - 页眉页脚清理
  - 长文标题/列表/段落恢复
  - scientific table 启发式恢复
  - code/formula block 启发式恢复
  - block-level repair，用于修复列表续行、孤立 bullet、漏升 heading
- `tests/conversion_eval` 中 PDF 已扩充到 7 个 case，且已有人工 reference markdown
- 最新 eval 结果：
  - PDF `7/7`
  - PDF 平均分 `0.9988`
  - `markitdown` baseline PDF 平均分 `0.7298`

这意味着本文档的以下阶段目标已经基本完成：

- 补齐 PDF case 与 reference markdown
- 建立 baseline 质量/耗时对比
- 将 PDF 转换器改成按页文本管线
- 在文本层 PDF 上把质量提升到不低于 `markitdown`

当前还未完成的主要事项已经从“文本层结构恢复”转向：

- 扫描 PDF 的页渲染 OCR recovery path
- 更高保真的 layout/table capability
- 进一步减少复杂 PDF 仍然依赖字符串启发式的部分

## 1. 目标与约束

本方案只针对 `PDF -> Markdown` 能力，目标分三层：

1. 质量目标
   - 在仓库维护的 PDF 评测集上，MoonBitMark 的输出质量不能低于 `markitdown`
   - 质量比较必须可量化，不能只靠人工肉眼判断
2. 性能目标
   - 在同一台机器、同一组 PDF 样本上，MoonBitMark native release 的耗时要优于 `markitdown`
   - 性能优化不能以明显牺牲质量为代价
3. 架构目标
   - 不破坏当前 `core -> engine -> formats -> ast` 的总架构
   - 优先优化 `src/formats/pdf/` 包内结构，而不是把 PDF 特例扩散到全局
   - OCR、页面渲染等横切能力仍应放在 `src/capabilities/`，不要把能力层直接塞进 CLI 或 engine

这轮工作不是“一次性重写 PDF 转换器”，而是建立一套可持续迭代的 PDF 提质方法，后续其他格式可以复用这套方法。

## 2. 当前代码现状

本节保留的是方案启动时的基线判断，用来解释为什么当时要做这轮重构；它不再代表 2026-03-22 的最新实现状态。最新状态以上面的“当前状态快照”为准。

### 2.1 当前 PDF 转换链路

当前实现集中在 `src/formats/pdf/converter.mbt`，主路径非常短：

1. `@pdfread.pdf_of_file(...)` 读取 PDF
2. `@pdfcrypt.is_encrypted(...)` 判断是否加密
3. `@pdftextlib.extract_text(pdf, page_break="\n\n---\n\n")` 提取全文文本
4. `normalize_whitespace(...)` 做空白归一化
5. `merge_partial_numbering(...)` 合并类似 `.1` 这种残缺编号行
6. `pdf_to_document(...)` 按双换行切段，再把页分隔符转成 `HorizontalRule`
7. `@ast.render_markdown(...)` 输出 Markdown

这意味着当前 PDF 能力本质上还是：

- 纯文本抽取优先
- 后处理较轻
- 结构恢复较弱
- 表格、标题层级、列表、页眉页脚、跨页断行都没有成体系处理

### 2.2 当前 PDF AST 落地方式

当前 AST 在 `src/ast/types.mbt` 中已经支持：

- `Heading`
- `Paragraph`
- `List`
- `Quote`
- `CodeBlock`
- `Table`
- `HorizontalRule`

因此，PDF 提质并不需要先改 AST 才能开始。先把 PDF 更稳定地映射到这些现有 block，就已经能提升很多质量。

### 2.3 当前 PDF 评测现状

当前 `tests/conversion_eval` 已经是很好的开发抓手，但对 PDF 还不够强：

1. 当前只有两个 PDF fixture
   - `multi_page.pdf`
   - `right_to_left_01.pdf`
2. 当前两个 PDF case 都没有 `golden_markdown`
   - 所以没有 `markdown_similarity`
   - 没有 `ast_similarity`
   - 没有 `table_similarity`
3. baseline 对 PDF 当前只验证“工具可运行”
   - `markitdown` / `docling` 的 `score` 现在是 `null`
   - 也没有记录 baseline 的耗时
4. 当前 PDF whitebox test 只覆盖了几个小 helper
   - `count_occurrences`
   - `file_stem`
   - `pdf_warning_diagnostics`
   - `pdf_ocr_warning`

结论很明确：

- 当前 PDF “看起来分数高”，主要因为用的是锚点、长度、顺序这类较浅指标
- 这说明 PDF 主路径现在“可用”，但还不能证明它已经超过 `markitdown`

### 2.4 当前依赖能力边界

通过 `moon ide doc` 看 `bobzhang/mbtpdf/pdftext`，当前可直接使用的提取能力主要是：

- `extract_text(...)`
- `extract_text_by_page(...)`

也就是说，当前已明确可依赖的是“全文文本”或“按页文本”。方案设计必须先按这个能力边界来做，不能假设现在已经有稳定的字级/块级坐标信息。

这会带来一个重要判断：

- 第一阶段应优先把“文本层 PDF”的段落、标题、列表、页眉页脚、跨页断行处理做好
- 表格和复杂版面恢复可以先做启发式版本
- 如果后续复杂布局仍明显不如 `markitdown`，再做“引入更深版面能力”的架构决策

### 2.5 当前 OCR 能力边界

当前 OCR 在 `src/capabilities/ocr/` 中已经有能力层和 bridge，但它本质上是“图片 OCR”，不是“PDF 页面渲染 + OCR”。

现在 PDF 转换器对 OCR 的处理只是：

- 如果文本层为空且配置了 OCR 模式，就给 warning
- 但不会真正把 PDF 页面渲染成图再走 OCR

所以这轮 PDF 优化不应一开始就押宝 OCR。先把文本层 PDF 做强，才是正确顺序。

## 3. 核心问题拆解

当前 PDF 提质要解决的问题可以拆成五类：

### 3.1 内容抽到了，但结构太弱

典型表现：

- 标题只是普通段落
- 列表项混成正文
- 跨页后正文被硬切开
- 页分隔线直接进入正文语义

### 3.2 物理分页影响了语义输出

当前实现把每个页分隔都转换为 `HorizontalRule`。这对“保留页边界”有帮助，但对面向阅读的 Markdown 不一定是最佳默认行为。

更合理的策略应是：

- 页边界默认只作为分析信息使用
- 只有当页边界同时也是语义边界时，才落成最终 block

### 3.3 文本后处理过于简单

当前只有：

- 空白归一化
- 残缺编号合并

但 PDF 真正常见的问题还有：

- 行尾断词和连字符
- 同一段落被硬换行
- 页眉页脚重复
- 双栏造成的顺序异常
- 表格内容被压扁成多空格文本

### 3.4 测试深度不足

现在 PDF 还缺：

- reference markdown
- AST 比较
- 表格比较
- 与 baseline 的质量分对齐
- 与 baseline 的耗时对齐

### 3.5 性能还没有形成“固定样本、固定口径、可回归”的约束

目前只有 `scripts/benchmark.ps1` 这个最小基准脚本，能测单文件本地 CLI 耗时，但还没有形成：

- 固定 PDF 基准集
- MoonBitMark vs markitdown 同口径对比
- 报告归档
- 回归阈值

## 4. 设计原则

### 4.1 只在 PDF 包内做第一轮重构

保持以下稳定：

- `engine` 的注册方式不变
- `PdfConverter::accepts()` / `PdfConverter::convert()` 的对外接口不变
- `ConvertResult` / `Document` / `diagnostics` 统一模型不变

先把复杂度收敛到 `src/formats/pdf/` 包内，这样风险最低，也最符合当前架构。

### 4.2 先补“可测量性”，再做大改

如果没有更深的 PDF case 和 baseline 对齐，后面做再多结构优化也很容易陷入：

- 看起来更漂亮
- 但不知道是否更好
- 一改就可能回归

所以 PDF 开发第一步不是改算法，而是先把评测基座补齐。

### 4.3 优先优化文本层 PDF

因为当前已知稳定能力是 `extract_text_by_page(...)`，所以第一阶段应优先做：

- 分页感知的文本清洗
- 段落恢复
- 标题/列表/页眉页脚识别
- 跨页拼接

这类工作对性能友好，也最符合“先超过 markitdown，再扩展上限”的路线。

### 4.4 把“复杂布局能力”做成后续可选增强

如果后面确认只靠文本层启发式无法稳定超过 `markitdown` 的复杂 PDF 表格/双栏场景，再引入新的能力层，例如：

- 更深的 PDF 布局解析
- PDF 页面渲染
- OCR fallback

但这些能力必须继续放在 `capabilities`，不要直接把外部桥接逻辑堆进 `converter.mbt`。

## 5. 推荐的包内重构形态

建议把 `src/formats/pdf/` 从“单文件逻辑堆叠”逐步整理为下面的内部结构：

1. `converter.mbt`
   - 只保留公开入口和总编排
2. `model.mbt`
   - 内部数据结构
   - 例如 `PdfPageText`、`PdfLine`、`PdfBlockCandidate`、`PdfAnalysis`
3. `extract.mbt`
   - 读取 PDF
   - `extract_text_by_page(...)`
   - 加密检查
4. `normalize.mbt`
   - 空白归一化
   - 行合并
   - 断词修复
   - 页眉页脚清理
5. `structure.mbt`
   - 标题识别
   - 列表识别
   - 跨页拼接
   - 简单表格识别
6. `render.mbt`
   - 从内部 block 候选转成 `@ast.Document`
7. `diagnostics.mbt`
   - PDF 专属 warning / diagnostic / stats

注意：

- 这些都是包内私有重构，不引入新的公共 API
- `converter.mbt` 仍是唯一稳定出口

## 6. 分阶段开发路线

## 阶段 0：先把评测和对比基线补齐

这是第一优先级，必须先做。

### 6.0.1 增强 PDF case 集

在 `tests/conversion_eval/cases/` 中为 PDF 增加更有区分度的样本，至少补齐以下类型：

1. 多页长文
2. 双栏文章
3. 含表格 PDF
4. 含明显标题层级/列表的 PDF
5. RTL / Unicode 稳定性 PDF
6. 无文本层或近似空文本层 PDF

当前只有两个 PDF 输入，远远不够支撑“超过 markitdown”的结论。

### 6.0.2 为 PDF 增加 reference markdown

建议第一轮不要实现自动 `pdf reference_builder`，而是直接采用人工整理的 reference 文件：

1. 在 `tests/conversion_eval/fixtures/expected/markdown/` 下为 PDF case 增加人工维护的 `.md`
2. case 中使用：
   - `golden_markdown`
   - `reference_builder: "copy"`
   - `reference_source`

这样可以马上打开以下评测能力：

- `markdown_similarity`
- `ast_similarity`
- `table_similarity`
- baseline 的 `score`

这是当前 PDF 评测最关键的缺口。

### 6.0.3 扩展 baseline 结果，记录耗时

建议扩展 `tests/conversion_eval/scripts/run_eval.py`：

1. `compare_baseline(...)` 返回：
   - `score`
   - `error`
   - `duration_ms`
2. MoonBitMark 当前已有 `runner_duration_ms`
3. 报告里补充 baseline 的耗时字段
4. summary 里单列 PDF 的 baseline 质量分和耗时对比

这样 PDF 的目标就能从“主观说比 markitdown 好”变成：

- 质量分是否 >= markitdown
- 耗时是否 < markitdown

### 6.0.4 整理 PDF case 命名

当前存在 `pdf_two_column_table.case.json` 文件名与实际内容不一致的问题。建议在这一步一起整理：

- case 文件名
- case `id`
- fixture 文件名

避免后面维护时混乱。

### 阶段 0 验收标准

1. `tests/conversion_eval` 中 PDF 至少有 5 到 6 个 case
2. 其中至少 3 个 case 有人工 reference markdown
3. `report.json` 中 PDF baseline 质量分不再是 `null`
4. `report.json` 中 PDF baseline 有 `duration_ms`

---

## 阶段 1：先做不改变总体行为的包内重构

这一阶段的目标不是立刻提高很多分，而是为后面的提质打地基。

### 6.1.1 改成“按页文本”内部管线

当前用的是 `extract_text(...)`。建议内部改成：

1. `extract_text_by_page(...)`
2. 形成 `Array[PdfPageText]`
3. 后续所有规范化、页眉页脚检测、跨页拼接都按页处理

即使最终仍要输出整篇 Markdown，也应先把页维度保住。

### 6.1.2 引入内部阶段模型

建议内部明确几个阶段：

1. `load_pdf`
2. `extract_pages`
3. `normalize_pages`
4. `reconstruct_blocks`
5. `build_document`
6. `render_result`

每个阶段尽量纯函数化，便于 whitebox test。

### 6.1.3 增加 PDF stats 和诊断信息

当前 `ConvertStats.duration_ms` 在 PDF 中没有被真正利用。建议：

1. 在 PDF 转换器内部记录总耗时
2. 增加必要的 metadata
   - 页数
   - 清理掉的页眉页脚数
   - 合并的跨页段落数
   - 识别出的表格块数
3. 增加 warning / diagnostic
   - 检测到疑似双栏
   - 检测到疑似表格但未能结构化
   - OCR 可用但未启用

这类信息对于后面调优非常有价值。

### 阶段 1 验收标准

1. `PdfConverter::convert()` 对外接口不变
2. `engine` 和 CLI 无需配合修改
3. 当前已有两个 PDF case 不退化
4. 新增 whitebox test 可以直接验证各阶段 helper

---

## 阶段 2：文本层 PDF 的核心质量提升

这一阶段是第一轮真正拉开质量差距的关键。

### 6.2.1 段落重建

重点做以下规则：

1. 行尾不是句末标点，下一行不是明显新段落，则尝试拼接
2. 行尾是连字符且下一行首字符可继续单词，则做断词修复
3. 连续短行但缩进/编号模式一致时，保留列表或标题，而不是盲目拼接
4. 跨页时如果上一页末行和下一页首行是同一段延续，则自动合并

这是当前 PDF 质量提升最有性价比的一步。

### 6.2.2 标题识别

在没有坐标的前提下，先做文本启发式：

1. 单独成段、较短、标题化大小写或全大写
2. 编号标题
   - `1.`
   - `1.1`
   - `I.`
   - `Chapter 1`
3. 标题后紧跟较长正文
4. 页面顶部短行更倾向标题，而不是正文

落地目标：

- 能把明显标题从 `Paragraph` 提升为 `Heading`

### 6.2.3 列表识别

把当前 `.1` 这类局部补丁扩展成通用列表规则：

1. `-` / `*` / `•`
2. `1.` / `1)` / `a)` / `(1)`
3. 残缺编号拼接
4. 连续列表项聚合成 AST `List`

这一步会直接提升 Markdown 的可读性和 AST 相似度。

### 6.2.4 页眉页脚清理

利用 `extract_text_by_page(...)` 的结果，在页级做重复检测：

1. 每页顶部或底部出现的重复短行
2. 页码模式
3. 页眉+页码组合

策略不是简单全删，而是：

1. 只有“跨多页重复”才删
2. 删除时记录 metadata / diagnostic
3. 对可能误删的重要标题保守处理

### 6.2.5 页边界语义化

建议默认策略从“所有页边界都输出 HR”调整为：

1. 默认优先语义连续
2. 只有显式章节切换或用户确实需要页边界时才保留分隔
3. 页数信息保留在 metadata，而不是默认污染正文

这是当前 PDF Markdown 质量提升的重要点。

### 阶段 2 验收标准

1. narrative / headings / list 类 PDF case 分数稳定上升
2. 新增 reference-backed case 的 `markdown_similarity`、`ast_similarity` 提升
3. 在这类文本层 PDF 上，MoonBitMark 质量分不低于 `markitdown`

---

## 阶段 3：简单表格和复杂版面的启发式增强

这一阶段要谨慎推进，因为当前已知输入能力主要是“按页纯文本”。

### 6.3.1 先做简单表格识别

先只处理纯文本里最常见、最可控的情况：

1. 多空格对齐的列
2. 明显表头 + 多行记录
3. 行列数较稳定

落地形式：

- 能结构化时输出 AST `Table`
- 不能稳定结构化时，宁可保留成段落，也不要生成错误表格

### 6.3.2 识别“疑似双栏/顺序异常”页面

因为现在没有稳定坐标信息，所以对双栏 PDF 建议做两层处理：

1. 第一层：检测异常模式
   - 行非常短
   - 相邻行语义跳跃
   - 词频/句子延续性异常
2. 第二层：如果规则足够确定，再做局部重排

如果这一层效果不稳定，不要强上。先通过 diagnostic 标注“疑似双栏页面”，保留问题可见性。

### 6.3.3 为复杂布局能力设置决策闸门

在阶段 3 结束时，必须做一次明确判断：

1. 只靠文本层启发式，是否已经能在目标 PDF 集上追平或超过 `markitdown`
2. 如果不能，卡在哪里：
   - 表格
   - 双栏
   - 扫描件
   - 公式

只有当结论明确是“文本层方法到顶了”，才进入下一阶段的能力扩展。

### 阶段 3 验收标准

1. 至少有 1 到 2 个 PDF table / layout case 被纳入评测
2. 简单表格 case 的 `table_similarity` 可用
3. 复杂版面若仍不足，也能在报告中清楚暴露，而不是“分数看不出来”

---

## 阶段 4：扫描件与无文本层 PDF 的能力扩展

这是第二优先级，不要在前面阶段还没做完时抢跑。

### 6.4.1 新能力必须放在 `capabilities`

建议不要直接把“PDF 渲染成图 + OCR”的逻辑塞到 `src/formats/pdf/`。

更合理的演进方式是新增一个能力层，例如：

- `src/capabilities/pdf_render/`
- 或 `src/capabilities/ocr/pdf_bridge/`

职责分离：

1. `formats/pdf`
   - 决策何时需要 fallback
2. `capabilities/...`
   - 真正执行渲染/OCR

### 6.4.2 OCR 触发策略

建议默认只在以下情况触发：

1. `native_text.trim() == ""`
2. 或用户显式 `--ocr force`

不要让文本层 PDF 默认走 OCR，否则性能目标会被直接破坏。

### 6.4.3 OCR 输出的融合策略

OCR 不是替代全部文本层，而是 fallback：

1. 优先 native text
2. native text 为空时，用 OCR 结果
3. 部分页面失败时记录 diagnostic

### 阶段 4 验收标准

1. 新增扫描 PDF case
2. `ocr=auto` 时，对无文本层 PDF 能输出非空 Markdown
3. 文本层 PDF 默认性能不受明显影响

## 7. 测试与评估体系的具体用法

这部分是后续真正开发时要严格执行的闭环。

### 7.1 包内 whitebox test

在 `src/formats/pdf/` 下优先补 helper 级测试，覆盖：

1. 断词修复
2. 段落拼接
3. 列表识别
4. 标题识别
5. 页眉页脚重复检测
6. 页边界合并
7. 简单表格识别

原因：

- 这类逻辑最适合纯字符串输入输出测试
- 失败时定位最快
- 不依赖真实 PDF fixture，开发速度高

### 7.2 转换级测试

为 `PdfConverter::convert(...)` 增加更接近真实行为的测试：

1. 使用固定 PDF fixture
2. 断言 `metadata`
3. 断言 `warnings / diagnostics`
4. 断言 `document` 中 block 类型分布

相比只看字符串，这类测试更能约束结构质量。

### 7.3 利用 conversion_eval 驱动迭代

每次 PDF 改动都跑：

```powershell
python tests/conversion_eval/scripts/run_eval.py run --compare-baselines
```

重点只看 PDF：

1. MoonBitMark 分数是否上升
2. `markitdown` 相对分差是否扩大
3. 新增 case 是否暴露回归
4. artifacts 中实际输出是否符合预期

开发时要重点查看：

- `tests/conversion_eval/reports/latest/report.json`
- `tests/conversion_eval/reports/latest/artifacts/<case-id>/output.md`
- `tests/conversion_eval/reports/latest/artifacts/<case-id>/reference.md`

### 7.4 用 benchmark 脚本守住性能

每个阶段至少对 2 到 3 个代表 PDF 跑本地基准：

```powershell
pwsh -File scripts/benchmark.ps1 -InputPath tests/conversion_eval/fixtures/inputs/pdf/multi_page.pdf -Iterations 10
```

建议固定三类样本：

1. 多页长文
2. 表格型 PDF
3. 复杂布局 PDF

后续可把 `scripts/benchmark.ps1` 扩展成“批量 PDF benchmark”，并归档结果。

## 8. 推荐的开发顺序

下面是建议的实际执行顺序，不要打乱。

1. 补 PDF case 与人工 reference markdown
2. 扩展 eval 报告，记录 baseline 质量分和耗时
3. 在 `src/formats/pdf/` 做包内重构，改成按页文本管线
4. 补一批 whitebox test
5. 做段落、标题、列表、页眉页脚、跨页拼接
6. 复跑 PDF eval 和 benchmark
7. 再处理简单表格与疑似双栏问题
8. 判断是否需要更深的能力层
9. 只有文本层方法到顶后，再上 PDF 渲染/OCR fallback

这个顺序的原因是：

- 前 5 步就足以显著提升大多数文本层 PDF
- 而且对性能最友好
- 也最不容易破坏现有架构

## 9. 每一轮开发的标准动作

后续你和我按这个固定动作推进 PDF 提质：

1. 先选一个明确子目标
   - 例如“页眉页脚清理”
   - 或“跨页段落合并”
2. 先补对应的 whitebox test / eval case
3. 再做实现
4. 跑目标测试
   - `moon test src/formats/pdf`
5. 跑 PDF eval
6. 跑 PDF benchmark
7. 最后再跑：

```powershell
moon info
moon fmt
```

注意顺序不能反，因为 `moon info` / `moon fmt` 是收尾动作，不是开发主循环。

## 10. 第一轮建议直接开做的任务

如果下一步开始进入实现，我建议第一轮只做下面四件事：

1. 给 PDF 补 3 到 4 个 reference-backed case
   - 至少包含多页长文、表格、双栏、标题列表
2. 扩展 eval 报告，记录 baseline 的 `duration_ms`
3. 把 PDF 内部改成 `extract_text_by_page(...)` + 分页后处理
4. 实现第一版：
   - 段落拼接
   - 断词修复
   - 页眉页脚清理
   - 标题/列表识别

这四件事做完之后，再看结果决定是否进入“表格/复杂布局增强”。

## 11. Definition of Done

当下面这些条件同时成立时，可以认为 PDF 第一阶段达标：

1. PDF 评测集覆盖至少 5 到 6 个有代表性的 case
2. 至少 3 个 PDF case 有人工 reference markdown
3. MoonBitMark 在 PDF quality score 上不低于 `markitdown`
4. MoonBitMark 在同样 PDF 集上的耗时优于 `markitdown`
5. `src/formats/pdf/` 已经形成可维护的多文件包内结构
6. 当前 `engine/core/ast/capabilities` 总架构没有被破坏
7. 所有新增行为都有 whitebox test 或 eval case 兜底

## 12. 最后结论

当前 PDF 不是“完全不行”，而是“基础能力已经可用，但评测证据太浅、结构恢复太弱、性能对比还没闭环”。

正确路线不是马上重写，而是：

1. 先补评测深度和 baseline 对齐
2. 再做包内分页管线重构
3. 优先做文本层 PDF 的结构恢复
4. 最后再决定是否引入更深的布局/OCR 能力

这样做，既符合你“一个格式一个格式打磨”的节奏，也能最大程度复用当前项目已有的架构和评测体系。
