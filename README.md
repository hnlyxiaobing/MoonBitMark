# MoonBitMark

MoonBitMark 是一个用 MoonBit 实现的文档转 Markdown 引擎，强调轻依赖、原生分发、结构化 diagnostics，以及面向 AI-native 工具链的可演进接口。

当前主入口是 CLI。MCP capability surface 仍处于实验阶段，但本地 STDIO 入口已经补齐稳定 launcher，并提供了面向 Claude Code / Codex 的可复制接入配置、可发现的静态 resources、可复用的 prompts 模板，以及显式的 MCP 运行时安全边界。

## 为什么这个项目值得做

MoonBitMark 解决的不是“把某个文件转成文本”这么简单的问题，而是工程系统里常见的一类文档摄取需求：

- 需要把 Office、网页、PDF、图片这类输入统一转换成稳定 Markdown
- 需要结构化 metadata 和 diagnostics，便于自动化处理、失败分流和 agent 调用
- 不希望为了文档转换主链路引入整套重型 Python / ML 运行时

这也是本项目的定位：

> 一个以 MoonBit 实现、主路径轻量、可原生分发、具备结构化诊断协议的文档转 Markdown 引擎。

## 当前状态

截至 2026-03-31，本仓库的可验证状态如下：

- 支持输入：TXT、CSV、JSON、PDF、图片、HTML/XHTML/URL、DOCX、PPTX、XLSX、EPUB
- MoonBit 代码规模：`21653` 行 `src/**/*.mbt`，`22379` 行 tracked `.mbt` 总量（含测试）
- 本地测试：`moon test` 为 `184/184`
- 最新质量评测：`34/34` 通过，平均分 `0.9983`
- CI 覆盖：
  - Linux/macOS 的 `moon check` / `moon test`
  - Ubuntu non-blocking coverage check
  - Windows native release build
  - CLI / OCR / MCP smoke checks

对应质量报告：[`tests/conversion_eval/reports/latest/summary.md`](tests/conversion_eval/reports/latest/summary.md)

## 支持的输入类型

- TXT
- CSV
- JSON
- PDF
- 图片文件
- HTML / XHTML / URL
- DOCX
- PPTX
- XLSX
- EPUB

## 5 分钟验收路径

如果你是第一次看这个项目，推荐先走下面这条最短路径。

先给一个真正的一条命令入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/judge_quickstart.ps1
```

这个脚本会：

- 运行 `moon test`
- 复用现有 release binary，缺失时调用 `scripts\build.bat`
- 产出 HTML 样例 Markdown、PDF `--diag-json`、HTML `--dump-ast`
- 生成一份面向评委的产物总览 `_build\judge-quickstart\SUMMARY.md`
- 把输出保存到 `_build\judge-quickstart\`

如果你还想顺手覆盖 MCP STDIO smoke，可以执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/judge_quickstart.ps1 -IncludeMcp
```

### 1. 基础校验

```bash
moon check
moon test
```

如果你要检查覆盖率链路：

```bash
moon test --enable-coverage
moon coverage analyze
```

### 2. Windows native release 构建

推荐使用仓库脚本准备 MSVC 环境：

```bat
scripts\build.bat
```

或在已配置 MSVC 的环境中手动执行：

```bash
moon build --target native --release
```

### 3. 跑一个最短转换样例

```powershell
_build\native\release\build\cmd\main\main.exe tests\conversion_eval\fixtures\inputs\html\simple_table.html
```

### 4. 看结构化 diagnostics

```powershell
_build\native\release\build\cmd\main\main.exe --diag-json tests\conversion_eval\fixtures\inputs\pdf\multi_page.pdf
```

### 5. 看 AST strict JSON 输出

```powershell
_build\native\release\build\cmd\main\main.exe --dump-ast tests\conversion_eval\fixtures\inputs\html\simple_table.html
```

### 6. 跑 MCP smoke check

