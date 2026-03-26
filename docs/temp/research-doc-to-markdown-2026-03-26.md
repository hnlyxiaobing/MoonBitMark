# 文档转 Markdown 开源工具调研报告

> 调研日期：2026-03-26  
> 报告目的：广泛调研当前最优秀的开源文档转 Markdown 项目，与 MoonBitMark 进行横向对比，提出优化方向

---

## 一、调研范围与方法

本次调研覆盖以下主流开源文档转 Markdown 工具：

| 工具 | 来源 | GitHub Stars |
|------|------|-------------|
| **MarkItDown** | Microsoft / AutoGen 团队 | ⭐ 92.5k |
| **Docling** | IBM Research | ⭐ 56.5k |
| **MinerU** | OpenDataLab (上海AI实验室) | ⭐ 56.5k |
| **Marker** | datalab-to (VikParuchuri) | ⭐ 33.1k |
| **Pandoc** | John MacFarlane | ⭐ 42.9k |
| **Unstructured** | Unstructured-IO | ⭐ ~18k |

调研信息来源：GitHub 项目主页、官方文档、技术博客及社区评测报告（截至 2026-03-26）。

---

## 二、主流开源工具详细分析

### 2.1 Microsoft MarkItDown

**项目地址**：https://github.com/microsoft/markitdown  
**许可证**：MIT  
**语言**：Python 3.10+  
**版本**：v0.1.5（2026-02-20）

#### 核心定位

由微软 AutoGen 团队开发，定位为**轻量级文档转 Markdown 工具**，特别适合 LLM 和文本分析 Pipeline 场景。设计目标是在保留文档重要结构（标题、列表、表格、链接）的前提下实现多格式转换。

#### 支持格式

| 输入类型 | 具体格式 |
|----------|----------|
| 文档类 | PDF、DOCX、PPTX、XLSX/XLS |
| 媒体类 | 图像（EXIF + OCR）、音频（转录） |
| 网页类 | HTML、YouTube 字幕 |
| 数据类 | CSV、JSON、XML |
| 压缩包 | ZIP（遍历内容） |
| 电子书 | EPUB |

#### 架构特点

- **插件系统**：支持第三方插件扩展（`#markitdown-plugin` 标签生态）
- **流式处理**：使用二进制文件流，避免创建临时文件
- **可选依赖**：按功能分组（`[pdf]`、`[docx]` 等），按需安装
- **Docker 支持**：提供容器化部署方案
- **LLM 集成**：支持接入 OpenAI 等模型进行图像描述和增强

#### 优势

- 极高社区影响力（92.5k Stars），有微软背书
- 支持格式种类最广（20+ 种格式）
- 插件生态活跃，音频/视频支持是独有功能
- 使用门槛低，Python API 极为简洁（`md = MarkItDown(); md.convert("file.pdf")`）

#### 局限

- 依赖体量重，多种格式需要不同 Python 依赖库
- PDF 解析能力相对基础（依赖 pdfminer/pymupdf）
- 无原生 MCP/AI-native 集成
- 无深度布局分析（无法处理复杂 PDF 版式）
- 不支持本地离线完整运行（图像 OCR 依赖云服务）

---

### 2.2 IBM Docling

**项目地址**：https://github.com/docling-project/docling  
**许可证**：MIT  
**语言**：Python 3.10+

#### 核心定位

由 IBM Research 开发，定位为**面向 GenAI 生态的专业文档解析工具**，强调高级 PDF 理解和与 AI 框架的无缝集成。

#### 支持格式

| 输入格式 | 输出格式 |
|----------|----------|
| PDF、DOCX、PPTX、XLSX、HTML、图像、LaTeX、音频（WAV/MP3）、纯文本 | Markdown、HTML、WebVTT、DocTags、无损 JSON |

#### 架构特点

- **统一文档表示**：`DoclingDocument` 统一格式，减少下游转换损耗
- **深度 PDF 理解**：基于深度学习（DocLayNet 模型）的页面布局分析、表格结构识别、阅读顺序重建、公式识别
- **AI 生态集成**：内置 LangChain、LlamaIndex、Crew AI、Haystack 集成
- **VLM 支持**：支持 GraniteDocling 等视觉语言模型
- **MCP 服务器**：提供 MCP 协议支持（面向 AI Agent 场景）
- **专用格式支持**：XBRL 财务报告、JATS 学术文章、USPTO 专利

