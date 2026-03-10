# 已知问题记录

> 记录 MoonBitMark 项目中尚未解决的问题

---

## 🔴 高优先级问题

### 1. Deflate 动态 Huffman 解压 Bug

**状态**: 未解决
**发现日期**: 2026-03-11
**相关文件**: `src/libzip/deflate.mbt`

**问题描述**:
动态 Huffman 编码的 Deflate 解压产生错误的输出。固定 Huffman 解压工作正常。

**测试用例**:
```moonbit
// 测试数据 (使用动态 Huffman 压缩)
let original = "The quick brown fox jumps over the lazy dog. ..."
let compressed : Bytes = b"\x5d\x90\x4b\x6e\xc3\x30..."
let result = deflate_decompress(compressed)

// 预期输出: "The quick brown fox jumps over the lazy dog..."
// 实际输出: "The quick brown fox jumps over th ulazy dog..."
```

**已排查**:
- ✅ `read_bits_reverse` 函数已修复（MSB-first 位读取）
- ✅ 固定 Huffman 解压正常工作
- ❌ 动态 Huffman 解压输出错误

**可能原因**:
1. `build_huffman_tree` 函数构建树时逻辑错误
2. `decode_huffman` 函数遍历树时方向判断错误
3. 码长解码过程中的重复码处理（code 16/17/18）有 bug

**参考**:
- RFC 1951 DEFLATE 规范
- `docs/libzip-pure-implementation-plan.md`

---

## 🟡 中优先级问题

### 2. PPTX 文件转换 - 动态 Huffman 压缩文件

**状态**: 受问题1影响
**相关文件**: `src/formats/pptx/`, `src/libzip/deflate.mbt`

**问题描述**:
大多数 PPTX 文件使用动态 Huffman 压缩，导致转换失败。只有使用 Store 或固定 Huffman 压缩的 PPTX 文件可以正常转换。

**临时解决方案**:
使用简单的测试 PPTX 文件（Store 压缩）进行测试。

---

## 🟢 低优先级问题

### 3. 废弃函数警告

**状态**: 待清理
**相关文件**: `src/libzip/deflate.mbt`, `src/formats/pptx/parser.mbt`

**问题描述**:
存在一些已弃用的函数调用：
- `to_int()` 应改为 `reinterpret_as_int()`
- `Char::from_int()` 应改为 `Int::to_char()` 或 `Int::unsafe_to_char()`
- `Map::size()` 应改为 `Map::length()`

**影响**: 编译警告，不影响功能

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
