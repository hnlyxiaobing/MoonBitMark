# MoonBitMark 比赛验收速跑指南

这份文档面向比赛评委、答辩老师和第一次接触仓库的读者。

目标只有一个：用最短路径验证 MoonBitMark 不是“看起来很大”的项目，而是一个真实可构建、可运行、可验证的系统。

## 推荐验收顺序

### 1. 先看项目定位

建议先读：

- [`README.md`](../../README.md)
- [`docs/architecture.md`](../architecture.md)

只需要抓住三点：

1. 这是一个多格式文档转 Markdown 引擎，不是单格式 demo。
2. CLI 是当前主入口，MCP 还是实验性增量能力。
3. OCR / PDF fallback 明确是 bridge-backed 能力，不是假装“纯原生闭环”。

### 2. 做最小构建与测试

```bash
moon check
moon test
```

当前基线：

- `moon test` 通过数：`165/165`

### 3. 做 Windows native release 构建

推荐：

```bat
scripts\build.bat
```

或：

```bash
moon build --target native --release
```

### 4. 跑最短 CLI 成功路径

```powershell
_build\native\release\build\cmd\main\main.exe tests\conversion_eval\fixtures\inputs\html\simple_table.html
```

你应该能直接看到 Markdown 输出。

### 5. 看结构化 diagnostics

```powershell
_build\native\release\build\cmd\main\main.exe --diag-json tests\conversion_eval\fixtures\inputs\pdf\multi_page.pdf
```

建议重点看：

- `metadata`
- `diagnostics`
- `stats`

这一步能看出 MoonBitMark 的一个核心设计，不只是“转出 Markdown”，而是把转换过程里的结构化信息一起暴露出来。

### 6. 看 AST strict JSON

```powershell
_build\native\release\build\cmd\main\main.exe --dump-ast tests\conversion_eval\fixtures\inputs\html\simple_table.html
```

这一步可以验证项目不只是文本拼接，而是有统一 AST 输出协议。

### 7. 跑 MCP smoke check

```powershell
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
```

当前 MCP 验证范围是：

- `initialize`
- `tools/list`
- `tools/call`

这里建议把它理解成“已打通 agent-facing 最小工具面”，不要理解成“完整 MCP 实现”。

### 8. 跑完整质量评测

```bash
python tests/conversion_eval/scripts/run_eval.py run
```

当前最新结果：

- `34/34` 通过
- 平均分 `0.9983`

对应报告：

- [`tests/conversion_eval/reports/latest/summary.md`](../../tests/conversion_eval/reports/latest/summary.md)

## 如果只有 5 分钟，该看什么

如果时间非常紧，只做下面四步就够了：

1. `moon test`
2. `moon build --target native --release`
3. 跑一个 CLI 示例
4. 跑 `--diag-json`

这四步足够判断：

- 项目能不能构建
- 主路径能不能运行
- 输出是不是稳定
- 工程协议是不是清楚

## 建议重点关注的亮点

评审时最值得关注的不是“支持了多少格式”，而是下面这些工程特征：

- `src/engine/` 的统一调度结构
- `src/core/` 的 `ConvertResult + ConversionDiagnostic`
- `src/libzip/` 与 `src/xml/` 的纯 MoonBit 基础设施
- CLI、quality eval、OCR smoke、MCP smoke 分层验证
- 对 bridge-backed 边界的诚实表述

## 当前仍需如实理解的边界

下面这些是当前明确存在的边界，不建议忽略：

- OCR 依赖 Python bridge 和 backend
- PDF recovery 不是完整 layout understanding 系统
- MCP 仍为实验性 STDIO 入口
- Windows native release build 依赖 MSVC

这些边界没有被隐藏，而是作为项目真实状态的一部分被文档化。
