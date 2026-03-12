# MoonBitMark

**用 MoonBit 编写的文档转换工具 - 将多种格式转换为 Markdown**

[![Version](https://img.shields.io/badge/version-0.6.0-orange)]()
[![MoonBit](https://img.shields.io/badge/moonbit-latest-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Code](https://img.shields.io/badge/code-5311%20lines-brightgreen)]()

---

## 项目简介

MoonBitMark 是一个用 MoonBit 语言编写的命令行文档转换工具，支持将 HTML、PDF、DOCX、XLSX、EPUB 等格式转换为 Markdown。利用 MoonBit 的静态类型系统和编译为原生代码的能力，提供类型安全和高效的转换体验。

**核心特性:**
- 纯 MoonBit 实现，无 FFI 依赖
- 编译为原生代码，启动快速
- 完整的 ZIP/Deflate 解压支持（Store + Fixed/Dynamic Huffman）
- SAX 风格 XML 解析器

---

## 支持的格式

| 格式 | 状态 | 说明 |
|------|------|------|
| **TXT** | ✅ 完成 | 纯文本读取，UTF-8 支持 |
| **CSV** | ✅ 完成 | 转换为 Markdown 表格 |
| **JSON** | ✅ 完成 | 带语法高亮的代码块 |
| **PDF** | ✅ 完成 | 基于 mbtpdf 库，支持页面分隔 |
| **HTML** | ✅ 完成 | 本地文件 + URL 抓取 |
| **DOCX** | ✅ 完成 | 纯 MoonBit (libzip + xml parser) |
| **XLSX** | ✅ 完成 | 纯 MoonBit，多工作表、共享字符串 |
| **EPUB** | ✅ 完成 | 纯 MoonBit，支持 Deflate 压缩 |
| **PPTX** | ✅ 完成 | 纯 MoonBit，支持 Deflate 压缩 |
| **URL 抓取** | ✅ 完成 | HTTP GET + HTML 转换 |

---

## 快速开始

### 前置要求

- **MoonBit 工具链**: https://docs.moonbitlang.com
- **MSVC (Windows)**: Visual Studio Build Tools 2022

### 基本用法

```bash
# 编译项目（Release 模式）
scripts\build_msvc.bat

# 或手动编译
moon build --target native --release

# 转换文件
_build\native\release\build\cmd\main\main.exe input.html output.md

# 从 URL 抓取并转换
_build\native\release\build\cmd\main\main.exe https://example.com/page.html output.md

# 输出到控制台
_build\native\release\build\cmd\main\main.exe document.pdf
```

### 格式示例

```bash
# HTML 转换
main.exe page.html output.md

# PDF 转换
main.exe document.pdf output.md

# DOCX 转换
main.exe document.docx output.md

# XLSX 转换
main.exe spreadsheet.xlsx output.md

# EPUB 转换
main.exe book.epub output.md

# PPTX 转换
main.exe presentation.pptx output.md

# URL 抓取
main.exe https://www.moonbitlang.com output.md
```

---

## 项目统计

### 代码行数

| 模块 | 代码行数 |
|------|----------|
| **核心模块** | 58 行 |
| **libzip (Pure MoonBit)** | 1,453 行 |
| **xml (Pure MoonBit)** | 880 行 |
| **TXT 转换器** | 38 行 |
| **CSV 转换器** | 79 行 |
| **JSON 转换器** | 49 行 |
| **PDF 转换器** | 136 行 |
| **HTML 转换器** | 819 行 |
| **DOCX 转换器** | 243 行 |
| **XLSX 转换器** | 580 行 |
| **PPTX 转换器** | 582 行 |
| **EPUB 转换器** | 394 行 |
| **MCP 模块** 🆕 | ~1,410 行 |
| **总计** | **~6,721 行** |

### 依赖项

```json
{
  "moonbitlang/async": "文件系统、HTTP 客户端",
  "bobzhang/mbtpdf": "PDF 文本提取"
}
```

### 系统依赖

> **注意:** 项目完全使用纯 MoonBit 实现，无需任何 C 库依赖。

如需编译原生版本，Windows 需要 MSVC (Visual Studio Build Tools)。

---

## 技术架构

### 目录结构

```
MoonBitMark/
├── src/
│   ├── core/              # 核心类型和接口
│   ├── libzip/            # Pure MoonBit ZIP 库
│   │   ├── crc32.mbt      # CRC32 校验
│   │   ├── deflate.mbt    # Deflate 解压 (Store + Fixed + Dynamic Huffman)
│   │   └── zip.mbt        # ZIP 解析
│   ├── xml/               # Pure MoonBit XML 解析器
│   │   ├── types.mbt      # 类型定义
│   │   ├── tokenizer.mbt  # 词法分析
│   │   └── package.mbt    # SAX 解析
│   └── formats/           # 格式转换器
│       ├── text/          # TXT
│       ├── csv/           # CSV
│       ├── json/          # JSON
│       ├── pdf/           # PDF
│       ├── html/          # HTML + URL
│       ├── docx/          # DOCX
│       ├── xlsx/          # XLSX
│       ├── pptx/          # PPTX
│       └── epub/          # EPUB
├── cmd/main/              # CLI 入口
├── scripts/               # 构建/测试脚本
└── docs/                  # 文档
```

### 转换流程

```
用户输入 → CLI → 检测类型 → 选择转换器 → 读取文件 → 转换 → 输出 Markdown
```

### DOCX/EPUB/PPTX 转换流程

```
文件 → ZIP 解析 (libzip) → Deflate 解压 → XML 解析 (xml) → Markdown
```

---

## Pure MoonBit libzip 实现

MoonBitMark 包含一个完整的纯 MoonBit ZIP 库实现：

### 功能支持

| 功能 | 状态 |
|------|------|
| ZIP 结构解析 | ✅ |
| Store 解压 (无压缩) | ✅ |
| Deflate - Fixed Huffman | ✅ |
| Deflate - Dynamic Huffman | ✅ |
| CRC32 校验 | ✅ |
| UTF-8 文件名 | ✅ |

### 优势

- 无需外部 C 库依赖
- 编译为 WASM 可在浏览器运行
- 内存安全，无缓冲区溢出风险
- 代码简洁，约 1,453 行

---

## 开发指南

### 构建命令

```bash
# 检查类型
moon check

# 编译 (Windows)
scripts\build_msvc.bat

# 运行测试
moon test

# 更新快照
moon test --update

# 格式化代码
moon fmt

# 更新接口
moon info && moon fmt
```

### 添加新转换器

1. 创建包目录 `src/formats/your_format/`
2. 实现 `converter.mbt`:
   - `accepts(info: @core.StreamInfo) -> Bool`
   - `convert(file_path: String) -> String raise`
3. 在 `cmd/main/main.mbt` 注册

---

## 已知限制

### PDF 转换器
- 表格检测有限 (mbtpdf 无单词位置 API)
- 复杂 CJK 字体可能乱码
- 图片 PDF 需要 OCR (不支持)

### HTML 转换器
- 不支持 JavaScript 渲染页面
- CSS 样式识别有限
- 复杂表格降级处理

### DOCX 转换器
- 仅支持纯文本提取
- 不支持格式保留（粗体/斜体）
- 不支持表格

### XLSX 转换器
- 不支持日期格式识别
- 不支持合并单元格
- 不支持公式计算

### EPUB 转换器
- 提取标题、作者、语言等元数据
- 提取章节内容
- 不支持图片提取

### PPTX 转换器
- 提取幻灯片文本内容
- 不支持图片提取
- 不支持动画/过渡效果

---

## 文档

| 文档 | 说明 |
|------|------|
| [KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | 已知问题记录 |
| [MOONBIT_DEV_KNOWLEDGE.md](docs/MOONBIT_DEV_KNOWLEDGE.md) | MoonBit 开发知识 |
| [libzip-pure-implementation-plan.md](docs/libzip-pure-implementation-plan.md) | libzip 实现计划 |
| [epub-converter-development-plan.md](docs/epub-converter-development-plan.md) | EPUB 转换器计划 |

---

## 更新日志

### v0.7.0 (2026-03-12) - 当前版本 🆕

**新增功能:**
- **MCP 服务器支持** - 实现 Model Context Protocol 服务器
  - 完整的 JSON-RPC 2.0 协议支持
  - STDIO 传输层实现
  - `convert_to_markdown` 工具
  - 完整的 MCP 协议处理 (initialize, tools/list, tools/call)
  - **完整的 JSON 解析器** 🆕
  - **转换器桥接** 🆕
  - **错误处理和日志** 🆕
- **新增模块:**
  - `src/mcp/types/` - MCP 和 JSON-RPC 类型定义
  - `src/mcp/transport/` - STDIO 传输层
  - `src/mcp/handler/` - MCP 请求处理和工具注册
  - `src/mcp/util/` - 日志和错误处理 🆕
  - `cmd/mcp-server/` - MCP 服务器 CLI 入口

**文档更新:**
- [MCP 服务器使用指南](docs/mcp-server-usage.md)
- [MCP 服务设计文档](docs/mcp-service-design.md)
- [MCP 实现总结](docs/mcp-implementation-summary.md)
- [短期改进完成总结](docs/short-term-improvements-summary.md) 🆕

**技术实现:**
- 完整的 MCP 协议框架 (约 1,410 行代码) 🆕
- 完整的 JSON 解析器 (递归下降解析器) 🆕
- 转换器桥接模块 (支持所有格式) 🆕
- 类型安全的错误处理和日志系统 🆕
- 类型安全的工具注册和调用
- Claude Desktop 集成支持

**已知限制:**
- JSON 解析器: Unicode 转义未完全实现,不支持科学计数法
- 异步支持: 转换器桥接需要异步运行时
- 日志时间戳: 使用占位符实现
- 仅支持 STDIO 传输,HTTP/SSE 传输待实现

### v0.6.0 (2026-03-11)

**新增功能:**
- EPUB 格式支持（纯 MoonBit 实现）
- PPTX 完整支持（Dynamic Huffman bug 已修复）

**Bug 修复:**
- 修复 Deflate 滑动窗口复制 bug
- 修复 Dynamic Huffman 解压输出损坏问题

**改进:**
- 更新调试方法论文档
- 完善测试覆盖

### v0.5.0 (2026-03-11)

**新增功能:**
- XLSX 格式支持（多工作表、共享字符串）

### v0.4.0 (2026-03-10)

**新增功能:**
- PPTX 格式基础结构
- libzip Deflate 解压 (Fixed Huffman)

### v0.3.0 (2026-03-08)

**新增功能:**
- HTML 格式支持（本地文件 + URL 抓取）
- DOCX 格式支持（纯 MoonBit 实现）

### v0.2.0 (2026-03-02)

**新增功能:**
- PDF 格式支持（基于 mbtpdf 库）

### v0.1.0 (2026-03-01)

**初始版本:**
- TXT、CSV、JSON 格式支持
- CLI 命令行工具

---

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

**最后更新:** 2026-03-12 | **版本:** 0.7.0 | **代码:** 6,721 行
