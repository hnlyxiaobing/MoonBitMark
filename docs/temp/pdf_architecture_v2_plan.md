# MoonBitMark PDF 新架构方案（V2）

## 0. 实施状态快照（2026-03-22）

本文档仍然是 PDF V2 的主设计文档，但它不再只是“未来方案”。截至 2026-03-22，下面这些内容已经落地：

- `converter.mbt` 已经收敛为 orchestrator
- `route.mbt` 已实现页级 route 与 route summary
- `extract_native.mbt` 已承载 `mbtpdf` 提取主路径
- `extract_bridge.mbt` + `scripts/pdf/bridge.py` 已提供 `pdfminer` fallback provider
- `model.mbt` 已承载 route / extraction / assembly 所需的内部模型
- `assemble.mbt` 已接管 normalize + structure + metadata 汇总主流程
- `diagnostics.mbt` 已输出 route、fallback provider、bridge warning、OCR warning
- `normalize.mbt` / `structure.mbt` 已具备 native structured path 的首轮能力：
  - 页眉页脚与页码剔除
  - 标题 / 列表 / 段落恢复
  - scientific table 启发式重建
  - code / formula block 启发式恢复
  - block-level repair，用于收敛列表续行、孤立 bullet、漏升 heading

最新本地评测结果也说明第一轮 V2 已经越过“架构骨架”阶段，进入“能力继续增强”阶段：

- `tests/conversion_eval/reports/latest/summary.md`
- PDF `7/7`
- PDF 平均分 `0.9988`
- `markitdown` baseline PDF 平均分 `0.7298`

因此，本文档中各阶段的状态可以归纳为：

- 阶段 A `架构重排`：已完成
- 阶段 B `页级路由`：已完成
- 阶段 C `native structured stages`：已完成第一轮可用实现，仍可继续拆分细化
- 阶段 D `capability 接口`：只完成了 `pdfminer` bridge，一般化 `pdf_layout` / `pdf_page_render` / `pdf_ocr` 接口仍未完成
- 阶段 E `增强能力接入`：未完成

后续开发应把重点从“是否继续做 route/assembly 重排”切换到：

1. 把当前仍在 `normalize.mbt` / `structure.mbt` 内的启发式逐步拆到更清晰的 stage
2. 接入真正的 layout / page-render / OCR capability
3. 继续压复杂 PDF，而不是再重复做已解决的 narrative PDF 工作

## 1. 文档定位

本文档是 MoonBitMark PDF 转换能力的下一版正式架构方案。

它在现有 [pdf_optimization_plan.md](D:/MySoftware/MoonBitMark/docs/temp/pdf_optimization_plan.md) 基础上继续推进，但定位已经不同：

- `pdf_optimization_plan.md` 主要解决“如何先把当前 PDF 能力提起来”
- 本文档解决“MoonBitMark 未来 2 到 4 个开发阶段里，PDF 系统应该长成什么样”

本文档目标不是介绍思路，而是给出一份可以直接进入开发的蓝图，包括：

- 架构目标
- 分层设计
- 内部类型草案
- 模块目录与职责
- 阶段执行顺序
- 测试与验收标准
- 明确冻结的架构决策

文档确认后，后续开发应以本文档为主，不再反复回到“是否要改成多阶段架构”的讨论。

## 2. 背景判断

### 2.1 当前实现已经解决的问题

当前 MoonBitMark 的 PDF 路线已经具备以下基础能力：

- 基于 `mbtpdf` 的数字化 PDF 文本提取
- 按页提取与按页清洗
- 页眉页脚重复内容剔除
- 轻量的标题、列表、段落恢复
- 基本的 diagnostics、warnings、eval 闭环

这套路线已经足够处理：

- 简单 memo / report / notice
- 普通数字化长文 PDF
- 一部分标题和列表明确的文档
- 右到左字符稳定性和多页长文 case

### 2.2 当前实现的上限

当前方案的本质仍然是：

- 先拿文本
- 再做字符串级修复
- 最后推断结构

这个范式的上限已经清楚暴露在复杂 PDF 上：

- scientific PDF 的密集表格恢复弱
- 代码与公式块边界不可靠
- 双栏文档阅读顺序难稳定恢复
- 扫描件和坏文本层缺少真正的 recovery path

