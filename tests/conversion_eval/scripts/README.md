# Scripts

后续建议把脚本放在这里，例如：

- `run_smoke.ps1`
- `run_quality.ps1`
- `update_golden.ps1`
- `compare_with_markitdown.ps1`
- `compare_with_docling.ps1`

第一阶段只需要先实现：

- 读取 `cases/**/*.case.json`
- 调用 MoonBitMark CLI
- 产出 `reports/latest/*.json`
