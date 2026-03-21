# MoonBitMark Conversion Evaluation

这套评测框架把 MoonBitMark 的转换质量拆成三层：

- `L1` 回归检查：`must_include` / `must_not_include` / 最小长度 / 非空输出
- `L2` 参考对比：自动从源文档生成 reference markdown，再做文本、结构、表格比较
- `L3` 可选基线：若本机已安装 `markitdown` 或 `docling`，自动加入横向比较

## 一键入口

PowerShell:

```powershell
./scripts/run_conversion_eval.ps1
```

Python:

```powershell
python tests/conversion_eval/scripts/run_eval.py all `
  --benchmark-root D:\MySoftware\MoonBit\python-text-extraction-libs-benchmarks
```

## 自动化流程

1. 读取 `fixtures/source_manifest.json`
2. 从 benchmark 根目录同步精选样本到 `fixtures/inputs/`
3. 依据 case 的 `reference_builder` 自动生成 `fixtures/expected/markdown/*.md`
4. 调用 MoonBitMark 可执行文件运行所有 case
5. 计算锚点命中率、Markdown 相似度、结构相似度、表格相似度和顺序分数
6. 输出 `reports/latest/report.json`、`reports/latest/summary.md`，并归档到 `reports/history/`

## 目录说明

```text
tests/conversion_eval/
  cases/                  # 评测定义
  fixtures/
    inputs/               # 同步后的输入样本（git ignore）
    expected/markdown/    # 自动生成的 reference markdown（git ignore）
    source_manifest.json  # benchmark 同步映射
  reports/
    latest/               # 最近一次评测结果（git ignore）
    history/              # 历史归档（git ignore）
  schemas/
    case.schema.json
  scripts/
    run_eval.py
```

## case 设计原则

- `must_include` 负责召回
- `must_not_include` 负责噪声控制
- `reference_builder` 负责自动生成 reference，而不是人工维护大量 golden
- `weights` 只描述聚合分数，不替代硬性 pass/fail 规则

## 当前覆盖格式

- `csv`
- `docx`
- `epub`
- `html`
- `json`
- `pdf`
- `pptx`
- `text`
- `xlsx`
