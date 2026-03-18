# Project Optimization TODO List

> 用途：跟踪 `docs/ProjectOptimization/` 评审后确认的优化项。每完成一轮迭代，直接在本文件把对应事项打勾，并补一行迭代记录。

## 基线状态

- 评审时间：2026-03-18
- 基线结论：项目主链路已经成型，但插件化、识别增强、工程证据、元信息和 AST 深化仍有明显优化空间。

## 已完成的基线事项

- [x] engine 已接管 CLI 主流程
- [x] `ConvertResult`、typed diagnostics、frontmatter、asset 输出已进入主链路
- [x] CLI 已支持 `--frontmatter`、`--plain-text`、`--no-metadata`、`--asset-dir`、`--debug`
- [x] CLI `--debug` 已能输出结构化文本 debug report
- [x] 本地 `moon test` 已达到 `73 passed, 0 failed`

## 待完成的优化事项

### P0

- [x] 将 `ConverterRegistration` 升级为行为注册项，移除 engine 对 `ConverterKind` 的集中式调度
- [x] 拆出 `src/engine/detect.mbt`，补魔数与 zip 容器内部签名识别
- [x] 新增主干 CI：`moon check`、`moon test`、CLI smoke test
- [x] 重写 `tests/test_report/TEST_REPORT.md`，同步到当前真实测试状态

### P1

- [x] 扩展 `src/ast/types.mbt` 的 inline 语义：强调、加粗、链接、图片、行内代码、换行
- [x] 升级 `src/ast/renderer.mbt` 以支持 richer AST
- [x] 深化 HTML converter 的 AST 映射，覆盖链接、强调、图片、代码、换行
- [x] 深化 DOCX converter 的 AST 映射，覆盖 run 级强调、链接、图片与标题语义
- [x] 深化 EPUB converter 的 XHTML -> AST 复用路径
- [x] 为 CLI 增加 `--diag-json`
- [x] 为 CLI 增加 `--detect-only`
- [x] 修正 `moon.mod.json` 的仓库地址、readme 路径和 license 信息
- [x] 清理 `moonpkg.json` 与 `cmd/main/moon.pkg` 中的本机硬编码构建配置
- [x] 刷新 `README.md` 的项目叙事、架构图和 diagnostics 示例

### P2

- [x] 为 CLI 增加 `--dump-ast`
- [x] 增加最小 demo，用于展示 engine 与 CLI 的解耦
- [x] 增加 benchmark 文档或脚本

## 迭代记录

### Iteration 0

- [x] 完成 `docs/ProjectOptimization/` 文档评审与纠偏
- [x] 新建本 TODO 跟踪文件
- 说明：本轮只完成评审与跟踪基线建立，尚未开始代码优化项落地。

### Iteration 1

- [x] 完成 engine 行为注册式重构，移除主调度对 `ConverterKind` 的集中分发依赖
- [x] 新增 `src/engine/detect.mbt`，并让转换主链路使用增强识别结果
- [x] 新增 `.github/workflows/ci.yml`，补齐 `moon check` / `moon test` / CLI smoke test
- [x] 重写 `tests/test_report/TEST_REPORT.md`，同步到 `74` 项本地测试通过的当前状态

### Iteration 2

- [x] 扩展 AST inline 语义，并让 renderer 支持 richer inline Markdown 输出
- [x] 让 HTML / DOCX / EPUB 主链路接入 richer AST，其中 EPUB 复用 HTML 的 XHTML -> AST 路径
- [x] 为 CLI 增加 `--diag-json` 与 `--detect-only`
- [x] 修正 `moon.mod.json`、`moonpkg.json`、`cmd/main/moon.pkg` 与 `README.md` 的 P1 收口项
- 说明：本轮完成 P1 全量事项，Windows native 配置改为通过 `VCPKG_ROOT` / `VCPKG_TRIPLET` 注入依赖路径。

### Iteration 3

- [x] 为 `ConvertResult` 增加 AST 挂载，并让 AST-based converter 回填 `document`
- [x] 为 CLI 增加 `--dump-ast`，直接复用 engine 主链路输出 AST JSON
- [x] 新增 `cmd/demo/` 最小 demo，展示 engine 可脱离 CLI 独立使用
- [x] 新增 `scripts/benchmark.ps1` 与 `docs/benchmark.md`
- 说明：本轮完成 P2 全量事项。
