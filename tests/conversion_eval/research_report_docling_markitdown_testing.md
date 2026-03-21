# 文档转换项目测试方法与测试数据集研究报告

## 执行摘要

Docling 和 MarkItDown 是当前最受关注的两个文档转换开源项目，它们在测试策略上走了截然不同的路线。Docling 采用**结构化 Golden File（黄金文件）对比**为核心，搭配自定义 Levenshtein 文本相似度验证，测试数据集高达 18+ 种文档格式，并配套了专业的外部评估框架 `docling-eval`；MarkItDown 则采用**关键词锚点包含/排除双向检测**为主，辅以宽松的 Golden File 行级比对，测试覆盖 15 种格式、8 种输入路径方式。pandoc、pdfplumber 等周边工具同样提供了极具参考价值的测试数据集。结合业界最新基准（OmniDocBench、DP-Bench、SCORE-Bench），本报告为构建自定义文档转换测试数据集提供了完整的方法论与实践指南。

---

## 背景

在 RAG（检索增强生成）、知识库构建、文档智能处理等 AI 应用场景的推动下，将 PDF、DOCX、PPTX 等格式转换为 Markdown 的需求日益旺盛。如何客观评估这类转换的质量，是构建可靠测试体系的核心挑战。本研究深入分析了两个主流开源项目的测试实践，并结合学术界的评估基准，为需要验证自有文档转换项目效果的开发者提供参考。

---

## Docling 的测试体系

Docling（IBM 开源）是目前功能最完整的文档转换框架之一，其测试体系同样高度专业化。

### 测试目录结构

Docling 的 `tests/` 目录包含 47 个测试文件和 1 个核心验证工具模块 `verify_utils.py`，按功能分为后端格式测试（每种格式一个文件，如 `test_backend_msword.py`、`test_backend_html.py`）、端到端转换测试（`test_e2e_conversion.py`、`test_e2e_ocr_conversion.py`）和功能测试（OCR、CLI、公式、图片分类等）三大类。支持的格式横跨 PDF、DOCX、PPTX、HTML、LaTeX、CSV、XLSX、AsciiDoc、JATS、XBRL、WebVTT、WebP、TIFF 等 18 种以上，是目前测试覆盖面最广的文档转换项目之一。

测试数据存放于 `tests/data/` 目录，包含 20 个子目录，对应各种文档格式。PDF 测试集包含 15 个精心挑选的文件：有完整学术论文（如 arXiv 编号的多篇论文）、手册样本、含代码和公式的专项测试文件、多页文档、从右到左书写方向（阿拉伯文）文档，以及专门测试失败处理的"残缺"文档。CSV 测试集的设计尤为细致，针对逗号分隔、分号分隔、管道符分隔、Tab 分隔、单元格内含逗号、不一致表头、单列、列数过多/过少等 9 种边界情况各有独立测试文件。

### Golden File 对比机制

Docling 最核心的测试机制是 **Golden File 对比**。每个输入文档都在 `tests/data/groundtruth/docling_v2/` 目录下有 3-4 个对应的期望输出文件：`.json`（完整文档对象模型）、`.md`（Markdown 输出）、`.doctags.txt`（VLM 标注输出）和 `.pages.meta.json`（页面元数据）。测试时将实际转换输出与这些文件逐一比对。

控制 Golden File 的生成与使用，只需设置环境变量 `GEN_TEST_DATA=1`，测试框架便会将当前输出写入为新的基准文件；不设置时则执行对比验证。这种设计让更新基准数据和执行回归测试的切换极为便捷。

### verify_utils.py：验证引擎

`verify_utils.py` 是 Docling 测试体系的核心，包含了一套完整的多层次验证逻辑。

对于文本内容验证，精确模式下采用逐行字符串精确对比；模糊模式（主要用于 OCR 场景）下使用自实现的 Levenshtein 编辑距离，计算归一化相似度，默认阈值为 0.4。对于文档结构验证，会遍历文档中的每个元素（TextItem、TableItem、PictureItem、CodeItem、FormulaItem），比对元素类型标签、页码、边界框位置（严格模式容差为页面尺寸的 0.25%，模糊模式为 0.5%）、文本内容等。对于表格专项验证，会精确对比行列数量和每个单元格的内容与类型。这种"从宏观结构到微观内容"的分层验证策略，能精准定位转换中的任意层次问题。

