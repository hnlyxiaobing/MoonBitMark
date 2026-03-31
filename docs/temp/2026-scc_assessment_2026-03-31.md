# MoonBitMark 参赛收尾评估报告

日期：2026-03-31

## 1. 结论先行

基于当前仓库状态，我的判断是：

- MoonBitMark 已经具备很强的“工程底盘”，不是勉强参赛的半成品。
- 如果今天直接按当前状态去交，较大概率能进入“通过验收/优秀作品候选”区间。
- 但如果目标是冲击特等奖，当前最大短板已经不是转换能力本身，而是四个等权维度里最容易丢分的两项：
  - 可解释性
  - 用户体验

更直白地说：代码和评测已经接近高分项目，但“面向评委的答卷包装”还没有完成。

按比赛页面公开规则，滚动验收看四个 25% 维度：完成度、工程质量、可解释性、用户体验；线下答辩还会进一步看“解决实际应用问题、完整用户体验、充分利用 MoonBit 特性、结合领域知识”。在这套规则下，MoonBitMark 当前最危险的地方不是少一个格式，而是：

1. 缺少一套面向比赛的主叙事。
2. 缺少一套让评委 5 分钟内看懂并跑起来的体验闭环。
3. 缺少把 MoonBit 优势、AI-native 开发过程、工程取舍讲透的材料。

我的综合判断：

- 当前状态：强工程项目，已具备高分基础。
- 当前风险：总分会被“文档解释力 + 体验包装”明显拉低。
- 冲刺特等奖的关键：不是继续铺大功能面，而是用 2 到 3 轮高质量收尾，把“好代码”变成“好答卷”。

## 2. 比赛要求拆解

依据比赛页面 `https://www.moonbitlang.cn/2026-scc`：

- 最终验收截止日期：2026 年 4 月 21 日
- 统一答辩与优秀作品评选：2026 年 4 月 27 日（暂定）
- 赛事建议规模：有效 MoonBit 代码量至少 10,000 行

滚动验收四个等权维度：

1. 完成度评估（25%）
2. 工程质量评估（25%）
3. 可解释性评估（25%）
4. 用户体验评估（25%）

线下答辩优秀作品还会额外看：

1. 解决实际应用问题
2. 提供完整用户体验
3. 充分利用 MoonBit 语言特性
4. 结合领域特定知识和实际需求

这意味着评审逻辑不是“代码强就行”，而是“代码、说明、体验、定位”一起打分。

## 3. 当前项目快照

截至 2026-03-31，我核对到的仓库事实如下：

- 项目定位：MoonBit 文档转 Markdown 引擎，主入口是 CLI，另有实验性 MCP STDIO 入口
- 输入类型：TXT、CSV、JSON、PDF、图片、HTML/XHTML/URL、DOCX、PPTX、XLSX、EPUB
- MoonBit 代码规模：
  - source files：55
  - source lines：20296
  - test files：27
  - test lines：2599
  - total `.mbt`：82 files / 22895 lines
- Git 提交数：140
- GitHub 远程仓库已配置：`https://github.com/hnlyxiaobing/MoonBitMark.git`

本地验证结果：

- `moon check`：通过
- `moon test`：165/165 通过
- `moon build --target native --release`：通过

质量评测结果：

- `tests/conversion_eval/reports/latest/summary.md`
- 结果：34/34 通过，平均分 0.9983

当前真实边界：

- OCR 不是纯 MoonBit 内建能力，依赖 `scripts/ocr/bridge.py`
- PDF fallback 可能依赖 `scripts/pdf/bridge.py`
- MCP 目前只是实验性 STDIO 最小闭环
- Windows native 构建依赖 MSVC

## 4. 四个维度的现状评估

以下分数是基于当前仓库证据的主观估算，用来指导收尾优先级，不是官方评分。

| 维度 | 当前判断 | 估算区间 | 说明 |
| --- | --- | ---: | --- |
| 完成度 | 强 | 22-24 / 25 | 主功能已成型，构建/测试/评测链条成立 |
| 工程质量 | 强但还没打磨到“答辩级” | 20-22 / 25 | 架构清晰、测试扎实，但仍有 warning、口径漂移和若干边界债务 |
| 可解释性 | 当前最弱 | 12-16 / 25 | 缺比赛导向的开发历程、AI 使用说明、架构取舍文章 |
| 用户体验 | 中等偏上，但不够完整 | 14-18 / 25 | CLI 已能用，但新用户/评委/AI agent 的体验闭环还没包装好 |

