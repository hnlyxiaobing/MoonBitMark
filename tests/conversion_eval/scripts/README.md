# Scripts

此目录当前使用一个主入口脚本：

- `run_eval.py`

支持的子命令：

- `sync`：同步 benchmark 子集到 `fixtures/inputs/`
- `prepare`：生成/刷新 reference markdown
- `run`：执行 MoonBitMark 评测并输出报告，可选 `--compare-baselines`
- `all`：按 `sync -> prepare -> run` 全流程执行，可选 `--compare-baselines`

推荐直接通过仓库根目录的 `scripts/run_conversion_eval.ps1` 调用。

baseline 运行要点：

- baseline 是否启用，取决于当前 Python 环境里能否 `import markitdown` /
  `import docling`
- 推荐用独立虚拟环境运行，例如：

```powershell
./scripts/run_conversion_eval.ps1 `
  -CompareBaselines `
  -PythonExe C:\Users\hnlyh\.venvs\moonbitmark-baselines\Scripts\python.exe
```

- 当前 harness 会：
  - 对 baseline 子进程强制使用 UTF-8 输出
  - 让 `docling` 只跑它当前支持的格式
  - 让 `docling` 的 PDF baseline 使用 `do_ocr=False`
