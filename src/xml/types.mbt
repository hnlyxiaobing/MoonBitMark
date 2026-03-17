///|
/// XML 解析错误类型
pub(all) suberror XMLParseError {
  /// 语法错误
  SyntaxError(Int, String)
  /// 未闭合标签
  UnclosedTag(String)
  /// 标签不匹配
  MismatchedTag(String, String)
  /// 无效属性格式
  InvalidAttributeFormat(String)
  /// 无效实体引用
  InvalidEntity(String)
  /// IO 错误
  IOError(String)
}

///|
/// XML 解析器配置
pub(all) struct XMLParserConfig {
  encoding : String
  buffer_size : Int
}

///|
/// XML 标记类型
pub enum Token {
  /// 开始标签（标签名，属性映射）
  StartTag(String, Map[String, String])
  /// 结束标签（标签名）
  EndTag(String)
  /// 自闭合标签（标签名，属性映射）
  SelfCloseTag(String, Map[String, String])
  /// 文本内容
  Text(String)
  /// 注释
  Comment(String)
  /// XML 声明
  Declaration(String)
  /// CDATA 部分
  CData(String)
}

///|
/// 元素开始事件
pub(all) struct ElementStartEvent {
  name : String
  attributes : Map[String, String]
  line_number : Int
}

///|
/// 元素结束事件
pub(all) struct ElementEndEvent {
  name : String
  line_number : Int
}

///|
/// 文本内容事件
pub(all) struct TextEvent {
  content : String
  line_number : Int
}

///|
/// 解析事件
pub enum ParseEvent {
  ElementStart(ElementStartEvent)
  ElementEnd(ElementEndEvent)
  TextContent(TextEvent)
}