因此，V2 架构必须从“增强版文本提取器”升级为“可路由、可降级、可增强的 PDF 系统”。

### 2.3 调研后的工程结论

对外部工具调研后，可以把主流路线概括为三类：

1. 轻量文本提取类
   - 代表：MarkItDown 默认 PDF 路线
   - 实质：文本提取 + 轻包装
   - 优势：快、轻、稳定
   - 短板：复杂结构恢复弱

2. 多阶段文档理解类
   - 代表：Docling、Marker、MinerU
   - 实质：layout + reading order + table + code/formula + OCR 等显式阶段
   - 优势：复杂 PDF 质量高
   - 短板：重、慢、依赖多

3. 组件能力类
   - 代表：Surya、Azure Document Intelligence、Unstructured hi_res
   - 实质：提供 layout / OCR / table / markdown 等单项能力
   - 优势：可组合
   - 短板：需要上层自己编排

MoonBitMark 的正确路线不是：

- 继续堆更多 regex 和字符串规则
- 或者直接照搬 Docling/Marker 的完整依赖体系

MoonBitMark 的正确路线是：

- 保留纯 MoonBit 快速默认路径
- 引入显式的路由和统一中间表示
- 把复杂能力作为 capability 接入
- 让复杂 PDF 可以按页升级到更强路径

## 3. 架构目标

### 3.1 功能目标

PDF V2 必须稳定覆盖三类文档：

1. 快速文本型 PDF
   - 目标：快
   - 方式：native text fast path

2. 复杂结构型 PDF
   - 目标：结构正确
   - 方式：layout / table / reading order / code-formula path

3. 恢复型 PDF
   - 目标：避免空输出和严重乱码
   - 方式：OCR recovery path

### 3.2 工程目标

- 不破坏现有 `core -> formats -> ast` 主架构
- `PdfConverter::convert()` 对外签名保持稳定
- 默认路径继续支持纯 MoonBit、本地、低依赖执行
- 外部桥接能力全部放到 `src/capabilities/`
- 复杂能力必须是可选增强，而不是默认强依赖

### 3.3 性能目标

- 简单数字化 PDF 仍以当前 native path 为主，不允许因为 V2 架构重排而明显变慢
- 复杂增强 path 必须按页或按文档条件触发，不能默认全量运行
- diagnostics、route plan、IR 组装的开销必须明显低于 OCR / layout 类能力本身

### 3.4 质量目标

- 对于普通数字化 PDF，V2 不得退化现有已通过的 case
- 对于复杂 PDF，V2 必须为表格、代码、公式、双栏提供明确的架构落点，而不是继续靠字符串猜测
- 对于扫描 PDF，V2 必须能够给出可预期的 recovery 行为和 diagnostics

## 4. 冻结的架构决策

本节内容视为当前阶段的确认结论，后续开发默认遵守。

### 4.1 决策 1：PDF 必须改成多阶段系统

不再以单一 `extract -> normalize -> reconstruct` 字符串流程作为最终架构。

### 4.2 决策 2：保留纯 MoonBit 快路径

`mbtpdf` native text 路线不会被移除。它仍是默认路径和性能基线。

### 4.3 决策 3：复杂能力全部 capability 化

以下能力不直接耦合到 `src/formats/pdf/`：

- layout analysis
- page rendering
- OCR
- formula / advanced code understanding
- 外部服务或 Python bridge

### 4.4 决策 4：按页路由优先于整份文档路由

优先允许不同页面走不同 provider。整份文档单一路由只作为优化或兜底，不作为唯一模型。

### 4.5 决策 5：统一 PDF IR 是必选项

后续任何 provider 的结果都必须先落入统一 IR，再渲染 AST / Markdown。

### 4.6 决策 6：Markdown 渲染不直接绑定提取阶段

提取阶段只生产 IR，不直接输出 Markdown 片段。

### 4.7 决策 7：复杂表格优先保真，不强求纯 GFM

对于 merged cells、复杂 header、caption/footnote 丰富的表格：

- 优先输出 HTML table
- 不为了“看起来像 Markdown”而破坏结构

### 4.8 决策 8：页信息默认不进入正文语义

页码、页眉、页脚、分页符默认进入：

- metadata
- diagnostics
- 或 HTML comments

