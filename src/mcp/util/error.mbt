// MoonBitMark MCP Utility - Enhanced Error Handling with Context

///|
/// MCP 错误代码
pub(all) type McpErrorCode =
  | ParseError(Int)
  | InvalidRequest
  | MethodNotFound
  | InvalidParams
  | InternalError
  | ServerError(Int)
  | ToolError(String)

///|
/// 错误位置信息
pub(all) struct ErrorLocation {
  file : String?
  line : Int?
  column : Int?
  function : String?
}

pub(all) fn ErrorLocation::new() -> ErrorLocation {
  {
    file: None,
    line: None,
    column: None,
    function: None
  }
}

pub(all) fn ErrorLocation::with_file(self : ErrorLocation, file : String) -> ErrorLocation {
  { file: Some(file), ..self }
}

pub(all) fn ErrorLocation::with_line(self : ErrorLocation, line : Int) -> ErrorLocation {
  { line: Some(line), ..self }
}

pub(all) fn ErrorLocation::with_function(self : ErrorLocation, function : String) -> ErrorLocation {
  { function: Some(function), ..self }
}

pub(all) fn ErrorLocation::to_string(self : ErrorLocation) -> String {
  let mut parts = Array::empty()

  match self.file {
    Some(f) => parts.push(f)
    None => {}
  }

  match self.line {
    Some(l) => parts.push("line " + l.to_string())
    None => {}
  }

  match self.column {
    Some(c) => parts.push("col " + c.to_string())
    None => {}
  }

  match self.function {
    Some(fn_name) => parts.push("in " + fn_name)
    None => {}
  }

  if parts.length() == 0 {
    "(unknown location)"
  } else {
    parts.join(" ")
  }
}

///|
/// 错误上下文
pub(all) struct ErrorContext {
  location : ErrorLocation
  timestamp : String
  request_id : String?
  additional_info : Map[String, String]
}

pub(all) fn ErrorContext::new(location : ErrorLocation) -> ErrorContext {
  {
    location,
    timestamp: "[TIMESTAMP]",
    request_id: None,
    additional_info: Map::empty()
  }
}

pub(all) fn ErrorContext::with_request_id(self : ErrorContext, id : String) -> ErrorContext {
  { request_id: Some(id), ..self }
}

pub(all) fn ErrorContext::add_info(self : ErrorContext, key : String, value : String) -> ErrorContext {
  { additional_info: self.additional_info.insert(key, value), ..self }
}

///|
/// MCP 错误类型（增强版）
pub(all) struct McpError {
  code : McpErrorCode
  message : String
  details : String?
  context : ErrorContext
  cause : McpError?
}

///|
/// 创建解析错误
pub(all) fn McpError::parse_error(code : Int, message : String, context : ErrorContext) -> McpError {
  { code: ParseError(code), message, details: None, context, cause: None }
}

///|
/// 创建无效请求错误
pub(all) fn McpError::invalid_request(message : String, context : ErrorContext) -> McpError {
  { code: InvalidRequest, message, details: None, context, cause: None }
}

///|
/// 创建方法未找到错误
pub(all) fn McpError::method_not_found(method : String, context : ErrorContext) -> McpError {
  { code: MethodNotFound, message: "Method not found: " + method, details: None, context, cause: None }
}

///|
/// 创建无效参数错误
pub(all) fn McpError::invalid_params(message : String, context : ErrorContext) -> McpError {
  { code: InvalidParams, message, details: None, context, cause: None }
}

///|
/// 创建内部错误
pub(all) fn McpError::internal_error(message : String, details : String?, context : ErrorContext) -> McpError {
  { code: InternalError, message, details, context, cause: None }
}

///|
/// 创建带原因的内部错误
pub(all) fn McpError::internal_error_with_cause(message : String, details : String?, context : ErrorContext, cause : McpError) -> McpError {
  { code: InternalError, message, details, context, cause: Some(cause) }
}

