// MoonBitMark MCP Handler - Server Implementation

///|
pub(all) struct McpServer {
  tools : ToolRegistry
  transport : @transport.StdioTransport
  logger : @util.Logger
}

///|
pub fn McpServer::new(transport : @transport.StdioTransport) -> McpServer {
  McpServer::new_with_logger(transport, @util.Logger::default())
}

///|
pub fn McpServer::new_with_logger(
  transport : @transport.StdioTransport,
  logger : @util.Logger,
) -> McpServer {
  let registry = ToolRegistry::new().register_convert_tools() catch {
    _error => ToolRegistry::new()
  }

  McpServer::{ tools: registry, transport, logger }
}

///|
pub async fn McpServer::handle_jsonrpc_request(
  self : McpServer,
  json_str : String,
) -> @types.JsonResponse {
  match @types.parse_json(json_str) {
    Ok(json) =>
      match parse_json_request(json) {
        Ok(request) => self.handle_request(request)
        Err(message) =>
          @types.JsonResponse::{
            jsonrpc: "2.0",
            result: None,
            error: Some(@types.JsonError::{ code: -32600, message, data: None }),
            id: None,
          }
      }
    Err(error) =>
      @types.JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(@types.JsonError::{
          code: -32700,
          message: error.to_string(),
          data: None,
        }),
        id: None,
      }
  }
}

///|
async fn McpServer::handle_request(
  self : McpServer,
  request : @types.JsonRequest,
) -> @types.JsonResponse {
  match request.method_name {
    "initialize" => self.handle_initialize(request.id)
    "tools/list" => self.handle_tools_list(request.id)
    "tools/call" => self.handle_tools_call(request.params, request.id)
    _ =>
      @types.JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(@types.JsonError::{
          code: -32601,
          message: "Method not found: " + request.method_name,
          data: None,
        }),
        id: request.id,
      }
  }
}

///|
fn McpServer::handle_initialize(
  self : McpServer,
  id : @types.JsonId?,
) -> @types.JsonResponse {
  ignore(self)
  let result = @types.McpInitializeResult::{
    protocol_version: "2024-11-05",
    capabilities: @types.McpServerCapabilities::{
      tools: @types.McpServerCapabilitiesTools::{ list_changed: false },
    },
    server_info: @types.McpServerInfo::{
      name: "moonbitmark",
      version: "0.3.0",
      protocol_version: "2024-11-05",
    },
  }

  @types.JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id,
  }
}

///|
fn McpServer::handle_tools_list(
  self : McpServer,
  id : @types.JsonId?,
) -> @types.JsonResponse {
  let result = @types.McpToolsListResult::{ tools: self.tools.list() }
  @types.JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id,
  }
}

///|
async fn McpServer::handle_tools_call(
  self : McpServer,
  params : @types.JsonValue?,
  id : @types.JsonId?,
) -> @types.JsonResponse {
  let parsed_params = match params {
    Some(value) => parse_tool_call_params(value)
    None => Err("Invalid params: params is required")
  }

  match parsed_params {
    Ok(call_params) => {
      let result = self.tools.call(call_params.name, call_params.arguments)
      @types.JsonResponse::{
        jsonrpc: "2.0",
        result: Some(result.to_json()),
        error: None,
        id,
      }
    }
    Err(message) =>
      @types.JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(@types.JsonError::{ code: -32602, message, data: None }),
        id,
      }
  }
}

///|
pub async fn McpServer::run(self : McpServer) -> Unit {
  while true {
    let json_str = match self.transport.read_line() {
      Some(value) => value
      None => break
    }
    if json_str.trim().length() == 0 {
      continue
    }
    let response = self.handle_jsonrpc_request(json_str)
    self.transport.write_line(response_to_json(response))
  }
}

///|
fn parse_json_request(
  json : @types.JsonValue,
) -> Result[@types.JsonRequest, String] {
  match json {
    @types.Object(map) => {
      let jsonrpc = match map.get("jsonrpc") {
        Some(@types.String(value)) => value
        _ => return Err("Missing or invalid 'jsonrpc' field")
      }
      let method_name = match map.get("method") {
        Some(@types.String(value)) => value
        _ => return Err("Missing or invalid 'method' field")
      }
      let id = match map.get("id") {
        Some(@types.String(value)) => Some(@types.StringId(value))
        Some(@types.Number(value)) => Some(@types.NumberId(value))
        Some(@types.Null) => Some(@types.NullId)
        None => None
        _ => return Err("Invalid 'id' field")
      }

      Ok(@types.JsonRequest::{
        jsonrpc,
        method_name,
        params: map.get("params"),
        id,
      })
    }
    _ => Err("JSON must be an object")
  }
}

///|
fn parse_tool_call_params(
  json : @types.JsonValue,
) -> Result[@types.McpToolCallParams, String] {
  match json {
    @types.Object(map) => {
      let name = match map.get("name") {
        Some(@types.String(value)) => value
        _ => return Err("Missing or invalid 'name' field")
      }
      let arguments = match map.get("arguments") {
        Some(value) => value
        None => @types.Object(Map::new())
      }
      Ok(@types.McpToolCallParams::{ name, arguments })
    }
    _ => Err("Tool call params must be an object")
  }
}

///|
fn response_to_json(response : @types.JsonResponse) -> String {
  let map : Map[String, @types.JsonValue] = Map::new()
  map["jsonrpc"] = @types.String(response.jsonrpc)

  match response.result {
    Some(value) => map["result"] = value
    None => ()
  }
  match response.error {
    Some(error) => {
      let error_map : Map[String, @types.JsonValue] = Map::new()
      error_map["code"] = @types.Number(error.code)
      error_map["message"] = @types.String(error.message)
      match error.data {
        Some(value) => error_map["data"] = value
        None => ()
      }
      map["error"] = @types.Object(error_map)
    }
    None => ()
  }
  match response.id {
    Some(@types.StringId(value)) => map["id"] = @types.String(value)
    Some(@types.NumberId(value)) => map["id"] = @types.Number(value)
    Some(@types.NullId) => map["id"] = @types.Null
    None => ()
  }

  @types.Object(map).to_string()
}
