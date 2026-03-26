# MoonBitMark 文档转 Markdown 执行开发文档

> 编写日期：2026-03-26  
> 对应上层依据：`docs/temp/research-doc-to-markdown-2026-03-26.md`  
> 文档目的：把“方向性调研结论”细化成可直接进入开发排期和实施的执行文档

---

## 1. 文档定位

本文档不是新的调研报告，而是 MoonBitMark 下一轮开发的**执行说明书**。

它只回答 6 个问题：

1. 先做什么，后做什么
2. 每个任务改哪些文件
3. 每个任务先补什么测试或样例
4. 做到什么算完成
5. 用什么命令验证
6. 哪些事项不要现在做

如果本文件与代码现状冲突，以代码、测试和最新仓库文档为准，再回改本文件。

---

## 2. 适用范围与非目标

### 2.1 本轮适用范围

本轮执行范围只覆盖以下主题：

- Markdown 输出正确性
- AST 表达能力补强
- PDF 扫描件 recovery path
- PPTX 结构恢复深化
- CLI / `--dump-ast` / diagnostics 契约清晰化
- conversion eval 样本补强
- native 分发与 MCP 稳定化的前置收口

### 2.2 本轮明确非目标

以下事项不进入本轮主线：

- 音频 / 视频 / 字幕格式支持
- 全量 AI 框架生态接入
- HTTP / SSE MCP transport 立即扩张
- LaTeX 输入支持
- Markdown 逆向转换成其他格式
- 大规模 UI / DX 包装层优化

这些方向可以保留在长期路线图，但不能挤占当前主线资源。

---

## 3. 本轮执行原则

后续开发统一遵守以下规则：

1. 先修**正确性 bug**，再做“能力增强”。
2. 先补**可复现证据**，再下技术结论。
3. 先补**共享层瓶颈**，再做单格式抛光。
4. 先补**测试与样例**，再改实现。
5. 不用 conversion eval 高分替代真实能力闭环。
6. 文档、CLI help、tests、实现四者必须同步更新。
7. 每个任务完成后都要给出“完成定义”和“未完成边界”。

---

## 4. 开发批次总览

| 批次 | 目标 | 是否阻塞后续 |
|------|------|-------------|
| Batch 0 | 建立证据与任务基线 | 是 |
| Batch 1 | 修复 Markdown 正确性与 CLI 契约问题 | 是 |
| Batch 2 | 提升共享 AST 表达能力 | 是 |
| Batch 3 | 打通 PDF 扫描 recovery path | 否 |
| Batch 4 | 深化 PPTX 结构恢复 | 否 |
| Batch 5 | 样本、分发、MCP 稳定化收口 | 否 |

推荐顺序必须保持为：

1. Batch 0
2. Batch 1
3. Batch 2
4. Batch 3
5. Batch 4
6. Batch 5

---

## 5. Batch 0：建立证据与任务基线

### EXEC-00A：冻结当前基线结论

**目标**

- 把后续开发依赖的关键事实固定下来，避免任务推进过程中口径漂移。

**主要文件**

- `docs/temp/research-doc-to-markdown-2026-03-26.md`
- `docs/KNOWN_ISSUES.md`
- `docs/features/ocr.md`
- `docs/features/mcp.md`
- `tests/conversion_eval/reports/latest/summary.md`

**实施步骤**

1. 复核当前报告中的 P0 / P1 结论是否都有仓库依据。
2. 对“已确认缺陷”和“待复核风险”分别标注。
3. 确认当前最新 conversion eval 摘要、OCR 边界、MCP 成熟度说明一致。

**完成定义**

- 报告、已知问题文档、特性文档之间不存在直接冲突
- 后续开发任务引用的事实都能在仓库中找到证据

**验证**

- 人工 review
- `rg -n "Dynamic Huffman|dump-ast|OCR|MCP|escape_markdown_text" docs src tests`

---

### EXEC-00B：补齐最小任务样例清单

**目标**

- 为 Batch 1 到 Batch 4 提前准备样例入口，避免改实现时才发现没有验收样本。