```powershell
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_resources_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_prompts_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_security_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_security_smoke.ps1
```

如果你要把 MoonBitMark 作为 MCP server 接入：

- STDIO 推荐通过 `scripts\mcp\moonbitmark-mcp.cmd` 接入
- HTTP 推荐先启动 `moon run --target native --release -q cmd/mcp-http-server -- --host 127.0.0.1 --port 8765`，再接入 `http://127.0.0.1:8765/mcp`
- STDIO wrapper 会优先使用 release binary，缺失时回退到 `moon run --target native --release -q cmd/mcp-server`
- 先用 `prompts/list` / `prompts/get` 获取 guided workflow，再按需调用 tools
- 先用 `resources/list` / `resources/read` 获取能力边界，再用工具
- 先用 `inspect_document`，再用默认 preview 的 `convert_to_markdown`，只有需要全文时再切 `mode=full`
- HTTP/remote 客户端如果不共享文件路径，优先用 `upload_document` 拿到 `resource_uri`，再调用 `inspect_document` / `convert_to_markdown`；`convert_uploaded_document` 保留为 one-shot 便捷入口
- 需要结构化结果时，为转换工具传 `response_mode=json`，读取 `structuredContent`
- 运行时边界通过 `MOONBITMARK_MCP_ALLOWED_ROOTS`、`MOONBITMARK_MCP_ALLOW_HTTP`、`MOONBITMARK_MCP_ENABLE_OCR`、`MOONBITMARK_MCP_MAX_OUTPUT_CHARS`、`MOONBITMARK_MCP_MAX_UPLOAD_BYTES`、`MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL` 控制
- HTTP 只提供最小闭环：`POST /mcp` + `GET /healthz`，不提供 SSE 或流式输出

Claude Code 项目级 `.mcp.json` 示例：

```json
{
  "mcpServers": {
    "moonbitmark": {
      "command": "cmd",
      "args": ["/d", "/c", "scripts\\mcp\\moonbitmark-mcp.cmd"],
      "env": {
        "MOONBITMARK_MCP_ALLOWED_ROOTS": ".;tests",
        "MOONBITMARK_MCP_ALLOW_HTTP": "0",
        "MOONBITMARK_MCP_ENABLE_OCR": "0",
        "MOONBITMARK_MCP_MAX_OUTPUT_CHARS": "12000"
      }
    }
  }
}
```

Claude Code HTTP 注册示例：

```bash
claude mcp add --transport http moonbitmark-http http://127.0.0.1:8765/mcp
```

Codex STDIO 配置示例：

```toml
[mcp_servers.moonbitmark]
command = "cmd"
args = ["/d", "/c", "scripts\\mcp\\moonbitmark-mcp.cmd"]
env = { MOONBITMARK_MCP_ALLOWED_ROOTS = ".;tests", MOONBITMARK_MCP_ALLOW_HTTP = "0", MOONBITMARK_MCP_ENABLE_OCR = "0", MOONBITMARK_MCP_MAX_OUTPUT_CHARS = "12000" }
```

Codex HTTP 注册示例：

```bash
codex mcp add moonbitmark-http --url http://127.0.0.1:8765/mcp
```

推荐 launcher：

```bat
scripts\mcp\moonbitmark-mcp.cmd
```

详细说明见：

- [`docs/features/mcp.md`](docs/features/mcp.md)
如果你想看完整质量评测：

```bash
python tests/conversion_eval/scripts/run_eval.py run
```

更详细的比赛/评委验收路径见：

- [`docs/competition/judge-runbook.md`](docs/competition/judge-runbook.md)
- [`scripts/judge_quickstart.ps1`](scripts/judge_quickstart.ps1)
- `_build\judge-quickstart\SUMMARY.md`（运行 quickstart 后生成）

## CLI 常用命令

核心开发命令：

```bash
moon check
moon test
moon info
moon fmt
```

