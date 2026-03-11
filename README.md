# MoonBitMark

**用 MoonBit 编写的文档转换工具 - 将多种格式转换为 Markdown**

[![Version](https://img.shields.io/badge/version-0.5.0-orange)]()
[![MoonBit](https://img.shields.io/badge/moonbit-latest-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Code](https://img.shields.io/badge/code-4958%20lines-brightgreen)]()

---

## 📖 项目简介

MoonBitMark 是一个用 MoonBit 语言编写的命令行文档转换工具，支持将 HTML、PDF、DOCX、XLSX 等格式转换为 Markdown。利用 MoonBit 的静态类型系统和编译为原生代码的能力，提供类型安全和高效的转换体验。

---

## ✨ 支持的功能

| 格式 | 状态 | 说明 |
|------|------|------|
| **TXT** | ✅ 完成 | 纯文本读取，UTF-8 支持 |
| **CSV** | ✅ 完成 | 转换为 Markdown 表格 |
| **JSON** | ✅ 完成 | 带语法高亮的代码块 |
| **PDF** | ✅ 完成 | 基于 mbtpdf 库，支持页面分隔 |
| **HTML** | ✅ 完成 | 本地文件 + URL 抓取，支持标题/列表/链接/表格 |
| **DOCX** | ✅ 完成 | 纯 MoonBit (libzip + xml parser) |
| **XLSX** | ✅ 完成 | 纯 MoonBit，支持多工作表、共享字符串 |
| **PPTX** | ⚠️ 部分支持 | 基础结构完成，受动态 Huffman bug 影响 |
| **URL 抓取** | ✅ 完成 | HTTP GET + HTML 转换 |

---

## 🚀 快速开始

### 前置要求

- **MoonBit 工具链**: https://docs.moonbitlang.com
- **MSVC (Windows)**: Visual Studio Build Tools 2022

### 基本用法

```bash
# 编译项目（Release 模式）
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

# URL 抓取
main.exe https://www.moonbitlang.com output.md
```

---

## 📊 项目统计

### 代码行数

| 模块 | MoonBit 代码 |
|------|-------------|
| **核心模块** | 44 行 |
| **TXT 转换器** | 33 行 |
| **CSV 转换器** | 36 行 |
| **JSON 转换器** | 35 行 |
| **PDF 转换器** | 125 行 |
| **HTML 转换器** | 751 行 |
| **DOCX 转换器** | 150 行 |
| **XLSX 转换器** | 450 行 |
| **PPTX 转换器** | 300 行 |
| **libzip (Pure MoonBit)** | 793 行 |
| **xml (Pure MoonBit)** | 200 行 |
| **总计** | **~4,958 行** |

### 测试覆盖

| 测试类型 | 状态 |
|---------|------|
| TXT 转换 | ✅ 通过 |
| CSV 转换 | ✅ 通过 |
| JSON 转换 | ✅ 通过 |
| PDF 转换 | ✅ 通过 |
| HTML 转换 | ✅ 通过 |
| HTML 表格 | ✅ 通过 |
| HTML Unicode | ✅ 通过 |
| DOCX 转换 | ✅ 通过 |
| XLSX 转换 | ✅ 通过 |
| URL 抓取 | ✅ 通过 |

**通过率:** 10/10 (100%)

### 依赖项

```json
{
  "moonbitlang/async": "0.16.7",
  "bobzhang/mbtpdf": "0.1.1"
}
```

### 系统依赖

> **注意:** 项目现已完全使用纯 MoonBit 实现，无需任何 C 库依赖。

如需编译原生版本，Windows 需要 MSVC (Visual Studio Build Tools)。

---

## 🏗️ 技术架构

### 目录结构

```
MoonBitMark/
├── src/
│   ├── core/              # 核心类型和接口
│   │   ├── types.mbt      # 类型定义
│   │   └── engine.mbt     # 转换引擎
│   ├── libzip/            # Pure MoonBit ZIP 库
│   ├── xml/               # Pure MoonBit XML 解析器
│   └── formats/           # 格式转换器
│       ├── text/          # TXT 转换器
│       ├── csv/           # CSV 转换器
│       ├── json/          # JSON 转换器
│       ├── pdf/           # PDF 转换器
│       ├── html/          # HTML 转换器
│       ├── docx/          # DOCX 转换器
│       ├── xlsx/          # XLSX 转换器
│       └── pptx/          # PPTX 转换器
├── cmd/main/              # CLI 入口
├── scripts/               # 构建/测试脚本
├── docs/                  # 文档
└── tests/                 # 测试数据
```

### 设计模式

```
用户输入 → CLI → 检测类型 → 选择转换器 → 读取文件 → 转换 → 输出 Markdown
```

---

## 🔍 与 MarkItDown 对比

MarkItDown 是微软的 Python 文档转换库。MoonBitMark 与其对比：

| 特性 | MarkItDown (Python) | MoonBitMark (MoonBit) |
|------|---------------------|----------------------|
| **语言** | Python | MoonBit |
| **执行方式** | 解释执行 | 编译为原生代码 |
| **类型安全** | ❌ 动态类型 | ✅ 静态类型 |
| **支持格式** | PDF/DOCX/XLSX/PPTX/HTML/等 | TXT/CSV/JSON/PDF/HTML/DOCX/XLSX/PPTX/URL |
| **PDF 支持** | ✅ 完整 | ✅ 完整 (mbtpdf) |
| **DOCX 支持** | ✅ 完整 (mammoth) | ✅ 基础文本提取 (纯 MoonBit) |
| **XLSX 支持** | ✅ 完整 | ✅ 基础表格提取 (纯 MoonBit) |
| **HTML 支持** | ✅ 完整 | ✅ 完整 + URL 抓取 |
| **URL 抓取** | ✅ | ✅ |
| **包大小** | ~50MB+ (Python 环境) | ~5MB (原生二进制) |
| **启动速度** | 较慢 (Python 启动) | 快 (原生执行) |
| **内存占用** | 较高 | 较低 |

### MoonBitMark 优势

- ✅ **类型安全** - 编译时类型检查
- ✅ **性能** - 编译为原生代码，启动快
- ✅ **轻量** - 无 Python 运行时依赖
- ✅ **单文件分发** - 编译后单个可执行文件

### MoonBitMark 差距

- ⚠️ **PPTX 功能有限** - 受动态 Huffman bug 影响
- ⚠️ **DOCX 功能有限** - 仅支持纯文本提取
- ⚠️ **生态系统** - MoonBit 库生态较小
- ⚠️ **社区成熟度** - 项目较新

---

## 🔄 Pure MoonBit libzip vs C libzip 对比

MoonBitMark 项目实现了纯 MoonBit 版本的 libzip 库，作为 C 语言版本的替代方案。

### 功能对比

| 功能 | C libzip | Pure MoonBit libzip | 状态 |
|------|----------|---------------------|------|
| **ZIP 解析** | ✅ | ✅ | 完整 |
| **读取文件条目** | ✅ | ✅ | 完整 |
| **中央目录解析** | ✅ | ✅ | 完整 |
| **CRC32 校验** | ✅ | ✅ | 完整 (IEEE 802.3) |
| **Deflate 解压** | ✅ | ⚠️ | 部分支持 |
| - Stored 块 | ✅ | ✅ | 完整 |
| - Fixed Huffman | ✅ | ✅ | 完整 |
| - Dynamic Huffman | ✅ | ⚠️ | 有 bug |
| **ZIP 写入/创建** | ✅ | ❌ | 不支持 |
| **加密支持** | ✅ | ❌ | 不支持 |
| **更多压缩方法** | ✅ (bzip2, lzma) | ❌ (仅 Deflate) | - |

### 实现差异

| 特性 | C libzip | Pure MoonBit libzip |
|------|----------|---------------------|
| **语言** | C | MoonBit |
| **编译目标** | 原生 | WASM/JS/原生 |
| **内存安全** | ❌ 手动管理 | ✅ 自动管理 |
| **类型安全** | ❌ | ✅ 静态类型 |
| **代码行数** | ~15,000 行 | ~800 行 |
| **外部依赖** | 需要 libzip 库 | 无依赖 |

### 文件结构

```
src/libzip/
├── crc32.mbt        # CRC32 校验 (78 行)
├── deflate.mbt      # Deflate 解压 (715 行)
├── format.mbt      # ZIP 格式常量
├── zip.mbt          # ZIP 解析主逻辑
└── zip_spec.mbt     # API 规范/错误类型
```

### 优势与限制

**Pure MoonBit 优势:**
- ✅ 无需外部 C 库依赖
- ✅ 编译为 WASM 可在浏览器运行
- ✅ 内存安全，无缓冲区溢出风险
- ✅ 代码简洁，易于维护

**当前限制:**
- ⚠️ 动态 Huffman 解压存在 bug
- ⚠️ 仅支持读取，不支持写入
- ⚠️ 不支持加密 ZIP 文件
- ⚠️ 不支持 bzip2/lzma 等其他压缩方法

---

## 🛠️ 开发指南

### 添加新转换器

1. **创建包目录**
```
src/formats/your_format/
├── converter.mbt
└── moon.pkg.json
```

2. **实现转换器接口**
```moonbit
pub struct YourConverter {
  dummy: Int
}

pub fn YourConverter::new() -> YourConverter { ... }

pub fn YourConverter::accepts(info: @core.StreamInfo) -> Bool { ... }

pub async fn YourConverter::convert(file_path: String) -> String raise { ... }
```

3. **在 CLI 中注册** (cmd/main/main.mbt)

### 构建命令

```bash
# 检查类型
moon check

# 编译 (Release 模式，需要 MSVC 环境)
# Windows: 使用 scripts/build_msvc.bat
scripts\build_msvc.bat

# 或手动编译
moon build --target native --release

# 运行（使用编译后的二进制文件）
_build\native\release\build\cmd\main\main.exe <input> [output]
```

### 测试

```bash
# 运行测试
moon test

# 更新快照
moon test --update

# 格式化代码
moon fmt

# 更新接口
moon info
```

---

## 📝 已知限制

### PDF 转换器
- ⚠️ 表格检测有限 (mbtpdf 无单词位置 API)
- ⚠️ 复杂 CJK 字体可能乱码
- ⚠️ 图片 PDF 需要 OCR (不支持)

### HTML 转换器
- ⚠️ 不支持 JavaScript 渲染页面
- ⚠️ CSS 样式识别有限
- ⚠️ 复杂表格降级处理 (colspan/rowspan 注释)

### DOCX 转换器
- ✅ 纯文本提取 - 已完成
- ✅ 纯 MoonBit 实现 - 已完成 (libzip + xml)
- ⚠️ 格式保留 (粗体/斜体) - 待实现
- ⚠️ 表格支持 - 待实现

### XLSX 转换器
- ✅ 基础表格提取 - 已完成
- ✅ 多工作表支持 - 已完成
- ✅ 共享字符串 - 已完成
- ⚠️ 日期格式识别 - 待实现
- ⚠️ 合并单元格 - 待实现

### PPTX 转换器 (部分支持)
- ✅ 基础结构 - 已完成
- ✅ presentation.xml 解析 - 已完成
- ✅ slide XML 解析 - 已完成
- ⚠️ Deflate 动态 Huffman - 有 bug，待修复

---

## 🐛 已知问题

详见 [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)

**最关键问题:** 动态 Huffman 解压在 `src/libzip/deflate.mbt` 有 bug，影响 PPTX 文件处理。

---

## 📚 文档

| 文档 | 说明 |
|------|------|
| [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | 已知问题记录 |
| [docs/libzip-pure-implementation-plan.md](docs/libzip-pure-implementation-plan.md) | libzip 纯 MoonBit 实现计划 |
| [docs/xlsx-converter-development-plan-v2.md](docs/xlsx-converter-development-plan-v2.md) | XLSX 转换器开发计划 |
| [docs/pptx-converter-development-plan.md](docs/pptx-converter-development-plan.md) | PPTX 转换器开发计划 |
| [docs/MOONBIT_DEV_KNOWLEDGE.md](docs/MOONBIT_DEV_KNOWLEDGE.md) | MoonBit 开发核心知识 |
| [docs/MOONBIT_COMMON_ERRORS.md](docs/MOONBIT_COMMON_ERRORS.md) | MoonBit 常见错误速查 |

---

## 📋 更新日志

### v0.5.0 (2026-03-11) - 当前版本

**新增功能:**
- ✅ XLSX 格式支持（多工作表、共享字符串、基础表格）
- ✅ 改进的测试文件结构

**改进:**
- 🔧 XLSX 转换器单元测试
- 🔧 文档更新

### v0.4.0 (2026-03-10)

**新增功能:**
- ✅ PPTX 格式基础结构
- ✅ libzip Deflate 解压 (Fixed Huffman)

**改进:**
- 🔧 纯 MoonBit XML 解析器优化
- 🔧 错误处理增强

### v0.3.0 (2026-03-08)

**新增功能:**
- ✅ HTML 格式支持（本地文件 + URL 抓取）
- ✅ DOCX 格式支持（纯 MoonBit 实现）
- ✅ 完整测试套件

**改进:**
- 🔧 UTF-8 解码优化
- 🔧 CLI 帮助信息更新
- 🔧 MSVC 编译配置完善

### v0.2.0 (2026-03-02)

**新增功能:**
- ✅ PDF 格式支持（基于 mbtpdf 库）
- ✅ 页面自动分隔

### v0.1.0 (2026-03-01)

**初始版本:**
- ✅ TXT、CSV、JSON 格式支持
- ✅ CLI 命令行工具

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

**最后更新:** 2026-03-11
**版本:** 0.5.0
**代码统计:** ~4,958 行 MoonBit
**测试状态:** ✅ 通过
