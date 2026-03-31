// MoonBitMark MCP Types - JSON Parser

///|
pub enum JsonParseError {
  UnexpectedEnd
  ExpectedChar(Int)
  InvalidEscape(Int)
  ExpectedColon
  ExpectedCommaOrTerminator
  InvalidJson(String)
}

///|
pub fn JsonParseError::to_string(self : JsonParseError) -> String {
  match self {
    UnexpectedEnd => "Unexpected end of JSON input"
    ExpectedChar(ch) =>
      "Expected character: '" + ch.unsafe_to_char().to_string() + "'"
    InvalidEscape(ch) =>
      "Invalid escape sequence: \\" + ch.unsafe_to_char().to_string()
    ExpectedColon => "Expected ':'"
    ExpectedCommaOrTerminator => "Expected ',' or closing delimiter"
    InvalidJson(message) => "Invalid JSON: " + message
  }
}

///|
priv struct ParserState {
  mut index : Int
}

///|
pub fn parse_json(input : String) -> Result[JsonValue, JsonParseError] {
  let state = ParserState::{ index: 0 }
  match parse_value(input, state) {
    Ok(value) => {
      skip_whitespace(input, state)
      if state.index != input.length() {
        Err(InvalidJson("Trailing content"))
      } else {
        Ok(value)
      }
    }
    Err(error) => Err(error)
  }
}

///|
fn parse_value(
  input : String,
  state : ParserState,
) -> Result[JsonValue, JsonParseError] {
  skip_whitespace(input, state)

  if state.index >= input.length() {
    return Err(UnexpectedEnd)
  }

  let ch = char_code_at(input, state.index)
  match ch {
    34 => parse_string(input, state)
    123 => parse_object(input, state)
    91 => parse_array(input, state)
    116 => parse_literal(input, state, "true", Bool(true))
    102 => parse_literal(input, state, "false", Bool(false))
    110 => parse_literal(input, state, "null", Null)
    45 => parse_number(input, state)
    _ =>
      if is_digit(ch) {
        parse_number(input, state)
      } else {
        Err(ExpectedChar(ch))
      }
  }
}

///|
fn parse_string(
  input : String,
  state : ParserState,
) -> Result[JsonValue, JsonParseError] {
  state.index = state.index + 1
  let mut result = ""

  while state.index < input.length() {
    let ch = input.at(state.index)
    if ch == 34 {
      state.index = state.index + 1
      return Ok(String(result))
    }

    if ch == 92 {
      state.index = state.index + 1
      if state.index >= input.length() {
        return Err(UnexpectedEnd)
      }
      let escaped = char_code_at(input, state.index)
      state.index = state.index + 1
      match decode_escape(input, state, escaped) {
        Ok(decoded) => result = result + decoded.to_string()
        Err(error) => return Err(error)
      }
    } else {
      result = result + ch.unsafe_to_char().to_string()
      state.index = state.index + 1
    }
  }

  Err(UnexpectedEnd)
}

///|
fn decode_escape(
  input : String,
  state : ParserState,
  escaped : Int,
) -> Result[Char, JsonParseError] {
  match escaped {
    34 => Ok('"')
    92 => Ok('\\')
    47 => Ok('/')
    98 => Ok('\b')
    102 => Ok('\f')
    110 => Ok('\n')
    114 => Ok('\r')
    116 => Ok('\t')
    117 => parse_unicode_escape(input, state)
    _ => Err(InvalidEscape(escaped))
  }
}

///|
fn parse_unicode_escape(
  input : String,
  state : ParserState,
) -> Result[Char, JsonParseError] {
  if state.index + 4 > input.length() {
    return Err(UnexpectedEnd)
  }

  let hex = input[state.index:state.index + 4].to_string()
  state.index = state.index + 4

  match hex_to_int(hex) {
    Some(codepoint) =>
      match codepoint.to_char() {
        Some(ch) => Ok(ch)
        None => Err(InvalidJson("Invalid unicode code point: " + hex))
      }
    None => Err(InvalidJson("Invalid unicode escape: " + hex))
  }
}

///|
fn parse_object(
  input : String,
  state : ParserState,
) -> Result[JsonValue, JsonParseError] {
  state.index = state.index + 1
  let entries : Map[String, JsonValue] = Map::new()

  skip_whitespace(input, state)
  if is_current_char(input, state, 125) {
    state.index = state.index + 1
    return Ok(Object(entries))
  }

  while true {
    let key_value = match parse_string(input, state) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let key = match key_value {
      String(value) => value
      _ => return Err(InvalidJson("Object key must be a string"))
    }

    skip_whitespace(input, state)
    if !is_current_char(input, state, 58) {
      return Err(ExpectedColon)
    }
    state.index = state.index + 1

    let value = match parse_value(input, state) {
      Ok(parsed) => parsed
      Err(error) => return Err(error)
    }
    entries[key] = value

    skip_whitespace(input, state)
    if is_current_char(input, state, 125) {
      state.index = state.index + 1
      break
    }
    if !is_current_char(input, state, 44) {
      return Err(ExpectedCommaOrTerminator)
    }
    state.index = state.index + 1
  }

  Ok(Object(entries))
}

