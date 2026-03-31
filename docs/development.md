# Development Guide

## 常用命令

```bash
moon check
moon test
moon info
moon fmt
```

Windows native 构建推荐：

```bat
scripts\build.bat
scripts\test.bat
```

## 建议开发流程

1. 先改实现和测试。
2. 运行 `moon check` 做快速类型检查。
3. 运行 `moon test` 验证行为。
4. 需要查看测试覆盖时，先运行 `moon test --enable-coverage`，再运行 `moon coverage analyze`。
5. 涉及格式输出质量时，运行 `python tests/conversion_eval/scripts/run_eval.py run`。
6. 运行 `moon info` 更新接口文件，检查 `.mbti` 变化是否符合预期。
7. 运行 `moon fmt` 做最终格式化。

如果输出是有意变化，再执行：

```bash
moon test --update
```

## Coverage 工作流

```bash
moon test --enable-coverage
moon coverage analyze
```

如果需要保存报告，可以把 `moon coverage analyze` 的输出重定向到日志文件再做筛查。

## 质量回归建议

- 改 CSV / HTML / JSON / TXT 这类输出收敛逻辑时，优先补白盒测试，再跑 conversion eval。
- 改共享渲染层时，不要只看单格式测试；至少复跑 `moon test` 和 `conversion_eval`。
- 需要引入或刷新真实样本时，优先使用外部 benchmark 仓库，通过 `tests/conversion_eval/scripts/run_eval.py sync|prepare` 同步，而不是手工拼散落 fixture。
- 涉及 OCR 时，同时检查 `mock` 和真实 backend 缺失场景下的 warning / diagnostics。

## 代码导航建议

- 想看主链路：从 `cmd/main/main.mbt` 和 `src/engine/engine.mbt` 开始。
- 想看检测逻辑：读 `src/engine/detect.mbt`。
- 想看统一结果协议：读 `src/core/types.mbt`。
- 想看共享 helper：读 `src/core/file_helpers.mbt` 和 `src/core/conversion_helpers.mbt`。
- 想看 Markdown 输出：读 `src/ast/types.mbt` 和 `src/ast/renderer.mbt`。
- 想看某个格式：直接进入 `src/formats/<format>/`。
- 想看 MCP：从 `cmd/mcp-server/main.mbt` 和 `src/mcp/` 开始。
- 想看 OCR：从 `src/capabilities/ocr/` 和 `src/formats/image/` 开始。

## 文档维护原则

- `README.md`、`docs/architecture.md`、`docs/development.md` 和 `docs/benchmark.md` 记录当前真实状态，不保留过时阶段说明。
- `docs/temp/` 可以保留计划文档，但状态快照、阶段完成度和数据结论要随主线实现更新。
- 如果某次改动改变了公开接口、评测入口、支持范围或主要限制，文档要和代码在同一轮提交里同步更新。

## 当前值得关注的维护点

- 新增公开 API 后，确认 `.mbti` 变化是有意的。
- 涉及 ZIP/Office 容器格式时，优先补白盒测试和真实样本测试。
- 涉及 HTML / CSV 这类轻量解析器时，优先避免把局部修复继续堆成字符串分支；能沉到共享 helper 或共享 renderer 的，优先收敛。
- 涉及 MCP 时，优先保持 STDIO + JSON-RPC 2.0 兼容，不要引入与当前实现无关的传输层复杂度。
