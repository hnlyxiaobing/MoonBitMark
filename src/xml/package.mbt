///|
/// XML 解析器公共 API
///
/// 提供简单易用的 XML 解析接口

///|
/// 解析 XML 字符串，返回事件列表
pub fn parse_xml(
  xml_content : String,
) -> Result[Array[ParseEvent], XMLParseError] {
  match tokenize(xml_content) {
    Ok(tokens) => parse_tokens(tokens)
    Err(e) => Err(e)
  }
}

///|
/// 将标记列表转换为事件列表
fn parse_tokens(
  tokens : Array[Token],
) -> Result[Array[ParseEvent], XMLParseError] {
  let events : Array[ParseEvent] = Array::new()
  let line = 1
  // 元素栈，用于追踪嵌套结构
  let tag_stack : Array[String] = Array::new()

  for token in tokens {
    match token {
      StartTag(name, attrs) => {
        // 推入栈
        tag_stack.push(name)
        // 生成开始事件
        events.push(
          ElementStart({ name, attributes: attrs, line_number: line }),
        )
      }
      EndTag(name) => {
        // 检查栈顶是否匹配
        if tag_stack.length() == 0 {
          return Err(UnclosedTag(name))
        }
        match tag_stack.pop() {
          Some(top) => {
            if top != name {
              return Err(MismatchedTag(top, name))
            }
            // 生成结束事件
            events.push(ElementEnd({ name, line_number: line }))
          }
          None => return Err(UnclosedTag(name))
        }
      }
      SelfCloseTag(name, attrs) => {
        // 自闭合标签同时生成开始和结束事件
        events.push(
          ElementStart({ name, attributes: attrs, line_number: line }),
        )
        events.push(ElementEnd({ name, line_number: line }))
      }
      Text(content) =>
        // 只在内容非空时生成文本事件
        if content.length() > 0 {
          events.push(TextContent({ content, line_number: line }))
        }
      Comment(_) => {
        // 忽略注释
        let _ = 0
      }
      Declaration(_) => {
        // 忽略 XML 声明
        let _ = 0
      }
      CData(content) =>
        // CDATA 作为文本内容处理
        if content.length() > 0 {
          events.push(TextContent({ content, line_number: line }))
        }
    }
  }

  // 检查是否所有标签都已闭合
  if tag_stack.length() > 0 {
    let unclosed = tag_stack[tag_stack.length() - 1]
    return Err(UnclosedTag(unclosed))
  }

  Ok(events)
}