**主要文件**

- `tests/conversion_eval/cases/`
- `tests/conversion_eval/fixtures/inputs/`
- `tests/conversion_eval/fixtures/expected/markdown/`
- `tests/conversion_eval/fixtures/expected/ast/`

**实施步骤**

1. 列出当前已覆盖的 Markdown 特殊字符、扫描 PDF、PPTX、AST-rich list/table 样例。
2. 为缺口建立待新增样例清单。
3. 明确哪些样例用 wbtest，哪些进入 conversion eval。

**完成定义**

- 至少形成一份新增样例待办表
- 后续每个开发任务都能映射到明确测试入口

**验证**

- `Get-ChildItem tests\\conversion_eval\\cases -Recurse`
- `rg -n "pdf_blank_scanned_mock_ocr|pptx|table|ast" tests\\conversion_eval src`

---

## 6. Batch 1：修复 Markdown 正确性与 CLI 契约

### EXEC-01：实现 Markdown 特殊字符转义

**优先级**

- P0

**目标**

- 修复 `escape_markdown_text()` 为空实现导致的 Markdown 渲染破坏问题。

**主要文件**

- `src/ast/renderer.mbt`
- `src/ast/ast_test.mbt`
- 如有必要：新增 `src/ast/renderer_test.mbt`
- 如有必要：补充 `tests/conversion_eval/cases/regression/`

**实施步骤**

1. 先定义转义范围：
   - 标题/段落普通文本
   - 列表项文本
   - 表格单元格文本
   - link label / code span 保持现有专门处理
2. 明确不做“过度转义”，避免把正常 Markdown 输出全部降级成纯文本。
3. 先补测试，再实现 renderer。
4. 必要时按上下文拆分 `escape_markdown_text` 与 `escape_table_cell` 的职责。

**至少补的测试**

