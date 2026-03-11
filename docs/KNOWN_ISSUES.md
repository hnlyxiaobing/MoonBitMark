# 已知问题记录

> 记录 MoonBitMark 项目中尚未解决的问题

---

## 🟡 中优先级问题

### 2. PPTX 文件转换 - 动态 Huffman 压缩文件

**状态**: ✅ 已解决
**解决日期**: 2026-03-11
**相关文件**: `src/libzip/deflate.mbt`

**问题描述**:
大多数 PPTX 文件使用动态 Huffman 压缩，导致转换失败。只有使用 Store 或固定 Huffman 压缩的 PPTX 文件可以正常转换。

**解决方案**:
修复了 `decompress_dynamic_huffman` 和 `decompress_fixed_huffman` 中的滑动窗口复制 bug。问题是在复制循环中 `window_pos` 被修改导致 `src_pos` 计算错误。

修复前的错误代码：
```moonbit
for j in 0..<length {
  let src_pos = (window_pos - distance + j) & 0x7FFF  // BUG: window_pos 变化！
  ...
  window_pos = (window_pos + 1) & 0x7FFF
}
```

修复后的正确代码：
```moonbit
let copy_start = window_pos - distance
for j in 0..<length {
  let src_pos = (copy_start + j) & 0x7FFF  // 正确：使用固定起始位置
  ...
  window_pos = (window_pos + 1) & 0x7FFF
}
```

---

## 🟢 低优先级问题

### 3. 编译警告清理

**状态**: 待清理
**相关文件**: 多个文件

**问题描述**:
存在一些编译警告：
- `unused_error_type`: 未使用的错误类型
- `unused_value`: 未使用的变量
- `reserved_keyword`: 使用保留关键字 `local`

**影响**: 仅编译警告，不影响功能

---

### 4. DOCX 功能限制

**状态**: 功能限制
**相关文件**: `src/formats/docx/`

**问题描述**:
DOCX 转换器目前仅支持纯文本提取：
- ❌ 不支持格式保留（粗体/斜体）
- ❌ 不支持表格
- ❌ 不支持图片

---

### 5. XLSX 功能限制

**状态**: 功能限制
**相关文件**: `src/formats/xlsx/`

**问题描述**:
XLSX 转换器目前支持基础功能：
- ✅ 多工作表支持
- ✅ 共享字符串
- ✅ 基础数据类型（字符串、数字、布尔值）
- ❌ 不支持样式（日期/货币格式）
- ❌ 不支持合并单元格
- ❌ 不支持公式计算

---

## ✅ 已解决问题

### 6. XLSX 转换器开发 (2026-03-11)

**状态**: ✅ 已解决
**相关文件**: `src/formats/xlsx/`

**问题描述**:
需要实现 XLSX 格式的转换支持。

**解决方案**:
1. 实现 `XlsxConverter` 转换器
2. 使用 SAX 风格 XML 解析器解析 `sheetN.xml`
3. 解析 `workbook.xml` 获取工作表列表
4. 解析 `sharedStrings.xml` 获取共享字符串
5. 支持单元格坐标转换（A1 → 行0列0）
6. 生成 Markdown 表格格式

**实现文件**:
- `src/formats/xlsx/converter.mbt` - 主转换逻辑
- `src/formats/xlsx/converter_test.mbt` - 单元测试

---

### 7. libzip Stored 和 Fixed Huffman 解压 (2026-03-10)

**状态**: ✅ 已解决
**相关文件**: `src/libzip/deflate.mbt`

**问题描述**:
需要实现 ZIP 文件的 Deflate 解压功能。

**解决方案**:
1. 实现 `deflate_decompress` 函数
2. 支持 Stored（无压缩）块
3. 支持 Fixed Huffman 编码块
4. 实现 CRC32 校验

**限制**:
动态 Huffman 编码仍有 bug（见问题1）

---

## 📝 问题记录模板

```markdown
### N. 问题标题

**状态**: 未解决 / 调查中 / 已解决
**发现日期**: YYYY-MM-DD
**相关文件**: 文件路径列表

**问题描述**:
详细描述问题现象

**已排查**:
- ✅ 已验证正常的部分
- ❌ 存在问题的部分

**解决方案**:
（如果已解决）

**参考**:
相关文档或链接
```

---

**最后更新**: 2026-03-11
