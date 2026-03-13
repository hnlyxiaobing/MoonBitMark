// MoonBitMark MCP Handler - Server Implementation

use @types.*
use @transport.*
use @util.*

///|
pub(all) struct McpServer {
  tools : ToolRegistry
  transport : StdioTransport
  logger : Logger
}

///|
pub fn McpServer::new(transport : StdioTransport) -> McpServer {
  McpServer::new_with_logger(transport, Logger::default())
}

///|
pub fn McpServer::new_with_logger(
  transport : StdioTransport,
  logger : Logger,
) -> McpServer {
  let registry = ToolRegistry::new().register_convert_tools() catch {
    error => {
      logger.error("Failed to register tools: " + error.to_string())
      ToolRegistry::new()
    }
  }

  McpServer::{ tools: registry, transport, logger }
}

///|
pub async fn McpServer::handle_jsonrpc_request(
  self : McpServer,
  json_str : String,
) -> JsonResponse {
  match parse_json(json_str) {
    Ok(json) =>
      match parse_json_request(json) {
        Ok(request) => self.handle_request(request)
        Err(message) =>
          JsonResponse::{
            jsonrpc: "2.0",
            result: None,
            error: Some(JsonError::{ code: -32600, message, data: None }),
            id: None,
          }
      }
    Err(error) =>
      JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(JsonError::{
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
  request : JsonRequest,
) -> JsonResponse {
  match request.method {
    "initialize" => self.handle_initialize(request.id)
    "tools/list" => self.handle_tools_list(request.id)
    "tools/call" => self.handle_tools_call(request.params, request.id)
    _ =>
      JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(JsonError::{
          code: -32601,
          message: "Method not found: " + request.method,
          data: None,
        }),
        id: request.id,
      }
  }
}

///|
fn McpServer::handle_initialize(self : McpServer, id : JsonId?) -> JsonResponse {
  ignore(self)
  let result = McpInitializeResult::{
    protocol_version: "2024-11-05",
    capabilities: McpServerCapabilities::{
      tools: McpServerCapabilitiesTools::{ list_changed: false },
    },
    server_info: McpServerInfo::{
      name: "moonbitmark",
      version: "0.3.0",
      protocol_version: "2024-11-05",
    },
  }

  JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id,
  }
}

///|
fn McpServer::handle_tools_list(self : McpServer, id : JsonId?) -> JsonResponse {
  let result = McpToolsListResult::{ tools: self.tools.list() }
  JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id,
  }
}

///|
async fn McpServer::handle_tools_call(
  self : McpServer,
  params : JsonValue?,
  id : JsonId?,
) -> JsonResponse {
  let parsed_params = match params {
    Some(value) => parse_tool_call_params(value)
    None => Err("Invalid params: params is required")
  }

  match parsed_params {
    Ok(call_params) => {
      let result = self.tools.call(call_params.name, call_params.arguments)
      JsonResponse::{
        jsonrpc: "2.0",
        result: Some(result.to_json()),
        error: None,
        id,
      }
    }
    Err(message) =>
      JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(JsonError::{ code: -32602, message, data: None }),
        id,
      }
  }
}

///|
pub async fn McpServer::run(self : McpServer) -> Unit {
  self.logger.info("Starting MCP server")
  loop {
    let json_str = self.transport.read_line()
    if json_str.trim().length() == 0 {
      continue
    }
    let response = self.handle_jsonrpc_request(json_str)
    self.transport.write_line(response_to_json(response))
  }
}

///|
fn parse_json_request(json : JsonValue) -> Result[JsonRequest, String] {
  match json {
    Object(map) => {
      let jsonrpc = match map.get("jsonrpc") {
        Some(String(value)) => value
        _ => return Err("Missing or invalid 'jsonrpc' field")
      }
      let method = match map.get("method") {
        Some(String(value)) => value
        _ => return Err("Missing or invalid 'method' field")
      }
      let id = match map.get("id") {
        Some(String(value)) => Some(StringId(value))
        Some(Number(value)) => Some(NumberId(value))
        Some(Null) => Some(NullId)
        None => None
        _ => return Err("Invalid 'id' field")
      }

      Ok(JsonRequest::{ jsonrpc, method, params: map.get("params"), id })
    }
    _ => Err("JSON must be an object")
  }
}

///|
fn parse_tool_call_params(json : JsonValue) -> Result[McpToolCallParams, String] {
  match json {
    Object(map) => {
      let name = match map.get("name") {
        Some(String(value)) => value
        _ => return Err("Missing or invalid 'name' field")
      }
      let arguments = match map.get("arguments") {
        Some(value) => value
        None => Object(Map::new())
      }
      Ok(McpToolCallParams::{ name, arguments })
    }
    _ => Err("Tool call params must be an object")
  }
}

///|
fn response_to_json(response : JsonResponse) -> String {
  let map : Map[String, JsonValue] = Map::new()
  map["jsonrpc"] = String(response.jsonrpc)

  match response.result {
    Some(value) => map["result"] = value
    None => ()
  }
  match response.error {
    Some(error) => {
      let error_map : Map[String, JsonValue] = Map::new()
      error_map["code"] = Number(error.code)
      error_map["message"] = String(error.message)
      match error.data {
        Some(value) => error_map["data"] = value
        None => ()
      }
      map["error"] = Object(error_map)
    }
    None => ()
  }
  match response.id {
    Some(StringId(value)) => map["id"] = String(value)
    Some(NumberId(value)) => map["id"] = Number(value)
    Some(NullId) => map["id"] = Null
    None => ()
  }

  Object(map).to_string()
}