### 外部评估框架 docling-eval

除单元测试外，Docling 还维护了独立的评估框架 `docling-eval`（https://github.com/DS4SD/docling-eval），支持在公开学术基准上进行系统级评测。支持的基准数据集包括：**DP-Bench**（文本提取、版面分析、阅读顺序、表格结构四个维度全覆盖）、**OmniDocBench**（同上）、**DocLayNetV1**（版面分析专项）、**FinTabNet**、**PubTabNet**、**Pub1M**（三个表格结构专项基准）。评估指标包括文本提取的 Precision/Recall/F1，版面分析的 mAP，表格结构的 TEDS（树编辑距离相似度），以及阅读顺序一致性。

---

## MarkItDown 的测试体系

MarkItDown（Microsoft 开源）采用了一种更轻量但同样精巧的测试策略，其核心思想是"不求格式完全一致，只求关键内容必达"。

### 测试目录结构

测试文件位于 `packages/markitdown/tests/`，包含 10 个测试文件和 1 个核心数据定义文件 `_test_vectors.py`。测试文件覆盖模块功能向量测试（`test_module_vectors.py`）、CLI 向量测试（`test_cli_vectors.py`）、PDF 专项测试（`test_pdf_masterformat.py`、`test_pdf_memory.py`、`test_pdf_tables.py`）、Document Intelligence HTML 测试（`test_docintel_html.py`）以及杂项功能测试（`test_module_misc.py`、`test_cli_misc.py`）。

测试数据存放于 `tests/test_files/` 目录，共 30 个文件，格式覆盖 DOCX（含注释版、含公式版、含安全漏洞回归版）、XLSX/XLS、PPTX、MSG、EPUB、7 个 PDF（含扫描版医疗报告）、4 个 HTML 页面、CSV、JSON、XML、IPYNB、ZIP、JPG、WAV/MP3/M4A 及二进制测试文件。`test_files/expected_outputs/` 子目录存放 6 个 PDF 测试的期望输出 Markdown 文件。

### 关键词锚点检测：核心创新

MarkItDown 测试体系最具特色的设计是**UUID 锚点策略**。测试文档内部预埋了随机 UUID 字符串（如 `314b0a30-5b04-470b-b9f7-eed2c2bec74a`），测试时只需检查这些 UUID 是否出现在转换输出中，就能高可信度地验证内容完整性。UUID 的唯一性极强，碰撞概率接近零，且不受文档格式或语言差异影响，即使 ZIP 包内的多层嵌套文件也使用同一套 UUID 体系进行验证。

在此基础上，每个测试用例通过 `FileTestVector` 数据类定义了两组检查列表：`must_include`（必须出现的字符串，验证内容召回）和 `must_not_include`（绝不能出现的字符串，验证噪声过滤）。例如 Wikipedia HTML 转换测试不仅要求提取到文章正文，还要确保"You are encouraged to create an account"等登录提示、"move to sidebar"等导航 UI 元素不出现在输出中。

### 参数化覆盖策略

MarkItDown 用参数化测试将 15 个测试向量与 8 种输入路径方式（本地文件路径、带提示字节流、无提示字节流、HTTP URI、file:// URI、data:// URI、keep\_data\_uris=True 本地路径、keep\_data\_uris=True 字节流）交叉组合，以极低代码量自动生成 120 个测试用例，实现了对各种使用场景的全路径覆盖。

### PDF 专项深度测试

针对 PDF 转换，MarkItDown 设计了三个独立测试文件。`test_pdf_tables.py` 覆盖 6 种 PDF 类型（无边框表格、零售收据、多页发票、学术论文、扫描文档、影院订单），其中 `TestPdfFullOutputComparison` 类与 `expected_outputs/` 下的 Golden File 进行宽松对比：允许行数相差 ±2 行，但要求表格管道符数量和关键词均达标，在稳定性和精确性之间取得了良好平衡。`test_pdf_masterformat.py` 使用正则表达式验证部分编号格式不会被孤立拆分，而 `test_pdf_memory.py` 则使用 `tracemalloc` 对 200 页 PDF 设置峰值内存上限（<30 MiB），将性能测试纳入 CI 流程。

