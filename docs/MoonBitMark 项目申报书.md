# MoonBitMark 项目申报书

**参赛项目：** MoonBitMark —— 基于 MoonBit 的文档转换工具  
**参赛类别：** 软件合成赛道  
**提交日期：** 2026 年 3 月 8 日  
**项目版本：** 0.3.0 (MVP)

---

## （1）项目目标与应用场景

### 项目目标

MoonBitMark 旨在用 MoonBit 编程语言复刻并优化微软 MarkItDown 项目的核心功能，提供一个**高性能、类型安全、跨平台**的文档转换工具。项目将多种常见文档格式（HTML、PDF、DOCX、XLSX、PPTX 等）转换为统一的 Markdown 格式，服务于知识管理、文档归档、内容迁移等场景。

### 拟解决的实际问题

1. **文档格式碎片化** - 用户面临多种文档格式（PDF、Word、Excel、PPT、HTML），难以统一管理和检索
2. **现有工具依赖重** - MarkItDown 等 Python 工具需要完整的 Python 运行时，部署复杂，启动慢
3. **跨平台体验不一致** - 现有工具在不同平台上表现差异大，依赖管理复杂
4. **类型安全缺失** - 动态语言编写的转换工具缺乏编译时类型检查，运行时错误频发

### 应用场景

| 场景 | 描述 |
|------|------|
| **知识库构建** | 将企业文档库批量转换为 Markdown，接入知识库系统 |
| **内容迁移** | 从 Word/PDF 迁移到 Markdown 驱动的文档系统（如 GitBook、Docusaurus） |
| **AI 数据预处理** | 为 LLM 训练/推理准备统一的 Markdown 格式数据 |
| **个人知识管理** | 将收集的各类文档统一为 Markdown，便于 Obsidian/Logseq 管理 |
| **自动化工作流** | 集成到 CI/CD 流程，自动转换上传的文档 |

---

## （2）交付物说明

### 核心功能与功能边界（Scope）

#### 已实现功能（MVP v0.3.0）

| 功能模块 | 状态 | 说明 |
|---------|------|------|
| **TXT 转换** | ✅ 完成 | 纯文本读取，UTF-8 编码处理 |
| **CSV 转换** | ✅ 完成 | 转换为 Markdown 表格 |
| **JSON 转换** | ✅ 完成 | 带语法高亮的代码块输出 |
| **PDF 转换** | ✅ 完成 | 基于 mbtpdf 库，支持页面分隔、MasterFormat 合并 |
| **HTML 转换** | ✅ 完成 | 本地文件 + URL 抓取，支持标题/列表/链接/图片/表格 |
| **DOCX 转换** | 🚧 部分完成 | FFI 绑定完成，纯文本提取可用 |
| **CLI 工具** | ✅ 完成 | 命令行界面，支持文件/URL 输入 |

#### 计划实现功能（v0.4.0 - v1.0.0）

| 功能模块        | 优先级 | 说明                                     |
| ----------- | --- | -------------------------------------- |
| **DOCX 完善** | P0  | 标题识别、列表支持、表格提取、格式保留                    |
| **EPUB 转换** | P1  | FFI 实现，支持电子书转换                         |
| **XLSX 转换** | P1  | FFI 实现，支持 Excel 表格转换                   |
| **PPTX 转换** | P1  | FFI 实现，支持幻灯片转换                         |
| **MCP 服务**  | P0  | 提供 Model Context Protocol 服务，供 AI 助手调用 |
| **批量转换**    | P2  | 支持目录递归转换                               |
| **配置系统**    | P2  | 支持自定义转换规则                              |
| **OCR 功能**  | P2  | OCR 功能（图片 PDF 文字识别）                    |

#### 功能边界（不在 Scope 内）

- ❌ 手写公式识别
- ❌ 复杂布局还原（多栏、图文混排精确还原）
- ❌ 视频/音频内容提取
- ❌ 加密文档解密（除标准 PDF 加密外）

### 预期使用方式与交互流程

#### 命令行使用

```bash
# 单个文件转换
moonbitmark input.pdf output.md

# URL 抓取转换
moonbitmark https://example.com/page.html output.md

# 批量转换
moonbitmark --batch ./documents/ ./output/

# 使用 MCP 服务（AI 助手调用）
moonbitmark --mcp-server
```

#### 交互流程

