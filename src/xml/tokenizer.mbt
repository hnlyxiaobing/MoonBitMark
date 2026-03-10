///|
/// XML 词法分析器
/// 将 XML 字符串转换为标记流

///|
/// 解析结果（包含 Token、新位置、新行号）
priv struct ParseResult {
  token : Token
  pos : Int
  line : Int
}

///|
/// 属性解析结果
priv struct AttrParseResult {
  name : String
  value : String
  pos : Int
  line : Int
}

///|
/// 文本解析结果
priv struct TextParseResult {
  text : Token
  pos : Int
  line : Int
}

///|
/// XML 分词器实现
fn tokenize(xml : String) -> Result[Array[Token], XMLParseError] {
  try {
    let tokens : Array[Token] = Array::new()
    let mut pos = 0
    let mut line = 1
    let len = xml.length()

    while pos < len {
      let ch = xml[pos]

      // 处理换行符
      if ch == '\n' {
        line = line + 1
        pos = pos + 1
        continue
      }

      // 跳过空白符
      if ch == ' ' || ch == '\t' || ch == '\r' {
        pos = pos + 1
        continue
      }

      // 检查是否进入标签
      if ch == '<' {
        // 检查后续字符
        if pos + 1 < len {
          let next = xml[pos + 1]
          match next {
            '!' =>
              // 可能是注释或 CDATA
              if pos + 3 < len && xml[pos + 2] == '-' && xml[pos + 3] == '-' {
                // 注释 <!--
                let result = parse_comment(xml, pos + 4, line)
                tokens.push(result.token)
                pos = result.pos
                line = result.line
              } else if pos + 9 < len {
                // 检查 CDATA: 逐个字符比较 ![CDATA[
                let is_cdata = xml[pos + 2] == '!' &&
                  xml[pos + 3] == '[' &&
                  xml[pos + 4] == 'C' &&
                  xml[pos + 5] == 'D' &&
                  xml[pos + 6] == 'A' &&
                  xml[pos + 7] == 'T' &&
                  xml[pos + 8] == 'A' &&
                  xml[pos + 9] == '['
                if is_cdata {
                  let result = parse_cdata(xml, pos + 10, line)
                  tokens.push(result.token)
                  pos = result.pos
                  line = result.line
                } else {
                  raise SyntaxError(line, "Invalid markup declaration")
                }
              } else {
                raise SyntaxError(line, "Invalid markup declaration")
              }
            '?' => {
              // XML 声明 <?xml ... ?>
              let result = parse_declaration(xml, pos + 2, line)
              tokens.push(result.token)
              pos = result.pos
              line = result.line
            }
            '/' => {
              // 结束标签 </tag>
              let result = parse_end_tag(xml, pos + 2, line)
              tokens.push(result.token)
              pos = result.pos
              line = result.line
            }
            _ => {
              // 开始标签 <tag> 或自闭合标签 <tag/>
              let result = parse_start_tag(xml, pos + 1, line)
              tokens.push(result.token)
              pos = result.pos
              line = result.line
            }
          }
        } else {
          raise SyntaxError(line, "Unclosed tag")
        }
      } else {
        // 文本内容
        let result = parse_text(xml, pos, line)
        tokens.push(result.text)
        pos = result.pos
        line = result.line
      }
    }

    Ok(tokens)
  } catch {
    _ => Err(SyntaxError(1, "Parse error"))
  }
}

