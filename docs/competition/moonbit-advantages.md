# 为什么这个项目适合用 MoonBit 做

MoonBitMark 不是“碰巧用 MoonBit 写出来”的项目。

这个题目之所以适合 MoonBit，核心原因在于它本质上是一个很强调工程结构、可演进性和原生分发的软件系统问题。

## 1. 这个题目需要的不是脚本语言快感，而是系统结构

文档转 Markdown 看上去像一个工具题，但真正做大之后，马上会遇到这些问题：

- 多格式输入如何共享结果协议
- 错误、warning、hint 怎么统一
- 多个 converter 如何保持一致行为
- 哪些能力是纯主链，哪些能力是 bridge-backed
- 怎么兼顾 CLI、测试、评测和 agent 工具面

这些问题都更像“系统软件工程”，而不是“单文件脚本处理”。

MoonBit 在这个题目上的优势，恰好不在“语法花哨”，而在：

- 包组织清楚
- 类型和错误边界清楚
- native build 路径明确
- 适合做长期演进的工程代码

## 2. MoonBit 的包结构很适合这个项目

MoonBitMark 的目录结构天然受益于 MoonBit 的 package 组织：

```text
src/
├── ast/
├── capabilities/
├── core/
├── engine/
├── formats/
├── libzip/
├── mcp/
└── xml/
```

这种组织方式带来的直接好处：

- 共享层和格式层边界很清楚
- 不同格式 converter 可以复用同一个结果协议
- 容易把“基础设施”和“业务路径”拆开

对一个要持续扩格式、扩能力、扩测试的项目来说，这比临时性脚本堆叠重要得多。

## 3. checked errors 和 diagnostics 很适合做“工程友好”的转换器

MoonBitMark 有一个很关键的设计点：

- 不只是“生成 Markdown”
- 还要生成结构化 diagnostics

这类设计和 MoonBit 的错误处理方式很契合。

项目里最终形成了这样的统一协议：

- `ConvertResult`
- `ConversionDiagnostic`
- `DiagnosticLevel`
- `ConversionPhase`
- `DiagnosticSource`
- `DiagnosticHint`

这让输出不只是“好看”，而是“可被自动化消费”。

这件事对比赛很重要，因为它体现的是软件系统思维，而不是简单结果导向。

## 4. 原生分发能力是 MoonBitMark 的重要支点

MoonBitMark 的一个重要目标，是让主路径尽量保持轻量，适合 native CLI 分发。

这和 MoonBit 的优势天然一致：

- 可以走 native build
- 不需要把整个项目变成重型解释器环境
- 适合做命令行工具和嵌入式调用组件

这里并不是说 MoonBitMark 完全没有外部依赖边界，而是说：

- 核心转换主链尽量轻
- bridge 能力明确收口
- 主路径和恢复路径分开表达

这正是 MoonBit 在工程实现上比较舒服的一种问题类型。

## 5. `libzip + xml` 这类基础设施特别适合在 MoonBit 里沉淀

MoonBitMark 里最有长期价值的部分之一，不是某个单独格式，而是：

- `src/libzip/`
- `src/xml/`

这两部分代表的是可以被重复利用的基础设施。

它们的意义在于：

- DOCX / PPTX / XLSX / EPUB 不再只是“各写各的解析器”
- 容器处理和结构提取能共享底座
- 项目会逐渐拥有自己的“生态资产”

这比单纯补更多 if/else 分支有价值，也更符合比赛对“MoonBit 生态奠基者”的预期。

## 6. MoonBit 让“主链清晰，边界诚实”更容易成立

MoonBitMark 当前明确区分了三层东西：

1. 纯 MoonBit 主链
2. 可选 bridge-backed recovery
3. 实验性 agent-facing 接口

这种边界感来自工程决策，也来自语言和工具链的约束帮助。

MoonBit 在这里的价值不是“替你决定产品方向”，而是让你更容易把系统做成：

- 模块清楚
- 结果清楚
- 边界清楚
- 可验证

## 7. 这也是一个很适合展示 MoonBit 生态潜力的题目

比赛强调的不只是能不能做出一个作品，还包括：

- 是否充分利用 MoonBit 语言特性
- 是否能成为 MoonBit 生态里的长期资产

MoonBitMark 在这两个点上都比较成立：

- 它不是展示语法特性的小项目，而是一个真实系统
- 它已经沉淀出 `libzip`、`xml`、diagnostics 协议、统一 engine 这些长期资产
- 它还有向 CLI / MCP / agent tooling 继续演进的空间

所以 MoonBit 在这里的意义，不是“能写”，而是“适合长期做”。

## 8. 一句话总结

如果要把这篇文档压缩成一句话：

> MoonBit 让 MoonBitMark 更容易成为一个主链轻量、结构清楚、可原生分发、具备长期生态价值的文档处理系统，而不只是一个短期可用的转换脚本集合。