```
用户输入 → 格式检测 → 选择转换器 → 读取内容 → 格式转换 → 输出 Markdown
                ↓
           MCP 服务（可选）
                ↓
         AI 助手直接调用
```

### 初步测试规划

#### 单元测试

| 模块 | 测试内容 | 状态 |
|------|---------|------|
| 核心类型 | StreamInfo、ConvertResult 序列化 | ⏸️ 计划 |
| TXT 转换器 | 编码处理、空文件处理 | ⏸️ 计划 |
| CSV 转换器 | 边界情况、特殊字符转义 | ⏸️ 计划 |
| HTML 转换器 | 各 HTML 元素转换正确性 | ⏸️ 计划 |
| PDF 转换器 | 多语言文档、加密检测 | ✅ 部分完成 |
| DOCX 转换器 | FFI 调用、XML 解析 | ⏸️ 计划 |

#### 集成测试

| 测试场景 | 测试文件 | 预期结果 |
|---------|---------|---------|
| 英文 PDF 文档 | test.pdf | 文本完整提取，页面分隔正确 |
| Unicode 文档 | test_unicode.pdf | 无乱码 |
| 日文文档 | test_japanese.pdf | CJK 字符正确 |
| HTML 页面 | test.html | 结构保留，链接正确 |
| URL 抓取 | https://example.com | 网络错误处理 |
| DOCX 文档 | test.docx | 文本提取正确 |

#### 性能测试

- 小文件（<1MB）：转换时间 <1 秒
- 中文件（1-10MB）：转换时间 <5 秒
- 大文件（>10MB）：转换时间 <30 秒
- 内存占用：<100MB

### 文档与使用说明覆盖范围

| 文档类型 | 状态 | 位置 |
|---------|------|------|
| README.md | ✅ 完成 | 项目根目录 |
| 用户指南 | ✅ 完成 | docs/README_DOCX.md |
| 开发知识 | ✅ 完成 | docs/MOONBIT_DEV_KNOWLEDGE.md |
| 常见错误 | ✅ 完成 | docs/MOONBIT_COMMON_ERRORS.md |
| API 文档 | ⏸️ 计划 | 待生成 |
| MCP 服务文档 | ⏸️ 计划 | 待编写 |

---

## （3）技术路线说明

### 整体系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      MoonBitMark                            │
├─────────────────────────────────────────────────────────────┤
│  CLI 层                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ 文件输入    │  │ URL 抓取     │  │ MCP 服务    │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
├─────────┴────────────────┴────────────────┴─────────────────┤
│  转换引擎层                                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  格式检测 → 转换器选择 → 执行转换 → 输出处理        │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  转换器层（Formats）                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│  │ TXT  │ │ CSV  │ │ JSON │ │ PDF  │ │ HTML │ │ DOCX │   │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘   │
│  ┌──────┐ ┌──────┐ ┌──────┐                               │
│  │ EPUB │ │ XLSX │ │ PPTX │  (计划)                      │
│  └──────┘ └──────┘ └──────┘                               │
├─────────────────────────────────────────────────────────────┤
│  核心层（Core）                                              │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ 类型定义        │  │ 转换引擎        │                  │
│  │ StreamInfo      │  │ MarkItDown      │                  │
│  │ ConvertResult   │  │                 │                  │
│  └─────────────────┘  └─────────────────┘                  │
├─────────────────────────────────────────────────────────────┤
│  依赖层                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ moonbitlang  │  │ mbtpdf       │  │ FFI C 库      │     │
│  │ /async       │  │              │  │ libzip/expat │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### 核心模块划分

| 模块 | 路径 | 代码量 | 职责 |
|------|------|--------|------|
| **核心类型** | src/core/types.mbt | 20 行 | 定义 StreamInfo、ConvertResult、DocumentConverter 接口 |
| **转换引擎** | src/core/engine.mbt | 15 行 | MarkItDown 主引擎（待完善） |
| **TXT 转换器** | src/formats/text/ | 33 行 | 纯文本读取 |
| **CSV 转换器** | src/formats/csv/ | 36 行 | CSV→Markdown 表格 |
| **JSON 转换器** | src/formats/json/ | 35 行 | JSON→代码块 |
| **PDF 转换器** | src/formats/pdf/ | 125 行 | PDF 文本提取（mbtpdf） |
| **HTML 转换器** | src/formats/html/ | 751 行 | HTML→Markdown + URL 抓取 |
| **DOCX 转换器** | src/formats/docx/ | 158 行 | DOCX→Markdown（FFI） |
| **C 存根代码** | src/formats/docx/ffi/stub.c | 350 行 | libzip/expat 绑定 |