#### 优势

- 最强 PDF 版式理解（深度学习驱动，非启发式规则）
- 唯一内置 MCP 服务器的主流工具之一
- 专业领域格式支持（金融/学术）
- 本地完全离线运行
- AI 框架生态集成最完善

#### 局限

- 重型依赖（需要 PyTorch/ML 运行时，安装 GB 级）
- GPU 需求较高（复杂 PDF 处理）
- 对非 PDF 格式的支持相对薄弱
- 启动和处理速度较慢

---

### 2.3 OpenDataLab MinerU

**项目地址**：https://github.com/opendatalab/MinerU  
**许可证**：AGPL-3.0  
**语言**：Python  
**版本**：v2.7.6（2026-02）

#### 核心定位

由上海人工智能实验室 OpenDataLab 开发，诞生于书生-浦语大模型预训练流程。定位为**高精度 PDF 转 Markdown 专项工具**，专注于从复杂 PDF 中提取高质量结构化数据。

#### 支持格式

- **输入**：PDF（扫描版、文字版、混合版）
- **输出**：Markdown（多模态）、JSON（按阅读顺序）

#### 架构特点

- **多后端支持**：
  - `pipeline`：兼容性高，纯 CPU 可运行，精度 82%+（OmniDocBench v1.5）
  - `vlm/hybrid`：视觉语言模型，精度 90%+，需 GPU/NPU
  - 自动引擎选择：根据硬件环境自动选择最优路径
- **109 种语言 OCR**：自动检测并支持多语言扫描文档
- **智能清理**：自动去除页眉页脚、脚注、页码，保证语义连贯
- **国产硬件适配**：昇腾、算能、沐曦、昆仑芯等国内硬件加速
- **公式与表格专项处理**：公式转 LaTeX、表格转 HTML
- **跨平台**：Windows/Linux/macOS，支持 Docker

#### 优势

- 专注 PDF，PDF 处理精度最高
- 深度学习驱动，处理复杂学术/技术 PDF 效果卓越
- 公式识别（LaTeX 输出）是独有优势
- 国产大模型/AI 生态最友好
- 多语言 OCR 覆盖最广

#### 局限

- 仅支持 PDF 输入（不支持 Office/HTML 等格式）
- 重型依赖，部署成本高
- AGPL-3.0 许可证商业使用有限制

---

### 2.4 Marker

**项目地址**：https://github.com/datalab-to/marker  
**许可证**：GPL-3.0（模型权重用修改版 AI Pubs Open Rail-M）  
**语言**：Python

#### 核心定位

由 VikParuchuri 开发，定位为**快速、高精度的文档转 Markdown 工具**，侧重于速度与质量的平衡。

#### 支持格式

- **输入**：PDF、图像、PPTX、DOCX、XLSX、HTML、EPUB
- **输出**：Markdown、JSON、HTML、分块文本

#### 架构特点

- **速度优势**：单页 PDF 平均转换时间 2.84 秒，H100 GPU 下吞吐量约 25 页/秒
- **可选 LLM 增强**：支持接入大语言模型提升准确率
- **图像提取保留**：自动提取并保存文档图像
- **智能清理**：自动去除页眉/页脚等冗余内容
- **多平台**：支持 GPU（CUDA）、CPU、MPS（Apple Silicon）

#### 优势

- 速度和精度的综合表现最佳（基准测试显示优于同类工具）
- 支持格式种类丰富（不只 PDF）
- LLM 增强可选，灵活性高

#### 局限

- GPL 许可证商业使用受限
- 重型 ML 依赖
- 对非 PDF 格式支持不如 MarkItDown

---

### 2.5 Pandoc

**项目地址**：https://github.com/jgm/pandoc  
**许可证**：GPL-2.0  
**语言**：Haskell  
**版本**：3.9.0.2（2026-03-19）

#### 核心定位

由 John MacFarlane 开发，被誉为"**文档转换的瑞士军刀**"，专注于标记格式之间的高质量相互转换。

