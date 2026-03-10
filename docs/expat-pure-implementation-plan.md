# MoonBit 纯实现 expat 库开发计划

## 执行摘要

本项目旨在用纯 MoonBit 实现一个 XML 解析库，完全替代当前通过 FFI 调用的 C 语言 expat 库。实现后将获得更好的跨平台兼容性、内存安全和开发体验。

**关键优势**:
- ✅ 零外部依赖，纯 MoonBit 实现
- ✅ 与现有 API 完全兼容，平滑迁移
- ✅ 自动内存管理，无需手动释放
- ✅ 完整的类型安全
- ✅ 支持流式解析大文件

## 1. 项目背景

### 1.1 当前状态

当前 MoonBitMark 项目在处理 DOCX 文件时，通过 FFI 调用 C 语言的 expat 库来解析 XML 内容。

**现有 FFI 接口** (`src/formats/docx/ffi/expat.mbt`):
- `XML_Parser` - XML 解析器句柄
- `XML_ParserCreate` - 创建解析器
- `XML_ParserFree` - 释放解析器
- `XML_Parse` - 解析 XML 数据
- `XML_GetErrorCode` - 获取错误码
- `XML_ErrorString` - 获取错误信息
- `XML_GetCurrentLineNumber` - 获取当前行号

### 1.2 目标

用纯 MoonBit 实现一个 XML 解析库，替代 FFI 依赖的 expat：
- 无外部 C 库依赖
- 跨平台兼容性（Windows/Linux/macOS/WASM）
- 支持 DOCX 文件所需的 XML 解析功能
- 保持 API 兼容

## 2. expat 技术分析

### 2.1 XML 解析特性

expat 是一个流式 XML 解析器，支持：
- SAX 风格的回调解析
- UTF-8 编码支持
- 命名空间支持
- 错误报告（行号、列号）

### 2.2 核心功能需求

DOCX 文件解析需要：
- 元素开始/结束回调
- 文本内容回调
- 错误处理
- 行号追踪

### 2.3 需要实现的功能

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 基础解析 | 高 | 解析 XML 元素、属性、文本 |
| 回调机制 | 高 | 支持 start_element, end_element, character_data |
| 错误处理 | 高 | 报告错误位置和原因 |
| 编码支持 | 中 | UTF-8 编码处理 |
| 命名空间 | 低 | XML 命名空间支持 |

## 3. API 设计规范

### 3.1 核心 API

```moonbit
///|
/// XML 解析器
pub type XML_Parser

///|
/// XML 解析状态
pub enum XML_Status {
  OK
  Error
}

///|
/// 创建 XML 解析器
pub fn XML_ParserCreate(encoding : String?) -> XML_Parser?

///|
/// 释放 XML 解析器
pub fn XML_ParserFree(parser : XML_Parser) -> Unit

///|
/// 解析 XML 数据
pub fn XML_Parse(parser : XML_Parser, data : Bytes, is_final : Bool) -> XML_Status

///|
/// 获取错误码
pub fn XML_GetErrorCode(parser : XML_Parser) -> Int

///|
/// 获取错误信息
pub fn XML_ErrorString(code : Int) -> String

///|
/// 获取当前行号
pub fn XML_GetCurrentLineNumber(parser : XML_Parser) -> Int
```

### 3.2 回调接口

```moonbit
///|
/// 元素开始回调
pub type StartElementHandler = fn(String, Map[String, String]) -> Unit

///|
/// 元素结束回调
pub type EndElementHandler = fn(String) -> Unit

///|
/// 字符数据回调
pub type CharacterDataHandler = fn(String) -> Unit

///|
/// 设置元素处理器
pub fn XML_SetElementHandler(
  parser : XML_Parser,
  start_handler : StartElementHandler,
  end_handler : EndElementHandler
) -> Unit

///|
/// 设置字符数据处理器
pub fn XML_SetCharacterDataHandler(
  parser : XML_Parser,
  handler : CharacterDataHandler
) -> Unit
```

### 3.3 便捷 API

```moonbit
///|
/// 简单解析 XML 文档
pub fn parse_xml_document(
  xml_data : Bytes,
  on_element_start : StartElementHandler?,
  on_element_end : EndElementHandler?,
  on_character_data : CharacterDataHandler?
) -> Result[Unit, XML_ParseError]
```

## 4. 实现计划

### 4.1 文件结构

