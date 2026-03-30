# Documentation Guide

`docs/` 只保留对当前仓库仍然有效、能长期帮助理解项目和继续开发的文档。

## 文档分类

- [architecture.md](architecture.md): 当前系统架构、主链路、共享层职责和各格式簇的真实状态。
- [architecture/external_dependencies.md](architecture/external_dependencies.md): 纯 MoonBit 与 bridge / 子进程 / 工具链依赖边界。
- [audit/placeholder_audit.md](audit/placeholder_audit.md): 第一阶段 placeholder / 半实现路径审计。
- [audit/cli_matrix.md](audit/cli_matrix.md): CLI 公开参数与负向路径矩阵。
- [development.md](development.md): 日常开发命令、验证流程、quality eval 入口和文档维护规则。
- [features/mcp.md](features/mcp.md): MCP 服务的当前实现、运行方式和能力边界。
- [features/ocr.md](features/ocr.md): OCR 能力层的接入方式、CLI 选项和当前限制。
- [testing/test_layers.md](testing/test_layers.md): quality / integration / cli / ocr / baseline 分层。
- [benchmark.md](benchmark.md): 最小性能 benchmark 和 conversion eval 入口。
- [html_url_optimization_plan.md](html_url_optimization_plan.md): HTML/URL 路径对齐 MarkItDown 差距后的优化方案与完成标准。
- [pdf_ocr_optimization_plan.md](pdf_ocr_optimization_plan.md): PDF recovery/OCR 路径对齐 MarkItDown 差距后的优化方案与完成标准。
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md): 当前仍未解决、值得持续跟踪的问题。

## 目录原则

- 保留“当前有效”的说明，不保留已经失效的状态结论。
- `docs/temp/` 可以保留计划文档，但计划里的状态快照和数据结论要和主线代码同步更新。
- 如果某份文档已经不能指导当前代码，应直接更新或删除，而不是继续叠加补丁说明。
- 影响支持范围、共享架构、评测入口或主要限制的改动，应同步更新 `README.md` 和对应专题文档。
