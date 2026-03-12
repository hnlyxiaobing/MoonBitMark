// MoonBitMark MCP Error Handling Tests

use @error.*

///|
/// 测试错误创建
pub fn test_error_creation() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 测试解析错误
  let context = create_error_context("test_function")
  let parse_err = McpError::parse_error(-32700, "Parse error", context)
  if parse_err.message == "Parse error" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试无效请求错误
  let invalid_req = McpError::invalid_request("Invalid request", context)
  if invalid_req.message == "Invalid request" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试方法未找到错误
  let method_not_found = McpError::method_not_found("test_method", context)
  if method_not_found.message == "Method not found: test_method" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试无效参数错误
  let invalid_params = McpError::invalid_params("Invalid parameters", context)
  if invalid_params.message == "Invalid parameters" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试内部错误
  let internal_err = McpError::internal_error("Internal error", Some("Details"), context)
  if internal_err.message == "Internal error" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试工具错误
  let tool_err = McpError::tool_error("convert_to_markdown", "Conversion failed", context)
  if tool_err.message == "Tool execution failed: Conversion failed" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  @io.println("Error creation tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试错误上下文
pub fn test_error_context() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 测试错误位置
  let location = ErrorLocation::new()
    .with_file("test.mbt")
    .with_line(42)
    .with_function("test_function")

  if location.to_string().contains("test.mbt") {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  if location.to_string().contains("line 42") {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试错误上下文
  let context = ErrorContext::new(location)
    .with_request_id("req-123")
    .add_info("key1", "value1")
    .add_info("key2", "value2")

  match context.request_id {
    Some(id) if id == "req-123" => passed = passed + 1
    _ => failed = failed + 1
  }

  if context.additional_info.length() == 2 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  @io.println("Error context tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试错误格式化
pub fn test_error_formatting() -> Bool {
  let mut passed = 0
  let mut failed = 0

  let context = create_error_context_with_request("test_function", "req-456")
    .add_info("user", "test_user")

  let error = McpError::internal_error(
    "Test error",
    Some("Error details"),
    context
  )

  let formatted = error.format()

  if formatted.contains("Test error") {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  if formatted.contains("Location:") {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  if formatted.contains("Request ID: req-456") {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  if formatted.contains("Details: Error details") {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  @io.println("Error formatting tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试错误链（原因）
pub fn test_error_chain() -> Bool {
  let mut passed = 0
  let mut failed = failed

  let context = create_error_context("inner_function")
  let inner_error = McpError::internal_error("Inner error", None, context)

  let outer_context = create_error_context("outer_function")
  let outer_error = McpError::internal_error_with_cause(
    "Outer error",
    None,
    outer_context,
    inner_error
  )

  if outer_error.message == "Outer error" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  match outer_error.cause {
    Some(cause) => {
      if cause.message == "Inner error" {
        passed = passed + 1
      } else {
        failed = failed + 1
      }
    }
    None => failed = failed + 1
  }

  let formatted = outer_error.format()
  if formatted.contains("Caused by:") {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  @io.println("Error chain tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试 JSON-RPC 错误代码转换
pub fn test_jsonrpc_code_conversion() -> Bool {
  let mut passed = 0
  let mut failed = 0

  let context = create_error_context("test")

  // ParseError (-32700)
  let parse_err = McpError::parse_error(-32700, "Parse error", context)
  if parse_err.to_jsonrpc_code() == -32700 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // InvalidRequest (-32600)
  let invalid_req = McpError::invalid_request("Invalid request", context)
  if invalid_req.to_jsonrpc_code() == -32600 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // MethodNotFound (-32601)
  let not_found = McpError::method_not_found("method", context)
  if not_found.to_jsonrpc_code() == -32601 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // InvalidParams (-32602)
  let invalid_params = McpError::invalid_params("Invalid params", context)
  if invalid_params.to_jsonrpc_code() == -32602 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // InternalError (-32603)
  let internal = McpError::internal_error("Internal error", None, context)
  if internal.to_jsonrpc_code() == -32603 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // ToolError (-32000)
  let tool_err = McpError::tool_error("tool", "error", context)
  if tool_err.to_jsonrpc_code() == -32000 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  @io.println("JSON-RPC code conversion tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 运行所有测试
pub fn run_all_tests() -> Bool {
  @io.println("========================================")
  @io.println("Error Handling Tests")
  @io.println("========================================")
  @io.println("")

  let all_passed = test_error_creation()
    && test_error_context()
    && test_error_formatting()
    && test_error_chain()
    && test_jsonrpc_code_conversion()

  @io.println("")
  @io.println("========================================")
  if all_passed {
    @io.println("All tests passed!")
  } else {
    @io.println("Some tests failed!")
  }
  @io.println("========================================")

  all_passed
}