///|
fn parse_array(
  input : String,
  state : ParserState,
) -> Result[JsonValue, JsonParseError] {
  state.index = state.index + 1
  let values : Array[JsonValue] = []

  skip_whitespace(input, state)
  if is_current_char(input, state, 93) {
    state.index = state.index + 1
    return Ok(Array(values))
  }

  while true {
    match parse_value(input, state) {
      Ok(value) => values.push(value)
      Err(error) => return Err(error)
    }
    skip_whitespace(input, state)

    if is_current_char(input, state, 93) {
      state.index = state.index + 1
      break
    }
    if !is_current_char(input, state, 44) {
      return Err(ExpectedCommaOrTerminator)
    }
    state.index = state.index + 1
  }

  Ok(Array(values))
}

///|
fn parse_number(
  input : String,
  state : ParserState,
) -> Result[JsonValue, JsonParseError] {
  let start = state.index

  if is_current_char(input, state, 45) {
    state.index = state.index + 1
  }

  consume_digits(input, state)

  let mut has_decimal = false
  if is_current_char(input, state, 46) {
    has_decimal = true
    state.index = state.index + 1
    consume_digits(input, state)
  }

  let mut has_exponent = false
  if state.index < input.length() {
    let ch = input.at(state.index)
    if ch == 101 || ch == 69 {
      has_exponent = true
      state.index = state.index + 1
      if state.index < input.length() {
        let sign = input.at(state.index)
        if sign == 43 || sign == 45 {
          state.index = state.index + 1
        }
      }
      consume_digits(input, state)
    }
  }

  let number_text = input[start:state.index].to_string()
  if has_decimal || has_exponent {
    match parse_float(number_text) {
      Some(value) => Ok(Float(value))
      None => Err(InvalidJson("Invalid float: " + number_text))
    }
  } else {
    Ok(Number(@string.parse_int(number_text))) catch {
      _ => Err(InvalidJson("Invalid number: " + number_text))
    }
  }
}

///|
fn parse_literal(
  input : String,
  state : ParserState,
  literal : String,
  value : JsonValue,
) -> Result[JsonValue, JsonParseError] {
  if state.index + literal.length() > input.length() {
    return Err(UnexpectedEnd)
  }

  let actual = input[state.index:state.index + literal.length()].to_string()
  if actual == literal {
    state.index = state.index + literal.length()
    Ok(value)
  } else {
    Err(InvalidJson("Expected literal: " + literal))
  }
}

///|
fn consume_digits(input : String, state : ParserState) -> Unit {
  while state.index < input.length() &&
        is_digit(char_code_at(input, state.index)) {
    state.index = state.index + 1
  }
}

///|
fn skip_whitespace(input : String, state : ParserState) -> Unit {
  while state.index < input.length() {
    let ch = char_code_at(input, state.index)
    if ch == 32 || ch == 10 || ch == 13 || ch == 9 {
      state.index = state.index + 1
    } else {
      break
    }
  }
}

///|
fn is_current_char(input : String, state : ParserState, expected : Int) -> Bool {
  state.index < input.length() && char_code_at(input, state.index) == expected
}

///|
fn is_digit(ch : Int) -> Bool {
  ch >= 48 && ch <= 57
}

///|
fn hex_to_int(hex : String) -> Int? {
  let mut result = 0
  for ch in hex {
    let digit = match ch {
      '0'..='9' => ch.to_int() - '0'.to_int()
      'a'..='f' => ch.to_int() - 'a'.to_int() + 10
      'A'..='F' => ch.to_int() - 'A'.to_int() + 10
      _ => return None
    }
    result = result * 16 + digit
  }
  Some(result)
}

///|
fn parse_float(text : String) -> Float? {
  let mut index = 0
  let mut sign = 1.0F
  if text.length() == 0 {
    return None
  }

  if char_code_at(text, 0) == 45 {
    sign = -1.0F
    index = 1
  } else if char_code_at(text, 0) == 43 {
    index = 1
  }

  let mut integer_part = 0
  while index < text.length() && is_digit(char_code_at(text, index)) {
    integer_part = integer_part * 10 + (char_code_at(text, index) - 48)
    index = index + 1
  }

  let mut result = Float::from_int(integer_part)

  if index < text.length() && char_code_at(text, index) == 46 {
    index = index + 1
    let mut fraction = 0.0F
    let mut divisor = 10.0F
    while index < text.length() && is_digit(char_code_at(text, index)) {
      fraction = fraction +
        Float::from_int(char_code_at(text, index) - 48) / divisor
      divisor = divisor * 10.0F
      index = index + 1
    }
    result = result + fraction
  }

  if index < text.length() &&
    (char_code_at(text, index) == 101 || char_code_at(text, index) == 69) {
    index = index + 1
    let mut exponent_sign = 1
    if index < text.length() && char_code_at(text, index) == 45 {
      exponent_sign = -1
      index = index + 1
    } else if index < text.length() && char_code_at(text, index) == 43 {
      index = index + 1
    }

    let mut exponent = 0
    while index < text.length() && is_digit(char_code_at(text, index)) {
      exponent = exponent * 10 + (char_code_at(text, index) - 48)
      index = index + 1
    }

    let power = pow10(exponent)
    result = if exponent_sign < 0 { result / power } else { result * power }
  }

  if index != text.length() {
    None
  } else {
    Some(sign * result)
  }
}

///|
fn pow10(exponent : Int) -> Float {
  let mut result = 1.0F
  let mut i = 0
  while i < exponent {
    result = result * 10.0F
    i = i + 1
  }
  result
}

///|
fn char_code_at(text : String, index : Int) -> Int {
  text.at(index).to_int()
}