不再默认进入正文 block。

## 5. 总体架构

PDF V2 固定拆成五层：

1. `Route Layer`
2. `Extraction Layer`
3. `IR Layer`
4. `Assembly Layer`
5. `Render Layer`

整体流程：

`PDF file`
-> `open + basic diagnostics`
-> `route plan`
-> `page providers`
-> `page IR`
-> `document assembly`
-> `AST render`
-> `Markdown + metadata + diagnostics`

### 5.1 分层边界

每层只做自己职责内的事：

- Route：决定怎么处理
- Extraction：抽取原始内容
- IR：承载结构化中间表示
- Assembly：解决跨页与文档级逻辑
- Render：转成 AST 和 Markdown

### 5.2 层间不变量

1. Route 层不产生正文 Markdown
2. Extraction 层不决定最终 heading/list/table 渲染策略
3. IR 层必须可表达复杂对象
4. Assembly 层允许修改顺序和归属，但不丢 provenance
5. Render 层不再做重推断，只做受控映射与轻量格式化

## 6. 分层设计

### 6.1 Route Layer

职责：

- 读取原始 PDF 的低成本特征
- 选择文档级默认路径
- 选择页级 provider
- 产出 diagnostics 和 route metadata

输入：

- `file_path : String`
- `ctx : @core.ConvertContext`
- `pdf_doc : @pdf.Pdf`

输出：

- `PdfRoutePlan`

建议数据结构：

```text
PdfRoutePlan
- document_mode : PdfDocumentMode
- pages : Array[PdfPageRoute]
- summary : PdfRouteSummary
```

```text
PdfPageRoute
- page_no : Int
- provider : PdfPageProviderKind
- text_quality : PdfTextQuality
- layout_complexity : PdfLayoutComplexity
- flags : Array[PdfRouteFlag]
```

建议枚举：

```text
PdfDocumentMode
- FastTextOnly
- Mixed
- RecoveryOnly
```

```text
PdfPageProviderKind
- NativeTextFast
- NativeTextStructured
- LayoutEnhanced
- OcrRecovery
- Hybrid
```

```text
PdfTextQuality
- Empty
- VeryPoor
- Weak
- Good
- Strong
```

```text
PdfLayoutComplexity
- Simple
- Medium
- Complex
```

```text
PdfRouteFlag
- SuspectTable
- SuspectCode
- SuspectFormula
- SuspectMultiColumn
- SuspectScanned
- SuspectHeaderFooter
- SuspectBrokenSpacing
```

#### 6.1.1 第一版路由算法

第一版不依赖复杂模型，仅使用低成本启发式：

1. 提取每页原始文本
2. 统计：
   - 字符数
   - 非空行数
   - 数字比例
   - 标点比例
   - 单词平均长度
   - 长连写 token 数
   - 代码关键字命中
   - 公式特征命中
   - 表格特征命中
3. 产出页级 route
4. 汇总出文档级 mode

#### 6.1.2 第一版 route 判定规则

建议初版按以下优先级：

1. 如果页文本近空：
   - `OcrRecovery`
2. 如果命中强表格特征或强代码/公式特征：
   - `NativeTextStructured`
3. 如果命中明显多栏或强坏间距特征：
   - `NativeTextStructured`
4. 其余：
   - `NativeTextFast`

说明：

- 第一阶段先不真正启用 `LayoutEnhanced`
- 但路由枚举必须先预留，避免之后重构 provider 接口

### 6.2 Extraction Layer

职责：

- 根据 route 提取每页内容
- 输出原始 page extraction 结果
- 保留来源与置信信息

建议接口：

```text
trait PdfPageProvider {
  extract_page(
    pdf_doc : @pdf.Pdf,
    page_route : PdfPageRoute,
    ctx : @core.ConvertContext,
  ) -> PdfPageExtraction raise
}
```

建议结果结构：

```text
PdfPageExtraction
- page_no
- source_kind
- raw_text?
- lines : Array[PdfRawLine]
- regions : Array[PdfRawRegion]
- diagnostics
```

```text
PdfRawLine
- text
- bbox?
- source
- confidence?
```

```text
PdfRawRegion
- kind
- text
- bbox?
- lines
- source
- confidence?
```

#### 6.2.1 Provider 列表