///|
/// 创建工具错误
pub(all) fn McpError::tool_error(tool_name : String, reason : String, context : ErrorContext) -> McpError {
  { code: ToolError(tool_name), message: "Tool execution failed: " + reason, details: None, context, cause: None }
}

///|
/// 转换为 JSON-RPC 错误代码
pub(all) fn McpError::to_jsonrpc_code(self : McpError) -> Int {
  match self.code {
    ParseError(c) => c
    InvalidRequest => -32600
    MethodNotFound => -32601
    InvalidParams => -32602
    InternalError => -32603
    ServerError(c) => c
    ToolError(_) => -32000 // 自定义工具错误代码
  }
}

///|
/// 格式化错误消息（包含上下文）
pub(all) fn McpError::format(self : McpError) -> String {
  let mut result = ""

  // 基本错误消息
  result = result + self.message

  // 添加位置信息
  result = result + "\nLocation: " + self.context.location.to_string()

  // 添加时间戳
  result = result + "\nTime: " + self.context.timestamp

  // 添加请求 ID
  match self.context.request_id {
    Some(req_id) => result = result + "\nRequest ID: " + req_id
    None => {}
  }

  // 添加详细信息
  match self.details {
    Some(details) => result = result + "\nDetails: " + details
    None => {}
  }

  // 添加附加信息
  if self.context.additional_info.length() > 0 {
    result = result + "\nAdditional Info:"
    for (key, value) in self.context.additional_info.to_array() {
      result = result + "\n  " + key + ": " + value
    }
  }

  // 添加原因链
  match self.cause {
    Some(cause) => {
      result = result + "\n\nCaused by:"
      result = result + "\n" + cause.format()
    }
    None => {}
  }

  result
}

///|
/// 错误结果
pub(all) type Result[T] = Ok(T) | Err(McpError)

///|
/// 将 Result 转换为 JSON-RPC 响应（包含错误详情）
pub(all) fn Result::to_jsonrpc_response[T](self : Result[T], id : JsonId) -> JsonResponse {
  match self {
    Ok(value) => {
      // 假设 T 可以转换为 JsonValue
      let json_value = match (unwrap_any(value) : JsonValue) {
        v => v
      }
      JsonResponse::{
        jsonrpc: "2.0",
        result: Some(json_value),
        error: None,
        id: Some(id)
      }
    }
    Err(err) => {
      // 构建错误数据，包含上下文信息
      let mut error_data = Map::empty()
      error_data = error_data.insert("location", String(err.context.location.to_string()))
      error_data = error_data.insert("timestamp", String(err.context.timestamp))

      // 添加详细信息
      match err.details {
        Some(details) => error_data = error_data.insert("details", String(details))
        None => {}
      }

      // 添加附加信息
      if err.context.additional_info.length() > 0 {
        let mut info_map = Map::empty()
        for (key, value) in err.context.additional_info.to_array() {
          info_map = info_map.insert(key, String(value))
        }
        error_data = error_data.insert("additionalInfo", Object(info_map))
      }

      JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(JsonError::{
          code: err.to_jsonrpc_code(),
          message: err.message,
          data: Some(Object(error_data))
        }),
        id: Some(id)
      }
    }
  }
}

///|
/// 创建带有上下文的错误位置（用于日志）
pub(all) fn create_error_context(function_name : String) -> ErrorContext {
  ErrorContext::new(
    ErrorLocation::new()
      .with_function(function_name)
  )
}

///|
/// 创建带有请求 ID 的错误上下文
pub(all) fn create_error_context_with_request(function_name : String, request_id : String) -> ErrorContext {
  ErrorContext::new(
    ErrorLocation::new()
      .with_function(function_name)
  ).with_request_id(request_id)
}

///|
/// 安全的 unwrap 辅助函数
fn unwrap_any[T](value : T) -> Any {
  value
}