### 大模型与智能体工具在开发过程中的作用

在本项目开发过程中，大模型与智能体工具发挥了以下作用：

1. **代码生成辅助**
   - 生成重复性代码（如各转换器的 accepts/convert 模板）
   - 辅助编写 FFI 绑定代码（C 存根函数）
   - 生成单元测试框架代码

2. **错误诊断与修复**
   - 分析 MoonBit 编译错误信息
   - 提供类型错误修复建议
   - 解释 MoonBit 语言特性

3. **文档生成**
   - 自动生成 API 文档草稿
   - 编写用户使用示例
   - 生成技术调研报告

4. **代码审查**
   - 识别潜在的类型安全问题
   - 建议代码优化方案
   - 检查错误处理完整性

### 关键技术选型说明

| 技术选择 | 选型理由 |
|---------|---------|
| **MoonBit 语言** | 静态类型、编译为原生、类型安全、高性能 |
| **mbtpdf 库** | MoonBit 原生 PDF 库，无需 FFI |
| **libzip + expat** | 成熟 C 库，MoonBit 无原生 ZIP/XML 库 |
| **MSVC 编译** | Windows 平台 async 库要求 |
| **MCP 协议** | AI 助手标准化调用接口 |

---

## （4）风险分析与应对方案

### 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| **MoonBit 生态不成熟** | 缺少必要的库（ZIP/XML） | 高 | 使用 FFI 绑定成熟 C 库 |
| **FFI 绑定复杂性** | 内存管理、类型转换错误 | 中 | 参考官方 moonbit-c-binding 示例，编写充分测试 |
| **跨平台编译问题** | 不同平台 C 库链接差异 | 中 | 使用 vcpkg 统一管理依赖，提供各平台构建脚本 |
| **PDF 解析质量** | 复杂 PDF 提取效果差 | 中 | 使用 mbtpdf 库优化，添加后处理逻辑 |
| **DOCX 格式兼容性** | 非标准 DOCX 无法解析 | 中 | 使用 libzip 标准 ZIP 解析，添加错误处理 |
| **MCP 服务稳定性** | 服务崩溃影响 AI 调用 | 低 | 添加健康检查、自动重启机制 |

### 应对方案汇总（AI 技术驱动）

本项目充分发挥 AI 技术在软件开发中的赋能作用，采用以下应对方案：

#### 1. 大模型辅助开发

- **更聪明的大模型** - 使用 advanced coding models（如 GPT 5.4）进行代码生成和审查
- **上下文理解** - 利用大模型的长上下文能力，保持项目整体架构一致性
- **错误分析** - 使用 AI 分析编译错误和运行时问题，快速定位根因

#### 2. AI 编程工具

- **智能代码生成** - 使用原生 AI 编程工具（如 codex、claude code）提高编码效率
- **自动代码审查** - 使用 AI 工具进行代码质量检查和最佳实践建议
- **智能重构** - 借助 AI 工具进行代码重构和优化

#### 3. 智能体协作

- **任务分解智能体** - 将复杂任务分解为可执行的小步骤
- **测试生成智能体** - 自动生成单元测试和集成测试用例
- **文档生成智能体** - 自动同步代码变更生成文档

#### 4. Spec 驱动的 AI 开发

- **规格优先（Specification-First）** - 先定义详细的规格说明书（包括功能需求、接口定义、数据结构、行为约束），再让 AI 根据规格生成代码
- **文档讨论迭代** - 与 AI 多轮讨论完善规格文档，确保需求理解一致，将所有要求落实到文档中
- **规格验证** - AI 生成的代码必须通过规格定义的验收标准，确保实现与需求一致

#### 5. 技术验证与迭代

- **快速原型** - 使用 AI 快速生成原型代码进行技术验证
- **渐进式开发** - 先实现 MVP，再通过 AI 辅助逐步完善功能
- **持续集成** - 利用 AI 生成 CI/CD 配置，自动化测试和部署

#### 6. 知识管理与复用

- **AI 知识库** - 建立项目专属的 AI 知识库，存储技术决策和经验教训
- **代码片段库** - 使用 AI 整理和归类可复用的代码片段
- **最佳实践总结** - 定期使用 AI 总结开发过程中的最佳实践

