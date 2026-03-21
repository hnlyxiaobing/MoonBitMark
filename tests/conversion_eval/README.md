# MoonBitMark Conversion Evaluation Scaffold

这是一套为 MoonBitMark 设计的测试评估目录骨架，目标是同时支持：

- **L1 轻量回归**：`must_include` / `must_not_include` / 空输出 / 最小长度
- **L2 结构化质量验证**：Markdown golden、AST golden、metadata golden、表格专项
- **L3 横向 benchmark**：未来可接 MarkItDown / Docling / 公开基准子集

## 目录约定

```text
tests/conversion_eval/
  cases/
    smoke/        # 轻量功能验证
    quality/      # 质量评分样本
    edge/         # 边界条件
    regressions/  # 线上 bug / 历史 bug 回归
  fixtures/
    inputs/       # 原始输入样本，按格式分目录
    expected/
      markdown/   # golden markdown
      ast/        # golden ast json
      metadata/   # golden metadata json
      tables/     # golden table json
  evaluators/
    normalize/    # 文本标准化
    anchors/      # must_include / must_not_include
    ast_compare/  # AST 规则式比较
    table_compare/# 表格结构比较
    metrics/      # Levenshtein / NID / 聚合得分
  reports/
    latest/       # 当前评估报告
    history/      # 历史报告归档
  schemas/
    case.schema.json
  scripts/
    README.md
```

## 先放什么

你现在先把样本放到这些目录：

- `fixtures/inputs/csv`
- `fixtures/inputs/docx`
- `fixtures/inputs/epub`
- `fixtures/inputs/html`
- `fixtures/inputs/json`
- `fixtures/inputs/pdf`
- `fixtures/inputs/pptx`
- `fixtures/inputs/text`
- `fixtures/inputs/xlsx`

然后给每个样本配一个 case 文件，放到：

- `cases/smoke`
- `cases/quality`
- `cases/edge`
- `cases/regressions`

## case 文件命名建议

- `csv_basic_sales.case.json`
- `docx_resume_rich.case.json`
- `epub_novel_with_images.case.json`
- `html_article_sidebar_noise.case.json`
- `json_api_response.case.json`
- `pdf_two_column_table.case.json`
- `pptx_quarterly_review.case.json`
- `text_unicode_notes.case.json`
- `xlsx_multi_sheet_budget.case.json`
