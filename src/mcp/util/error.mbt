// MoonBitMark MCP Utility - Error Handling

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
/// MCP 错误类型
pub(all) struct McpError {
  code : McpErrorCode
  message : String
  details : String?
}

///|
/// 创建解析错误
pub(all) fn McpError::parse_error(code : Int, message : String) -> McpError {
  { code: ParseError(code), message, details: None }
}

///|
/// 创建无效请求错误
pub(all) fn McpError::invalid_request(message : String) -> McpError {
  { code: InvalidRequest, message, details: None }
}

///|
/// 创建方法未找到错误
pub(all) fn McpError::method_not_found(method : String) -> McpError {
  { code: MethodNotFound, message: "Method not found: " + method, details: None }
}

///|
/// 创建无效参数错误
pub(all) fn McpError::invalid_params(message : String) -> McpError {
  { code: InvalidParams, message, details: None }
}

///|
/// 创建内部错误
pub(all) fn McpError::internal_error(message : String, details : String?) -> McpError {
  { code: InternalError, message, details }
}

///|
/// 创建工具错误
pub(all) fn McpError::tool_error(tool_name : String, reason : String) -> McpError {
  { code: ToolError(tool_name), message: "Tool execution failed: " + reason, details: None }
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
/// 格式化错误消息
pub(all) fn McpError::format(self : McpError) -> String {
  let mut result = self.message

  match self.details {
    Some(details) => result = result + "\nDetails: " + details
    None => {}
  }

  result
}

///|
/// 错误结果
pub(all) type Result[T] = Ok(T) | Err(McpError)

///|
/// 将 Result 转换为 JSON-RPC 响应
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
      JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(JsonError::{
          code: err.to_jsonrpc_code(),
          message: err.format(),
          data: None
        }),
        id: Some(id)
      }
    }
  }
}

///|
/// 安全的 unwrap 辅助函数
fn unwrap_any[T](value : T) -> Any {
  value
}