#### 支持格式

- **输入**：30+ 种格式（asciidoc、docx、epub、html、latex、markdown 多变体、org、rst 等）
- **输出**：40+ 种格式（含 PDF 通过 LaTeX/Groff/HTML）

#### 架构特点

- **基于文档 AST**：输入 → AST → 输出，可通过 Lua 过滤器修改 AST
- **学术友好**：内置引用、脚注、数学公式、元数据块等扩展 Markdown 支持
- **成熟稳定**：20+ 年开源积累，生态极为成熟

#### 优势

- 支持格式最多，是学术/出版领域标准工具
- 架构优雅，可通过过滤器高度定制化
- 稳定可靠，有极强的社区和文档支持
- 跨平台支持最好（Haskell 编译，无需运行时）

#### 局限

- 不支持深度语义提取（无 OCR、无版式分析）
- 对 Office 格式（DOCX/PPTX/XLSX）的语义理解有限
- 不面向 LLM/AI 场景优化

---

### 2.6 Unstructured

**项目地址**：https://github.com/Unstructured-IO/unstructured  
**许可证**：Apache-2.0  
**语言**：Python

#### 核心定位

定位为**非结构化数据提取和预处理工具**，专注于为 RAG（检索增强生成）和 AI Pipeline 提供干净的文本数据。

#### 架构特点

- 支持多种文件格式（PDF、Word、HTML、图像等）
- 提供元素级别的文档结构识别（标题、正文、表格、列表等）
- 有托管 API 和本地两种部署模式
- 与 LangChain 等 RAG 框架深度集成

---

## 三、主流工具横向对比矩阵

| 对比维度 | MarkItDown | Docling | MinerU | Marker | Pandoc | MoonBitMark |
|----------|-----------|---------|--------|--------|--------|------------|
| **GitHub Stars** | 92.5k | 56.5k | 56.5k | 33.1k | 42.9k | 开发中 |
| **实现语言** | Python | Python | Python | Python | Haskell | MoonBit |
| **许可证** | MIT | MIT | AGPL-3.0 | GPL-3.0 | GPL-2.0 | Apache-2.0 |
| **格式覆盖广度** | ⭐⭐⭐⭐⭐（20+）| ⭐⭐⭐⭐（PDF/Office/HTML）| ⭐⭐（PDF 专项）| ⭐⭐⭐⭐（7种）| ⭐⭐⭐⭐⭐（30+）| ⭐⭐⭐⭐（10种）|
| **PDF 处理质量** | ⭐⭐⭐（启发式） | ⭐⭐⭐⭐⭐（深度学习）| ⭐⭐⭐⭐⭐（专项优化）| ⭐⭐⭐⭐⭐（速度+精度）| ⭐⭐（基础）| ⭐⭐⭐（启发式）|
| **图像/OCR 能力** | ⭐⭐⭐（插件/云服务）| ⭐⭐⭐⭐⭐（内置 DL）| ⭐⭐⭐⭐⭐（109语言）| ⭐⭐⭐⭐（可选 LLM）| ❌ | ⭐⭐（外部 bridge）|
| **表格识别精度** | ⭐⭐⭐（基础）| ⭐⭐⭐⭐⭐（结构识别）| ⭐⭐⭐⭐（HTML输出）| ⭐⭐⭐⭐（格式化）| ⭐⭐⭐（文本表格）| ⭐⭐⭐（文本表格）|
| **公式识别** | ❌ | ⭐⭐⭐⭐（识别+渲染）| ⭐⭐⭐⭐⭐（LaTeX）| ⭐⭐⭐⭐（格式化）| ⭐⭐⭐（LaTeX输入）| ❌ |
| **LLM/AI 集成** | ⭐⭐⭐⭐（OpenAI 等）| ⭐⭐⭐⭐⭐（生态最全）| ⭐⭐⭐（国内生态）| ⭐⭐⭐（可选）| ❌ | ⭐⭐（实验性 MCP）|
| **MCP 协议** | ❌ | ⭐⭐⭐⭐（MCP Server）| ❌ | ❌ | ❌ | ⭐⭐（实验性）|
| **Native 编译** | ❌（需 Python 运行时）| ❌ | ❌ | ❌ | ✅（Haskell）| ✅（MoonBit 原生）|
| **依赖体量** | ⭐⭐⭐（中等，可选）| ⭐（很重，ML）| ⭐（很重，ML）| ⭐（很重，ML）| ⭐⭐⭐⭐（轻量）| ⭐⭐⭐⭐⭐（极轻量）|
| **跨平台** | ✅ | ✅（macOS/Linux/Win）| ✅ | ✅ | ✅ | ⚠️（目前仅 Windows MSVC）|
| **扫描 PDF/OCR** | ⭐⭐⭐（插件）| ⭐⭐⭐⭐⭐（内置）| ⭐⭐⭐⭐⭐（内置）| ⭐⭐⭐⭐（内置）| ❌ | ⭐⭐（外部 bridge，有缺口）|
| **音频/视频** | ⭐⭐⭐（转录）| ⭐⭐⭐（ASR）| ❌ | ❌ | ❌ | ❌ |
| **结构化诊断协议** | ❌ | ⭐⭐⭐（DoclingDocument）| ❌ | ❌ | ❌ | ⭐⭐⭐⭐⭐（ConvertDiagnostic）|
| **成熟度** | ⭐⭐⭐⭐（成熟）| ⭐⭐⭐⭐（成熟）| ⭐⭐⭐⭐（成熟）| ⭐⭐⭐⭐（成熟）| ⭐⭐⭐⭐⭐（非常成熟）| ⭐⭐（v0.3.0，早期）|
| **测试评分（内部）** | N/A | N/A | N/A | N/A | N/A | **0.9963**（31/31）|