结论：

- MoonBitMark 现在不是“不能打”，而是“打得还不够像特等奖答卷”。
- 如果只看工程完成度，项目已经很强。
- 如果按比赛四项等权来算，当前真正拖分的是解释力和体验，而这两项恰好各占 25%。

## 5. 已经具备冲高分的硬实力

### 5.1 功能完成度已经不是主要问题

当前项目已经满足比赛推荐方向中的“文档 / PDF 处理引擎”范畴，而且不是单格式 demo，而是一个多格式统一引擎：

- 10 类输入格式
- 统一 `engine -> converter -> result` 主链路
- CLI 主入口可直接跑
- 实验性 MCP 入口已存在
- OCR / PDF fallback 边界有明确说明，不是伪装成“纯原生能力”

这类项目体量和结构，明显高于“只有一个功能点的比赛作业”。

### 5.2 工程结构有明显优势

当前仓库最有竞争力的部分其实不是格式列表，而是工程组织方式：

- `src/engine/` 负责统一调度
- `src/core/` 负责统一结果协议、diagnostics、stats、context
- `src/ast/` 负责统一 Markdown 输出
- `src/libzip/` 与 `src/xml/` 是长期可复用的纯 MoonBit 基础设施
- `src/formats/` 按格式分包，边界清晰

这种结构很符合比赛页面强调的“可复用、可演进、可持续的软件工程流程”。

### 5.3 测试和评测证据很扎实

目前最有说服力的几条证据：

- `moon test` 165/165 通过
- `conversion_eval` 34/34 通过，平均分 0.9983
- CI 覆盖了 Linux/macOS 源码级检查，以及 Windows native build + CLI/OCR/MCP smoke

这意味着项目不只是“能跑一次”，而是已经具备较成熟的验证体系。

### 5.4 MoonBit 特性其实已经被用出来了，只是还没讲出来

从代码结构看，项目已经体现出不少 MoonBit 价值：

- 包级组织清楚
- `raise` / 结构化 error path 的使用比较稳定
- 共享 AST 与共享 diagnostics 协议清晰
- 纯 MoonBit 的 `libzip + xml` 为 Office/EPUB 提供基础设施
- native build 路径清楚

问题不在于“没用到 MoonBit”，而在于“这些点还没有被面向评委组织成明确论证”。

## 6. 冲击特等奖的主要不足

### 6.1 最大短板：比赛导向的可解释性材料缺失

这是当前最需要正视的问题。

比赛明确要求提交开发历程文章，并说明：

- 关键架构决策
- AI 工具在开发过程中的作用
- 对既有开源工作的借鉴与取舍

但当前仓库主线材料里，这部分基本是缺位的。

我检索后看到的现状是：

- `README.md` 只有约 288 个英文单词
- 主文档主要是“能力与边界说明”
- 没有一份正式的开发历程/复盘文章
- 没有一份系统讲 AI 工具如何参与开发的主文档
- 没有一份面向评委的“为什么这样设计”的架构决策说明

这会直接导致两个问题：

1. 评委需要自己从代码和零散文档里拼答案。
2. 项目的 AI-native 特征无法转化为分数。

对 MoonBitMark 来说，这一项不是“可以以后再补”的文案问题，而是当前最可能把总分从高位拉下来的主风险。

### 6.2 第二短板：用户体验没有被包装成完整闭环

CLI 已经不差，但比赛看的是“完整用户体验”，而不是“开发者知道怎么跑”。

当前体验层的主要问题：

- `README.md` 没有形成清晰的 5 分钟上手路径
- 缺少“给评委直接运行”的最短 demo 流程
- 缺少输入样例 -> 输出结果 -> diagnostics 的连贯展示
- 缺少“给 AI agent 用”的明确 cookbook
- MCP 放在定位里，但当前仍是实验性最小闭环，容易分散主叙事

换句话说，项目已经具备可用性，但还没有被包装成“非常好验证、非常好理解、非常好演示”的答辩材料。

### 6.3 第三短板：主文档存在口径漂移，会伤害可信度

这是一个很具体、也很应该优先修掉的问题。

当前我核对到的文档漂移：