直接运行 CLI：

```bash
_build/native/release/build/cmd/main/main.exe <input> [output]
```

常用选项：

- `--frontmatter`
- `--plain-text`
- `--no-metadata`
- `--asset-dir <dir>`
- `--ocr <off|auto|force>`
- `--ocr-lang <lang>`
- `--ocr-images`
- `--ocr-backend <auto|mock|tesseract>`
- `--ocr-timeout <ms>`
- `--diag-json`
- `--detect-only`
- `--dump-ast`
- `--debug`

其中：

- `--diag-json` 输出结构化 diagnostics/stats/metadata
- `--dump-ast` 输出 strict JSON 形式的归一化 AST
- `--detect-only` 只做输入检测，不执行转换

详细 CLI 行为矩阵见：

- [`docs/audit/cli_matrix.md`](docs/audit/cli_matrix.md)

## 架构概览

主链路：

```text
input path / url
  -> engine.detect
  -> converter registry
  -> concrete converter
  -> AST / metadata / diagnostics / assets
  -> renderer / postprocess
  -> ConvertResult
```

关键目录：

```text
src/
├── ast/              统一 AST 与 Markdown renderer
├── capabilities/     横切能力层，目前包含 OCR
├── core/             ConvertResult、context、diagnostics、stats
├── engine/           detect、converter registry、统一调度
├── formats/          各格式 converter
├── libzip/           纯 MoonBit ZIP / Deflate
├── mcp/              MCP 协议、传输与 handler
└── xml/              纯 MoonBit XML parser

cmd/
├── main/             CLI 入口
├── demo/             engine 最小示例
└── mcp-server/       MCP STDIO 入口
```

更完整的架构说明见：

- [`docs/architecture.md`](docs/architecture.md)
- [`docs/architecture/external_dependencies.md`](docs/architecture/external_dependencies.md)

## 这个项目的差异化

和常见 Python 文档转换工具相比，MoonBitMark 当前最值得关注的点是：

- 主转换链路轻量，适合 native 分发和工程集成
- `libzip + xml` 是可复用的纯 MoonBit 基础设施
- `ConvertResult + ConversionDiagnostic` 适合 CLI、自动化和 agent 消费
- OCR / PDF fallback 被明确放在可选 bridge 能力，而不是被包装成“纯原生闭环”
- MCP 虽然还在早期，但已经有 agent-facing 的最小工具面

## 当前边界与限制

这些限制是有意保留在 README 里的，避免误导：

- CLI 是当前主公共入口
- OCR 是可选能力，依赖 `python scripts/ocr/bridge.py`
- PDF 主路径以 MoonBit-native 提取为主，fallback 可能走 `scripts/pdf/bridge.py`
- MCP 当前是实验性协议面，但本地 STDIO launcher 已有明确入口和 smoke coverage
- baseline 对比（`markitdown` / `docling`）是可选环境，不是默认依赖
- Windows native release 构建依赖 MSVC

当前已知问题见：

- [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md)

## 比赛材料

如果你是从 2026 MoonBit 软件合成挑战赛来到这个仓库，建议直接看：

- [`docs/competition/judge-runbook.md`](docs/competition/judge-runbook.md)
- [`docs/competition/dev-retrospective.md`](docs/competition/dev-retrospective.md)
- [`docs/competition/moonbit-advantages.md`](docs/competition/moonbit-advantages.md)

历史计划和临时评估草稿保存在 `docs/temp/`，但它们不作为当前项目状态的主信息源。

## 文档索引

- [`docs/README.md`](docs/README.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/development.md`](docs/development.md)
- [`docs/benchmark.md`](docs/benchmark.md)
- [`docs/features/ocr.md`](docs/features/ocr.md)
- [`docs/features/mcp.md`](docs/features/mcp.md)
- [`docs/testing/test_layers.md`](docs/testing/test_layers.md)

## 许可证

Apache-2.0