---

## 四、MoonBitMark 现状深度分析

### 4.1 项目概况

MoonBitMark（v0.3.0，Apache-2.0）是一个用 **MoonBit** 语言编写的多格式文档转 Markdown 引擎，支持 TXT、CSV、JSON、PDF、图像、HTML/XHTML/URL、DOCX、PPTX、XLSX、EPUB 共 10 种输入格式，提供 CLI 前端和实验性的 MCP STDIO 服务端。

### 4.2 格式支持状态

| 格式 | 实现状态 | 当前评测分 | 主要限制 |
|------|----------|-----------|----------|
| TXT | ✅ 完整 | 1.0000 | 无 |
| CSV | ✅ 完整 | 1.0000 | 无 |
| JSON | ✅ 完整（纯代码块）| 0.9996 | 无语义提取 |
| HTML/XHTML/URL | ✅ 基本完整 | 1.0000 | 无 JS 渲染 |
| DOCX | ✅ 完整 | 1.0000 | 无 |
| XLSX | ✅ 完整 | 1.0000 | 无 |
| EPUB | ✅ 完整 | 0.9544 | 结构恢复有噪声 |
| PPTX | ✅ 基础结构恢复已打通 | 1.0000 | 已覆盖 notes / chart / table / 编号与分组 shape，仍未覆盖 SmartArt、连接线、复杂图表语义 |
| PDF | ✅ 主路径完整 | 0.9990 | 扫描件仅有实验性 OCR recovery，仍缺真正的 page-rendering backend |
| Image | ✅ 骨架完整 | 1.0000（mock）| 内容完全依赖外部 OCR |

**最新评测结果（2026-03-26）**：32/32 全部通过，平均分 0.9964。其中 PPTX 为 4/4，当前样本集中已覆盖基础 notes / chart / table / shape 语义。需要注意，这证明当前样本集表现很强，但不等于所有公开能力都已完全闭环。

### 4.3 架构亮点与真实边界

这一节原稿的判断方向基本对，但有几处表述过满。按仓库现状，更准确的总结应是：