- `README.md` 仍写着旧的质量结果：`29/29`、平均分 `0.9964`
- `docs/benchmark.md` 写的是 `33/33`
- 但最新 `tests/conversion_eval/reports/latest/summary.md` 已经是 `34/34`、平均分 `0.9983`

这类不一致会产生很差的外部观感：

- 项目到底哪个数字是真的？
- 文档是不是没跟上代码？
- 评委还能不能信后面其他叙述？

对于比赛答卷，文档自洽本身就是工程质量和可解释性的一部分。

### 6.4 第四短板：工程质量还差最后一轮“答辩级清理”

当前工程质量已经不错，但还没完全到“拿去答辩就很体面”的程度。

`moon check` 虽然通过，但仍有 16 条 warning，主要集中在：

- `src/formats/pdf/model.mbt`
- `src/formats/pdf/normalize.mbt`
- `src/formats/pdf/structure.mbt`
- `src/mcp/types/json_parser.mbt`

其中包括：

- 未使用的 enum variant / field / function
- 一处 deprecated API：`@strconv.parse_int`

这类问题不会让项目失效，但会让工程质量从“强”掉到“还差一口气”。

对特等奖项目来说，建议尽量做到：

- 主验证链路全绿
- warning 尽量清零
- deprecated 调用清掉
- 公开能力和文档口径完全一致

### 6.5 第五短板：项目定位还不够聚焦到“真实问题”

比赛答辩阶段会看“解决实际应用问题”。

MoonBitMark 当前的问题不是没有应用价值，而是主文案还停留在“我是一个多格式转换器”。

这还不够强。

更有竞争力的讲法应该是：

- 我解决的是 AI-native 工具链中的文档摄取问题
- 我提供的是一个低依赖、可原生分发、可诊断、可逐步 agent 化的转换引擎
- 我针对的是“想要把文档变成稳定 Markdown 资产，但又不想引入重型 Python/ML 运行时”的场景

如果这个“真实问题定义”不被明确写出来，评委就会把项目理解成“又一个转换器”，而不是“MoonBit 生态里有长期价值的系统软件”。

### 6.6 第六短板：MoonBit 优势没有被显式转化成比赛语言

当前代码里已经有 MoonBit 优势，但还没被翻译成评审语言。

评委更想看到的不是“我用了 MoonBit”，而是：

- 为什么这个问题适合用 MoonBit 做
- MoonBit 在模块组织、错误处理、native build、共享基础设施上带来了什么
- 为什么 `libzip + xml + diagnostics + native CLI` 这个组合在 MoonBit 里有工程意义

如果这些点不被专门写出来，评委只能自己猜。

### 6.7 第七短板：MCP 是亮点，但现在更容易成为“干扰项”

MCP 方向是有潜力的，但当前状态必须如实表述：

- 只有 STDIO
- 只验证了 `initialize` / `tools/list` / `tools/call`
- 没有 HTTP/SSE
- 没有 prompts/resources
- 没有 streaming

因此现在更合理的策略不是把 MCP 讲成成熟能力，而是讲成：

- 已经有 agent-facing 原型
- 核心价值在于统一结果协议和结构化 diagnostics
- 后续可演进，但当前比赛交付仍以 CLI 主路径为核心

如果把 MCP 放得过重，反而会让评委追问一堆当前尚未成熟的协议细节。

## 7. 目前最值得强调的亮点

为了后续收尾，我建议你在所有比赛材料里反复强调以下 5 个亮点：

1. 这是一个系统级文档处理引擎，不是单点脚本。
2. 核心转换主链轻量，且具备 native build 能力。
3. `libzip + xml` 是纯 MoonBit 基础设施，具备长期复用价值。
4. `ConvertResult + ConversionDiagnostic` 的结构化协议很适合 CLI、自动化和 agent 消费。
5. 项目已经有真实验证体系，不是“看起来能跑”。

这 5 点是 MoonBitMark 冲高分最应该放大的地方。

## 8. 收尾优先级建议

### P0：必须优先做，不做会明显影响成绩

#### P0-1. 写一套比赛专用主文档

建议补至少三份文档：

1. `README.md` 重写
2. `docs/competition/dev-retrospective.md`
3. `docs/competition/moonbit-advantages.md`

这三份文档分别回答：

- 这项目是什么，怎么跑，为什么有价值
- 你是怎么做出来的，AI 工具如何参与，做了哪些关键取舍
- 为什么这个题目适合用 MoonBit 做，项目如何体现 MoonBit 优势

