# Codex Development Guide

这份文档是给 Codex 或类似代理的执行说明。目标不是重新介绍项目（见
`README.md` 与 `docs/architecture.md`），而是帮助代理在当前仓库状态下做出
正确的架构判断和任务拆分。

## 核心判断

MoonBitMark 已经不是"先补统一入口、再补评测、再补 MCP"的早期项目。
统一骨架已经全部存在：

- `src/engine/` 统一调度：`detect` → converter registry → `convert` → `finalize_result`
- 统一 `Document AST` + 单一 Markdown renderer（`src/ast/`）
- `ConvertResult` 统一输出（markdown / document / metadata / diagnostics /
  warnings / assets / stats）
- 共享归一层 `src/normalize/` 与语义派生层 `src/semantic/`
- OCR capability 注入（`src/capabilities/ocr/`，bridge-backed）
- `src/mcp/` 与 `cmd/mcp-server`、`cmd/mcp-http-server`
- `tests/conversion_eval/` 分层 conversion evaluation 框架

默认前提：

> 不要重做统一骨架。优先在现有骨架上补强语义层、归一化层和评测闭环。

## 已确认的现状

1. **统一调度层已存在**：默认 converter 注册顺序（按优先级）为
   `Docx(100) / Epub(95) / Pptx(90) / Doc(88) / Xlsx(85) / Pdf(80) /
   Image(75) / Html(70) / Json(50) / Csv(40) / Text(10)`，注册与 dispatch 都在
   `src/engine/engine.mbt` 的 `register_default_converters`。不要重建 engine
   或 registry。
2. **统一输出已存在，AST 保持轻量**：`src/ast/types.mbt` 仍是薄模型
   （`Document { title, metadata, blocks }`，
   `Block = Heading | Paragraph | List | Quote | CodeBlock | Table | HorizontalRule`）。
   更强的中间语义（section tree、SemanticRole、Provenance、confidence、
   block diagnostics）在 `src/semantic/`。不要推翻 AST；继续做稳
   "AST 兼容层 + semantic 派生层"的组合。
3. **Renderer 已统一**：集中在 `src/ast/renderer.mbt`。不要另起 renderer
   抽象；优先在 AST 和 normalize 层提升质量。
4. **OCR 与 MCP 已是现有能力**：不要当从零开始的新能力/新协议层；要做的是
   增强 OCR 决策与 fallback、扩展 MCP 工具与解释输出。
5. **评测框架已闭环**：`tests/conversion_eval/` 含 `cases / evaluators /
   fixtures / reports / schemas / scripts`，具备结构指标、按格式/簇/层级报告、
   OCR evidence 汇总与 baseline 留口。不要另建平行评测系统。

## 共享链路

当前主链路：

```text
Input
 -> detect / select converter
 -> format converter
 -> Raw Document AST
 -> Structural Normalizer (src/normalize/)
 -> Canonical Semantic Document (src/semantic/)
 -> renderer / inspect / compare
 -> CLI / MCP / eval + regression + baseline report
```

两个关键层已经存在，当前重点是提升规则精度和调试可见性，而不是"是否引入"：

### Structural Normalizer（`src/normalize/`）

- 不重写 parser、不替换 renderer；在 converter 产出的 AST 之后做共享归一化
- 覆盖：heading 层级、list 形态、table header/body、paragraph merge/split、
  quote/code 判定、图片与 OCR 注释注入
- 接入点：`engine.convert(...)` 到 `finalize_result(...)` 之间
- block 级决策轨迹已通过 MCP `explanations.normalizer` 对外暴露

### Canonical Semantic Document（`src/semantic/`）

- 保留现有 `Document / Block / Inline` 兼容层，在其上派生
  `SectionTree / SemanticRole / Provenance / Confidence / BlockDiagnostics`
- 服务于：结构评测、RAG chunk、MCP inspect、调试解释、baseline compare
- 轻量 provenance 约定：PDF `page_no`、PPTX `slide_no`、XLSX `sheet_name`、
  EPUB `chapter` / `resource`、通用 `source_path` / `source_url`

## 默认工作原则

应该做：

- 复用 `src/engine/` 主链、`src/ast/` 与现有 renderer、`ConvertResult`
- 复用现有 CLI 调试选项（`--dump-raw-ast` / `--dump-normalized-ast` /
  `--dump-semantic` / `--diag-json` / `--debug`）
- 复用 `tests/conversion_eval/` 作为主质量回归入口
- 在共享层补能力，而不是在单个 converter 里堆特判

不应该做：

- 不要设计新的统一入口或平行 renderer
- 不要绕开现有 evaluation 体系另做一套打分脚本
- 不要把 OCR、MCP、registry、CLI 当成"尚未存在"的模块
- 不要为了加语义层一次性推翻当前 AST

## 已完成的里程碑（不要再当"待实现"）

- P0：`src/normalize/` 接入主路径；AST 扩展为多阶段 dump
- P1：`src/semantic/` SectionTree / SemanticRole / Provenance v1
- P2：eval 结构指标（heading/list/table/paragraph/asset）+ 按格式短板报告；
  PDF 页级 OCR fallback 主闭环（恢复页号/原因写回 metadata）
- P3：MCP 工具面（`inspect_document`、`convert_to_markdown`、
  `dump_normalized_ast`、`extract_structure`、`compare_with_baseline`、
  `upload_document`、`convert_uploaded_document`、`list_documents`、
  `delete_document`）与 `structuredContent.explanations`
  （normalizer / headings / tables / OCR / uncertainties / comparison_debug）

## 当前未完成任务

1. 继续细化 `SemanticRole / Provenance` 的格式特异性规则，重点是
   DOCX / PPTX / HTML 的稳定性，并向 XLSX / EPUB / PDF 扩展更细粒度来源信息。
2. 继续增强 PDF OCR fallback 的质量判定与融合策略；目前仍是页级文本恢复，
   不是版面理解、bbox 或表格重建系统。
3. 继续增强 MCP 解释性输出的覆盖深度（格式特异性 reason、更多 compare case）。
4. 把 OCR / MCP smoke 回归当成相关改动的固定门禁，而不是大改动时手动补跑。
5. baseline compare 的长期优化需要稳定可用的 MarkItDown / Docling 环境。
6. 上游 mbtpdf 页树遍历丢页问题（重复 object 定义）的修复收敛，
   见 `docs/KNOWN_ISSUES.md` PDF 一节。

## 建议执行顺序

没有用户另行指定优先级时，默认按下面顺序推进：

1. 细化 `SemanticRole / Provenance` 的规则覆盖和测试稳定性
2. 增强 PDF OCR fallback 的质量判定、融合策略与解释信息
3. 扩展 MCP explanations / compare debug 的可读性
4. 保持 conversion eval 与 OCR/MCP smoke 作为相关改动的固定回归门禁

## 每次开发回合的验证要求

改了 MoonBit 源码或包结构时，至少跑：

```bash
moon check
moon test
moon info
moon fmt
```

改了转换质量相关逻辑时，额外跑：

```bash
python tests/conversion_eval/scripts/run_eval.py run
```

改了 OCR 或 MCP 时，额外跑对应 smoke tests（清单见 `docs/architecture.md`
验证入口一节）。

## 一句话总目标

> MoonBitMark 的主要精力不该再放在"补统一入口"上，而应在现有统一入口之上
> 持续提升共享 Normalizer、Semantic Document 层与评测闭环的精度，把项目从
> 统一转换框架推进成统一文档理解引擎。