1. `NativeTextProvider`
   - 基于 `mbtpdf`
   - 第一阶段唯一必须实现的 provider

2. `LayoutProvider`
   - capability bridge
   - 后续接 layout engine

3. `OcrProvider`
   - capability bridge
   - 后续接 pdf_page_render + ocr

4. `HybridProvider`
   - capability bridge
   - 后续用于 native text 与 OCR 混合

#### 6.2.2 NativeTextProvider 的固定职责

- 负责按页文本提取
- 尽可能保留原始行边界
- 不在 provider 内做强语义恢复
- 可以做非常轻量的字符规范化，例如：
  - `\r\n -> \n`
  - 控制字符清理
  - 明显坏编码字符剔除

#### 6.2.3 NativeTextProvider 禁止事项

- 不在这里决定 heading level
- 不在这里生成 Markdown table
- 不在这里做跨页拼接
- 不在这里把正文直接合并成最终段落

### 6.3 IR Layer

IR 是 V2 的中心，不得省略。

#### 6.3.1 文档 IR

```text
PdfDocumentIr
- title : String?
- metadata : Map[String, String]
- pages : Array[PdfPageIr]
- blocks : Array[PdfBlockIr]
- route_summary : PdfRouteSummary
```

#### 6.3.2 页 IR

```text
PdfPageIr
- number : Int
- route : PdfPageRoute
- regions : Array[PdfRegionIr]
- blocks : Array[PdfBlockIr]
- diagnostics : Array[PdfIrDiagnostic]
```

#### 6.3.3 区域 IR

```text
PdfRegionIr
- id : String
- kind : PdfRegionKind
- text : String
- bbox : PdfBBox?
- lines : Array[PdfLineIr]
- source : PdfSourceKind
- confidence : Double?
```

#### 6.3.4 行 IR

```text
PdfLineIr
- text : String
- bbox : PdfBBox?
- source : PdfSourceKind
- confidence : Double?
```

#### 6.3.5 块 IR

```text
PdfBlockIr
- id : String
- kind : PdfBlockKind
- text : String
- page_span : (Int, Int)
- attrs : PdfBlockAttrs
- children : Array[PdfBlockIr]
- provenance : Array[PdfProvenance]
```

#### 6.3.6 支撑类型

```text
PdfBBox
- left : Double
- top : Double
- right : Double
- bottom : Double
```

```text
PdfSourceKind
- NativeText
- Layout
- Ocr
- Hybrid
```

```text
PdfRegionKind
- BodyText
- Heading
- ListItem
- Table
- Code
- Formula
- Figure
- Caption
- Header
- Footer
- PageNumber
- Unknown
```

```text
PdfBlockKind
- Title
- Heading(Int?)
- Paragraph
- List(Bool)
- ListItem(Bool)
- Table
- CodeBlock(String?)
- Formula(Bool)
- Figure
- Caption
- Quote
- Furniture
- RawHtml
```

```text
PdfBlockAttrs
- caption : String?
- lang : String?
- ordered : Bool?
- table : PdfTableIr?
- code : PdfCodeIr?
- formula : PdfFormulaIr?
- figure_alt : String?
- html : String?
```

```text
PdfProvenance
- page_no : Int
- source : PdfSourceKind
- bbox : PdfBBox?
- confidence : Double?
```

#### 6.3.7 表格、代码、公式 IR

```text
PdfTableIr
- caption : String?
- headers : Array[String]
- rows : Array[Array[String]]
- footnotes : Array[String]
- merged_cells : Array[PdfMergedCell]
- render_mode : PdfTableRenderMode
```

```text
PdfMergedCell
- row
- col
- rowspan
- colspan
- text
```

```text
PdfTableRenderMode
- Markdown
- Html
```

```text
PdfCodeIr
- caption : String?
- lang : String?
- content : String
```

```text
PdfFormulaIr
- caption : String?
- latex : String?
- text_fallback : String
- display : Bool
```

#### 6.3.8 IR 约束

- 所有块都必须可追溯到页和来源
- IR 不依赖最终 Markdown 语法
- IR 必须能表达“复杂表格降级为 HTML”的情况
- IR 必须允许后续接入 layout / OCR / formula provider，而不改 render 主逻辑

### 6.4 Assembly Layer

职责：