---

## 其他项目的测试方法与公开数据集

### pandoc 的黄金文件体系

pandoc 拥有文档转换领域最丰富的测试数据集，`test/` 目录按格式分成 `docx/`、`epub/`、`pptx/`、`tables/`、`latex/` 等多个子目录，每个输入文件对应一个 `.native` 格式的期望抽象语法树文件。pandoc 的一个关键设计决策是**比较 AST 而非最终文本**，这样可以规避格式细节差异（如换行方式、空格数量）对测试结果的干扰，只关注语义和结构的正确性。`tables/` 专项目录集中收录了各种复杂表格场景，是研究表格转换测试方法的极佳参考。

### pdfplumber 的测试策略

pdfplumber 的 `tests/pdfs/` 目录包含大量专用 PDF 测试文件，`tests/comparisons/` 目录存放对比结果，`test_issues.py` 专门追踪历史 bug 回归，`test_oss_fuzz.py` 引入了模糊测试验证健壮性。它使用真实政府报告文件（`test_ca_warn_report.py`、`test_nics_report.py`）作为集成测试用例，这种"用真实业务文档而非人工构造文档"的策略，能发现在理想化测试文档上暴露不出的问题。

### 学术界主要基准数据集

**OmniDocBench**（CVPR 2025，https://github.com/opendatalab/OmniDocBench）是目前最全面的文档解析评估基准，包含 1355 页 PDF，覆盖 9 种文档类型（学术文献、PPT 转 PDF、书籍、彩色教材、试卷、手写笔记、杂志、研究报告、报纸）、4 种版面布局、3 种语言，标注粒度细到 token 级别。评估指标采用综合得分：文本使用归一化编辑距离、表格使用 TEDS、公式使用 CDM，三者平均后得出整体分数。可从 HuggingFace（https://huggingface.co/datasets/opendatalab/OmniDocBench）下载。

**DP-Bench**（Upstage，https://huggingface.co/datasets/upstage/dp-bench）包含 200 个来自美国国会图书馆、开放教育资源和内部文档的样本，标注了 12 类布局元素。核心评估指标 NID（归一化插入/删除距离）专门针对文档元素序列化任务设计，表格结构使用 TEDS 和 TEDS-S。提供完整的评估脚本，入门门槛低，是进行初步基准测试的首选。

**SCORE-Bench**（Unstructured，2025）专为生成式 AI 文档解析系统设计，数据来自医疗、金融、法律等多领域真实文档，由领域专家手工标注。其 SCORE 评估框架能区分"合法格式多样性"（如同一表格输出为纯文本、HTML 或 JSON 都可接受）与"真正的提取错误"，特别评估幻觉（添加令牌率）和内容遗漏（发现令牌率）。

**DocBank**（微软亚研院/哈工大，https://github.com/doc-analysis/DocBank）包含 50 万页学术文档，token 级标注 12 类语义单元（标题、摘要、正文、图片、表格、公式、参考文献等），使用 Macro-average F1 作为评估指标，更适合版面分析任务而非端到端转换评估。

---

## 质量评估指标体系

### 文本内容指标

**字符错误率（CER）** 是 OCR 场景最常用指标，计算方式为字符级编辑距离除以参考文本字符数，值越低越好。**归一化 Levenshtein 相似度**即 Docling 中使用的方法，计算编辑距离并归一化到 \[0,1\] 区间，值越高越好。**NID（归一化插入/删除距离）** 是 DP-Bench 的核心指标，公式为 `1 - 编辑距离/(参考文本长度+预测文本长度)`，特别适合评估文档元素的序列化输出。

**BLEU 和 ROUGE** 在文档转换评估中有一定适用性，但使用前必须做文本标准化处理（去除 Markdown/HTML 标签、统一空白符、处理 Unicode），否则格式差异会严重干扰得分。CambioML 的研究表明，在 PDF→Markdown 任务上，BLEU 分数确能区分优劣工具，但需搭配其他结构指标使用。

