# MoonBitMark 开发复盘

这份文档面向 2026 MoonBit 软件合成挑战赛，说明 MoonBitMark 是如何从“做一个文档转换工具”逐步收敛成“一个有工程价值的 MoonBit 系统软件项目”的。

## 1. 为什么做这个项目

最初的问题不是“能不能把文档转成 Markdown”，而是一个更偏工程系统的问题：

- 文档来源很杂，既有 Office，也有网页、PDF、图片
- 下游消费方既可能是人，也可能是脚本、流水线或 AI agent
- 很多成熟方案依赖重型 Python/ML 运行时，集成成本高
- 很多工具只给最终文本，不给过程信息，失败时很难自动化处理

所以 MoonBitMark 从一开始就不是“追求支持最多格式”，而是优先解决下面三件事：

1. 用统一引擎处理多种输入
2. 暴露结构化 metadata 和 diagnostics
3. 保持主链路足够轻，适合 native 分发和工程集成

## 2. 关键架构取舍

### 2.1 统一主链路，而不是每种格式各自为政

项目最终收敛成了统一链路：

```text
input
  -> detect
  -> converter registry
  -> concrete converter
  -> AST / metadata / diagnostics
  -> Markdown renderer
```

这么做的原因很现实：

- 后续新增格式时，不需要重造一遍接口
- diagnostics、metadata、asset materialization 可以共享
- CLI 和 MCP 都可以复用同一个引擎结果协议

### 2.2 把 OCR 放进 capability 层，而不是塞进单个 converter

OCR 是一个横切能力，不只影响图片，也会影响 PDF、Office 内嵌图片等路径。

因此最终没有把 OCR 直接揉进各个 converter，而是把它放进 `src/capabilities/ocr/`，通过 `ConvertContext` 传入。

这样做的好处：

- 能力边界清楚
- 便于未来继续扩展
- 更容易把“可选 OCR”而不是“强制 OCR”表达清楚

### 2.3 把桥接能力诚实地当成边界，而不是包装成纯 MoonBit

项目里有两块能力不是纯 MoonBit 主链：

- OCR：`scripts/ocr/bridge.py`
- PDF fallback：`scripts/pdf/bridge.py`

这里的取舍是明确的：

- 能用纯 MoonBit 做的容器解析和结构恢复，优先用 MoonBit 做
- 需要借助外部生态的恢复路径，明确标成 bridge-backed
- 文档里如实写清楚，不做“全原生闭环”的误导性表述

这不是妥协，而是一种工程诚实。

## 3. 为什么项目最后长成现在这个样子

开发过程中最重要的一次转折，是从“按格式补功能”切换到“先把共享层做对”。

几个典型例子：

- `src/ast/` 统一 Markdown 渲染，而不是让 CSV / HTML / XLSX 各自拼输出
- `src/core/` 统一结果协议，而不是每个 converter 自己定义 warning 和 metadata
- `src/libzip/` 与 `src/xml/` 成为 Office / EPUB 路线的共享底座

这让项目从“多个小功能堆在一起”，变成了“一个可扩展的系统”。

## 4. AI 工具在开发过程中的角色

这个项目不是“AI 一次性生成”，而是一个典型的 AI-assisted engineering 流程。

AI 在项目里主要承担了四类工作：

### 4.1 快速生成初版实现

尤其适合：

- 样板代码
- 重复性转换逻辑
- 测试样例草稿
- 初版 CLI / diagnostics 输出骨架

### 4.2 帮助做结构重构

随着代码体量上升，AI 更有价值的地方不再是“写第一版”，而是：

- 帮助抽共享 helper
- 拆分大文件
- 保持包边界清楚
- 在多个格式路径之间同步收敛行为

### 4.3 帮助做质量回归

项目后期，AI 的作用更多转向：

- 补测试
- 对照样例检查输出回退
- 对照文档检查口径漂移
- 帮助生成和更新比赛材料

### 4.4 帮助做外部研究与定位

在对比 MarkItDown、Docling、MinerU、Marker 等工具时，AI 明显提升了调研效率。

但这里最重要的原则不是“接受 AI 给出的全部判断”，而是：

- 对外部结论做事实核对
- 对项目定位做主观取舍
- 把 AI 产出当成起点，不当成最终结论

## 5. 借鉴了哪些开源工作

MoonBitMark 并不是从零想象出来的，它明显借鉴了当前文档转换工具的一些成熟经验：

- MarkItDown 的轻量转换器思路
- Docling / Marker 在 agent / pipeline 场景中的使用方式
- Pandoc 这种“统一中间表示再输出”的思路

但最后没有照搬它们的路线，而是有意识地做了取舍：

- 不走重型 ML 主路径
- 不把项目做成“大而全”的 Python AI 平台
- 不在当前阶段把 MCP 写成完整协议产品

核心取舍只有一句话：

> 优先做一个轻量、真实、可演进、适合 MoonBit 生态长期积累的系统。

## 6. 开发过程中最重要的经验

### 6.1 功能数量不是最难的，口径一致才难

支持 10 类输入已经不算小项目了，但真正难的是：

- 代码行为
- 测试结论
- README 表述
- 专题文档
- 比赛材料

这些东西必须长期一致。

### 6.2 diagnostics 是这个项目的真正价值点之一

如果项目只有“输入转输出”，那它只是一个工具。

但当项目能稳定提供：

- warning
- phase
- source
- hint
- stats
- metadata

它就更像一个可以被工程系统依赖的组件。

### 6.3 诚实地暴露边界，比夸大能力更重要

比赛项目很容易陷入一种诱惑，就是把未完全闭环的能力写得很满。

MoonBitMark 后期一个明显的收敛，就是开始明确写出：

- 哪些是稳定主路径
- 哪些是实验性入口
- 哪些是 bridge-backed recovery

这会让项目显得更像一个工程作品，而不是宣传材料。

## 7. 如果继续往后做，会怎么演进

MoonBitMark 后续更合理的方向不是无节制扩功能，而是继续强化下面几条主线：

- 更强的 PDF route / recovery / diagnostics
- 更稳的 MCP 工具接口
- 更完整的跨平台 native 分发
- 更丰富但仍然可验证的 quality eval 样本

这些方向都围绕同一个目标：

让 MoonBitMark 成为 MoonBit 生态里真正可复用、可依赖的文档处理底座。
