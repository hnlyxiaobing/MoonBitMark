# MoonBitMark 项目优化总任务文档

## 1. 文档定位

本文档是当前仓库唯一的临时总任务文档，用于替代此前分散在 `docs/temp/` 下的多份阶段性规划稿。

它整合了三类信息：

- 当前仓库在 `2026-03-24` 可直接核验的真实状态
- 既有临时规划稿中的长期优化方向
- 本轮最需要优先收口的可用性、真实性、自动化和质量提升任务

本文档的目标不是单纯汇总，而是给出一条执行后能明显改善项目现状的顺序：

1. 先收口真实性和可用性
2. 再扩大验证和自动化
3. 最后推进能继续拉高转换效果的质量任务

## 2. 当前现状快照（以本地代码为准）

以下事实已在本地仓库直接核验：

- [`src/mcp/transport/stdio.mbt`](/D:/MySoftware/MoonBitMark/src/mcp/transport/stdio.mbt) 的 `StdioTransport::read_line()` 目前恒返回空字符串，属于明确 placeholder。
- [`cmd/mcp-server/main.mbt`](/D:/MySoftware/MoonBitMark/cmd/mcp-server/main.mbt) 已将该 transport 接入 MCP server 主循环，因此 MCP 当前存在“入口已公开、闭环未证实”的风险。
- [`docs/features/mcp.md`](/D:/MySoftware/MoonBitMark/docs/features/mcp.md) 当前仍将 MCP 写成已提供 STDIO 服务入口，这与真实实现成熟度不一致。
- [`cmd/main/main.mbt`](/D:/MySoftware/MoonBitMark/cmd/main/main.mbt) 已暴露较多 CLI 参数，包括 `--detect-only`、`--dump-ast`、`--diag-json` 和整组 OCR 参数，但当前缺少系统化命令矩阵与负向自动化。
- [`src/capabilities/ocr/provider.mbt`](/D:/MySoftware/MoonBitMark/src/capabilities/ocr/provider.mbt) 仍通过 `scripts/ocr/bridge.py` 和 `@process.run("python", ...)` 调外部桥接，OCR 能力边界本质上仍依赖子进程和外部运行时。
- [`moonpkg.json`](/D:/MySoftware/MoonBitMark/moonpkg.json) 当前仍固定 `cl.exe`。
- [`moon.mod.json`](/D:/MySoftware/MoonBitMark/moon.mod.json) 当前包名仍是 `moonbitlang/moonbitmark`。
- [`.github/workflows/ci.yml`](/D:/MySoftware/MoonBitMark/.github/workflows/ci.yml) 当前主流程仍以 Windows 上的 `moon check`、`moon test`、两个 CLI smoke 输出检查和 `conversion_eval` 为主，尚未覆盖 CLI 负向、MCP 闭环或 OCR 缺 backend 的专项验证。
- [`tests/conversion_eval/reports/latest/summary.md`](/D:/MySoftware/MoonBitMark/tests/conversion_eval/reports/latest/summary.md) 显示当前最新评测为 `29/29` 通过，平均分 `0.9894`。这说明项目已有较强的质量评测主干，但不等于所有公开能力都已真实闭环。
- 同一份评测摘要还显示外部 baseline `markitdown` 与 `docling` 当前均为 `unavailable`，因此当前仓库并不具备稳定的外部基线对照能力。

当前判断：

- 转换质量主干已经建立
- 可用性与真实性边界尚未完全收口
- 文档成熟度描述高于部分入口的真实可验证程度

## 3. 评审结论

### 3.1 真实性

这份总方案的真实性建立在以下原则上：

- 只把当前仓库能直接打开文件核验的事实写入“现状”
- 不把旧临时文档里的“已完成”结论直接当作今天的状态
- 不把 `conversion_eval` 高分视为 MCP、CLI、OCR 等能力的存在性证明

结论：

- 真实性是足够的，但必须继续保持“事实快照”和“未来任务”分离
- 执行中如果发现新的事实与本文档冲突，应以代码和验证结果为准更新本文档

### 3.2 合理性