- 把页级抽取结果整理成文档级逻辑结构
- 解决跨页、顺序、caption、表格、列表、代码、公式归属

建议拆分为固定的子阶段：

1. `edge_cleanup`
2. `region_to_block`
3. `reading_order_resolver`
4. `paragraph_assembler`
5. `list_normalizer`
6. `table_assembler`
7. `code_formula_normalizer`
8. `caption_linker`
9. `document_finalize`

#### 6.4.1 `edge_cleanup`

职责：

- 去除重复 header/footer
- 去除独立页码
- 记录去除计数与 diagnostics

#### 6.4.2 `region_to_block`

职责：

- 将 raw region / line 先映射到 block 候选
- 这里允许使用当前已经实现的轻量 heading/list/paragraph 规则

#### 6.4.3 `reading_order_resolver`

职责：

- 统一 block 顺序
- 第一阶段主要服务 native text structured path
- 后续接 layout provider 时，变成关键阶段

#### 6.4.4 `paragraph_assembler`

职责：

- 合并跨行和跨页段落
- 修复断词
- 保留标题、列表、代码、公式边界

#### 6.4.5 `list_normalizer`

职责：

- 连续 list item -> list block
- 区分有序 / 无序列表

#### 6.4.6 `table_assembler`

职责：

- 表格候选区域 -> `PdfTableIr`
- 第一阶段允许两级策略：
  - 简单规则表 -> Markdown table
  - 复杂表 -> RawHtml / paragraph fallback

#### 6.4.7 `code_formula_normalizer`

职责：

- 稳定代码块和公式块边界
- 第一阶段允许只做 code/formula block 边界识别和文本整理
- 后续 capability 可补真正的 LaTeX / language enrichment

#### 6.4.8 `caption_linker`

职责：

- 将 `Table 1`、`Listing 1`、`Fig. 4` 一类 caption 与目标 block 关联

#### 6.4.9 `document_finalize`

职责：

- 输出最终 `PdfDocumentIr.blocks`
- 汇总 metadata、warnings、diagnostics

### 6.5 Render Layer

职责：

- 从 `PdfDocumentIr` 渲染到 `@ast.Document`
- 再由 AST 渲染 Markdown

建议接口：

```text
fn render_pdf_document(ir : PdfDocumentIr) -> @ast.Document
```

渲染规则固定如下。

#### 6.5.1 标题

- `Title` -> `Heading(1)`
- `Heading(level)` -> `Heading(level)`
- 如果 level 不确定：
  - 文档第一个主标题优先降到 1
  - 其余未知标题优先降到 2

#### 6.5.2 段落、引用、列表

- `Paragraph` -> `@ast.text_paragraph`
- `Quote` -> `@ast.Quote`
- `List` -> `@ast.List`

#### 6.5.3 代码

- `CodeBlock(lang?)` -> `@ast.CodeBlock`
- `lang` 为空则输出裸 fence

#### 6.5.4 公式

当前 AST 尚无专门公式节点，V2 第一阶段先采用以下规则：

- display formula -> 独立 paragraph，内容为 `$$...$$` 或 text fallback
- inline formula 不在第一阶段强制支持 AST 级恢复

后续如 AST 增加公式节点，再升级 render 规则。

#### 6.5.5 表格

- `PdfTableRenderMode.Markdown` -> `@ast.Table`
- `PdfTableRenderMode.Html` -> `RawHtml` paragraph 或 HTML block

#### 6.5.6 Figure / Caption

第一阶段：

- figure 先输出 caption 文本或占位说明
- 不强制输出图片资源

#### 6.5.7 Furniture

- 默认不进入正文 block
- 仅进入 metadata / diagnostics

## 7. 模块目录与职责

### 7.1 `src/formats/pdf/` 最终目录

```text
src/formats/pdf/
├── converter.mbt
├── model.mbt
├── route.mbt
├── extract_native.mbt
├── extract_layout_bridge.mbt
├── extract_ocr_bridge.mbt
├── normalize_text.mbt
├── assemble.mbt
├── reading_order.mbt
├── tables.mbt
├── code_formula.mbt
├── render.mbt
├── diagnostics.mbt
└── converter_wbtest.mbt
```

### 7.2 文件职责

#### `converter.mbt`

只保留总编排：

