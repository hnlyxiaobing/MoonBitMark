// MoonBitMark MCP Types - JSON-RPC 2.0 and MCP Protocol Type Definitions

///|
/// JSON-RPC 2.0 请求
pub(all) struct JsonRequest {
  jsonrpc : String
  method : String
  params : JsonValue?
  id : JsonId?
}

///|
/// JSON-RPC 2.0 响应
pub(all) struct JsonResponse {
  jsonrpc : String
  result : JsonValue?
  error : JsonError?
  id : JsonId?
}

///|
/// JSON-RPC 2.0 错误
pub(all) struct JsonError {
  code : Int
  message : String
  data : JsonValue?
}

///|
/// JSON-RPC ID 类型
pub(all) type JsonId =
  | StringId(String)
  | NumberId(Int)
  | NullId

pub(all) fn JsonId::to_string(self : JsonId) -> String {
  match self {
    StringId(s) => s
    NumberId(n) => n.to_string()
    NullId => "null"
  }
}

///|
/// JSON 值类型 (简化实现)
pub(all) type JsonValue =
  | String(String)
  | Number(Int)
  | Float(Float)
  | Bool(Bool)
  | Null
  | Object(Map[String, JsonValue])
  | Array(Array[JsonValue])

pub(all) fn JsonValue::to_string(self : JsonValue) -> String {
  match self {
    String(s) => {
      let escaped = s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
      "\"" + escaped + "\""
    }
    Number(n) => n.to_string()
    Float(f) => f.to_string()
    Bool(b) => if b { "true" } else { "false" }
    Null => "null"
    Object(m) => {
      let entries = m.to_vector().map(fn((k, v)) {
        "\"" + k + "\":" + v.to_string()
      })
      "{" + entries.join(",") + "}"
    }
    Array(arr) => {
      let elements = arr.map(fn(v) { v.to_string() })
      "[" + elements.join(",") + "]"
    }
  }
}

pub(all) fn JsonValue::get(self : JsonValue, key : String) -> JsonValue? {
  match self {
    Object(m) => m.get(key)
    _ => None
  }
}

pub(all) fn JsonValue::get_array(self : JsonValue, index : Int) -> JsonValue? {
  match self {
    Array(arr) => {
      if index >= 0 && index < arr.length() {
        Some(arr[index])
      } else {
        None
      }
    }
    _ => None
  }
}