单纯继续追 PDF V2、多格式提质或更高分数，并不能先解决当前最突出的项目问题。当前真正的主矛盾是：

- 某些入口已经公开，但可用性没有端到端证明
- 文档承诺与真实闭环程度不完全一致
- 外部依赖边界和失败路径未完全说明

因此，先做“真实性/可用性收口”，再做“质量提升”，顺序是合理的。

但如果只做前半段，项目会更诚实、更可测，却不一定显著提升转换效果。因此本文档明确拆成两个阶段：

- 第一阶段：真实性、可用性、自动化收口
- 第二阶段：基于可信基线继续提升转换质量

### 3.3 可操作性

本文档里的每个任务都要求以下要素：

- 明确目标
- 明确落点文件或目录
- 明确 DoD
- 明确验证方式

这使它具备直接执行性，而不是泛泛的架构讨论稿。

结论：

- 只要严格按任务顺序推进，这份方案是可操作的
- 若跳过第一阶段直接做质量任务，项目会继续保留“质量分高但能力边界模糊”的结构性问题

## 4. 总执行原则

后续任务统一遵守以下规则：

1. 先消灭“看起来实现了但其实没实现”的路径。
2. 一次只推进一个 TASK。
3. 每个 TASK 先补测试、验证脚本或核验文档，再动实现。
4. 如果某能力尚未真正闭环，优先降级文档、help、启动文案和对外承诺。
5. 不用 conversion quality 分数替代真实可用性验证。
6. 文档升级必须晚于或伴随真实实现核验。
7. 共享层问题优先于单格式局部抛光。
8. 质量提升任务必须建立在第一阶段收口结果之上。

## 5. 两阶段目标

### 第一阶段：真实性、可用性、自动化收口

目标：

- 让项目公开入口、文档承诺、测试自动化和外部依赖边界一致

预期收益：

- 大幅减少“文档说支持、实际不可用”的问题
- CLI、MCP、OCR 的失败模式更可预测
- 后续质量优化不再被能力边界不清拖累

### 第二阶段：转换质量持续提升

目标：

- 在第一阶段建立可信基线后，继续提升 Archive、Web、PDF/OCR 和轻结构文本簇的真实转换效果

预期收益：

- 提升复杂输入的结构恢复稳定性
- 减少依赖样本偶然匹配的高分
- 让 quality 改进与 integration/CLI/MCP 能力状态同步演进

## 6. 第一阶段任务列表

### TASK-001：全面扫描 placeholder / TODO / 半实现路径

目标：

- 盘点仓库里所有“看起来像实现了、但实际未完成或无闭环验证”的路径。

重点范围：

- `src/mcp/`
- `src/capabilities/ocr/`
- `src/engine/`
- `src/formats/`
- `cmd/`

建议产出：

- `docs/audit/placeholder_audit.md`

DoD：

- 全仓扫描完成
- 至少列出全部 `P0 / P1`
- [`src/mcp/transport/stdio.mbt`](/D:/MySoftware/MoonBitMark/src/mcp/transport/stdio.mbt) 的 `read_line()` 被明确标为 `P0`

### TASK-002：核验 MCP 最小可用闭环

目标：

- 验证 MCP server 是否真的能完成一次最小 STDIO 请求-响应。

建议产出：

- `tests/integration/mcp_stdio_smoke.ps1`
- 或 `tests/integration/mcp_stdio_smoke.py`
- `tests/integration/mcp/README.md`

DoD：

- 能稳定完成一次最小 MCP 请求-响应
- 或明确把 MCP 标为 `experimental`，并同步调整 README、MCP 文档、help 和启动文案

### TASK-003：建立 CLI 命令矩阵并逐项核验

目标：

- 把已公开暴露的 CLI 入口整理成矩阵，并按真实行为核验。

至少覆盖：

- `--help`
- 普通输入转输出
- `--detect-only`
- `--dump-ast`
- `--diag-json`
- `--ocr off|auto|force`
- `--ocr-lang`
- `--ocr-images`
- `--ocr-backend`
- `--ocr-timeout`
- 未知选项
- 缺失参数值
- 不兼容组合
- 不存在输入文件
- 不支持的扩展名
- 输出路径冲突

