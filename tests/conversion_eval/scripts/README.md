# Scripts

此目录当前使用一个主入口脚本：

- `run_eval.py`

支持的子命令：

- `sync`：同步 benchmark 子集到 `fixtures/inputs/`
- `prepare`：生成/刷新 reference markdown
- `run`：执行 MoonBitMark 评测并输出报告
- `all`：按 `sync -> prepare -> run` 全流程执行

推荐直接通过仓库根目录的 `scripts/run_conversion_eval.ps1` 调用。