---

## （5）相关研究与实践基础

### 参考项目

| 项目 | 说明 | 参考内容 |
|------|------|---------|
| **MarkItDown** (微软) | Python 文档转换库 | 功能设计、支持格式、转换逻辑 |
| **mammoth** | DOCX→HTML 转换库 | DOCX 解析思路 |
| **pandoc** | 通用文档转换器 | 架构设计、格式支持 |
| **moonbit-c-binding** | MoonBit FFI 示例 | FFI 绑定最佳实践 |

### 技术现状理解

#### 文档转换领域

- **Python 生态主导** - MarkItDown、mammoth、python-docx 等均为 Python 实现
- **依赖复杂** - 需要安装多个 Python 包，环境配置复杂
- **性能瓶颈** - 解释执行，启动慢，内存占用高
- **类型安全问题** - 动态类型导致运行时错误频发

#### MoonBit 语言优势

- **类型安全** - 编译时类型检查，减少运行时错误
- **高性能** - 编译为原生代码，执行效率高
- **轻量部署** - 单二进制文件，无运行时依赖
- **现代特性** - 模式匹配、错误处理、异步支持

### 既有工程实践

本项目基于以下既有实践：

1. **MoonBit 异步编程** - 使用 moonbitlang/async 库进行文件/网络操作
2. **FFI 绑定模式** - 参考官方示例绑定 libzip/expat
3. **PDF 处理经验** - 基于 mbtpdf 库实现 PDF 转换
4. **HTML 解析实践** - 纯 MoonBit 实现 HTML→Markdown 转换

---

## （6）个人背景与项目匹配度

### MoonBit 编程实践经历

作为一个关注 MoonBit 编程生态的开发者，在开发 MoonBitMark 项目的过程中，我深入使用了 MoonBit 语言的核心特性和生态系统工具，积累了以下实践经验：

### 使用的 MoonBit 标准库

| 库 | 用途 | 评价 |
|----|------|------|
| **moonbitlang/async** (v0.16.7) | 异步文件操作、HTTP 请求 | 异步 API 设计清晰，与 Rust async/await 类似 |
| **moonbitlang/async/fs** | 文件读取 | 简化了文件 I/O 操作 |
| **moonbitlang/async/http** | URL 抓取功能 | 实现了 HTTP GET 请求和响应处理 |
| **moonbitlang/async/io** | Data/Bytes 转换 | `data.text()` 方法自动 UTF-8 解码，非常便捷 |
| **moonbitlang/core** | 基础类型和操作 | 标准库设计合理 |
| **bobzhang/mbtpdf** | PDF 解析 | MoonBit 原生 PDF 库，无需 FFI |

### MoonBit 语言特色与优势特性

#### 1. 静态类型系统

```moonbit
// 类型注解强制完整，编译时检查
pub struct ConvertResult {
  markdown: String
  title: Option[String]
  metadata: Map[String, String]
} derive(Show, Eq, ToJson)
```

**优势：** 编译时捕获类型错误，减少运行时异常。

#### 2. 错误处理机制

```moonbit
// 显式声明可能抛出错误的函数
pub async fn convert(file_path: String) -> String raise {
  let file = @fs.open(file_path, mode=ReadOnly)
  // 错误自动向上传播
}
```

**优势：** 错误处理明确，`raise` 关键字让错误传播路径清晰。

#### 3. 模式匹配

```moonbit
// 优雅的处理 Option 类型
match info.extension {
  Some(ext) => ext.to_lower() == ".pdf"
  None => false
}
```

**优势：** 比 if-else 更清晰，编译器检查 exhaustiveness。

#### 4. FFI 支持

```moonbit
// 直接声明 C 函数
extern "c" {
  fn zip_open(path: String) -> ZipHandle
  fn zip_read(handle: ZipHandle, name: String) -> Bytes
}
```

**优势：** 可以复用成熟的 C 库生态，弥补 MoonBit 库生态的不足。

#### 5. 方法调用语法

```moonbit
// 链式调用，代码简洁
let result = s.trim().to_lower().split(",")
```

**优势：** 代码可读性好，类似 Rust 的链式调用。

### MoonBit 生态链工具及使用体验

