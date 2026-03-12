// MoonBitMark MCP JSON Parser - Simple JSON Parser

///|
/// JSON 解析错误类型
pub(all) type JsonParseError =
  | UnexpectedEnd
  | ExpectedChar(Char)
  | InvalidEscape(Char)
  | ExpectedColon
  | ExpectedCommaOrBrace
  | InvalidJson(String)

pub(all) fn JsonParseError::to_string(self : JsonParseError) -> String {
  match self {
    UnexpectedEnd => "Unexpected end of JSON input"
    ExpectedChar(c) => "Expected character: '" + c.to_string() + "'"
    InvalidEscape(c) => "Invalid escape sequence: \\" + c.to_string()
    ExpectedColon => "Expected ':'"
    ExpectedCommaOrBrace => "Expected ',' or '}'"
    InvalidJson(msg) => "Invalid JSON: " + msg
  }
}

///|
/// 解析 JSON 字符串
pub(all) fn parse_json(input : String) -> Result[JsonValue, JsonParseError] {
  let mut index = 0
  parse_value(input, { index: index })
}

///|
/// 解析 JSON 值
fn parse_value(input : String, state : { index : Int }) -> Result[JsonValue, JsonParseError] {
  skip_whitespace(input, state)

  if state.index >= input.length() {
    return Err(UnexpectedEnd)
  }

  let c = input.at(state.index) catch { return Err(UnexpectedEnd) }

  match c {
    '"' => parse_string(input, state)
    '{' => parse_object(input, state)
    '[' => parse_array(input, state)
    't' => parse_literal(input, state, "true", Bool(true))
    'f' => parse_literal(input, state, "false", Bool(false))
    'n' => parse_literal(input, state, "null", Null)
    '0'..'9' | '-' => parse_number(input, state)
    _ => Err(ExpectedChar(c))
  }
}

///|
/// 解析字符串
fn parse_string(input : String, state : { index : Int }) -> Result[JsonValue, JsonParseError] {
  state.index = state.index + 1 // 跳过开头的 "

  let mut result = ""

  while state.index < input.length() {
    let c = input.at(state.index) catch { return Err(UnexpectedEnd) }

    if c == '"' {
      state.index = state.index + 1
      return Ok(String(result))
    } else if c == '\\' {
      state.index = state.index + 1
      if state.index >= input.length() {
        return Err(UnexpectedEnd)
      }

      let escaped = input.at(state.index) catch { return Err(UnexpectedEnd) }
      state.index = state.index + 1

      let decoded = match escaped {
        '"' => '"'
        '\\' => '\\'
        '/' => '/'
        'b' => '\b'
        'f' => '\f'
        'n' => '\n'
        'r' => '\r'
        't' => '\t'
        'u' => {
          // Unicode 转义暂时不支持，返回原始字符
          'u'
        }
        _ => return Err(InvalidEscape(escaped))
      }
      result = result + decoded.to_string()
    } else {
      result = result + c.to_string()
      state.index = state.index + 1
    }
  }

  Err(UnexpectedEnd)
}

///|
/// 解析对象
fn parse_object(input : String, state : { index : Int }) -> Result[JsonValue, JsonParseError] {
  state.index = state.index + 1 // 跳过 {

  let mut map = Map::empty()
  skip_whitespace(input, state)

  // 检查是否为空对象
  if state.index < input.length() && input.at(state.index) catch { return Err(UnexpectedEnd) } == '}' {
    state.index = state.index + 1
    return Ok(Object(map))
  }

  // 解析键值对
  while true {
    skip_whitespace(input, state)

    // 解析键
    match parse_value(input, state) {
      Ok(String(key)) => {
        skip_whitespace(input, state)

        // 检查冒号
        if state.index >= input.length() || input.at(state.index) catch { return Err(UnexpectedEnd) } != ':' {
          return Err(ExpectedColon)
        }
        state.index = state.index + 1

        skip_whitespace(input, state)

        // 解析值
        match parse_value(input, state) {
          Ok(value) => {
            map = map.insert(key, value)
          }
          Err(e) => return Err(e)
        }
      }
      Ok(_) => return Err(ExpectedChar('"'))
      Err(e) => return Err(e)
    }

    skip_whitespace(input, state)

    // 检查下一个字符
    if state.index >= input.length() {
      return Err(UnexpectedEnd)
    }

    let next = input.at(state.index) catch { return Err(UnexpectedEnd) }

    if next == '}' {
      state.index = state.index + 1
      break
    } else if next == ',' {
      state.index = state.index + 1
      continue
    } else {
      return Err(ExpectedCommaOrBrace)
    }
  }

  Ok(Object(map))
}

