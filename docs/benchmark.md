# Benchmark And Eval

MoonBitMark 当前有两类验证入口：

1. `scripts/benchmark.ps1`
   用于对 native CLI 做最小重复基准，适合快速比较改动前后的本地耗时。
2. `tests/conversion_eval/scripts/run_eval.py`
   用于跑固定样本集的转换质量评测，并生成 `tests/conversion_eval/reports/latest/` 报告。

## 1. 最小性能基准

### 前提

- 已完成 native release 构建。
- 可执行文件位于 `_build/native/release/build/cmd/main/main.exe`。

推荐先执行：

```bat
scripts\build.bat
```

### 示例

```powershell
pwsh -File scripts/benchmark.ps1 -InputPath <your-input-file> -Iterations 10
```

### 参数

- `-InputPath`: 待转换输入文件。
- `-Iterations`: 重复次数，默认 `5`。
- `-BinaryPath`: CLI 路径，默认 release 主程序。
- `-OutputPath`: 临时输出文件路径，默认系统临时目录。

### 输出

脚本会输出每轮耗时和平均耗时。这个脚本是最小基准入口，不负责长期结果归档或固定样本管理。

## 2. 转换质量评测

### 直接运行当前样本集

```bash
python tests/conversion_eval/scripts/run_eval.py run
```

### 需要同步外部 benchmark 样本时

```bash
python tests/conversion_eval/scripts/run_eval.py sync --benchmark-root <benchmark-repo>
python tests/conversion_eval/scripts/run_eval.py prepare --benchmark-root <benchmark-repo> --refresh-references
python tests/conversion_eval/scripts/run_eval.py run --benchmark-root <benchmark-repo>
```

如果 Python 环境里装好了 baseline 依赖，也可以加：

```bash
python tests/conversion_eval/scripts/run_eval.py run --compare-baselines
```

### 最新已验证结果

截至 `2026-03-30T12:17:54.953247+00:00`，最新一轮本地评测结果为：

- `33/33` 通过
- 平均分 `0.9983`
- `csv` 平均分 `1.0000`
- `html` 平均分 `0.9995`
- 在当前 HTML 样例上，本地 `markitdown` baseline 平均分为 `0.7165`

对应报告：

- `tests/conversion_eval/reports/latest/summary.md`
- `tests/conversion_eval/reports/latest/report.json`

## 3. 何时跑哪一种

- 想看单文件性能回归：先跑 `scripts/benchmark.ps1`。
- 想看格式质量是否回退：跑 `run_eval.py run`。
- 改了共享渲染层、CSV/HTML 解析器或 reference fixture：优先跑 conversion eval。
- 改了 native 路径性能热点：同时跑 benchmark 和 conversion eval，避免只快不准。
