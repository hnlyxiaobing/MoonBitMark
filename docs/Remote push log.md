# Remote Push Log

> 这份文档按“每次推送远程仓库”为单位记录修改内容，便于后续回看每一批提交实际推进了什么。

## 记录规范

每次推送建议记录：

- 日期
- 分支
- 本次推送的主要目标
- 涉及的核心文件或模块
- 验证命令
- 剩余问题 / 后续建议

---

## 2026-03-17

- 分支：main
- 主题：架构改造阶段性收口与文档刷新

本次推送包含的核心修改：

1. CLI 前端改造
- `cmd/main/main.mbt` 接入统一 engine 调用与 `ConvertContext` 参数透传
- 补齐 `--frontmatter`、`--plain-text`、`--no-metadata`、`--asset-dir`、`--debug`、`--help`
- 新增 `cmd/main/main_wbtest.mbt`

2. 核心类型与统一诊断
- `src/core/types.mbt` 引入 typed `ConversionDiagnostic`、`ConversionPhase`、`DiagnosticSource`、`DiagnosticHint`
- 统一 warning / error 渲染与默认补齐逻辑
- 更新 `src/core/core_test.mbt` 与 `pkg.generated.mbti`

3. engine 主链路落地
- `src/engine/engine.mbt` 真正接管输入识别、converter 选择、结果汇总与错误透传
- 增加标准化 typed failure 透传逻辑
- 新增 `asset_output_dir` 的真实资源落盘流程：将 Markdown 中的 `data:image/*;base64,...` 解码写入目录，并回写相对链接
- 回填 `asset_count` 与 `asset_output_dir` metadata
- 新增 `src/engine/engine_wbtest.mbt`

4. converter 与 parser 改造
- `csv/docx/epub/html/pdf/pptx/xlsx` converter 接入 typed diagnostics
- `docx/pptx/xlsx/epub` 的关键 archive / XML 失败路径改为统一 typed failure
- 收口 `pptx` 与 `xlsx` 次级 helper 的静默吞错问题

5. AST / 渲染与整体结构
- HTML、DOCX、EPUB 已接入 `Document -> renderer` 主链路
- engine 后处理阶段开始承担 output mode、frontmatter、asset rewrite 等统一职责

6. warning 与工程清理
- 清理 HTML、PDF、libzip、xml、mcp util 等历史 warning
- 删除 `src/formats/pptx/types.mbt` 无用类型
- 项目 warning 大幅收敛；当前只剩 1 个工具链层面 warning：`src/engine/moon.pkg` 中 `moonbitlang/async` 被误判为 `unused_package`

7. 文档刷新
- 更新 `README.md`
- 刷新 `docs/Project architecture transformation.md`
- 新增 `docs/Architecture refactor lessons learned.md`
- 新增本文件 `docs/Remote push log.md`

本次推送前验证：

```bash
moon info
moon fmt
moon check
moon test src/engine
```

本次推送前的下一步建议：

1. 统一 DOCX / EPUB / PPTX / XLSX 的原生资源提取链路
2. 继续把 AST 推广到更多格式
3. 在主链路稳定后再推进 Web / MCP 展示层

---

## 2026-03-18

- 分支：main
- 主题：修复路径分割 bug 与完善项目文档

本次推送包含的核心修改：

1. 路径分割 bug 修复
   - `src/engine/engine.mbt` 中 `split_path_segments` 函数存在 UTF-8 多字节字符处理错误
   - 原代码使用 `ch.to_string()` 会将单个字节转为字符，导致非 ASCII 字符（如中文）被错误拆分
   - 修复：改用 `normalized[i:i + 1].to_string()` 进行正确的子串切片

2. 测试增强
   - `src/engine/engine_wbtest.mbt` 添加测试验证 `materialize_data_uri_assets` 不会创建杂散目录
   - 之前该函数可能因路径分割 bug 创建以 Unicode 码点数字命名的错误目录

3. 文档更新
   - `AGENTS.md` 添加 Repo-Scoped Skills 使用说明
   - 指导 AI 助手正确使用项目内置的 `.codex/skills/` 技能

4. 工程配置
   - `.gitignore` 添加 `.codex/` 目录

本次推送前验证：

```bash
moon info && moon fmt
moon check
moon test src/engine
```

推送后的下一步建议：

1. 继续完善 AST 渲染链路
2. 推进更多格式的 converter 改造

