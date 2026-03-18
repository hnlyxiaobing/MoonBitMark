# Project Optimization Construction Plan

> 这是按当前仓库真实状态收口后的施工结项版路线图，已从“待施工”切换为“已完成 + 后续建议”。

## 已完成施工项

### 1. engine 插件化改造

已完成：

- `src/engine/engine.mbt` 已完成行为注册式调度。
- registration 自身携带 `accepts` 与 `convert`。
- engine 聚焦于 detect、选择、调度、后处理与 diagnostics 合并。

### 2. detect 模块拆分与输入识别增强

已完成：

- `src/engine/detect.mbt` 已独立存在。
- 已形成“输入类型 -> 扩展名 -> 魔数 -> 容器内部签名”的识别梯度。
- DOCX / PPTX / XLSX / EPUB 均已支持容器内部特征识别。

### 3. AST 扩展与 renderer 升级

已完成：

- `src/ast/types.mbt` 已支持 richer inline 语义。
- `src/ast/renderer.mbt` 已支持对应 Markdown 渲染。
- `ConvertResult.document` 已把 AST 纳入统一结果协议。

### 4. HTML / DOCX / EPUB 深化接入 richer AST

已完成：

- HTML 已映射链接、强调、图片、代码与换行。
- DOCX 已映射 run 级强调、链接、图片与标题语义，并为不支持样式保留 warning。
- EPUB 已复用 HTML 的 XHTML -> AST 路径。

### 5. CLI 结构化展示能力

已完成：

- `--diag-json`
- `--detect-only`
- `--dump-ast`

CLI 现在已覆盖文本 debug、diagnostics JSON、detect-only 与 AST dump 四类展示面。

### 6. diagnostics / metadata / stats 协议收口

已完成：

- `ConvertResult` 已统一承载 markdown、diagnostics、metadata、stats、assets、AST。
- `src/engine/engine.mbt` 已作为统一归一化与后处理入口。

### 7. 工程证据补齐

已完成：

- `.github/workflows/ci.yml` 已补齐主干验证。
- `tests/test_report/TEST_REPORT.md` 已同步到当前测试状态。
- `cmd/demo/` 已提供最小解耦 demo。
- `scripts/benchmark.ps1` 与 `docs/benchmark.md` 已提供最小 benchmark 入口。

### 8. 元信息与构建体验收口

已完成：

- `moon.mod.json` 已同步到真实仓库、README 与 Apache-2.0。
- `moonpkg.json` 与 `cmd/main/moon.pkg` 已移除仓库内绝对 vcpkg 路径。
- `scripts/build.bat` / `scripts/test.bat` 已改为依赖 `VCPKG_ROOT` / `VCPKG_TRIPLET`。

### 9. README 升级

已完成：

- README 已同步当前架构、CLI、demo、benchmark 与结构化输出能力。

## 当前结项状态

本轮优化计划中的 P0、P1、P2 已全部完成。

当前仓库可视为进入新的维护/增强阶段，而不再处于本轮结构改造施工阶段。

## 后续建议

1. 清理 Windows native 构建中生成 C 文件的 `C4819` 代码页 warning。
2. 深化 bytes-input 直接转换路径，减少 demo / SDK 场景对文件路径的依赖。
3. 为 benchmark 引入固定样本集与结果归档，形成长期性能基线。