1. **主路径依赖轻**：模块元数据确认当前依赖主要是 `moonbitlang/async`（0.16.7）和 `bobzhang/mbtpdf`（0.1.1），没有引入 PyTorch 这类重型 ML 运行时
2. **共享基础设施有工程价值**：`src/libzip/` 与 `src/xml/` 是纯 MoonBit 实现，这对 DOCX/PPTX/XLSX/EPUB 这类 archive/XML 格式是长期资产
3. **诊断模型设计较完整**：`ConvertResult` + `ConversionDiagnostic` 确实已经有 `level/error/phase/source/message/hint` 等结构化字段，是项目的明显亮点；但“比所有竞品都规范”属于未经同口径验证的结论，不宜写成事实
4. **Native 部署是重要方向，但不是独占优势**：MoonBitMark 可编译为原生二进制，这对 CLI 嵌入和高频调用是加分项；但“唯一无需 Python/JVM/ML 框架即可运行”并不成立，因为 Pandoc 也是原生分发路线
5. **MCP 有差异化潜力，但当前仍是最小闭环**：仓库文档只确认了实验性 STDIO MCP，以及 `initialize` / `tools/list` / `tools/call` 三个方法的 smoke path，不能把它写成成熟能力
6. **CLI 面向调试和诊断的可观察性较强**：`--diag-json`、`--detect-only`、`--dump-ast`、`--ocr-*`、`--asset-dir` 等参数已经具备，但要区分“参数存在”和“对应能力已完全闭环”
7. **必须正视 runtime boundary**：OCR 和 PDF fallback 仍依赖 Python bridge。MoonBitMark 的准确定位不是“纯 MoonBit 端到端全闭环”，而是“核心转换主链轻量、部分恢复能力通过 bridge 提供”

### 4.4 已确认剩余技术债务与已收口事项

更准确的现状不是“问题都还在”，而是要把**已经收口的事项**和**仍待推进的剩余缺口**分开写。更新后的判断如下：

| 优先级 | 类型 | 问题 | 证据/说明 | 影响 |
|--------|------|------|-----------|------|
| 🟡 P1 | 已确认能力缺口 | 扫描版 PDF 仍缺真正的 page-rendering OCR backend | `src/formats/pdf/converter.mbt` 已有 route + OCR 注入路径，但 `docs/features/ocr.md` 与 diagnostics 仍明确当前没有 page-rendering backend | 全扫描或混合扫描 PDF 的正文恢复能力仍不稳 |
| 🟡 P1 | 已确认剩余能力缺口 | PPTX 深层对象语义仍未覆盖 | `src/formats/pptx/slide.mbt` 已支持 notes、chart、table、显式编号和 grouped shape，但未覆盖 SmartArt、连接线、复杂图表组件 | 复杂演示稿仍会丢失更深层视觉语义 |
| 🟢 P2 | 已完成修复 | `escape_markdown_text()` 已补真实转义 | `src/ast/renderer.mbt` 与 `src/ast/ast_test.mbt` 已有回归覆盖 | 这一项已从当前阻塞缺陷降为持续守护项 |
| 🟢 P2 | 已完成共享层升级 | AST `List/Table` 已支持 rich inline | `src/ast/types.mbt` 及 HTML/DOCX/XLSX/PDF/CSV/EPUB 相关代码已切到 inline 容器 | 后续重点从“改 AST”转为“补样例和扩 converter 覆盖” |
| 🟢 P2 | 已完成接口收口 | `--dump-ast` 已输出 strict JSON | `cmd/main/main.mbt`、`cmd/main/main_wbtest.mbt`、`tests/cli/cli_smoke.ps1` 已验证 | 机器消费接口已闭环 |
| 🟢 P2 | 已确认代码异味 | `HtmlConverter` 忽略 `ConvertContext` | `src/formats/html/converter.mbt` 中存在 `ignore(ctx)` | 当前实际影响有限，但会阻碍后续 HTML 资产/OCR/上下文扩展 |
| 🟢 P2 | 已完成维护性收口 | PPTX 命名空间前缀剥离已合并 | `src/formats/pptx/xml_names.mbt` 已作为共享 helper 被 `parser.mbt` 与 `slide.mbt` 复用 | 这项债务已关闭 |
| 🟢 P2 | 当前无复现证据 | Dynamic Huffman 现阶段不应再列为活跃阻塞缺陷 | `src/libzip/zip_easy_test.mbt` 中的 dynamic Huffman 单测可通过，`docs/architecture.md` 口径与当前测试一致 | 在补到真实失败 fixture 前，应把它视为“旧口径待清理”，而不是“当前已确认 P0” |

---

## 五、差距分析：MoonBitMark vs. 主流工具

