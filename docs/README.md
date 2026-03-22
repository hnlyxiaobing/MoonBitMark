# Documentation Guide

`docs/` 只保留对当前仓库仍然有效、能长期帮助理解项目和继续开发的文档。

## 文档分类

- [architecture.md](architecture.md): 当前系统架构、主链路和关键模块入口。
- [development.md](development.md): 日常开发命令、目录约定、验证流程和维护建议。
- [features/mcp.md](features/mcp.md): MCP 服务的当前实现、运行方式和能力边界。
- [features/ocr.md](features/ocr.md): OCR 能力层的接入方式、CLI 选项和当前限制。
- [benchmark.md](benchmark.md): 本地最小 benchmark 脚本使用方法。
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md): 当前仍未解决、值得持续跟踪的问题。

## 目录原则

- 保留“当前有效”的说明，不保留一次性的计划、阶段总结、推送日志和任务报告。
- 历史过程信息统一交给 Git 记录，而不是继续堆在 `docs/` 根目录。
- 如果某份文档已经不能指导当前代码，应直接更新或删除，而不是继续叠加补丁说明。