///|
/// 解析数组
fn parse_array(input : String, state : { index : Int }) -> Result[JsonValue, JsonParseError] {
  state.index = state.index + 1 // 跳过 [

  let mut array = Array::empty()
  skip_whitespace(input, state)

  // 检查是否为空数组
  if state.index < input.length() && input.at(state.index) catch { return Err(UnexpectedEnd) } == ']' {
    state.index = state.index + 1
    return Ok(Array(array))
  }

  // 解析元素
  while true {
    skip_whitespace(input, state)

    match parse_value(input, state) {
      Ok(value) => {
        array = array.push(value)
      }
      Err(e) => return Err(e)
    }

    skip_whitespace(input, state)

    // 检查下一个字符
    if state.index >= input.length() {
      return Err(UnexpectedEnd)
    }

    let next = input.at(state.index) catch { return Err(UnexpectedEnd) }

    if next == ']' {
      state.index = state.index + 1
      break
    } else if next == ',' {
      state.index = state.index + 1
      continue
    } else {
      return Err(ExpectedCommaOrBrace)
    }
  }

  Ok(Array(array))
}

///|
/// 解析数字
fn parse_number(input : String, state : { index : Int }) -> Result[JsonValue, JsonParseError] {
  let mut start = state.index

  // 处理负号
  if state.index < input.length() && input.at(state.index) catch { return Err(UnexpectedEnd) } == '-' {
    state.index = state.index + 1
  }

  // 处理整数部分
  while state.index < input.length() {
    let c = input.at(state.index) catch { break }
    if c < '0' || c > '9' {
      break
    }
    state.index = state.index + 1
  }

  // 检查是否有小数部分
  if state.index < input.length() && input.at(state.index) catch { break } == '.' {
    state.index = state.index + 1

    while state.index < input.length() {
      let c = input.at(state.index) catch { break }
      if c < '0' || c > '9' {
        break
      }
      state.index = state.index + 1
    }

    // 解析为浮点数
    let num_str = input[start:state.index].to_string()
    match num_str.to_float() {
      Some(f) => return Ok(Float(f))
      None => return Err(InvalidJson("Invalid float: " + num_str))
    }
  }

  // 解析为整数
  let num_str = input[start:state.index].to_string()
  match num_str.to_int() {
    Some(n) => return Ok(Number(n))
    None => Err(InvalidJson("Invalid number: " + num_str))
  }
}

///|
/// 解析字面量 (true, false, null)
fn parse_literal(input : String, state : { index : Int }, literal : String, value : JsonValue) -> Result[JsonValue, JsonParseError] {
  if state.index + literal.length() > input.length() {
    return Err(UnexpectedEnd)
  }

  let actual = input[state.index : state.index + literal.length()].to_string()

  if actual == literal {
    state.index = state.index + literal.length()
    Ok(value)
  } else {
    Err(ExpectedChar(input.at(state.index) catch { return Err(UnexpectedEnd) }))
  }
}

///|
/// 跳过空白字符
fn skip_whitespace(input : String, state : { index : Int }) {
  while state.index < input.length() {
    let c = input.at(state.index) catch { break }
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      state.index = state.index + 1
    } else {
      break
    }
  }
}
