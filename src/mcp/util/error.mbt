// MoonBitMark MCP Utility - Error Helpers

///|
pub enum McpErrorCode {
  ParseError(Int)
  InvalidRequest
  MethodNotFound
  InvalidParams
  InternalError
  ServerError(Int)
  ToolError(String)
}

///|
pub(all) struct ErrorLocation {
  file : String?
  line : Int?
  column : Int?
  function : String?
}

///|
pub fn ErrorLocation::new() -> ErrorLocation {
  { file: None, line: None, column: None, function: None }
}

///|
pub fn ErrorLocation::with_file(
  self : ErrorLocation,
  file : String,
) -> ErrorLocation {
  {
    file: Some(file),
    line: self.line,
    column: self.column,
    function: self.function,
  }
}

///|
pub fn ErrorLocation::with_line(
  self : ErrorLocation,
  line : Int,
) -> ErrorLocation {
  {
    file: self.file,
    line: Some(line),
    column: self.column,
    function: self.function,
  }
}

///|
pub fn ErrorLocation::with_column(
  self : ErrorLocation,
  column : Int,
) -> ErrorLocation {
  {
    file: self.file,
    line: self.line,
    column: Some(column),
    function: self.function,
  }
}

///|
pub fn ErrorLocation::with_function(
  self : ErrorLocation,
  function_name : String,
) -> ErrorLocation {
  {
    file: self.file,
    line: self.line,
    column: self.column,
    function: Some(function_name),
  }
}

///|
pub fn ErrorLocation::to_string(self : ErrorLocation) -> String {
  let parts : Array[String] = []
  match self.file {
    Some(value) => parts.push(value)
    None => ()
  }
  match self.line {
    Some(value) => parts.push("line " + value.to_string())
    None => ()
  }
  match self.column {
    Some(value) => parts.push("col " + value.to_string())
    None => ()
  }
  match self.function {
    Some(value) => parts.push("in " + value)
    None => ()
  }

  if parts.length() == 0 {
    "(unknown location)"
  } else {
    parts.join(" ")
  }
}

///|
pub(all) struct ErrorContext {
  location : ErrorLocation
  timestamp : String
  request_id : String?
  additional_info : Map[String, String]
}

///|
pub fn ErrorContext::new(location : ErrorLocation) -> ErrorContext {
  {
    location,
    timestamp: "[TIMESTAMP]",
    request_id: None,
    additional_info: Map::new(),
  }
}

///|
pub fn ErrorContext::with_request_id(
  self : ErrorContext,
  request_id : String,
) -> ErrorContext {
  {
    location: self.location,
    timestamp: self.timestamp,
    request_id: Some(request_id),
    additional_info: self.additional_info,
  }
}

///|
pub fn ErrorContext::add_info(
  self : ErrorContext,
  key : String,
  value : String,
) -> ErrorContext {
  let info = self.additional_info
  info[key] = value
  {
    location: self.location,
    timestamp: self.timestamp,
    request_id: self.request_id,
    additional_info: info,
  }
}

///|
pub(all) struct McpError {
  code : McpErrorCode
  message : String
  details : String?
  context : ErrorContext
  cause : McpError?
}

///|
pub fn McpError::parse_error(
  code : Int,
  message : String,
  context : ErrorContext,
) -> McpError {
  { code: ParseError(code), message, details: None, context, cause: None }
}

///|
pub fn McpError::invalid_request(
  message : String,
  context : ErrorContext,
) -> McpError {
  { code: InvalidRequest, message, details: None, context, cause: None }
}

///|
pub fn McpError::method_not_found(
  method_name : String,
  context : ErrorContext,
) -> McpError {
  {
    code: MethodNotFound,
    message: "Method not found: " + method_name,
    details: None,
    context,
    cause: None,
  }
}

///|
pub fn McpError::invalid_params(
  message : String,
  context : ErrorContext,
) -> McpError {
  { code: InvalidParams, message, details: None, context, cause: None }
}

///|
pub fn McpError::internal_error(
  message : String,
  details : String?,
  context : ErrorContext,
) -> McpError {
  { code: InternalError, message, details, context, cause: None }
}

///|
pub fn McpError::internal_error_with_cause(
  message : String,
  details : String?,
  context : ErrorContext,
  cause : McpError,
) -> McpError {
  { code: InternalError, message, details, context, cause: Some(cause) }
}

///|
pub fn McpError::tool_error(
  tool_name : String,
  reason : String,
  context : ErrorContext,
) -> McpError {
  {
    code: ToolError(tool_name),
    message: "Tool execution failed: " + reason,
    details: None,
    context,
    cause: None,
  }
}

///|
pub fn McpError::to_jsonrpc_code(self : McpError) -> Int {
  match self.code {
    ParseError(code) => code
    InvalidRequest => -32600
    MethodNotFound => -32601
    InvalidParams => -32602
    InternalError => -32603
    ServerError(code) => code
    ToolError(_) => -32000
  }
}

///|
pub fn McpError::format(self : McpError) -> String {
  let parts : Array[String] = []
  parts.push(self.message)
  parts.push("Location: " + self.context.location.to_string())
  parts.push("Time: " + self.context.timestamp)

  match self.context.request_id {
    Some(request_id) => parts.push("Request ID: " + request_id)
    None => ()
  }
  match self.details {
    Some(details) => parts.push("Details: " + details)
    None => ()
  }
  for entry in self.context.additional_info.to_array() {
    let (key, value) = entry
    parts.push(key + ": " + value)
  }
  match self.cause {
    Some(cause) => parts.push("Caused by:\n" + cause.format())
    None => ()
  }

  parts.join("\n")
}

///|
pub fn create_error_context(function_name : String) -> ErrorContext {
  ErrorContext::new(ErrorLocation::new().with_function(function_name))
}

///|
pub fn create_error_context_with_request(
  function_name : String,
  request_id : String,
) -> ErrorContext {
  create_error_context(function_name).with_request_id(request_id)
}