1. 打开 PDF
2. 获取 route plan
3. 执行 provider
4. 生成 page IR
5. assembly
6. render
7. 填充 `ConvertResult`

#### `model.mbt`

放全部 PDF 内部数据模型：

- route models
- extraction models
- IR models
- diagnostics support models

#### `route.mbt`

放 route diagnostics 与 route plan 构建逻辑。

#### `extract_native.mbt`

封装 `mbtpdf` native text provider。

#### `extract_layout_bridge.mbt`

封装 `src/capabilities/pdf_layout/` 桥接逻辑。

#### `extract_ocr_bridge.mbt`

封装 `src/capabilities/pdf_ocr/` 与 `pdf_page_render/` 桥接逻辑。

#### `normalize_text.mbt`

只做文本层面的轻量规整：

- 控制字符清理
- 基本断词修复
- 行边界保留
- 明显坏间距处理

不承担文档级结构恢复。

#### `assemble.mbt`

主装配流程入口。

#### `reading_order.mbt`

阅读顺序的独立逻辑，不再混在 paragraph merge 内。

#### `tables.mbt`

表格检测、表格组装、表格渲染模式选择。

#### `code_formula.mbt`

代码块和公式块的边界、caption、规范化处理。

#### `render.mbt`

IR -> AST 的集中渲染。

#### `diagnostics.mbt`

route、fallback、drop、recovery 等告警与 metadata 汇总。

### 7.3 `src/capabilities/` 推荐目录

```text
src/capabilities/
├── pdf_layout/
├── pdf_page_render/
├── pdf_ocr/
└── pdf_formula/
```

能力层职责：

- 统一桥接外部能力
- 隔离具体实现差异
- 暴露 capability availability
- 输出统一 diagnostics

## 8. 配置设计

PDF V2 建议增加包内专用配置对象。

```text
PdfPipelineConfig
- enable_route : Bool
- enable_page_level_routing : Bool
- enable_native_fast_path : Bool
- enable_layout_bridge : Bool
- enable_ocr_bridge : Bool
- enable_code_formula_stage : Bool
- enable_table_stage : Bool
- prefer_html_tables : Bool
- preserve_page_comments : Bool
```

配置来源：

- 默认值内置
- 可从 `ConvertContext` 派生
- 不建议一开始就开放大量 CLI 选项

第一阶段推荐默认值：

- `enable_route = true`
- `enable_page_level_routing = true`
- `enable_native_fast_path = true`
- `enable_layout_bridge = false`
- `enable_ocr_bridge = false`
- `enable_code_formula_stage = true`
- `enable_table_stage = true`
- `prefer_html_tables = true`

## 9. 三条执行路径

### 9.1 FastTextPath

适用：

- 文本层强
- 版面简单
- 表格/代码/公式信号弱

处理链：

`NativeTextProvider`
-> `normalize_text`
-> `region_to_block`
-> `paragraph/list/heading assembly`
-> `render`

目标：

- 保持当前性能优势
- 作为所有 PDF 的默认起点

### 9.2 StructuredPath

适用：

- 强表格
- 强代码
- 强公式
- 强双栏
- 强 caption

第一阶段处理链：

`NativeTextProvider`
-> `normalize_text`
-> `table/code/formula heuristics`
-> `reading_order`
-> `assembly`
-> `render`

后续增强处理链：

`LayoutProvider`
-> `table/code/formula stage`
-> `reading_order`
-> `assembly`
-> `render`

### 9.3 RecoveryPath

适用：

- 无文本层
- 极弱文本层
- 扫描件
- 坏编码页

处理链：

`page_render`
-> `ocr`
-> `text cleanup`
-> `structured assembly`
-> `render`

第一阶段只保留接口，不要求全实现。

## 10. 当前问题到新架构的映射

### 10.1 `pdf_code_and_formula`

当前问题：

- 代码和正文粘连
- `Formula` 页恢复不稳
- 块边界与顺序不稳定

V2 对应修复责任：

- `Route Layer` 标记 `SuspectCode` / `SuspectFormula`
- `code_formula.mbt` 负责代码与公式边界
- `reading_order.mbt` 负责块顺序
- 后续 `pdf_formula` capability 负责公式增强

### 10.2 `pdf_embedded_images_tables`

当前问题：

