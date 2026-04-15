# Codex Development Guide

这份文档是给 Codex 或类似代理的执行说明。目标不是重新介绍项目，而是帮助代理在当前仓库状态下做出正确的架构判断和任务拆分。

## 核心判断

MoonBitMark 已经不是“先补统一入口、再补评测、再补 MCP”的早期项目。

当前已经存在：

- `src/engine/` 统一调度入口
- `MarkItDown` converter registry
- 统一 `Document AST + Markdown renderer`
- `ConvertResult` 风格的统一输出
- OCR capability 注入
- `src/mcp/` 与 `cmd/mcp-server`
- `tests/conversion_eval/` 下分层的 conversion evaluation 框架

因此，后续开发的默认前提应该是：

> 不要重做统一骨架。优先在现有骨架上补强语义层、归一化层和评测闭环。

## 已确认的现状

### 1. 统一调度层已经存在

`src/engine/engine.mbt` 已经承载主流程：

- `detect`
- `select_converter`
- `convert`
- `finalize_result`

默认 converter 注册顺序已经把 `Docx / Epub / Pptx / Xlsx / Pdf / Image / Html / Json / Csv / Text` 串起来。

结论：

- 不要重建 engine
- 不要重建 converter registry
- 不要再提出“统一入口”作为 P0

### 2. 统一输出已经存在，但 AST 仍偏薄

当前统一输出包含：

- `markdown`
- `document`
- `metadata`
- `diagnostics`
- `warnings`
- `assets`
- `stats`

但现有 `src/ast/types.mbt` 仍以较薄的文档模型为主，核心还是：

- `Document { title, metadata, blocks }`
- `Block = Heading | Paragraph | List | Quote | CodeBlock | Table | HorizontalRule`

目前还缺少更强的中间语义信息，例如：

- section tree
- semantic role
- provenance
- confidence
- block-level diagnostics

结论：

- 不要推翻现有 AST
- 要在现有 AST 之上逐步补强

### 3. Renderer 已经统一

Markdown renderer 已经集中在 `src/ast/renderer.mbt`。表格收敛等共享输出逻辑也已经进入统一层。

结论：

- 不要另起 renderer 抽象
- 优先在 AST 和 normalize 层提升质量

### 4. OCR 和 MCP 已经是现有能力

当前仓库已经有：

- `src/capabilities/ocr/`
- `src/mcp/`
- `cmd/mcp-server`
- `cmd/mcp-http-server`

结论：

- 不要把 OCR 当作从零开始的新能力
- 不要把 MCP 当作从零开始的新协议层
- 应该做的是增强 OCR 决策、fallback 和 MCP 工具体系

### 5. 评测框架已经存在

`tests/conversion_eval/` 已经不是简单 golden diff。当前已有：

- `cases`
- `evaluators`
- `fixtures`
- `reports`
- `schemas`
- `scripts`

并且有分层评测思路，可接 baseline 对比。

结论：

- 不要另建平行评测系统
- 应该在现有评测框架上补结构指标和分格式报告

## 对 Codex 的默认工作原则

### 应该做的事

- 复用 `src/engine/` 主链
- 复用 `src/ast/` 和现有 renderer
- 复用 `ConvertResult`
- 复用现有 CLI 调试选项
- 复用 `tests/conversion_eval/` 作为主质量回归入口
- 在共享层补能力，而不是在单个 converter 里堆特判

### 不应该做的事

- 不要再设计新的统一入口
- 不要再新建一套平行 renderer
- 不要绕开现有 evaluation 体系另做一套打分脚本
- 不要把 OCR、MCP、registry、CLI 当成“尚未存在”的模块
- 不要为了加语义层而一次性推翻当前 AST

## 推荐目标架构

当前状态：

```text
Input
 -> detect / select converter
 -> format converter
 -> Document AST + metadata/diagnostics/assets/stats
 -> unified renderer / postprocess
 -> CLI / MCP / eval
```

建议的下一阶段：

```text
Input
 -> detect / select converter
 -> format converter
 -> Raw Document AST
 -> Structural Normalizer
 -> Canonical Semantic Document
 -> renderer / chunker / inspect / compare
 -> eval + regression + baseline report
```

这里最关键的新层只有两个：

- `Structural Normalizer`
- `Canonical Semantic Document`

## 新增层的定义

### A. Structural Normalizer

目标：

- 不重写 parser
- 不替换 renderer
- 在各格式 converter 产出的 AST 之后做共享归一化

它应该统一处理：

- heading 层级
- list 形态
- table header/body 结构
- paragraph merge/split
- quote/code 判定
- 图片与 OCR 注释注入策略

最合适的接入点：

- `engine.convert(...)` 到 `finalize_result(...)` 之间

### B. Canonical Semantic Document

目标：

- 保留现有 `Document / Block / Inline` 兼容层
- 在其上增加更强语义模型

第一阶段建议至少引入：

- `SectionTree`
- `SemanticRole`
- `Provenance`
- `Confidence`
- `BlockDiagnostics`

这个语义层不是为了替代 Markdown 输出，而是为了支撑：

- 结构评测
- RAG chunk
- MCP inspect
- 调试解释
- baseline compare

## 建议目录布局