- 标题中包含 `#`、`*`、`_`
- 段落中包含 `` ` ``、`[`、`]`
- 列表项中包含强调符号
- 表格单元格中同时包含换行和 Markdown 特殊字符

**完成定义**

- `escape_markdown_text()` 不再为空实现
- 新增测试能覆盖主要 Markdown 特殊字符场景
- 现有 renderer 行为未对 code block / inline code / image / link 造成回归

**验证命令**

```powershell
moon test src/ast
moon test
moon fmt
moon info
```

**风险**

- 过度转义导致现有 golden markdown 大量变化
- 不同上下文共用一套转义逻辑可能引入误伤

---

### EXEC-02：澄清 Dynamic Huffman 兼容性状态

**优先级**

- P0

**目标**

- 用可复现 fixture 证明 Dynamic Huffman 问题是否仍然存在，而不是继续沿用旧结论。

**主要文件**

- `src/libzip/deflate.mbt`
- `src/libzip/zip_easy_test.mbt`
- 如有必要：`tests/conversion_eval/fixtures/inputs/pptx/`
- 如有必要：`tests/conversion_eval/cases/quality/` 或 `regression/`
- `docs/KNOWN_ISSUES.md`

**实施步骤**

1. 先找一个能稳定复现的 PPTX/ZIP 样例。
2. 把该样例最小化到能定位 deflate dynamic Huffman 路径。
3. 新增单元/集成测试，确保能稳定复现。
4. 再决定是修实现，还是清理过期文档结论。

**完成定义**

- 要么得到可稳定复现的 failing fixture
- 要么证明当前实现已通过该类样例，并回收过期“已知问题”口径

**验证命令**

```powershell
moon test src/libzip
moon test src/formats/pptx
moon test
```

**风险**

- 如果没有最小复现样例，任务会长期停留在“怀疑但不可验证”状态

---

### EXEC-03：明确 `--dump-ast` 的机器消费契约

**优先级**

- P1

**目标**

- 解决 CLI 参数名与实际输出语义不一致的问题。

**主要文件**

- `cmd/main/main.mbt`
- `cmd/main/main_wbtest.mbt`
- `tests/cli/cli_smoke.ps1`
- `docs/audit/cli_matrix.md`
- `docs/temp/research-doc-to-markdown-2026-03-26.md`

**实施步骤**

1. 在两条路线中二选一：
   - 保留现有输出，文档明确它是 MoonBit AST 表示
   - 新增 strict JSON AST 输出，并给机器消费使用
2. 同步更新 CLI 文案、测试和文档。
3. 如果新增 strict JSON，确保与 `diagnostics json` 的编码风格一致。

**完成定义**

- 用户看到的 `--dump-ast` 行为与文档完全一致
- CLI smoke test 对该行为有稳定断言

**验证命令**

```powershell
moon test cmd/main
powershell -File tests/cli/cli_smoke.ps1
powershell -File tests/cli/cli_negative.ps1
```

**风险**

- 改参数语义可能影响现有脚本调用

---

## 7. Batch 2：提升共享 AST 表达能力

### EXEC-04：让 `List/Table` 可承载 rich inline

**优先级**

- P1

**目标**

- 把 AST 中 `List/Table` 的纯字符串容器升级为可承载 inline-rich 内容的结构，消除共享层上限。

**主要文件**

- `src/ast/types.mbt`
- `src/ast/renderer.mbt`
- `src/ast/markdownish.mbt`
- `src/ast/ast_test.mbt`
- `src/formats/html/converter.mbt`
- `src/formats/docx/converter.mbt`
- `src/formats/xlsx/converter.mbt`
- `src/formats/pdf/structure.mbt`
- 对应 test / wbtest 文件

**实施步骤**

1. 先定新 AST 形状，再开始逐格式迁移。
2. 先改 renderer 和 AST 测试。
3. 按影响面从大到小迁移 converter：
   - HTML
   - DOCX
   - XLSX
   - PDF
   - 其他依赖 `List/Table` 的格式
4. 只要格式暂时无法产出 rich inline，也要保证能平滑适配新结构。

**建议新测试场景**

- 列表项内含 `Strong`
- 列表项内含 `Link`
- 表格单元格内含 `Code`
- 表格单元格内含多段 inline 混合

**完成定义**

- AST 类型完成升级
- renderer 可稳定输出 rich inline list/table
- 至少 HTML 与 DOCX 两条主要 rich inline 来源完成适配
- 现有字符串型 list/table 输出不回退

**验证命令**

```powershell
moon test src/ast
moon test src/formats/html
moon test src/formats/docx
moon test src/formats/xlsx
moon test src/formats/pdf
moon test
moon fmt
moon info
```

**风险**

- AST 改动面大，容易引发跨格式回归
- `pkg.generated.mbti` 可能发生预期内变化，需要明确 review

---

## 8. Batch 3：打通 PDF 扫描件 recovery path

### EXEC-05：把扫描 PDF 从“只有 diagnostics”提升到“可产出正文”

**优先级**

- P1

**目标**

- 建立扫描 PDF 的最小可用 recovery path：检测、触发 OCR、恢复正文、保留 diagnostics。

**主要文件**

- `src/formats/pdf/converter.mbt`
- `src/formats/pdf/route.mbt`
- `src/formats/pdf/extract_native.mbt`
- `src/formats/pdf/extract_bridge.mbt`
- `src/formats/pdf/structure.mbt`
- `src/formats/pdf/diagnostics.mbt`
- `tests/conversion_eval/cases/regression/pdf_blank_scanned_mock_ocr.case.json`
- `tests/ocr/`
- 如有必要：新增 PDF regression case

**实施步骤**

1. 明确触发条件：
   - 空文本层
   - 极弱文本层
   - route 识别为 scanned
2. 先在 mock OCR 路径打通最小闭环。
3. 保留 route diagnostics，不能因为 recovery path 成功就丢失“这是恢复路径”的事实。
4. 将正文恢复和 diagnostics 输出同时纳入验收。

**完成定义**

- 扫描 PDF 在 mock OCR 下能稳定产出正文
- diagnostics 能明确说明是否进入 recovery path
- 缺 backend、timeout、OCR unavailable 时仍保持可诊断行为

**验证命令**

```powershell
moon test src/formats/pdf
powershell -File tests/ocr/ocr_force_smoke.ps1
powershell -File tests/ocr/ocr_backend_missing.ps1
powershell -File tests/ocr/ocr_timeout_smoke.ps1
python tests/conversion_eval/scripts/run_eval.py run
```

**风险**

- OCR recovery path 可能污染当前文字型 PDF 主路径
- 需要避免把“扫描识别失败”误判为“转换成功”

---

## 9. Batch 4：深化 PPTX 结构恢复

> 当前状态（2026-03-26）：
> `EXEC-06` 已完成第一轮收口。PPTX 已补齐 `notes`、`table`、`chart`、显式编号列表、grouped shape 文本顺序；`tests/conversion_eval/cases/quality/pptx_notes_chart_semantics.case.json` 已进入自动化，当前 conversion eval 为 32/32 通过。

### EXEC-06：把 PPTX 从文本提取提升到基础结构恢复

**优先级**

- P1

**目标**

- 在不重写整条 PPTX 路线的前提下，补齐最有价值的结构信息。

**主要文件**

- `src/formats/pptx/converter.mbt`
- `src/formats/pptx/parser.mbt`
- `src/formats/pptx/slide.mbt`
- `src/formats/pptx/converter_test.mbt`
- `src/formats/pptx/converter_wbtest.mbt`
- `tests/conversion_eval/cases/quality/pptx_quarterly_review.case.json`
- `tests/conversion_eval/cases/quality/pptx_powerpoint_with_image.case.json`
- 如有必要：新增 PPTX fixture 与 case

**实施步骤**

1. 先去掉重复的 namespace prefix stripping 实现。
2. 明确本轮主收口做 3 类结构：
   - notes
   - table
   - 更稳健的 shape 文本提取
3. 如果样例里能稳定取得图表文本，则一并纳入本轮。
4. 对无法恢复的结构补 warning/diagnostics，而不是静默丢失。

**完成定义**

- `notes`、`table` 至少有一种 fixture 进入自动化
- PPTX 输出不再只依赖 title/body 纯文本抽取
- 重复实现已合并

**本轮实际收口结果**

- 已进入自动化的 PPTX 结构样例包括：content placeholder list、table、speaker notes、chart、显式 auto numbering、grouped shape
- `tests/conversion_eval/cases/quality/pptx_notes_chart_semantics.case.json` 已覆盖 notes + chart + shape 组合场景
- 后续剩余边界已收敛到 SmartArt、连接线、复杂 chart 组件、notes master 等更深层对象语义

**验证命令**

```powershell
moon test src/formats/pptx
python tests/conversion_eval/scripts/run_eval.py run
```

**风险**

- 结构深化容易引入顺序错乱
- notes 与主 slide 内容的合并策略需要提前定义

---

## 10. Batch 5：样本、分发、MCP 稳定化收口

> 当前状态（2026-03-26）：
> `EXEC-07`、`EXEC-08`、`EXEC-09` 已完成当前批次目标。conversion eval 新增回归样例后为 32/32；CI 已拆出 Linux/macOS 源码级校验与 Windows native release 校验；MCP STDIO 已补 `jsonrpc == "2.0"` 校验和 notification 无响应约束。

### EXEC-07：扩充 conversion eval 样本与失败归因

**优先级**

- P2

**目标**

- 让当前开发主线的每项改动都有对应样本，不依赖偶然高分。

**主要文件**

- `tests/conversion_eval/cases/`
- `tests/conversion_eval/fixtures/inputs/`
- `tests/conversion_eval/fixtures/expected/markdown/`
- `tests/conversion_eval/reports/latest/`

**实施步骤**

1. 新增以下类型样例：
   - Markdown 特殊字符
   - 扫描 PDF recovery
   - PPTX notes/table
   - rich inline list/table
2. 为新增样例写清楚 must include / must not include / golden markdown。
3. 若引入 strict AST JSON，再考虑扩 AST fixture。

**完成定义**

- 样本集不再明显偏向“当前已擅长场景”
- 每个本轮主任务至少对应 1 个 case

**当前已补样例**

- Markdown 特殊字符：`text_markdown_specials`
- 扫描 PDF recovery：`pdf_blank_scanned_mock_ocr`
- PPTX 结构恢复：`pptx_simple_lists`、`pptx_notes_chart_semantics`
- rich inline list/table：已通过 AST / HTML / DOCX / XLSX / PDF 路径用包级测试守护

**验证命令**

```powershell
python tests/conversion_eval/scripts/run_eval.py run
```

---

### EXEC-08：跨平台 native 分发前置收口

**优先级**

- P2

**目标**

- 为后续 Linux/macOS native 分发准备清晰的构建前提，而不是立即追求一次性全平台完成。

**主要文件**

- `moon.mod.json`
- `moonpkg.json`
- `scripts/build.bat`
- `.github/workflows/ci.yml`
- `docs/architecture/external_dependencies.md`

**实施步骤**

1. 明确当前哪些步骤硬依赖 Windows + MSVC。
2. 评估 MoonBit 在 Linux/macOS 上的构建前置条件。
3. 先把文档和 CI 预留点补齐，再决定是否本轮直接接入。

**完成定义**

- 跨平台构建前提被文档化
- 当前 Windows-only 假设不再是隐含规则

**验证**

- 人工 review
- CI 配置 review

---

### EXEC-09：MCP 先做 STDIO 契约硬化

**优先级**

- P2

**目标**

- 在不扩 transport 的前提下，把现有 STDIO MCP 做成可靠最小产品。

**主要文件**

- `cmd/mcp-server/main.mbt`
- `src/mcp/handler/server.mbt`
- `src/mcp/transport/stdio.mbt`
- `src/mcp/util/logger.mbt`
- `tests/integration/mcp_stdio_smoke.ps1`
- `docs/features/mcp.md`

**实施步骤**

1. 确认 stdout 只保留协议输出。
2. 确认 logger 不会污染 STDIO transport。
3. 固化 tool schema、错误输出和 smoke test。
4. 在以上稳定前，不引入 HTTP/SSE。

**完成定义**

- STDIO smoke test 稳定
- 文档对 MCP 的描述与实现成熟度完全一致
- 代码里不存在已知会污染协议流的日志输出路径

**验证命令**

```powershell
powershell -File tests/integration/mcp_stdio_smoke.ps1
moon test
```

---

## 11. 每个任务的固定交付格式

后续执行每个 EXEC 任务时，统一按以下格式提交结果：

1. 改了哪些文件
2. 为什么这样改
3. 新增了哪些测试 / fixture / case
4. 用什么命令验证
5. 哪些风险仍未关闭
6. 下一任务是否已解锁

如果一个任务无法完整关闭，必须明确写出：

- 卡在哪个前置条件
- 是否需要新样例
- 是否需要调整上层报告口径

---

## 12. 本轮推荐完成定义

当以下条件同时成立时，可以认为本轮主线开发完成：

1. `escape_markdown_text()` 不再为空，且有回归测试
2. Dynamic Huffman 状态不再模糊，要么有复现并修复，要么有证据证明旧结论过期
3. `--dump-ast` 契约明确，不再让用户误判
4. `List/Table` 已能承载 rich inline，至少主要来源格式已适配
5. 扫描 PDF 在 mock OCR 下能稳定产出正文
6. PPTX 至少补到 notes/table/shape 文本中的核心一批
7. conversion eval 新增了能覆盖本轮改动的样例
8. MCP 与跨平台分发的边界说明清晰，不再存在“默认看起来已成熟”的错觉

---

## 13. 一句话执行指令

先用样例和测试把事实钉住，再修 Markdown 正确性和共享 AST，再补扫描 PDF 与 PPTX 主能力，最后才做分发与 MCP 稳定化收口；不要反过来做。
