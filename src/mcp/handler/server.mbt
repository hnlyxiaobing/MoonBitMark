// MoonBitMark MCP Handler - Server Implementation

use @jsonrpc.*
use @json_parser.*
use @types.*
use @transport.*
use @handler.*
use @util.*
use @async_runtime.*

///|
/// MCP 服务器
pub(all) struct McpServer {
  tools : ToolRegistry
  transport : StdioTransport
  logger : Logger
}

///|
/// 创建 MCP 服务器
pub fn McpServer::new(transport : StdioTransport) -> McpServer {
  let server = McpServer::{
    tools: ToolRegistry::new(),
    transport: transport,
    logger: Logger::default()
  }

  // 注册默认工具
  let server = match server.tools.register_convert_tools() {
    Ok(registry) => {
      server.tools = registry
      server.logger.info("Registered convert_to_markdown tool")
      server
    }
    Err(e) => {
      server.logger.error("Failed to register tools: " + e)
      server
    }
  }

  server
}

///|
/// 创建带日志器的 MCP 服务器
pub fn McpServer::new_with_logger(transport : StdioTransport, logger : Logger) -> McpServer {
  let server = McpServer::{
    tools: ToolRegistry::new(),
    transport: transport,
    logger: logger
  }

  // 注册默认工具
  let server = match server.tools.register_convert_tools() {
    Ok(registry) => {
      server.tools = registry
      server.logger.info("Registered convert_to_markdown tool")
      server
    }
    Err(e) => {
      server.logger.error("Failed to register tools: " + e)
      server
    }
  }

  server
}

///|
/// 处理 JSON-RPC 请求
pub fn McpServer::handle_jsonrpc_request(self : McpServer, json_str : String) -> JsonResponse {
  self.logger.debug("Processing JSON-RPC request")

  // 尝试解析 JSON
  match parse_json(json_str) {
    Ok(json) => {
      self.logger.debug("JSON parsed successfully")

      // 解析为 JsonRequest
      match parse_json_request(json) {
        Ok(request) => {
          self.logger.info("Handling method: " + request.method)
          let response = self.handle_request(request)
          self.logger.debug("Response generated")
          response
        }
        Err(e) => {
          self.logger.error("Invalid request: " + e.to_string())
          JsonResponse::{
            jsonrpc: "2.0",
            result: None,
            error: Some(JsonError::{
              code: -32600,
              message: "Invalid Request: " + e.to_string(),
              data: None
            }),
            id: None
          }
        }
      }
    }
    Err(e) => {
      self.logger.error("Parse error: " + e.to_string())
      JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(JsonError::{
          code: -32700,
          message: "Parse error: " + e.to_string(),
          data: None
        }),
        id: None
      }
    }
  }
}

///|
/// 处理 MCP 请求
fn McpServer::handle_request(self : McpServer, request : JsonRequest) -> JsonResponse {
  match request.method {
    "initialize" => self.handle_initialize(request.params, request.id)
    "tools/list" => self.handle_tools_list(request.id)
    "tools/call" => self.handle_tools_call(request.params, request.id)
    _ => self.handle_method_not_found(request.method, request.id)
  }
}

///|
/// 初始化处理
fn McpServer::handle_initialize(self : McpServer, params : JsonValue?, id : JsonId?) -> JsonResponse {
  self.logger.info("Initializing MCP server")

  let result = McpInitializeResult::{
    protocol_version: "2024-11-05",
    capabilities: McpServerCapabilities::{
      tools: McpServerCapabilitiesTools::{
        listChanged: false
      }
    },
    server_info: McpServerInfo::{
      name: "moonbitmark",
      version: "0.7.0",
      protocol_version: "2024-11-05"
    }
  }

  JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id: id
  }
}

///|
/// 工具列表处理
fn McpServer::handle_tools_list(self : McpServer, id : JsonId?) -> JsonResponse {
  let tools = self.tools.list()
  let result = McpToolsListResult::{ tools: tools }

  JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id: id
  }
}

