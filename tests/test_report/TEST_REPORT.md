# MoonBitMark 测试报告

**测试时间:** 2026-03-18
**项目版本:** v0.3.0
**测试环境:** Windows 11 + MSVC 2022 + vcpkg + MoonBit native target
**测试状态:** ✅ 所有本地测试通过

---

## 执行摘要

本轮测试基于当前主干真实状态重新整理，已覆盖 P0、P1、P2 完成后的代码面。

本轮实际执行命令：

```bash
moon check
moon info
moon fmt
cmd /c "set VCPKG_ROOT=C:\vcpkg&& scripts\test.bat"
```

本轮结果：

| 指标 | 数值 |
|------|------|
| 总测试数 | **80** |
| 通过 | **80** |
| 失败 | **0** |
| 通过率 | **100%** |

---

## 当前覆盖重点

### 1. 架构层

已覆盖：

- `MarkItDown::new()` 默认注册表初始化
- `select_converter()` 优先级选择
- diagnostics merge 与重复 warning 去重
- detect 模块中的 zip / bytes 输入升级识别
- frontmatter / metadata / asset postprocess 所在主链路的稳定性
- `DetectionResult` 输出
- `ConvertResult.document` AST 主链路挂载

### 2. converter 层

已覆盖：

- TXT
- CSV
- JSON
- PDF
- HTML
- DOCX
- PPTX
- XLSX
- EPUB

其中复杂格式已额外覆盖 typed diagnostics / warning 渲染相关白盒测试，HTML / DOCX / EPUB 已纳入 richer AST 回归面。

### 3. CLI 与前端层

已覆盖：

- 参数解析
- `--frontmatter`
- `--asset-dir`
- `--debug`
- `--diag-json`
- `--detect-only`
- `--dump-ast`
- 输出文件写入主路径
- `cmd/demo` 独立 engine demo 编译与测试进入主测试集

---

## 代表性验证结论

### engine / detect / AST

- engine 主调度已是行为注册式调度
- `src/engine/detect.mbt` 已独立存在，并接入转换主链路
- AST 已从基础块模型扩展为 richer inline 语义模型
- AST 现在会通过 `ConvertResult.document` 返回给上层，CLI 可直接 `--dump-ast`

### diagnostics / metadata / stats

- `ConversionDiagnostic` 已统一进入 `ConvertResult`
- `warning` / `error` 渲染协议稳定
- CLI 已可输出文本 debug report、diagnostics JSON 和 detect-only 结果
- `metadata`、`stats`、`assets` 与 AST 已统一归口到主结果对象

### 输出后处理

- frontmatter 输出可用
- metadata enrich 可用
- `asset_output_dir` 可统一处理 converter 产出的 `OutputAsset`
- Markdown 中 data URI 图片可统一落盘并回写相对链接

---

## 当前工程证据

- `.github/workflows/ci.yml` 已存在
- `cmd/demo/` 已证明 engine 与 CLI 解耦
- `scripts/benchmark.ps1` 与 `docs/benchmark.md` 已提供最小 benchmark 入口

---

## 当前已知说明

- `moon check` 当前通过。
- `moon test` 当前通过，共 `80 passed, 0 failed`。
- 在 Windows 本地执行 native 构建或测试时，MSVC 仍会对生成的 `cmd/main` / `cmd/demo` C 文件报告 `C4819` 代码页警告；该警告未导致测试失败，但属于后续可继续清理的本地构建噪声。

---

## 结论

当前 MoonBitMark 已完成本轮优化计划中的 P0、P1、P2：

- engine 主链路统一
- diagnostics / metadata / stats / assets / AST 已纳入统一结果模型
- richer AST 已进入 HTML / DOCX / EPUB 主链路
- CLI 已具备 detect / diagnostics / AST dump 三类结构化展示能力
- demo 与 benchmark 入口已落地

这份报告可作为下一阶段继续清理 native 编码 warning、增强 bytes-input 适配与沉淀性能基线的当前基线版本。
