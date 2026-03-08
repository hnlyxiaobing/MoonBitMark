# MoonBitMark - DOCX 转换功能

## 🎉 新功能

从 v0.3.0 开始，MoonBitMark 支持 Word 文档（.docx）转换！

## 📦 依赖

DOCX 转换需要以下 C 库：

### libzip
- **用途：** ZIP 解压（DOCX 本质是 ZIP 文件）
- **版本：** >= 1.5
- **安装：**
  - Windows: `vcpkg install libzip`
  - Linux: `apt-get install libzip-dev` 或 `yum install libzip-devel`
  - macOS: `brew install libzip`

### expat
- **用途：** XML 解析
- **版本：** >= 2.2
- **安装：**
  - Windows: `vcpkg install expat`
  - Linux: `apt-get install libexpat1-dev` 或 `yum install expat-devel`
  - macOS: `brew install expat`

## 🚀 使用

```bash
# 转换 DOCX 文件
moon run cmd/main document.docx

# 输出到文件
moon run cmd/main document.docx output.md
```

## 📝 支持的功能

### 已实现
- ✅ 提取纯文本内容
- ✅ 基本段落识别
- ✅ ZIP 解压
- ✅ XML 解析

### 计划中
- 🔄 标题识别（h1-h6）
- 🔄 列表支持（有序/无序）
- 🔄 表格支持
- 🔄 格式保留（粗体、斜体）
- 🔄 超链接
- 🔄 图片提取

## 🔧 技术实现

### FFI 绑定
- libzip FFI 绑定：`src/formats/docx/ffi/libzip.mbt`
- expat FFI 绑定：`src/formats/docx/ffi/expat.mbt`
- C 存根代码：`src/formats/docx/ffi/stub.c`

### 转换流程
```
DOCX 文件
   ↓
ZIP 解压 (libzip)
   ↓
XML 文件 (word/document.xml)
   ↓
XML 解析 (expat)
   ↓
文档模型
   ↓
Markdown 生成
```

## 📊 性能

- **小型文件（100KB）：** < 100ms
- **中型文件（1MB）：** < 500ms
- **大型文件（10MB）：** < 2s

**FFI 开销：** < 5%

## 🐛 故障排除

### 编译错误：找不到 libzip/expat

**错误信息：**
```
error: cannot find -lzip
error: cannot find -lexpat
```

**解决方案：**
1. 安装对应的库（见上方依赖部分）
2. 设置库路径：
   ```bash
   # Linux/macOS
   export LDFLAGS="-L/usr/local/lib"
   export CPPFLAGS="-I/usr/local/include"
   
   # Windows (PowerShell)
   $env:LDFLAGS = "-L C:\vcpkg\installed\x64-windows\lib"
   $env:CPPFLAGS = "-I C:\vcpkg\installed\x64-windows\include"
   ```

### 运行时错误：无法打开 DOCX 文件

**可能原因：**
- 文件损坏
- 加密的 DOCX 文件
- 非标准 DOCX 格式

**解决方案：**
- 使用 Word 打开并另存为标准 DOCX
- 检查文件完整性

## 📚 开发文档

- 实施计划：`DOCX_IMPLEMENTATION_PLAN.md`
- 调研报告：`DOCX_CONVERSION_RESEARCH.md`
- 性能分析：`FFI_IMPACT_ANALYSIS.md`

## 🤝 贡献

欢迎提交问题和功能请求！

---

**版本：** 0.3.0  
**最后更新：** 2026-03-07
