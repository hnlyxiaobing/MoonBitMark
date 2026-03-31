# Documentation Guide

`docs/` 只保留当前仓库仍然有效、可以长期帮助理解项目和继续开发的文档。

## 文档分类

- [architecture.md](architecture.md): 当前系统架构、主链路、共享层职责和各格式簇的真实状态。
- [architecture/external_dependencies.md](architecture/external_dependencies.md): 纯 MoonBit 与 bridge / 子进程 / 工具链依赖边界。
- [competition/judge-runbook.md](competition/judge-runbook.md): 面向比赛评委和新读者的 5 分钟验收路径。
- [competition/dev-retrospective.md](competition/dev-retrospective.md): 参赛开发复盘，说明关键架构取舍与 AI 工具使用方式。
- [competition/moonbit-advantages.md](competition/moonbit-advantages.md): 为什么这个题目适合用 MoonBit 做。
- [audit/placeholder_audit.md](audit/placeholder_audit.md): 第一阶段 placeholder / 半实现路径审计。
- [audit/cli_matrix.md](audit/cli_matrix.md): CLI 公开参数与负向路径矩阵。
- [development.md](development.md): 日常开发命令、验证流程、quality eval 入口和文档维护规则。
- [features/mcp.md](features/mcp.md): MCP 服务的当前实现、运行方式和能力边界。
- [features/ocr.md](features/ocr.md): OCR 能力层的接入方式、CLI 选项和当前限制。
- [testing/test_layers.md](testing/test_layers.md): quality / integration / cli / ocr / baseline 分层。
- [benchmark.md](benchmark.md): 最小性能 benchmark 和 conversion eval 入口。
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md): 当前仍未解决、值得持续跟踪的问题。

## 目录原则

- 保留“当前有效”的说明，不保留已经失效的状态结论。
- `docs/temp/` 可以保留计划文档和阶段性研究，但主线状态说明以 `README.md` 和 `docs/` 正式文档为准。
- 如果某份文档已经不能指导当前代码，应直接更新或删除，而不是继续叠加补丁说明。
- 影响支持范围、共享架构、评测入口或主要限制的改动，应同步更新 `README.md` 和对应专题文档。