### 结构指标

**TEDS（树编辑距离相似度）** 是表格结构识别的标准指标，同时评估表格结构和单元格内容；TEDS-S 变体仅评估结构，忽略内容，用于纯布局评估。**CDM** 是公式识别专用指标。这两类指标是 OmniDocBench、DP-Bench、docling-eval 的核心评估组件。

### 单元测试方法

法国 PDF-to-Markdown 基准（arXiv:2602.11960）提出了一种精细化的单元测试框架，将测试分为 TextPresenceTest（目标文本片段是否存在）、TableTest（表格局部结构约束）和 TextOrderTest（阅读顺序正确性）三类，不依赖全局字符串匹配，能精准定位错误类型并对"合法的格式多样性"保持容忍。这与 MarkItDown 的关键词锚点策略思想相通，但更加系统化。

---

## 构建自定义测试数据集的实践建议

### 文档类型覆盖维度

测试数据集应覆盖以下维度，每个维度都应包含若干典型文档和若干边界情况文档。纯文本场景包括简单单栏文章、多级标题（H1-H6 各层均有）、有序和无序列表（含嵌套）。表格场景包括简单规则表格、含合并单元格的表格、跨页表格、无边框稀疏表格，这是最容易出问题也最值得重点测试的场景。公式场景包括行内数学公式、行间公式、含积分矩阵的复杂公式。代码场景包括单行代码、多行代码块、带语言标注的代码块。图像场景包括内嵌图片、带图注的图片、图表（Chart）。布局场景包括双栏/三栏 PDF、文字环绕图片，重点测试阅读顺序。边界情况包括空文件、加密 PDF、超长段落、从右到左书写方向文档、Unicode 特殊字符、扫描版（无文本层）PDF。

### 测试数据集目录组织

参考 pandoc 的分格式子目录模式，推荐以下结构：`inputs/` 目录按格式分子目录存放源文件，`expected/` 目录按相同路径结构存放对应 Golden File，`edge_cases/` 子目录专放边界情况测试文件，`metadata.json` 记录每个测试用例的难度级别、所属类别和预期评估指标权重。

### 测试方法选择

对于功能性测试，推荐采用 MarkItDown 的**关键词锚点策略**：在源文档中预埋 UUID 字符串作为内容完整性锚点，配合结构性关键词（标题文本、特定单元格值）构建 `must_include`/`must_not_include` 检查列表。这种方法实现简单、稳定性高、不受格式细节影响。

对于精确性测试，在已知期望输出稳定的场景下采用 Docling 的 **Golden File 精确对比**，辅以文本归一化预处理（合并多余空行、去除行尾空格）和适当的容差（允许 ±2 行差异）。

对于定量评估，使用 NID 评估整体内容序列化质量（最易计算，适合快速基准）；使用 TEDS 评估表格转换质量（专业但需要额外依赖）；使用 Levenshtein 相似度（模糊匹配，阈值可根据场景调整）评估文本内容准确性。

### 测试设计原则

参考各项目的实践经验，几个原则值得重视：其一，**语义优先于格式**，不苛求 `*bold*` 与 `**bold**` 一致，重点验证内容和结构的正确性；其二，**困难样本采样**，参考法语 PDF 基准的"模型分歧采样"策略，优先收录多个工具处理结果存在分歧的文档，这类文档往往包含更有价值的边界情况；其三，**分层测试**，从单一格式特性的单元测试，到多格式转换的集成测试，再到完整工作流的端到端测试；其四，**真实文档补充**，pdfplumber 使用政府报告文件作为测试用例的做法值得借鉴，真实业务文档能发现人工构造文档暴露不出的问题；其五，**回归测试文件**，MarkItDown 为每个安全漏洞修复创建专属测试文件（`rlink.docx` 对应 CVE-2025-11849），这种追踪机制可防止已修复问题重新出现。

---

## 结论