#### P0-2. 把所有指标、口径、边界同步到最新

至少要同步：

- `README.md`
- `docs/benchmark.md`
- `docs/KNOWN_ISSUES.md`
- 其他引用旧评测数字的文档

要求是：

- 所有质量数字统一
- 所有能力边界统一
- 所有“实验性”表述统一

#### P0-3. 做一个“评委 5 分钟验收路径”

建议在 README 顶部直接给出：

1. 安装/构建
2. 运行 1 个最代表性的输入
3. 查看 Markdown 输出
4. 查看 `--diag-json`
5. 可选再展示 1 个 OCR/PDF case

目标不是覆盖所有能力，而是让评委在最短时间内建立信任。

### P1：强烈建议做，会显著提升特等奖竞争力

#### P1-1. 把 warning 和 deprecated 调用清掉

建议把 `moon check` 尽量打磨到接近 warning-free。

这类工作虽然不性感，但对答辩印象非常关键。

#### P1-2. 给 AI agent / MCP / CLI 各做一个标准示例

建议至少准备三条标准使用路径：

- 人类用户：CLI 最短使用示例
- 工程用户：`--diag-json` / `--dump-ast` 示例
- AI agent：最小 MCP `tools/call` 示例

这样能把“用户体验”从抽象概念变成可演示材料。

#### P1-3. 做 3 到 5 个代表性案例页

建议挑最能体现优势的样例：

- Office 文档
- HTML/URL
- PDF
- 扫描图像/OCR

每个案例只展示：

- 输入
- 输出摘要
- 为什么这个结果有价值
- diagnostics / metadata 能带来什么工程收益

这会比堆更多格式更有说服力。

#### P1-4. 准备一份“与主流工具相比，我的取舍是什么”

不需要夸张，不要写成“全面超越”。

只要把这几点讲清楚就够：

- 我不走重型 ML 路线
- 我强调 native/轻依赖/可诊断
- 我把 OCR 和 PDF fallback 诚实地放在可选 bridge 能力上
- 我在 MoonBit 生态里提供了长期资产，而不是一次性 demo

### P2：可以做，但不要抢主线资源

- 扩 HTTP/SSE MCP
- 继续铺更多输入格式
- 追求复杂 PDF 公式识别
- 做 GUI 主线化
- 追求“大而全”的 AI 平台叙事

这些方向并非没价值，但它们对 2026-04-21 提交的边际收益，不如把文档、演示、warning 清理和体验闭环做好。

## 9. 一个更合理的比赛定位

我建议你在后续材料里，把 MoonBitMark 的定位统一成下面这句话：

> MoonBitMark 是一个以 MoonBit 实现的文档转 Markdown 引擎，强调轻依赖、原生分发、结构化诊断和可演进的 agent/tooling 接口，面向 AI-native 工具链中的文档摄取与规范化场景。

这个定位的好处是：

- 比“多格式转换器”更有工程价值
- 比“全面对标 Docling/Marker”更真实
- 能把 MoonBit、native、diagnostics、MCP 潜力串起来
- 不会因为 OCR / 深度布局理解还没做满而自我设坑

## 10. 最后判断

如果目标只是顺利交付，MoonBitMark 现在已经比较稳。

如果目标是冲击特等奖，我的判断是：

- 底盘已经够了。
- 最缺的不是新功能，而是“比赛化收尾”。

当前最该做的三件事：

1. 把比赛主叙事写出来。
2. 把体验闭环做出来。
3. 把文档口径和工程细节打磨到答辩级。

只要这三件事做到位，MoonBitMark 就会从“工程很强的项目”升级成“很像特等奖答案的项目”。

## 11. 本报告使用的主要证据

比赛规则：

- `https://www.moonbitlang.cn/2026-scc`

仓库材料：

- `README.md`
- `docs/architecture.md`
- `docs/architecture/external_dependencies.md`
- `docs/testing/test_layers.md`
- `docs/benchmark.md`
- `docs/features/mcp.md`
- `docs/features/ocr.md`
- `docs/KNOWN_ISSUES.md`
- `tests/conversion_eval/reports/latest/summary.md`
- `.github/workflows/ci.yml`

本地验证：

- `moon check`
- `moon test`
- `moon build --target native --release`
- `scripts/count_moonbit_loc.ps1`