原稿这一章的问题是“面面俱到，但主次不够清楚”。MoonBitMark 当前真正应该盯住的，不是把竞品所有能力都补齐，而是先把**正确性、主路径闭环、发布能力、MCP 契约**四件事排出先后。

### 5.1 第一优先级：先守住已经收口的正确性与契约

#### A. Markdown 转义问题已经修掉，下一步是用回归样例守住

`escape_markdown_text()` 已经补上真实转义逻辑，并覆盖了标题、段落、列表、表格单元格等关键路径。它不再是“当前未解决缺陷”，但仍应保持高优先级回归覆盖，因为这是最容易被后续格式优化重新破坏的正确性边界。

#### B. Dynamic Huffman 当前更像“旧结论漂移”，不该继续占用 P0 认知

到当前代码状态，Dynamic Huffman 至少已经有明确单测，且测试可通过。更合理的做法不是继续把它写成现存重大缺陷，而是：

- 在拿到真实失败 PPTX/ZIP fixture 前，不再把它当成当前阻塞项
- 如果后续能复现真实失败，再以 fixture 驱动修复
- 同步清理仓库里仍残留的旧口径，避免文档继续制造伪优先级

#### C. `--dump-ast` 契约已经澄清，当前重点转为保持 schema 稳定

`--dump-ast` 现在已经输出 strict JSON，并通过 `cmd/main` wbtest 与 CLI smoke 脚本双重验证。它已经从“契约不清”转成“已收口接口”，后续工作重点应转为：

1. 避免无意 breaking change
2. 在需要时补 AST fixture / conversion eval 样例
3. 保持与 `diag-json` 一样的机器消费稳定性

### 5.2 第二优先级：补齐真正影响产品可信度的主能力缺口

#### A. 扫描 PDF recovery path 是能力短板，不应再降到中优先级

如果 MoonBitMark 把 PDF 作为主格式之一，那么“扫描件仍缺真正的 page-rendering OCR backend”就是非常实质的短板。当前实现已经有 route、diagnostics 和 OCR 注入式 recovery，但这还不是成熟页渲染管线；扫描件正文恢复仍明显依赖外部 backend 与当前 bridge 边界。

这件事的重要性高于公式识别、多媒体支持、JSON 智能渲染，因为它直接决定用户会不会把 MoonBitMark 视作“能处理 PDF 的工具”。

#### B. AST 表达能力是结构性瓶颈

`List/Table` 的共享层瓶颈已经解除，多个格式现在可以把 inline-rich 内容带进列表项和表格单元格。下一阶段的重点不再是“继续改 AST 定义”，而是补齐更多格式样例、确认边缘 case，并把这层能力持续传导到 conversion eval。

这类问题比单一格式的小修更值得优先处理，因为它是共享层瓶颈。

#### C. PPTX 已进入“基础结构恢复”，但还不是“高保真重建器”

原稿关于 PPTX 的判断在调研当时基本成立，但以当前代码状态看已经需要更新。更准确的说法是：

- 当前 PPTX 已能恢复标题、正文、table、speaker notes、基础 chart 数据表，以及显式编号/分组 shape 的文本顺序
- 它已经不是“纯文本提取器”，而是“基础结构恢复器”
- 但它仍不是“高保真演示文稿重建器”，因为 SmartArt、连接线、复杂图表语义、notes master 等仍未覆盖

这更贴近源码现实，也更利于制定后续范围。

#### D. 跨平台发布是 adoption bottleneck

MoonBitMark 把 native 作为卖点，但当前构建文档与 CI 假设仍明显偏向 Windows + MSVC。对一个强调“轻量可嵌入”的工具来说，跨平台二进制分发不是锦上添花，而是落地门槛。

### 5.3 第三优先级：战略演进要聚焦，而不是做功能愿望单

#### A. MCP 的重点应是“契约稳定”，不是先扩 transport 数量

原稿把 HTTP/SSE 放得太靠前了，这不够聚焦。对 MoonBitMark 来说，MCP 当前更核心的问题是：

- STDIO 输出是否绝对干净
- tool schema 是否稳定
- 错误与 diagnostics 是否适合 agent 消费
- 集成测试是否覆盖协议回归