| 工具 | 用途 | 使用体验 |
|------|------|---------|
| **moon** | 包管理、编译、运行 | 命令简洁，类似 cargo |
| **moon check** | 类型检查 | 快速发现类型错误 |
| **moon build** | 编译为原生 | 支持 MSVC/MinGW |
| **moon run** | 运行项目 | 开发调试方便 |
| **moon add** | 添加依赖 | 自动解析依赖树 |
| **moon doc** | 查看文档 | 快速查阅包 API |
| **moon clean** | 清理构建缓存 | 解决缓存问题 |

### 开发过程中的收获

1. **类型安全的价值** - 多次在编译阶段发现潜在错误，避免运行时问题
2. **FFI 绑定的能力** - 成功绑定 libzip/expat，证明 MoonBit 可以调用现有 C 库
3. **异步编程的便利** - async/await 语法让异步代码像同步代码一样易读
4. **错误处理的清晰** - `raise` 机制让错误传播路径一目了然

### 项目匹配度总结

| 维度 | 匹配情况 |
|------|---------|
| **语言能力** | 熟练掌握 MoonBit 语法和核心特性 |
| **工具使用** | 熟练使用 moon 工具链 |
| **FFI 经验** | 成功实现 libzip/expat 绑定 |
| **项目规模** | 已完成 1500+ 行 MoonBit 代码 |
| **问题解决** | 独立解决编译、类型、FFI 等问题 |

---

## （7）补充材料

### 项目仓库

- **本地路径：** `D:\MySoftware\MoonBitMark\`
- **代码统计：** ~1,182 行 MoonBit + ~350 行 C
- **测试状态：** 9/9 测试通过 (100%)

### 技术架构图

```
用户/CLI/MCP
      │
      ▼
┌─────────────────┐
│  格式检测层     │
│  (extension/    │
│   mimetype)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  转换器路由     │
│  (accepts())    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  转换器执行     │
│  (convert())    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  输出处理       │
│  (Markdown)     │
└─────────────────┘
```

### 核心代码示例

#### 转换器接口

```moonbit
pub(open) trait DocumentConverter {
  accepts(StreamInfo) -> Bool
  convert(String) -> ConvertResult raise
}
```

#### HTML 转换器（URL 抓取）

```moonbit
pub async fn convert_from_url(url: String) -> String raise {
  let (response, data) = @http.get(url)
  if response.code != 200 {
    fail("HTTP request failed: " + response.code.to_string())
  }
  let html = data.text()  // 自动 UTF-8 解码
  html_to_markdown(html)
}
```

#### DOCX FFI 绑定

```moonbit
extern "c" {
  fn moonbit_convert_docx_file(path: Bytes) -> Option[Bytes]
}

pub async fn DocxConverter::convert(file_path: String) -> String raise {
  let result = @expat.convert_docx_file(file_path)
  if result.length() > 0 {
    result.trim().to_string()
  } else {
    fail("No text content found in DOCX")
  }
}
```

### 测试数据

| 测试类型         | 文件数   | 状态       |
| ------------ | ----- | -------- |
| PDF 英文文档     | 1     | ✅ 通过     |
| PDF Unicode  | 1     | ✅ 通过     |
| PDF 日文文档     | 1     | ✅ 通过     |
| HTML 基础      | 1     | ✅ 通过     |
| HTML 复杂表格    | 1     | ✅ 通过     |
| HTML Unicode | 1     | ✅ 通过     |
| DOCX 基础  | 1 | ✅ 通过 |
| URL 抓取       | 1     | ✅ 通过     |

### 参考链接

- MoonBit 官方文档：https://docs.moonbitlang.com
- MoonBit 包仓库：https://mooncakes.io
- MarkItDown 项目：https://github.com/microsoft/markitdown
- MCP 协议：https://modelcontextprotocol.io

---

## 附录：项目时间规划

| 阶段 | 时间 | 目标 |
|------|------|------|
| **MVP 完成** | 2026-03-07 | 基础功能可用（当前状态） |
| **DOCX 完善** | 2026-03-14 | 标题/列表/表格支持 |
| **MCP 服务** | 2026-03-21 | 提供 MCP 接口 |
| **EPUB/XLSX/PPTX** | 2026-03-31 | FFI 实现 |
| **测试完善** | 2026-04-07 | 单元测试 + 集成测试 |
| **发布 v1.0** | 2026-04-14 | 跨平台二进制发布 |

---

**申报书版本：** 1.1  
**撰写日期：** 2026 年 3 月 8 日  
**项目状态：** MVP 完成，所有测试通过 (9/9)
