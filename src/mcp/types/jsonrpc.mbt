// MoonBitMark MCP Types - JSON-RPC 2.0 Core Types

///|
pub(all) struct JsonRequest {
  jsonrpc : String
  method_name : String
  params : JsonValue?
  id : JsonId?
}

///|
pub(all) struct JsonResponse {
  jsonrpc : String
  result : JsonValue?
  error : JsonError?
  id : JsonId?
}

///|
pub(all) struct JsonError {
  code : Int32
  message : String
  data : JsonValue?
}

///|
pub(all) enum JsonId {
  StringId(String)
  NumberId(Int32)
  NullId
}

///|
pub fn JsonId::to_string(self : JsonId) -> String {
  match self {
    StringId(value) => value
    NumberId(value) => value.to_string()
    NullId => "null"
  }
}

///|
pub fn JsonError::to_json(self : JsonError) -> JsonValue {
  let map : Map[String, JsonValue] = Map([])
  map["code"] = Number(self.code)
  map["message"] = String(self.message)
  match self.data {
    Some(value) => map["data"] = value
    None => ()
  }
  Object(map)
}

///|
pub fn JsonResponse::to_json(self : JsonResponse) -> JsonValue {
  let map : Map[String, JsonValue] = Map([])
  map["jsonrpc"] = String(self.jsonrpc)
  match self.result {
    Some(value) => map["result"] = value
    None => ()
  }
  match self.error {
    Some(value) => map["error"] = value.to_json()
    None => ()
  }
  match self.id {
    Some(StringId(value)) => map["id"] = String(value)
    Some(NumberId(value)) => map["id"] = Number(value)
    Some(NullId) => map["id"] = Null
    None => ()
  }
  Object(map)
}

///|
pub(all) enum JsonValue {
  String(String)
  Number(Int32)
  Float(Float)
  Bool(Bool)
  Null
  Object(Map[String, JsonValue])
  Array(Array[JsonValue])
}

///|
pub fn JsonValue::to_string(self : JsonValue) -> String {
  match self {
    String(value) => "\"" + escape_json_string(value) + "\""
    Number(value) => value.to_string()
    Float(value) => value.to_string()
    Bool(value) => if value { "true" } else { "false" }
    Null => "null"
    Object(entries) => object_to_string(entries)
    Array(values) => array_to_string(values)
  }
}

///|
pub fn JsonValue::get(self : JsonValue, key : String) -> JsonValue? {
  match self {
    Object(entries) => entries.get(key)
    _ => None
  }
}

///|
pub fn JsonValue::get_array(self : JsonValue, index : Int32) -> JsonValue? {
  match self {
    Array(values) =>
      if index >= 0 && index < values.length() {
        Some(values[index])
      } else {
        None
      }
    _ => None
  }
}

///|
fn escape_json_string(input : String) -> String {
  let mut escaped = ""
  for ch in input {
    if ch == '\\' {
      escaped = escaped + "\\\\"
    } else if ch == '"' {
      escaped = escaped + "\\\""
    } else if ch == '\n' {
      escaped = escaped + "\\n"
    } else if ch == '\r' {
      escaped = escaped + "\\r"
    } else if ch == '\t' {
      escaped = escaped + "\\t"
    } else if ch.to_int() < 0x20 {
      // JSON forbids raw C0 control characters inside strings; emit the
      // \u00XX form so document content can never produce an invalid
      // JSON-RPC response.
      escaped = escaped + control_char_escape(ch)
    } else {
      escaped = escaped + ch.to_string()
    }
  }
  escaped
}

///|
/// Render a C0 control character as its `\u00XX` JSON escape sequence.
pub fn control_char_escape(ch : Char) -> String {
  let code = ch.to_int()
  let hex = "0123456789abcdef"
  let high = code / 16
  let low = code % 16
  "\\u00" + hex[high:high + 1].to_owned() + hex[low:low + 1].to_owned()
}

///|
fn object_to_string(entries : Map[String, JsonValue]) -> String {
  let pairs : Array[String] = []
  for entry in entries.to_array() {
    let (key, value) = entry
    pairs.push("\"" + escape_json_string(key) + "\":" + value.to_string())
  }
  "{" + pairs.join(",") + "}"
}

///|
fn array_to_string(values : Array[JsonValue]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(value.to_string())
  }
  "[" + items.join(",") + "]"
}
