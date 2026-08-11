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
python tests/conversion_eval/scripts/run_eval.py all
```

带 baseline 的推荐调用：

```powershell
./scripts/run_conversion_eval.ps1 `
  -CompareBaselines `
  -PythonExe C:\Users\hnlyh\.venvs\moonbitmark-baselines\Scripts\python.exe
```

## Benchmark 来源与可复现性

输入样本来自开源 benchmark
[Goldziher/python-text-extraction-libs-benchmarks](https://github.com/Goldziher/python-text-extraction-libs-benchmarks)
的 `test_documents/` 目录，并在 `fixtures/source_manifest.json` 中固定到具体
commit（`remote.ref`）。每个样本记录了 git blob sha，同步时逐项校验内容哈希，
因此任何机器、任何检出上跑的都是同一批字节。

同步优先级（`sync` / `prepare` / `run` / `all` 共用）：

1. 显式传入 `--benchmark-root` 时使用本地 checkout，并校验与固定 commit 一致
2. `fixtures/inputs/` 已存在且哈希匹配时直接复用
3. `_build/conversion-eval-cache/blobs/` 本地缓存命中时复制
4. 否则从固定的 `raw.githubusercontent.com` URL 下载并写入缓存

## 自动化流程

1. 读取 `fixtures/source_manifest.json`
2. 按上述优先级把精选样本同步到 `fixtures/inputs/`（默认走固定远程，不再依赖本机路径）
3. 依据 case 的 `reference_builder` 自动生成 `fixtures/expected/markdown/*.md`
4. 调用 MoonBitMark 可执行文件运行所有 case
5. 计算锚点命中率、内容 precision/recall、unigram+bigram 内容相似度、结构相似度、表格相似度和顺序分数
6. 输出 `reports/latest/report.json`、`reports/latest/summary.md`，并归档到 `reports/history/`

## 缺失 fixture 与退出码（门禁语义）

- 输入缺失的 case 标记为 `skipped` 并在报告中单独列出；默认情况下
  **skipped 会使门禁失败**（退出码 1），因为只跑通一部分 case 无法证明转换器健康。
  本地快速迭代可用 `--allow-skipped` 显式放宽。
- runner 二进制落后于源码（provisional 报告）同样使门禁失败，可用
  `--allow-stale` 显式放宽。
- 存在失败 case、skipped case（未放宽）、stale runner（未放宽）或没有任何
  case 被评估时，`run` / `all` 以退出码 `1` 结束。
- `scripts/run_conversion_eval.ps1` 通过 `exit $LASTEXITCODE` 把 harness 的
  退出码透传给调用方，CI 门禁因此真正生效。
- `fixtures/inputs/corrupt/` 下的负例 fixture 是仓库内跟踪的最小合成文件，
  保证错误路径 case 在任何检出上都能运行。

## 负例 case（错误路径）

case 支持以下可选字段，用于验证 CLI 在损坏 / 不支持 / 缺失输入下的行为：

- `expect_exit_code`：期望的进程退出码。非零时按负例处理，跳过 reference
  构建与相似度指标。
- `error_must_include`：stdout+stderr 中必须出现的片段。
- `error_must_not_include`：stdout+stderr 中禁止出现的片段（例如
  `Failure(`、`.mbt:`，防止把内部 trace 泼给用户）。

现有负例：

- 非 ZIP 垃圾字节：`negative_corrupt_docx`、`negative_corrupt_pptx`、
  `negative_corrupt_xlsx`、`negative_corrupt_epub`
- 截断 ZIP（local header 完好、central directory 缺失）：`negative_truncated_docx`
- 合法 ZIP 但缺少必需内部条目：`negative_empty_archive_docx`
- 非 PDF 内容：`negative_corrupt_pdf`
- 未知扩展名：`negative_unknown_extension`
- 输入文件不存在：`negative_missing_file`
- 目录当作输入：`negative_directory_input`
- 空输入边界 case：`text_empty_file`

## 指标设计（区分度）

指标围绕"内容 × 结构 × 顺序"三个正交维度设计，避免单一饱和分数：

- `content_precision` / `content_recall`：输出相对 reference 的 token 多重集
  精确率/召回率。拆开报告是为了区分两类完全不同的退化——截断（recall 低）
  与噪声注入（precision 低）在单一 F1 下不可区分。
- `markdown_similarity`：unigram F1 与 bigram F1 的等权混合（ROUGE 风格）。
  bigram 对局部顺序敏感，双栏交错、段落重复、块乱序都会显著拉低分数；
  取代了旧的字符级 difflib 比率（对长公共子串饱和，且在大文档上是 O(n²)）。
- `heading_structure_score`：heading 按 `(level, text)` 元素级序列匹配为主、
  heading 文本 token F1 为辅；层级错误的 heading 不再拿到字符级部分分。
- `table_similarity`：按 cell F1 贪心最优配对，按两侧表数量的较大者归一——
  输出静默丢整张表会被惩罚（旧实现按位置配对且只按输出表数取平均）。
- case 聚合分是**加权几何平均**而非算术平均：最弱维度主导总分，
  饱和指标无法再掩盖单点退化。
- `summary.md` 的 `Metric Spread` 段直接给出每个指标的 mean/stddev/min/max，
  stddev 趋近 0 的指标即失去区分度，可被直接发现。


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

- `--compare-baselines` 会在运行 MoonBitMark 评测的同时，优先尝试当前 Python，
  不可用时再自动回退到本机的 baseline venv（默认
  `C:\Users\hnlyh\.venvs\moonbitmark-baselines\Scripts\python.exe`）
- baseline 是否可用，取决于当前 Python 或 baseline venv 里是否真的安装了对应包
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
- 注意：`--refresh-references` 会用 builder 输出覆盖所有 golden，包括
  git 跟踪的精修 golden（`html_*` / `pdf_*` / `text_markdown_specials`）。
  builder 是比精修 golden 更粗糙的近似（例如不处理 colspan 表头合并），
  刷新前先用 `git status` 确认跟踪 golden 的 diff 是预期内的。
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
