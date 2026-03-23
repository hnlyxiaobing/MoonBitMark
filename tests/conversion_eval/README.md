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

带 baseline 的推荐调用：

```powershell
./scripts/run_conversion_eval.ps1 `
  -CompareBaselines `
  -PythonExe C:\Users\hnlyh\.venvs\moonbitmark-baselines\Scripts\python.exe
```

## 自动化流程

1. 读取 `fixtures/source_manifest.json`
2. 从 benchmark 根目录同步精选样本到 `fixtures/inputs/`
3. 依据 case 的 `reference_builder` 自动生成 `fixtures/expected/markdown/*.md`
4. 调用 MoonBitMark 可执行文件运行所有 case
5. 计算锚点命中率、Markdown 相似度、结构相似度、表格相似度和顺序分数
6. 输出 `reports/latest/report.json`、`reports/latest/summary.md`，并归档到 `reports/history/`

## 当前汇总口径

`summary.md` 和 `report.json` 现在会同时给出：

- `By Format`
- `By Cluster`
- `By Tier`
- `OCR Evidence`

当前固定簇定义：

- `archive`: `docx / epub / pptx / xlsx`
- `web`: `html / url`
- `ocr`: 独立 image case，以及任何显式传入 `--ocr` / `--ocr-images` 的 case

这样做的目的不是重写现有评测主结构，而是让报告能更快回答：

- 哪个格式退化了
- 是 Archive 共性问题还是 Web / OCR 横切问题
- OCR 是否真的介入了该 case

## Baseline 说明

- `--compare-baselines` 会在运行 MoonBitMark 评测的同时，调用当前 Python
  解释器中的 `markitdown` 和 `docling`
- baseline 是否可用，取决于运行 `run_eval.py` 的那个 Python 环境里是否真的
  安装了对应包
- Windows 控制台默认编码会影响 baseline 输出，本仓库脚本会强制设置
  `PYTHONUTF8=1` 和 `PYTHONIOENCODING=utf-8`

当前推荐的 baseline 环境是独立虚拟环境，例如：

```powershell
C:\Users\hnlyh\.venvs\moonbitmark-baselines\Scripts\python.exe
```

推荐安装方式：

```powershell
python -m venv C:\Users\hnlyh\.venvs\moonbitmark-baselines
C:\Users\hnlyh\.venvs\moonbitmark-baselines\Scripts\python.exe -m pip install -U pip
C:\Users\hnlyh\.venvs\moonbitmark-baselines\Scripts\python.exe -m pip install markitdown docling
```

baseline 的当前行为边界：

- `markitdown`：会尝试当前评测集中的全部格式
- `docling`：只尝试它当前支持的格式，当前评测集中实际会运行
  `csv/docx/html/pdf/pptx/xlsx`
- `docling` 对 `text/json/epub` 不做尝试，避免把“不支持的格式”误记成评测失败
- `docling` 的 PDF baseline 会以 `do_ocr=False` 运行，避免为 OCR 路径下载额外模型
- `docling` 首次处理 PDF 时仍可能拉取布局模型；如果网络受限，需要先在允许联网的环境里预热一次

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
- `cli_args` 允许单个 case 传入额外 CLI 参数，例如为 image case 固定
  `--ocr force --ocr-backend mock`
- `skip_baselines` 允许对单个 baseline 工具做 case 级跳过，并记录原因。
  适用于工具已知不支持或在本机稳定触发资源上限的样本。
- `weights` 只描述聚合分数，不替代硬性 pass/fail 规则

## Regression 纪律

- 每修一个真实 bug，补一个 `regression` tier case，或补强一个已有质量 case。
- 回归 case 优先覆盖共享层问题，例如 Archive path / diagnostics / OCR 约定，而不是只盯单一格式输出字符串。
- 新 case 应尽量复用现有 fixture；只有现有样本无法表达缺陷时，才新增最小化自定义 fixture。

## 当前覆盖格式

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