```text
src/engine/               # 保留，继续做统一调度
  detect
  registry
  convert
  finalize_result

src/formats/*             # 保留，各格式继续专注解析

src/ast/                  # 现有兼容层
  Inline / Block / Document
  renderer

src/normalize/            # 新增，共享归一层
  heading_normalize
  list_normalize
  table_normalize
  paragraph_normalize
  asset_annotate
  document_normalize

src/semantic/             # 新增，语义文档层
  SemanticDocument
  Section
  SemanticBlock
  SemanticRole
  Provenance
  Confidence

src/capabilities/ocr/     # 保留并增强
  provider
  policy
  fallback
  merge

src/mcp/                  # 保留并增强
  tools
  inspect
  compare
  debug

tests/conversion_eval/    # 保留并增强
  L1 regression
  L2 reference compare
  L3 baseline compare
  + structure metrics
  + per-format metrics
  + OCR metrics
```

## 分阶段任务

## P0：最小侵入的结构增强

### P0-1 新增 `src/normalize/`

先只做 4 个 pass：

- `normalize_heading_levels`
- `normalize_list_blocks`
- `normalize_table_shape`
- `normalize_paragraph_whitespace`

要求：

- 不改现有 CLI 对外语义
- 接到现有 engine 主路径里
- 现有 conversion eval 不退化

### P0-2 扩展现有 AST，而不是替换 AST

优先补最小必要信息：

- `Block::Image` 或等价图片块
- block metadata / block id
- 可选 `source_hint` / `origin_hint`
- 可选 block diagnostics

原则：

- 让 AST 承载更多已有结果信息
- 不要一步到位做大而全的语义树替换

### P0-3 把 AST dump 扩展成多阶段 dump

当前 CLI 已有：

- `--dump-ast`
- `--diag-json`
- `--debug`

后续优先新增：

- `--dump-raw-ast`
- `--dump-normalized-ast`
- `--dump-semantic`

目的是让代理和开发者能直接观察中间层，不再只能看最终 Markdown。

## P1：建立更强的语义中间层

### P1-1 新增 `src/semantic/`，先做 SectionTree

从现有 flat `blocks` 派生：

- heading 驱动的 section hierarchy
- 无 heading 文档的 fallback section
- section 级 block range / metadata / diagnostics 汇总

优先收益：

- RAG chunk
- inspect_document
- 结构评测
- 调试解释

### P1-2 引入有限集合的 `SemanticRole`

先从小集合做起：

- `title`
- `subtitle`
- `body`
- `caption`
- `note`
- `code`
- `table_header`
- `table_body`
- `quote`
- `footer_like`

优先覆盖格式：

- DOCX
- PPTX
- HTML

### P1-3 建 `Provenance v1`

先做轻量 provenance，不要一开始尝试 bbox 级系统：

- PDF: `page_no`
- PPTX: `slide_no`
- XLSX: `sheet_name`
- EPUB: `chapter` / `resource`
- all: `source_path` / `source_url`

## P2：把现有评测升级成优化闭环

### P2-1 在 L1/L2/L3 上加结构指标

直接扩展现有 conversion eval，而不是另起一套：

- `heading_structure_score`
- `list_nesting_score`
- `table_shape_score`
- `paragraph_segmentation_score`
- `asset_link_score`

### P2-2 固定生成按格式短板报告

建议报告里长期保留：

- top regressions by format
- top unstable cases by metric
- OCR gain/loss cases
- baseline gap vs MarkItDown / Docling

### P2-3 OCR 的现实优先项是 PDF fallback

OCR 的第一优先不是 everywhere OCR，而是：

1. PDF 文本抽取质量判定
2. 触发页渲染 OCR fallback
3. 融合回 Document / AST
4. 纳入 conversion eval

## P3：把现有 MCP 变成真正的展示面

### P3-1 扩展 inspect / compare / debug 工具

优先扩展现有 `src/mcp/`，而不是新建协议层。

建议优先暴露：

- `inspect_document`
- `convert_to_markdown`
- `dump_normalized_ast`
- `extract_structure`
- `compare_with_baseline`

### P3-2 增加解释性输出

利用已有 diagnostics / warnings / stats，补解释能力：

- 为什么判成这个 heading level
- 为什么 table 被降级成 paragraph
- 为什么 OCR 被触发
- 当前输出的不确定点是什么

## Codex 的建议执行顺序

如果没有用户另行指定优先级，默认按下面顺序推进：

1. 新建 `src/normalize/` 并接入 engine 主路径
2. 给 AST 补最小必要字段
3. 增加多阶段 dump
4. 新建 `src/semantic/section_tree.mbt`
5. 在 `tests/conversion_eval` 中加入 heading/list/table 结构指标
6. 增加按格式短板报告
7. 优先补 PDF OCR fallback 决策链
8. 用现有 MCP 目录扩展 inspect/compare/debug 工具

## 每次开发回合的验证要求

如果改了 MoonBit 源码或包结构，默认至少跑：

```bash
moon check
moon test
moon info
moon fmt
```

如果改了转换质量相关逻辑，额外跑：

```bash
python tests/conversion_eval/scripts/run_eval.py run
```

如果改了 OCR 或 MCP，额外跑对应 smoke tests。

## 一句话总目标

> MoonBitMark 现在不该继续把主要精力放在“补统一入口”上，而应该在现有统一入口之上，补出共享 Normalizer、更强的 Semantic Document 层，以及更细粒度的评测闭环，把项目从统一转换框架推进成统一文档理解引擎。