///|
/// 工具调用处理 (async)
fn McpServer::handle_tools_call(self : McpServer, params : JsonValue?, id : JsonId?) -> JsonResponse {
  match params {
    Some(p) => {
      // 尝试解析工具调用参数
      match parse_tool_call_params(p) {
        Ok(call_params) => {
          // Call tool (returns Future)
          let result_future = self.tools.call(call_params.name, call_params.arguments)

          // Wait for future to complete (blocking for now)
          match block_on(result_future) {
            Ok(result) => {
              JsonResponse::{
                jsonrpc: "2.0",
                result: Some(result.to_json()),
                error: None,
                id: id
              }
            }
            Err(e) => {
              JsonResponse::{
                jsonrpc: "2.0",
                result: None,
                error: Some(JsonError::{
                  code: -32603,
                  message: "Internal error: " + e,
                  data: None
                }),
                id: id
              }
            }
          }
        }
        Err(e) => {
          JsonResponse::{
            jsonrpc: "2.0",
            result: None,
            error: Some(JsonError::{
              code: -32602,
              message: "Invalid params: " + e,
              data: None
            }),
            id: id
          }
        }
      }
    }
    None => {
      JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(JsonError::{
          code: -32602,
          message: "Invalid params: params is required",
          data: None
        }),
        id: id
      }
    }
  }
}

///|
/// 方法不存在处理
fn McpServer::handle_method_not_found(self : McpServer, method : String, id : JsonId?) -> JsonResponse {
  JsonResponse::{
    jsonrpc: "2.0",
    result: None,
    error: Some(JsonError::{
      code: -32601,
      message: "Method not found: " + method,
      data: None
    }),
    id: id
  }
}

///|
/// 运行服务器主循环
pub fn McpServer::run(self : McpServer) -> Unit {
  self.logger.info("Starting MCP server (MoonBitMark v0.7.0)")

  loop {
    let json_str = self.transport.read_line()

    // 处理空行
    if json_str.trim().length() == 0 {
      continue
    }

    let response = self.handle_jsonrpc_request(json_str)
    let response_json = response_to_json(response)
    self.transport.write_line(response_json)
  }
}

///|
/// 解析 JSON (使用新的 JSON 解析器)
fn parse_json(json_str : String) -> Result[JsonValue, String] {
  match parse_json(json_str) {
    Ok(value) => Ok(value)
    Err(e) => Err(e.to_string())
  }
}

///|
/// 从 JSON 解析 JsonRequest
fn parse_json_request(json : JsonValue) -> Result[JsonRequest, String] {
  match json {
    Object(m) => {
      // 提取 jsonrpc
      let jsonrpc = match m.get("jsonrpc") {
        Some(String(s)) => s
        _ => return Err("Missing or invalid 'jsonrpc' field")
      }

      // 提取 method
      let method = match m.get("method") {
        Some(String(s)) => s
        _ => return Err("Missing or invalid 'method' field")
      }

      // 提取 params (可选)
      let params = m.get("params")

      // 提取 id
      let id = match m.get("id") {
        Some(String(s)) => Some(StringId(s))
        Some(Number(n)) => Some(NumberId(n))
        Some(Null) => Some(NullId)
        None => None
        _ => return Err("Invalid 'id' field")
      }

      Ok(JsonRequest::{ jsonrpc, method, params, id })
    }
    _ => Err("JSON must be an object")
  }
}

///|
/// 从 JSON 解析工具调用参数
fn parse_tool_call_params(json : JsonValue) -> Result[McpToolCallParams, String] {
  match json {
    Object(m) => {
      // 提取 name
      let name = match m.get("name") {
        Some(String(s)) => s
        _ => return Err("Missing or invalid 'name' field")
      }

      // 提取 arguments
      let arguments = match m.get("arguments") {
        Some(arg) => arg
        None => Object(Map::empty()) // 默认为空对象
        _ => return Err("Invalid 'arguments' field")
      }

      Ok(McpToolCallParams::{ name, arguments })
    }
    _ => Err("Tool call params must be an object")
  }
}

///|
/// 将 JsonResponse 转换为 JSON 字符串
fn response_to_json(response : JsonResponse) -> String {
  let mut m = Map::empty()
  m = m.insert("jsonrpc", String(response.jsonrpc))

  match response.result {
    Some(r) => m = m.insert("result", r)
    None => {}
  }

  match response.error {
    Some(e) => {
      let mut error_m = Map::empty()
      error_m = error_m.insert("code", Number(e.code))
      error_m = error_m.insert("message", String(e.message))
      match e.data {
        Some(d) => error_m = error_m.insert("data", d)
        None => {}
      }
      m = m.insert("error", Object(error_m))
    }
    None => {}
  }

  match response.id {
    Some(i) => {
      match i {
        StringId(s) => m = m.insert("id", String(s))
        NumberId(n) => m = m.insert("id", Number(n))
        NullId => m = m.insert("id", Null)
      }
    }
    None => {}
  }

  let json_value = Object(m)
  json_value.to_string()
}