建议产出：

- `docs/audit/cli_matrix.md`

DoD：

- 所有公开参数被列出
- 每个参数至少有 1 个成功例和 1 个失败例（如适用）

### TASK-004：把 CLI 正向/负向路径纳入自动化

目标：

- 把 TASK-003 中最重要的 CLI 路径固化进自动化。

建议产出：

- `tests/cli/cli_smoke.ps1`
- `tests/cli/cli_negative.ps1`
- 更新 [`.github/workflows/ci.yml`](/D:/MySoftware/MoonBitMark/.github/workflows/ci.yml)

DoD：

- CI 中有 CLI smoke tests
- CI 中有 CLI negative tests
- negative tests 同时校验退出行为和错误关键字

### TASK-005：梳理并文档化外部依赖 / 子进程 / bridge 边界

目标：

- 把哪些能力是纯 MoonBit、哪些依赖外部脚本或子进程写清楚。

建议产出：

- `docs/architecture/external_dependencies.md`

DoD：

- README / AGENTS / OCR 文档对外部依赖边界说法一致
- 明确哪些能力是核心默认依赖、可选增强、实验能力

### TASK-006：收口 OCR 行为与错误诊断

目标：

- 把 OCR 从“有 bridge”提升为“行为可预期、失败可诊断”。

建议产出：

- `tests/ocr/ocr_backend_missing.ps1`
- `tests/ocr/ocr_force_smoke.ps1`
- `tests/ocr/ocr_timeout_smoke.ps1`

DoD：

- 成功、失败、backend 缺失三类路径都有稳定输出
- README 与 [`docs/features/ocr.md`](/D:/MySoftware/MoonBitMark/docs/features/ocr.md) 的口径和真实行为一致

### TASK-007：重整测试分层，区分“质量评估”与“功能存在性验证”

目标：

- 防止 `conversion_eval` 的高分掩盖功能未闭环。

建议产出：

- `docs/testing/test_layers.md`

至少分层：

- `quality`
- `integration`
- `cli`
- `ocr`
- `mcp`
- `baseline-comparison`

DoD：

- 每类测试目的清晰
- 不再把质量评测当成功能实现证明

### TASK-008：统一 README / AGENTS / help / MCP / OCR 文档

目标：

- 让所有入口看到的能力边界一致。

涉及：

- [`README.md`](/D:/MySoftware/MoonBitMark/README.md)
- [`AGENTS.md`](/D:/MySoftware/MoonBitMark/AGENTS.md)
- [`cmd/main/main.mbt`](/D:/MySoftware/MoonBitMark/cmd/main/main.mbt)
- [`cmd/mcp-server/main.mbt`](/D:/MySoftware/MoonBitMark/cmd/mcp-server/main.mbt)
- [`docs/features/mcp.md`](/D:/MySoftware/MoonBitMark/docs/features/mcp.md)
- [`docs/features/ocr.md`](/D:/MySoftware/MoonBitMark/docs/features/ocr.md)

DoD：

- 不再出现“文档说支持，但代码是占位/实验线”的错位表述

### TASK-009：工程化收口

目标：

- 把前面验证过的能力持续纳入自动化，并减少环境假设。

重点：

- 扩 CI：CLI、MCP、OCR 手动或自动验证入口
- 评估并恢复外部 baseline 对照能力
- 评估 [`moonpkg.json`](/D:/MySoftware/MoonBitMark/moonpkg.json) 的可配置性
- 明确 [`moon.mod.json`](/D:/MySoftware/MoonBitMark/moon.mod.json) 的包名策略

DoD：

- CI 覆盖命令面明显增强
- 构建环境假设更清晰
- 包身份说明明确

## 7. 第二阶段质量提升任务

第一阶段不是终点。若只停在 TASK-009，项目会更诚实、更稳定，但“转换效果继续提升”的目标仍不完整。因此，第一阶段完成后，进入以下质量任务。

### TASK-010：Archive 簇第二轮质量提升

目标：