Docling 和 MarkItDown 代表了文档转换测试领域的两种主流范式。Docling 的路线是**精确、分层、系统**——Golden File + 多维度结构验证 + 外部基准评测，适合需要高精度质量保证的场景；MarkItDown 的路线是**轻量、稳定、易维护**——UUID 锚点 + 关键词双向过滤 + 宽松行级对比，适合快速迭代和多格式覆盖的场景。

对于构建自有文档转换测试数据集，建议采取分阶段策略：首先参考 MarkItDown 的 `test_files/` 目录，建立覆盖主要格式的基础测试集（每种格式 3-5 个代表性文件），使用 UUID 锚点策略实现快速可靠的功能验证；然后参考 pandoc 的 `tables/` 目录，针对表格、公式等难点场景构建专项深度测试集，引入 TEDS 等专业指标；最后接入 DP-Bench 或 OmniDocBench 中的文档样本，使用标准评估脚本进行横向对比基准测试，量化自己的项目与业界水平的差距。

---

## 参考资料

1. [Docling GitHub 仓库 - docling-project/docling](https://github.com/DS4SD/docling)
2. [Docling tests/ 目录](https://github.com/DS4SD/docling/tree/main/tests)
3. [Docling verify_utils.py 源码](https://raw.githubusercontent.com/docling-project/docling/main/tests/verify_utils.py)
4. [Docling 技术报告 - arXiv:2408.09869](https://arxiv.org/abs/2408.09869)
5. [docling-eval 评估框架](https://github.com/DS4SD/docling-eval)
6. [MarkItDown GitHub 仓库 - microsoft/markitdown](https://github.com/microsoft/markitdown)
7. [MarkItDown tests/ 目录](https://github.com/microsoft/markitdown/tree/main/packages/markitdown/tests)
8. [MarkItDown _test_vectors.py 源码](https://raw.githubusercontent.com/microsoft/markitdown/main/packages/markitdown/tests/_test_vectors.py)
9. [pandoc test/ 目录](https://github.com/jgm/pandoc/tree/master/test)
10. [pdfplumber tests/ 目录](https://github.com/jsvine/pdfplumber/tree/stable/tests)
11. [OmniDocBench - CVPR 2025](https://github.com/opendatalab/OmniDocBench)
12. [OmniDocBench 数据集 - HuggingFace](https://huggingface.co/datasets/opendatalab/OmniDocBench)
13. [OmniDocBench 论文 - arXiv:2412.07626](https://arxiv.org/abs/2412.07626)
14. [DP-Bench 数据集 - HuggingFace](https://huggingface.co/datasets/upstage/dp-bench)
15. [SCORE-Bench - Unstructured 博客](https://unstructured.io/blog/introducing-score-bench-an-open-benchmark-for-document-parsing)
16. [DocBank 数据集](https://github.com/doc-analysis/DocBank)
17. [DocBank 数据集 - HuggingFace](https://huggingface.co/datasets/liminghao1630/DocBank)
18. [Benchmarking VLMs for French PDF-to-Markdown Conversion - arXiv:2602.11960](https://arxiv.org/html/2602.11960)
19. [Evaluating Document Parsing Accuracy - CambioML 博客](https://www.cambioml.com/en/blog/evaluate-document-parsing-accuracy)
20. [深度调研开源 PDF 转 Markdown 工具 - Jimmy Song 博客](https://jimmysong.io/zh/blog/pdf-to-markdown-open-source-deep-dive/)
21. [MarkItDown vs Docling 对比分析 - 掘金](https://juejin.cn/post/7492264852917960754)
22. [MinerU 质量评估方法 - CSDN](https://blog.csdn.net/gitblog_00516/article/details/151124570)
23. [TEDS 指标说明 - deepwiki](https://deepwiki.com/intsig-textin/markdown_tester/4.2-teds-metric-(tree-edit-distance-similarity))
24. [Docling 介绍 - 微信公众号 AI悦创](https://mp.weixin.qq.com/s/xHCO_I_emTZ0y6iLa6SRUQ)
25. [2025 年 PDF 转 Markdown 工具终极指南](https://polly.wang/pdf-to-markdown-tools-comparison-2025/)