```
src/libexpat/
├── moon.pkg.json
├── expat_spec.mbt      # API 规范
├── expat.mbt           # 主实现
├── parser.mbt          # 解析器核心
├── tokenizer.mbt       # XML 分词器
├── handlers.mbt        # 回调处理
└── expat_test.mbt      # 测试
```

### 4.2 实现阶段

| 阶段 | 内容 | 优先级 |
|------|------|--------|
| Phase 1 | XML tokenizer (分词器) | 高 |
| Phase 2 | 基础元素解析 | 高 |
| Phase 3 | 属性解析 | 高 |
| Phase 4 | 回调机制 | 高 |
| Phase 5 | 错误处理 | 中 |
| Phase 6 | 编码处理 | 中 |
| Phase 7 | 性能优化 | 低 |

## 5. XML 解析技术细节

### 5.1 状态机设计

XML 解析本质上是一个状态机：

```
状态:
- START         # 文档开始
- ELEMENT_START # 元素开始 <
- TAG_NAME      # 标签名
- ATTR_NAME     # 属性名
- ATTR_VALUE    # 属性值
- TEXT          # 文本内容
- ENTITY        # 实体引用
- ELEMENT_END   # 元素结束 >
- CLOSE_TAG     # 关闭标签 /
- PI_TARGET     # 处理指令
- COMMENT       # 注释
- DONE          # 解析完成
```

### 5.2 关键算法

**分词 (Tokenization)**:
- 逐字节扫描输入
- 识别 < > = " ' / 等分隔符
- 处理实体引用 (&lt; &gt; &amp; 等)

**元素解析**:
- 解析标签名
- 解析属性名值对
- 区分自闭合标签

**文本处理**:
- 合并连续文本节点
- 处理空白符

## 6. 测试计划

### 6.1 基础测试

```moonbit
test "parse empty document" { ... }
test "parse simple element" { ... }
test "parse element with attributes" { ... }
test "parse nested elements" { ... }
test "parse text content" { ... }
```

### 6.2 错误处理测试

```moonbit
test "unclosed tag error" { ... }
test "mismatched tag error" { ... }
test "invalid attribute error" { ... }
```

### 6.3 DOCX 测试

```moonbit
test "parse word/document.xml" { ... }
test "parse word/styles.xml" { ... }
test "parse complex docx" { ... }
```

## 7. 与 C expat 对比

### 7.1 功能对比

| 功能 | C expat | Pure MoonBit expat | 状态 |
|------|---------|-------------------|------|
| XML 解析 | ✅ | ✅ | 完整 |
| 回调机制 | ✅ | ✅ | 完整 |
| 错误报告 | ✅ | ✅ | 完整 |
| 行号追踪 | ✅ | ✅ | 完整 |
| UTF-8 支持 | ✅ | ✅ | 完整 |
| 命名空间 | ✅ | ❌ | 可选 |

### 7.2 优势

- **零依赖**: 无需安装 expat 库
- **内存安全**: 无缓冲区溢出风险
- **类型安全**: 编译时类型检查
- **WASM 支持**: 可在浏览器运行

### 7.3 限制

- **性能**: 预期略低于 C 实现（~10-20%）
- **命名空间**: 暂不支持
- **外部实体**: 暂不支持

## 8. 验收标准

**功能性**:
- [ ] 正确解析标准 XML 文档
- [ ] 支持元素开始/结束回调
- [ ] 支持属性解析
- [ ] 支持文本内容回调
- [ ] 正确报告解析错误和位置
- [ ] 正确解析 DOCX 文件

**兼容性**:
- [ ] API 与现有 FFI 兼容
- [ ] 可完全替换 C expat

**易用性**:
- [ ] 自动内存管理
- [ ] 详细的错误信息

## 9. 开发命令

```bash
# 类型检查
moon check src/libexpat/

# 运行测试
moon test

# 格式化
moon fmt

# 更新接口
moon info && moon fmt
```

## 10. 参考资源

- [expat XML Parser](https://libexpat.github.io/)
- [XML 1.0 规范](https://www.w3.org/TR/xml/)
- 现有 FFI 实现: `src/formats/docx/ffi/expat/`

## 11. 总结

通过实现纯 MoonBit 版本的 expat 库，我们将：
1. 移除最后一个 C 外部依赖
2. 实现真正的零依赖部署
3. 获得更好的开发体验和类型安全

此计划确保开发过程可控，最终成果质量可期。
