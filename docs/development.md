# Development Guide

## 常用命令

```bash
moon check
moon test
moon fmt
moon info
```

Windows native 构建推荐：

```bat
scripts\build.bat
scripts\test.bat
```

## 建议开发流程

1. 先改实现和测试。
2. 运行 `moon test` 验证行为。
3. 运行 `moon info` 更新接口文件，检查 `.mbti` 变化是否符合预期。
4. 运行 `moon fmt` 做最终格式化。

如果输出是有意变化，再执行：

```bash
moon test --update
```

## 代码导航建议

- 想看主链路：从 `cmd/main/main.mbt` 和 `src/engine/engine.mbt` 开始。
- 想看检测逻辑：读 `src/engine/detect.mbt`。
- 想看统一结果协议：读 `src/core/types.mbt`。
- 想看 Markdown 输出：读 `src/ast/types.mbt` 和 `src/ast/renderer.mbt`。
- 想看某个格式：直接进入 `src/formats/<format>/`。
- 想看 MCP：从 `cmd/mcp-server/main.mbt` 和 `src/mcp/` 开始。
- 想看 OCR：从 `src/capabilities/ocr/` 和 `src/formats/image/` 开始。

## 文档维护原则

- `docs/` 只记录当前有效的知识，不保存一次性过程文档。
- 任务过程、阶段性总结、推送记录统一留在 Git 历史中。
- 如果 README 已经足够覆盖某个主题，就不要再新增一份重复文档。

## 当前值得关注的维护点

- 新增公开 API 后，确认 `.mbti` 变化是有意的。
- 涉及 ZIP/Office 容器格式时，优先补白盒测试和真实样本测试。
- 涉及 OCR 时，同时检查 `mock` 和真实 backend 缺失时的 warning / diagnostics。
- 涉及 MCP 时，优先保持 STDIO + JSON-RPC 2.0 兼容，不要引入与当前实现无关的传输层复杂度。