在这些没有稳定之前，盲目扩 HTTP/SSE 只会扩大维护面。更合理的路线是先把 STDIO 做成“可依赖的最小产品”，再判断是否有必要扩 transport。

#### B. 公式、多媒体、全 AI 生态接入不应进入近期主线

这些能力当然有价值，但和 MoonBitMark 当前定位并不对齐。当前阶段继续把精力分散到公式识别、音视频、字幕、全套框架集成，只会削弱真正的差异化建设。

#### C. JSON 智能渲染可以做，但只能排在主链之后

JSON 当前是稳定的“代码块导出”语义，这本身并不错误。智能表格/键值渲染属于可读性增强，不应先于 Markdown 正确性、PDF recovery、AST 演进和跨平台分发。

---

## 六、MoonBitMark 核心竞争力与定位建议

### 6.1 核心竞争力应如何表述才准确

原稿这一章的方向是对的，但“唯一”“最强”“超越所有竞品”这类措辞过多，削弱了专业性。更稳妥的版本如下：

| 竞争维度 | 更准确的表述 |
|----------|-------------|
| **运行时依赖** | 相比主流 Python/ML 路线更轻，核心转换主路径适合 native 分发 |
| **共享基础设施** | `libzip + xml` 的纯 MoonBit 基础设施让 Office/EPUB 路线具备长期可维护性 |
| **诊断设计** | `ConversionDiagnostic` 结构化程度较高，适合做 CLI/MCP 机器消费，这是明显差异化点 |
| **部署形态** | Native CLI 对嵌入式调用、工具链集成、冷启动场景有潜在优势，但仍需跨平台分发补齐 |
| **MCP 潜力** | 已有实验性 STDIO MCP 闭环，若协议契约稳定，能形成 agent-tooling 方向的真实特色 |
| **许可证** | Apache-2.0 是明确优势，商业采用阻力小于 GPL/AGPL 路线 |

同时必须明确一个边界：MoonBitMark **不是完全无外部运行时依赖的端到端系统**。OCR 与 PDF fallback 仍通过 Python bridge 提供，这是产品描述时必须保留的事实。

### 6.2 推荐定位

> **“以 Native 分发和结构化诊断为核心、主路径轻量、可选 bridge 扩展恢复能力的文档转 Markdown 引擎。”**

这个定位比“最轻量”更准确，也更有可执行性。它强调的不是全能，而是以下几件事：

- 主链路轻，适合工程集成
- 输出契约清晰，适合 CLI / MCP / agent 调用
- Office / HTML / 文本类格式有稳定基础
- OCR / PDF fallback 作为可选恢复能力，而不是核心卖点

对应的目标用户应聚焦为：

- 需要嵌入文档转 Markdown 能力、但不想引入整套 Python/ML 运行时的工程团队
- 需要结构化 diagnostics、便于自动化处理和失败分流的工具链场景
- 需要一个可原生分发、可逐步演进到 MCP 工具面的文档转换组件
- MoonBit 生态内需要文档处理能力的项目

---

## 七、优化路线图建议

原稿路线图的问题主要有两个：

1. 把“修 bug”“补证据”“做架构演进”“做长期扩展”混在一起
2. 过早投入公式、多媒体、HTTP/SSE 等非主链事项

更专业、更可执行的路线图建议如下。

### Phase 1（立即执行：修正确性，补事实证据）

| 任务 | 优先级 | 预期效果 |
|------|--------|----------|
| 持续守护 Markdown 转义回归样例 | 🟡 P1 | 防止正确性修复被后续改动破坏 |
| 为 Dynamic Huffman 补真实失败 fixture，确认是否存在仓库外样例缺口 | 🟡 P1 | 继续清理旧口径与真实行为之间的差异 |
| 维持 `--dump-ast` strict JSON schema 稳定，并补 AST fixture / eval 样例 | 🟡 P1 | 把已收口接口转成长期稳定契约 |
| 为扫描 PDF、PPTX 复杂结构、Markdown 转义补针对性评测样例 | 🟡 P1 | 让后续优化有稳定验收标准 |
| 同步修正文档口径：native/bridge 边界、MCP 成熟度、PDF OCR 现状 | 🟢 P2 | 避免外部描述与仓库事实脱节 |