///|
/// 解析注释
fn parse_comment(xml : String, start : Int, line : Int) -> ParseResult raise {
  let mut pos = start
  let mut current_line = line

  while pos + 2 < xml.length() {
    if xml[pos] == '-' && xml[pos + 1] == '-' && xml[pos + 2] == '>' {
      // 找到注释结束，提取内容
      let content = xml[start:pos].to_string()
      return { token: Comment(content), pos: pos + 3, line: current_line }
    }
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  raise SyntaxError(line, "Unclosed comment")
}

///|
/// 解析 CDATA
fn parse_cdata(xml : String, start : Int, line : Int) -> ParseResult raise {
  let mut pos = start
  let mut current_line = line

  while pos + 2 < xml.length() {
    if xml[pos] == ']' && xml[pos + 1] == ']' && xml[pos + 2] == '>' {
      // 找到 CDATA 结束
      let content = xml[start:pos].to_string()
      return { token: CData(content), pos: pos + 3, line: current_line }
    }
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  raise SyntaxError(line, "Unclosed CDATA section")
}

///|
/// 解析 XML 声明
fn parse_declaration(
  xml : String,
  start : Int,
  line : Int,
) -> ParseResult raise {
  let mut pos = start
  let mut current_line = line

  while pos + 1 < xml.length() {
    if xml[pos] == '?' && xml[pos + 1] == '>' {
      // 找到声明结束
      let content = xml[start:pos].trim().to_string()
      return { token: Declaration(content), pos: pos + 2, line: current_line }
    }
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  raise SyntaxError(line, "Unclosed XML declaration")
}

///|
/// 解析结束标签
fn parse_end_tag(xml : String, start : Int, line : Int) -> ParseResult raise {
  let mut pos = start
  let mut current_line = line

  // 跳过空白
  while pos < xml.length() &&
        (
          xml[pos] == ' ' ||
          xml[pos] == '\t' ||
          xml[pos] == '\n' ||
          xml[pos] == '\r'
        ) {
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  let name_start = pos
  // 读取标签名
  while pos < xml.length() &&
        xml[pos] != '>' &&
        xml[pos] != ' ' &&
        xml[pos] != '\t' &&
        xml[pos] != '\n' &&
        xml[pos] != '\r' {
    pos = pos + 1
  }

  let tag_name = xml[name_start:pos].to_string()

  // 跳过空白
  while pos < xml.length() &&
        (
          xml[pos] == ' ' ||
          xml[pos] == '\t' ||
          xml[pos] == '\n' ||
          xml[pos] == '\r'
        ) {
    pos = pos + 1
  }

  // 期望 >
  if pos >= xml.length() || xml[pos] != '>' {
    raise SyntaxError(line, "Unclosed end tag")
  }

  { token: EndTag(tag_name), pos: pos + 1, line: current_line }
}

///|
/// 解析开始标签
fn parse_start_tag(xml : String, start : Int, line : Int) -> ParseResult raise {
  let mut pos = start
  let mut current_line = line
  let attrs : Map[String, String] = Map::new()

  // 跳过空白
  while pos < xml.length() &&
        (
          xml[pos] == ' ' ||
          xml[pos] == '\t' ||
          xml[pos] == '\n' ||
          xml[pos] == '\r'
        ) {
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  let name_start = pos
  // 读取标签名
  while pos < xml.length() &&
        xml[pos] != '>' &&
        xml[pos] != '/' &&
        xml[pos] != ' ' &&
        xml[pos] != '\t' &&
        xml[pos] != '\n' &&
        xml[pos] != '\r' {
    pos = pos + 1
  }

  let tag_name = xml[name_start:pos].to_string()

  if tag_name.length() == 0 {
    raise SyntaxError(current_line, "Empty tag name")
  }

  // 解析属性
  let mut done = false
  while !done {
    // 跳过空白
    while pos < xml.length() &&
          (
            xml[pos] == ' ' ||
            xml[pos] == '\t' ||
            xml[pos] == '\n' ||
            xml[pos] == '\r'
          ) {
      if xml[pos] == '\n' {
        current_line = current_line + 1
      }
      pos = pos + 1
    }

    if pos >= xml.length() {
      raise SyntaxError(current_line, "Unclosed tag")
    }

    // 检查结束
    if xml[pos] == '>' {
      done = true
      return {
        token: StartTag(tag_name, attrs),
        pos: pos + 1,
        line: current_line,
      }
    }

    if xml[pos] == '/' {
      if pos + 1 < xml.length() && xml[pos + 1] == '>' {
        // 自闭合标签
        done = true
        return {
          token: SelfCloseTag(tag_name, attrs),
          pos: pos + 2,
          line: current_line,
        }
      } else {
        raise SyntaxError(current_line, "Invalid self-closing tag")
      }
    }

    // 解析属性
    let attr_result = parse_attribute(xml, pos, current_line)
    pos = attr_result.pos
    current_line = attr_result.line
    attrs.set(attr_result.name, attr_result.value)
  }

  raise SyntaxError(current_line, "Unexpected end of tag parsing")
}

///|
/// 解析属性
fn parse_attribute(
  xml : String,
  start : Int,
  line : Int,
) -> AttrParseResult raise {
  let mut pos = start
  let mut current_line = line

  let name_start = pos
  // 读取属性名 (允许命名空间前缀，如 r:id)
  while pos < xml.length() &&
        xml[pos] != '=' &&
        xml[pos] != ' ' &&
        xml[pos] != '\t' &&
        xml[pos] != '\n' &&
        xml[pos] != '\r' {
    pos = pos + 1
  }

  let attr_name = xml[name_start:pos].to_string()

  if attr_name.length() == 0 {
    raise SyntaxError(current_line, "Empty attribute name")
  }

  // 跳过空白
  while pos < xml.length() &&
        (
          xml[pos] == ' ' ||
          xml[pos] == '\t' ||
          xml[pos] == '\n' ||
          xml[pos] == '\r'
        ) {
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  // 期望 =
  if pos >= xml.length() || xml[pos] != '=' {
    raise SyntaxError(current_line, "Expected '=' after attribute name")
  }
  pos = pos + 1

  // 跳过空白
  while pos < xml.length() &&
        (
          xml[pos] == ' ' ||
          xml[pos] == '\t' ||
          xml[pos] == '\n' ||
          xml[pos] == '\r'
        ) {
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  if pos >= xml.length() {
    raise SyntaxError(current_line, "Expected attribute value")
  }

  // 读取属性值
  let quote = xml[pos]
  if quote != '"' && quote != '\'' {
    raise SyntaxError(current_line, "Attribute value must be quoted")
  }
  pos = pos + 1

  let value_start = pos
  while pos < xml.length() && xml[pos] != quote {
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  if pos >= xml.length() {
    raise SyntaxError(current_line, "Unclosed attribute value")
  }

  // 提取属性值并处理实体引用
  let raw_value = xml[value_start:pos].to_string()
  let attr_value = decode_entities(raw_value)
  pos = pos + 1 // 跳过结束引号

  { name: attr_name, value: attr_value, pos, line: current_line }
}

///|
/// 解码实体引用
fn decode_entities(s : String) -> String raise {
  let mut result = ""
  let mut i = 0
  let len = s.length()

  while i < len {
    if s[i] == '&' {
      // 查找结束的分号
      let mut j = i + 1
      while j < len && s[j] != ';' {
        j = j + 1
      }
      if j < len {
        let entity = s[i + 1:j].to_string()
        let decoded = match entity {
          "lt" => "<"
          "gt" => ">"
          "amp" => "&"
          "quot" => "\""
          "apos" => "'"
          _ => "&" + entity + ";"
        }
        result = result + decoded
        i = j + 1
      } else {
        result = result + "&"
        i = i + 1
      }
    } else {
      result = result + s[i:i + 1].to_string()
      i = i + 1
    }
  }

  result
}

///|
/// 解析文本内容
fn parse_text(xml : String, start : Int, line : Int) -> TextParseResult raise {
  let mut pos = start
  let mut current_line = line

  while pos < xml.length() && xml[pos] != '<' {
    if xml[pos] == '\n' {
      current_line = current_line + 1
    }
    pos = pos + 1
  }

  // 提取文本内容并解码实体引用
  let raw_text = xml[start:pos].to_string()
  let text = decode_entities(raw_text)

  { text: Text(text), pos, line: current_line }
}