- 表格线性化
- 词间空格坏掉
- caption 与表格脱离

V2 对应修复责任：

- `Route Layer` 标记 `SuspectTable`
- `tables.mbt` 负责表格组装
- `caption_linker` 负责表题挂接
- 后续 `pdf_layout` capability 负责更高保真表格恢复

## 11. 实施计划

### 11.1 总体顺序

开发顺序固定为：

1. 架构重排
2. route 与 page-level routing
3. table / code-formula / reading-order 的 native 版本
4. capability 接口
5. OCR / layout 增强

不建议把顺序改成“先上 OCR 或 layout”，否则会把简单问题复杂化。

### 11.2 阶段 A：架构重排

目标：

- 把现有逻辑迁移到 V2 骨架
- 不引入新重依赖
- 不回归现有通过 case

开发项：

- `converter.mbt` 收敛成 orchestrator
- `model.mbt` 升级为 route + extraction + IR 模型
- 新增 `route.mbt`
- 拆出 `extract_native.mbt`
- 拆出 `render.mbt`
- `assemble.mbt` 接手现有 normalize + structure 主逻辑

完成标准：

- 当前已通过的 PDF case 不下降
- `moon test src/formats/pdf` 通过
- eval 中 `pdf_multi_page`、`pdf_right_to_left`、`pdf_fake_memo` 不回归

### 11.3 阶段 B：页级路由

目标：

- 让复杂页可被识别
- diagnostics 能说明为什么选这个 path

开发项：

- `PdfRoutePlan`
- route flags
- text quality / complexity 评分
- metadata 与 diagnostics 输出

完成标准：

- 每页都有 route 结果
- `ConvertResult.metadata` 中可见 route summary
- whitebox test 覆盖 route 规则

### 11.4 阶段 C：native structured stages

目标：

- 在不引入 layout/OCR capability 的前提下，先把 structured path 走起来

开发项：

- `reading_order.mbt`
- `tables.mbt`
- `code_formula.mbt`
- `caption_linker`

完成标准：

- `pdf_code_and_formula` 明显改善
- `pdf_embedded_images_tables` 至少能稳定输出表题与结构化表格 fallback

### 11.5 阶段 D：capability 接口

目标：

- 不直接接实现，先把 capability 边界稳定下来

开发项：

- `src/capabilities/pdf_layout/` 接口
- `src/capabilities/pdf_page_render/` 接口
- `src/capabilities/pdf_ocr/` 接口
- `extract_layout_bridge.mbt`
- `extract_ocr_bridge.mbt`

完成标准：

- 格式包不依赖具体外部工具
- capability 不可用时有清晰 fallback

### 11.6 阶段 E：增强能力接入

目标：

- 给复杂 PDF 提供真正的 layout / OCR / formula 增强

开发项按优先级：

1. table / layout
2. OCR recovery
3. formula enhancement

完成标准：

- 至少一个复杂 provider 接通
- structured path 不再只依赖 native heuristics

## 12. 测试与评测方案

### 12.1 单元测试

应覆盖：

- route 规则
- text normalization
- paragraph assembly
- list grouping
- table assembly
- code/formula boundary
- diagnostics 输出

建议 test 文件拆分：

```text
src/formats/pdf/
├── route_wbtest.mbt
├── normalize_text_wbtest.mbt
├── assemble_wbtest.mbt
├── tables_wbtest.mbt
├── code_formula_wbtest.mbt
└── converter_wbtest.mbt
```

### 12.2 fixture eval

PDF fixture 要按子类型维护：

- plain text / memo
- long form multi-page
- scientific table
- code + formula
- multi-column
- slide-style PDF
- scanned / broken-text PDF

### 12.3 验收指标

架构阶段的验收不只看总分，也看结构性指标：

1. FastTextPath
   - 不退化已通过样本
   - 时间不显著上涨

2. StructuredPath
   - 表格、代码、公式至少有明确 block 边界
   - 不再全部退化成单一长段落

3. RecoveryPath
   - 即使结果不完美，也必须有稳定 fallback 与告警

### 12.4 diagnostics 验收

每次 route / fallback 都应能在 diagnostics 中看到原因，例如：

- selected native structured path due to suspected table density
- selected OCR recovery because native text quality was very poor
- dropped repeated header/footer lines
- rendered table as HTML due to merged-cell complexity

