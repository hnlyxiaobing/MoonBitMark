# Project Optimization Items Review

> 评审基线：按当前仓库真实代码状态校正，现已同步到 P0 / P1 / P2 全部完成后的当前状态。

## 当前真实状态

- 已完成：
  `MarkItDown` 已接管 CLI 主流程，CLI 本身不再直接分发各格式 converter。
- 已完成：
  `ConvertResult`、typed diagnostics、frontmatter、asset 输出、metadata、stats 与 AST 已统一进入主链路。
- 已完成：
  CLI 已支持 `--frontmatter`、`--plain-text`、`--no-metadata`、`--asset-dir`、`--debug`、`--diag-json`、`--detect-only`、`--dump-ast`。
- 已完成：
  `--debug` 已能输出结构化文本 debug report，`--diag-json` 与 `--dump-ast` 已提供结构化展示面。
- 已完成：
  当前本地验证已达到 `80 passed, 0 failed`。
- 已完成：
  engine 注册表已是行为对象，detect 模块、CI、测试报告、README、demo 与 benchmark 已全部落地。
- 仍可继续优化：
  native 构建生成的 `cmd/main` / `cmd/demo` C 文件在 Windows 本地仍有 `C4819` 代码页 warning。
- 仍可继续优化：
  bytes input 目前在 demo / SDK 场景仍更适合继续深化为“直接 converter 消费 bytes”模式，而不只是 detect 升级。
- 仍可继续优化：
  benchmark 目前是最小脚本形态，尚未沉淀固定样本集与长期性能基线。

## P0 回顾

### 1. engine 插件式内核

已完成。

- `ConverterRegistration` 已升级为行为注册项。
- `register_default_converters()` 已退化为装配层。
- engine 主调度不再按 `ConverterKind` 写集中式大 `match`。

### 2. 输入识别增强

已完成。

- `src/engine/detect.mbt` 已拆出。
- 已支持魔数识别和 zip 容器内部签名识别。
- DOCX / PPTX / XLSX / EPUB 可通过内部路径提升识别结果。

### 3. CI 与测试报告

已完成。

- `.github/workflows/ci.yml` 已补齐。
- `tests/test_report/TEST_REPORT.md` 已更新到真实测试状态。

## P1 回顾

### 4. AST 深化

已完成。

- `Inline` 已支持 `Emphasis`、`Strong`、`Code`、`Link`、`Image`、`LineBreak`。
- renderer 已同步支持 richer AST 渲染。
- HTML / DOCX / EPUB 已接入 richer AST 主链路。

### 5. diagnostics 结构化展示

已完成。

- CLI 已支持 `--diag-json`。
- detect-only 与 debug report 已成为统一前端展示面的一部分。

### 6. 元信息与 README 收口

已完成。

- `moon.mod.json` 已指向真实仓库、README 与 Apache-2.0 许可证。
- 原本机硬编码构建路径已移除。
- README 已改写为当前真实架构叙事。

## P2 回顾

### 7. AST dump

已完成。

- CLI 已支持 `--dump-ast`。
- `ConvertResult.document` 已让 AST 成为稳定结果协议的一部分。

### 8. 最小 demo

已完成。

- `cmd/demo/` 已证明 engine 可脱离 CLI 参数层直接使用。

### 9. benchmark

已完成。

- `scripts/benchmark.ps1` 与 `docs/benchmark.md` 已提供最小 benchmark 入口。

## 当前推荐的后续方向

1. 清理 native 生成 C 文件的 `C4819` 编码 warning。
2. 深化 bytes-input 直连 converter 的适配层，继续增强 engine 的嵌入式使用场景。
3. 沉淀固定 benchmark 样本集和结果归档，形成长期性能基线。
