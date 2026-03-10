# MoonBit 纯实现 XML 解析库开发计划

## 执行摘要

本项目旨在用纯 MoonBit 实现一个轻量级 XML 解析库，为 MoonBitMark 的 DOCX 处理提供 XML 解析能力。基于 MoonBit 的语言特性，提供更安全、更易用的解析方案。

**关键优势**:
- ✅ 零外部依赖，纯 MoonBit 实现
- ✅ 自动内存管理，无需手动释放
- ✅ 完整的类型安全和编译时检查
- ✅ 流式解析支持，适合大文件
- ✅ 简洁的异步友好的 API 设计
- ✅ 跨平台支持（包括 WASM）

## 1. 项目背景

### 1.1 当前状态

当前 MoonBitMark 项目在处理 DOCX 文件时，通过 FFI 调用 C 语言的 expat 库来解析 XML 内容。这引入了外部依赖和平台兼容性问题。

**现有 FFI 依赖**:
- 需要安装 expat C 库
- Windows 下需要 vcpkg 配置
- 存在内存安全风险
- 跨平台部署复杂

**DOCX 解析需求**:
- 解析 Office Open XML 格式的 XML 文件
- 提取文档结构、样式、内容信息
- 处理大型 XML 文件（>1MB）
- 准确的错误定位和报告

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

基于 DOCX 解析场景的实际需求：
- 解析标准的 Office Open XML 文件结构
- 提取元素属性和文本内容
- 处理嵌套的 XML 结构
- 准确的错误定位（行号、上下文）
- 支持流式解析以处理大文件

### 2.3 功能优先级

| 功能 | 优先级 | 说明 | MoonBit 实现要点 |
|------|--------|------|------------------|
| 基础XML解析 | 高 | 元素、属性、文本 | 使用模式匹配简化状态机 |
| SAX风格回调 | 高 | 事件驱动解析 | 利用MoonBit函数式特性 |
| 错误处理 | 高 | 错误类型和恢复 | 使用suberror定义错误类型 |
| UTF-8处理 | 中 | 编码检测转换 | MoonBit原生UTF-8支持 |
| 命名空间 | 低 | XML命名空间 | 可选功能，后期扩展 |

## 3. API 设计规范

### 3.1 核心 API 设计

采用 MoonBit 惯用设计，利用类型系统和错误处理优势：

```moonbit
///|
/// XML 解析错误类型
pub type XMLParseError {
  ///| 语法错误，包含行号和错误信息
  SyntaxError(Int, String)
  ///| 未闭合标签
  UnclosedTag(String)
  ///| 无效属性格式
  InvalidAttributeFormat
  ///| IO 错误
  IOError(String)
}

///|
/// XML 解析器配置
pub type XMLParserConfig {
  encoding : String = "utf-8"
  buffer_size : Int = 4096
}

///|
/// XML 解析器句柄（内部类型）
priv type XMLParserHandle

///|
/// XML 解析器实例
pub type XMLParser {
  handle : XMLParserHandle
  line_number : Int
}

///|
/// 解析结果
pub type ParseResult = Result[Unit, XMLParseError]

///|
/// 元素开始事件
pub type ElementStartEvent = {
  name : String
  attributes : Map[String, String]
  line_number : Int
}

///|
/// 元素结束事件
pub type ElementEndEvent = {
  name : String
  line_number : Int
}

///|
/// 文本内容事件
pub type TextEvent = {
  content : String
  line_number : Int
}

///|
/// 事件处理器类型
pub type EventHandler = Fn(ParseEvent) -> Unit
pub type ParseEvent =
  | ElementStart(ElementStartEvent)
  | ElementEnd(ElementEndEvent)  
  | TextContent(TextEvent)
```

### 3.2 主要 API

```moonbit
///|
/// 创建 XML 解析器
pub fn XMLParser::new(config : XMLParserConfig = XMLParserConfig::default()) -> XMLParser

///|
/// 设置事件处理器
pub fn XMLParser::set_handler(handler : EventHandler) -> Unit

///|
/// 解析 XML 数据块
pub fn XMLParser::parse_chunk(data : String) -> ParseResult

///|
/// 完成解析
pub fn XMLParser::finish() -> ParseResult

///|
/// 获取当前行号
pub fn XMLParser::line_number(self : XMLParser) -> Int

///|
/// 便捷解析函数
pub fn parse_xml(xml_content : String) -> Result[List[ParseEvent], XMLParseError] {
  ///| 一次性解析完整 XML 文档，返回事件列表
}

///|
/// 流式解析函数
pub fn parse_xml_stream(reader : @fs.StreamReader) -> Result[Unit, XMLParseError] {
  ///| 从流中读取并解析 XML
}
```

## 4. 实现计划

### 4.1 项目结构

遵循 MoonBit 项目组织规范：

```
src/xml/
├── moon.pkg.json              # 包配置
├── package.mbt                # 公共 API
├── parser/
│   ├── mod.mbt               # 模块入口
│   ├── core.mbt              # 核心解析逻辑
│   ├── tokenizer.mbt          # 词法分析器
│   └── state.mbt             # 解析状态管理
├── events/
│   ├── mod.mbt               # 事件定义
│   ├── handlers.mbt          # 事件处理器
│   └── types.mbt             # 数据类型定义
├── error/
│   ├── mod.mbt               # 错误处理模块
│   └── codes.mbt             # 错误码定义
└── test/
    ├── parser_test.mbt        # 解析器测试
    ├── integration_test.mbt   # 集成测试
    └── docx_samples/          # DOCX 测试样本
```