## 13. 迁移策略

### 13.1 迁移原则

- 先迁骨架，再迁逻辑
- 尽量保留现有 helper 和测试，逐步重命名与归位
- 避免一次性重写所有 PDF 文件

### 13.2 现有文件的迁移映射

- 当前 [converter.mbt](D:/MySoftware/MoonBitMark/src/formats/pdf/converter.mbt)
  - 保留
  - 职责缩减为 orchestrator

- 当前 [extract.mbt](D:/MySoftware/MoonBitMark/src/formats/pdf/extract.mbt)
  - 迁移为 `extract_native.mbt`

- 当前 [normalize.mbt](D:/MySoftware/MoonBitMark/src/formats/pdf/normalize.mbt)
  - 拆成 `normalize_text.mbt` + `assemble.mbt` 内的部分逻辑

- 当前 [structure.mbt](D:/MySoftware/MoonBitMark/src/formats/pdf/structure.mbt)
  - 拆成 `reading_order.mbt`、`tables.mbt`、`code_formula.mbt`、`assemble.mbt`

- 当前 [diagnostics.mbt](D:/MySoftware/MoonBitMark/src/formats/pdf/diagnostics.mbt)
  - 保留
  - 扩展 route / provider / fallback 诊断

- 当前 [model.mbt](D:/MySoftware/MoonBitMark/src/formats/pdf/model.mbt)
  - 升级为完整 IR 和 route model 容器

## 14. 开发顺序建议

为了让文档可以直接指导编码，建议开发顺序固定如下：

1. 先改 `model.mbt`
   - 把 route / extraction / IR 类型补齐

2. 再改 `converter.mbt`
   - 建立 orchestrator 骨架

3. 再拆 `extract_native.mbt`
   - 把现有提取逻辑迁进去

4. 再上 `route.mbt`
   - 让路由先工作

5. 再迁 `normalize_text` 与 `assemble`
   - 让老逻辑在新架构下跑通

6. 再拆 `reading_order`、`tables`、`code_formula`
   - 逐步把 structured logic 从 `assemble` 内抽离

7. 最后才加 capability bridges

这个顺序的目的是：

- 先把架构立住
- 再逐层替换旧逻辑
- 每一层都能在现有 eval 上验证

## 15. 第一轮开发的明确边界

为了避免 scope 膨胀，V2 第一轮明确只做以下内容：

- 建立 route / extraction / IR / assembly / render 架构骨架
- 保留并迁移 native text path
- 形成 native structured path 的最小实现
- 为 OCR / layout / formula capability 预留接口

V2 第一轮明确不做：

- 真正接入重模型 layout engine
- 真正接入 OCR provider
- 新增 AST 数学节点
- 图片资源抽取和 figure export 全量支持

## 16. 最终结论

MoonBitMark PDF 的下一步已经不再是“继续增强现有 normalize 和 structure”，而是完成以下转型：

1. 从单一路径转为可路由系统
2. 从字符串后处理转为统一 PDF IR
3. 从轻量文本提取器转为三路径 PDF pipeline
4. 从格式包内硬编码能力转为 formats + capabilities 分层

这份文档的结论是：

- 架构方向已经确认
- 模块边界已经确认
- 类型模型已经给到可实现级别
- 开发顺序已经明确

后续可以直接按本文档进入编码，不再需要重新讨论“要不要上 route / IR / capability 分层”。

## 17. 参考资料

- Docling Architecture  
  https://docling-project.github.io/docling/concepts/architecture/
- Docling Advanced Options  
  https://docling-project.github.io/docling/usage/advanced_options/
- Docling Model Catalog  
  https://docling-project.github.io/docling/usage/model_catalog/
- Docling Overview  
  https://docling-project.github.io/docling/
- MarkItDown README  
  https://github.com/microsoft/markitdown
- Marker README  
  https://github.com/datalab-to/marker
- Surya README  
  https://github.com/datalab-to/surya
- MinerU README  
  https://github.com/opendatalab/MinerU
- Unstructured Partitioning  
  https://docs.unstructured.io/open-source/core-functionality/partitioning
- Azure Document Markdown Representation  
  https://learn.microsoft.com/en-us/azure/ai-services/content-understanding/document/markdown