### Phase 2（核心能力补强：先补共享层，再补主格式）

| 任务 | 优先级 | 预期效果 |
|------|--------|----------|
| 扩充 rich inline list/table 的样例与 conversion eval 覆盖 | 🟡 P1 | 把共享层升级转成稳定可验收能力 |
| 继续深化 PPTX：补 SmartArt / 更复杂 chart / shape 语义 | 🟡 P1 | 让 PPTX 从“基础结构恢复”继续逼近主流工具可读性 |
| 打通扫描 PDF 的 OCR recovery path | 🟡 P1 | 扫描件从“只有 diagnostics”提升到“可产出正文” |
| 统一 HTML / 其他 converter 的 `ConvertContext` 使用策略 | 🟢 P2 | 降低未来能力扩展的分叉成本 |

### Phase 3（产品化落地：分发与协议稳定）

| 任务 | 优先级 | 预期效果 |
|------|--------|----------|
| 跨平台 native 构建与 CI（Linux/macOS） | 🟡 P1 | 让“轻量可嵌入”真正具备分发价值 |
| MCP 先做 STDIO 契约硬化：stdout 纯净、schema 稳定、错误可机读 | 🟡 P1 | 把实验性入口升级为可靠工具接口 |
| 在确有使用需求后，再评估 HTTP/SSE transport | 🟢 P2 | 控制维护面，避免过早扩张 |
| 扩充 conversion eval 样本集与失败归因报告 | 🟢 P2 | 让质量改进可持续追踪 |

### Phase 4（可选增强：不进入近期主线）

| 任务 | 说明 |
|------|------|
| JSON 智能渲染 | 可读性增强，不影响当前正确性主线 |
| XLSX 公式单元格显示策略 | 适合作为格式深化项 |
| PDF 公式检测/标注 | 仅在学术 PDF 场景明确成立时推进 |
| 音频/视频/字幕 | 与当前产品定位不一致，暂不建议进入近期路线图 |
| LaTeX 输入、逆向转换、多格式发布生态 | 长期扩展方向，不应挤占当前主线资源 |

---

## 八、总结

### MoonBitMark 的核心优势

1. ✅ **主路径轻量**：核心转换链路没有引入重型 ML 运行时，部署成本低
2. ✅ **Native 分发潜力明确**：适合 CLI 集成、嵌入式调用和工具链场景
3. ✅ **共享基础设施扎实**：`libzip + xml` 为 Office/EPUB 路线提供了长期资产
4. ✅ **诊断设计成熟度较高**：`ConvertResult` + `ConversionDiagnostic` 很适合自动化消费
5. ✅ **当前样本集质量表现强**：最新内部评测 32/32 通过，平均 0.9964
6. ✅ **Apache-2.0**：商业采用阻力小

### MoonBitMark 的核心差距

1. ⚠️ **扫描 PDF 的 page-rendering OCR backend 仍未落地**：这是当前 PDF 能力最实质的剩余短板
2. ⚠️ **PPTX 已有基础结构恢复，但距离主流工具的深层语义覆盖仍有差距**
3. ❌ **跨平台分发未落地**：native 卖点还没有变成完整产品能力
4. ❌ **MCP 仍处实验阶段**：目前只有最小 STDIO 闭环
5. ⚠️ **Dynamic Huffman 旧口径尚未完全清理**：在没有真实失败 fixture 前，不应继续把它当作活跃 P0
6. ⚠️ **HTML / PPTX 等局部实现仍有可维护性债务**：例如 `ConvertContext` 未充分使用，且 PPTX 深层对象语义仍需继续拆分治理
7. ✅ **Markdown 转义、AST rich inline、`--dump-ast` strict JSON 已完成收口**：这些项已经从主缺口转成需要持续守护的基线

### 战略定位

MoonBitMark 不应追求成为“全能型 Python AI 文档平台的替代品”，而应围绕**“主路径轻量、Native 分发、诊断优先、可选 bridge 恢复能力、逐步走向可靠 MCP 工具面”**建立差异化定位。

---

*本报告基于 2026-03-26 的开源项目现状，相关数据（Stars、版本号等）可能随时间变化。*