- 继续提升 `DOCX / PPTX / XLSX / EPUB` 的结构恢复稳定性。

当前优先级依据：

- 最新评测里 `archive` 簇平均分为 `0.9687`
- 单格式里 `epub` 当前平均分为 `0.9197`，是已统计格式中最低的一组

优先顺序：

1. `EPUB`
2. `DOCX`
3. `XLSX`
4. `PPTX`

重点：

- `libzip + xml` 共享层收益最大化
- 标题、列表、资源关系、sheet/slide 组织和退化策略更稳

### TASK-011：HTML / URL 第二轮质量提升

目标：

- 从当前轻量结构恢复，继续提升正文抽取与复杂块级结构恢复。

当前优先级依据：

- `html` 当前平均分为 `0.9965`，说明主路径已强，但复杂 DOM 和失败诊断仍是下一轮可继续提升的高感知区域

重点：

- `list`
- `quote`
- `code`
- `table`
- `container nesting`
- URL 获取失败诊断与本地 HTML 解析诊断分离

### TASK-012：PDF 与 OCR 恢复路径提质

目标：

- 在不破坏当前 PDF 主路径的前提下，提升扫描件、极弱文本层和复杂结构页的恢复质量。

当前优先级依据：

- `pdf` 当前平均分为 `0.9990`，说明 PDF 主路径已强
- 因此这里不应优先做大拆重写，而应集中补 recovery path、复杂页专项样本和 OCR 介入质量

重点：

- page-level OCR fallback
- route / diagnostics 可信度
- 表格、代码、公式、双栏 case 的回归样本与专项验证

### TASK-013：轻结构文本簇收尾提质

目标：

- 继续完善 `CSV / JSON / TXT` 的退化策略和可读性。

重点：

- CSV dialect 与 ragged row 退化
- JSON pretty-print 与 metadata/code block 边界
- TXT BOM、空白和段落切分

## 8. 推荐执行顺序

推荐按下面顺序推进，不建议跳步：

1. `TASK-001`
2. `TASK-002`
3. `TASK-003`
4. `TASK-004`
5. `TASK-005`
6. `TASK-006`
7. `TASK-007`
8. `TASK-008`
9. `TASK-009`
10. `TASK-010`
11. `TASK-011`
12. `TASK-012`
13. `TASK-013`

排序理由：

- `TASK-001 ~ TASK-009` 先解决真实性、能力边界、自动化和文档错位
- `TASK-010 ~ TASK-013` 再在可信基线上推进转换质量

这个顺序执行后，既能明显收敛当前项目存在的问题，也能继续拉高真实可用性和转换效果。

## 9. 为什么这套方案能明显改善项目

### 9.1 对可用性的改善

第一阶段会直接改善：

- MCP 假入口问题
- CLI 参数暴露面与自动化脱节问题
- OCR 外部依赖不透明问题
- 文档承诺高于实现成熟度的问题

这些问题一旦收口，项目对用户、AI agent 和后续开发者都会更可预测。

### 9.2 对转换效果的改善

第二阶段会继续针对最影响实际输出质量的方向推进：

- Archive 簇复杂结构恢复
- HTML 正文抽取与块级结构
- PDF 恢复路径与复杂页
- 轻结构文本退化策略

这部分不是泛泛地“继续提分”，而是针对当前项目里最可能继续产生实质质量收益的方向。

### 9.3 对长期维护的改善

两阶段串联后，项目会得到：

- 更可信的公开能力边界
- 更完整的测试分层
- 更稳定的 CI 与命令面验证
- 更少的“高分但不可用”或“可用但文档说不清”的维护成本

## 10. 每个 TASK 的固定交付格式

每次只交付一个 TASK，并固定输出这 6 项：

1. 改了哪些文件
2. 新增了哪些测试或脚本
3. 如何验证
4. 发现了哪些未解问题
5. 风险和回归点
6. 下一任务是否已解锁

## 11. 一句话总指令

先消灭“看起来实现了但其实没实现”的路径，再扩大自动化验证面，最后在可信基线上继续提升转换质量；不要优先做新功能，不要用 quality 分数代替真实可用性验证。