### 4.2 实现里程碑

采用迭代式开发，每个里程碑都产出可用的功能：

| 里程碑 | 目标 | 预计时间 | 产出 |
|--------|------|----------|------|
| M1 | 基础XML解析器 | 1周 | 能解析简单XML元素和文本 |
| M2 | 事件系统 | 1周 | 完整的SAX风格事件回调 |
| M3 | 错误处理 | 3天 | 精确的错误定位和报告 |
| M4 | DOCX集成测试 | 3天 | 成功解析真实DOCX文件 |
| M5 | 性能优化 | 2天 | 流式解析支持 |
| M6 | 文档和示例 | 2天 | 完整的API文档和使用示例 |

## 5. XML 解析技术细节

### 5.1 解析策略

采用简化的递归下降解析，利用 MoonBit 的强大模式匹配：

**核心思路**：
- 将 XML 解析分解为标记化 + 语法分析两个阶段
- 使用枚举类型表示解析状态
- 通过递归函数处理嵌套结构

**关键技术点**：
- **标记化**：识别 XML 标记（元素、属性、文本）
- **语法分析**：构建元素树，触发事件回调
- **状态管理**：跟踪当前元素栈和行号信息

### 5.2 简化实现

避免复杂的状态机，使用 MoonBit 的函数式特性：

```moonbit
///| XML 标记类型
pub enum Token {
  StartTag(String, Map[String, String])
  EndTag(String)
  SelfCloseTag(String, Map[String, String])
  Text(String)
  Comment(String)
}

///| 主要解析函数
fn parse_tokens(tokens : List[Token]) -> Result[List[ParseEvent], XMLParseError] {
  ///| 将标记转换为事件流
}
```

## 6. 测试计划

### 6.1 测试策略

采用分层测试，确保各组件正确性：

**单元测试** (`parser/` 和 `tokenizer/`)：
```moonbit
test "tokenize simple element" {
  let input = "<tag attr=\"value\">text</tag>"
  let tokens = tokenize(input)?
  assert_eq(tokens.length(), 3)
}

test "parse nested structure" {
  let xml = "<root><child attr=\"1\">content</child></root>"
  let events = parse_xml(xml)?
  // 验证事件序列
}
```

**集成测试** (`test/` 目录)：
- 真实 DOCX 文件解析测试
- 与其他 XML 库的兼容性对比
- 性能基准测试

**DOCX 专项测试**：
- Word 生成的文档.xml
- Excel 生成的共享字符串.xml  
- PowerPoint 生成的演示文稿.xml

## 7. MoonBit 实现价值

### 7.1 技术收益

此项目将为 MoonBitMark 带来显著的技术提升：

**架构现代化**：
- 消除最后一个 C 语言外部依赖
- 实现真正的单一二进制分发
- 为未来 WASM 部署铺平道路

**安全性增强**：
- 消除 FFI 边界的内存安全问题
- 编译时类型检查覆盖 XML 解析逻辑
- 避免 C 库潜在的缓冲区溢出风险

**开发效率**：
- 统一的 MoonBit 开发体验
- 更好的调试和错误追踪能力
- 便于后续功能扩展和维护

## 8. 验收标准

**核心功能** (必须达成)：
- [ ] 解析标准 XML 1.0 文档，正确处理元素嵌套
- [ ] 提取元素属性和文本内容，支持转义字符
- [ ] 生成结构化事件流（开始/结束/文本事件）
- [ ] 精确定位错误（行号、上下文信息）
- [ ] 成功解析至少 3 个真实的 DOCX 样本文件

**集成要求**：
- [ ] 无缝替换现有 FFI expat 调用
- [ ] DOCX 转换器功能不受影响
- [ ] 通过现有测试套件

**质量指标**：
- [ ] 代码覆盖率 ≥ 80%
- [ ] 解析 1MB XML 文件内存占用 < 10MB
- [ ] 错误恢复能力：能跳过错误继续解析

## 9. 开发工作流

遵循 MoonBit 最佳实践：

```bash
# 进入项目目录
cd d:/MySoftware/MoonBitMark

# 开发循环
moon check src/xml/           # 类型检查
moon test src/xml/test/       # 运行测试
moon fmt                      # 代码格式化
moon info && moon fmt         # 更新接口并格式化

# 集成验证
moon check                    # 全项目检查
moon test                     # 全项目测试
```

**开发准则**：
- 每完成一个里程碑，运行完整测试套件
- 提交前执行 `moon info` 检查接口变化
- 优先编写测试，采用 TDD 方式开发

## 10. 技术资源

- [XML 1.0 规范](https://www.w3.org/TR/xml/) - 语法参考
- [Office Open XML 规范](https://officeopenxml.com/) - DOCX 格式说明
- 现有实现: `src/formats/docx/ffi/expat/` - 参考 API 设计
- MoonBit 文档: https://docs.moonbitlang.com - 语言特性指南

## 11. 总结

通过实现纯 MoonBit 版本的 expat 库，我们将：
1. 移除最后一个 C 外部依赖
2. 实现真正的零依赖部署
3. 获得更好的开发体验和类型安全

此计划确保开发过程可控，最终成果质量可期。
