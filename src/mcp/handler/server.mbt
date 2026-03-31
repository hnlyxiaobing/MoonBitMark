// MoonBitMark MCP Handler - Server Implementation

///|
pub(all) struct McpDispatcher {
  tools : ToolRegistry
  resources : ResourceRegistry
  prompts : PromptRegistry
}

///|
pub(all) struct McpServer {
  dispatcher : McpDispatcher
  transport : @transport.StdioTransport
}

///|
pub fn McpDispatcher::new() -> McpDispatcher {
  McpDispatcher::new_with_logger(@util.Logger::default())
}

///|
pub fn McpDispatcher::new_with_logger(logger : @util.Logger) -> McpDispatcher {
  // Keep the compatibility constructor, but do not retain a logger on the
  // live STDIO server path where stdout must stay protocol-clean.
  ignore(logger)
  let registry = ToolRegistry::new().register_convert_tools() catch {
    _error => ToolRegistry::new()
  }
  let resources = ResourceRegistry::new().register_static_resources() catch {
    _error => ResourceRegistry::new()
  }
  let prompts = PromptRegistry::new().register_static_prompts() catch {
    _error => PromptRegistry::new()
  }

  McpDispatcher::{ tools: registry, resources, prompts }
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
  McpServer::{ dispatcher: McpDispatcher::new_with_logger(logger), transport }
}

///|
pub async fn McpDispatcher::handle_jsonrpc_request(
  self : McpDispatcher,
  json_str : String,
) -> @types.JsonResponse? {
  match @types.parse_json(json_str) {
    Ok(json) =>
      match parse_json_request(json) {
        Ok(request) => self.handle_request(request)
        Err(message) =>
          Some(@types.JsonResponse::{
            jsonrpc: "2.0",
            result: None,
            error: Some(@types.JsonError::{ code: -32600, message, data: None }),
            id: None,
          })
      }
    Err(error) =>
      Some(@types.JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(@types.JsonError::{
          code: -32700,
          message: error.to_string(),
          data: None,
        }),
        id: None,
      })
  }
}

///|
pub async fn McpServer::handle_jsonrpc_request(
  self : McpServer,
  json_str : String,
) -> @types.JsonResponse? {
  self.dispatcher.handle_jsonrpc_request(json_str)
}

///|
async fn McpDispatcher::handle_request(
  self : McpDispatcher,
  request : @types.JsonRequest,
) -> @types.JsonResponse? {
  if !request_expects_response(request) {
    return None
  }

  match request.method_name {
    "initialize" => Some(self.handle_initialize(request.id))
    "tools/list" => Some(self.handle_tools_list(request.id))
    "tools/call" => Some(self.handle_tools_call(request.params, request.id))
    "resources/list" => Some(self.handle_resources_list(request.id))
    "resources/read" =>
      Some(self.handle_resources_read(request.params, request.id))
    "prompts/list" => Some(self.handle_prompts_list(request.id))
    "prompts/get" => Some(self.handle_prompts_get(request.params, request.id))
    _ =>
      Some(@types.JsonResponse::{
        jsonrpc: "2.0",
        result: None,
        error: Some(@types.JsonError::{
          code: -32601,
          message: "Method not found: " + request.method_name,
          data: None,
        }),
        id: request.id,
      })
  }
}

///|
fn McpDispatcher::handle_initialize(
  self : McpDispatcher,
  id : @types.JsonId?,
) -> @types.JsonResponse {
  ignore(self)
  let result = @types.McpInitializeResult::{
    protocol_version: "2024-11-05",
    capabilities: @types.McpServerCapabilities::{
      tools: @types.McpServerCapabilitiesTools::{ list_changed: false },
      resources: Some(@types.McpServerCapabilitiesResources::{
        subscribe: false,
        list_changed: false,
      }),
      prompts: Some(@types.McpServerCapabilitiesPrompts::{ list_changed: false }),
    },
    server_info: @types.McpServerInfo::{
      name: "moonbitmark",
      version: "0.3.0",
      protocol_version: "2024-11-05",
    },
    instructions: Some(
      "Use prompts/get for guided flows, resources/read for boundaries, inspect first for unknown or large documents, keep convert_to_markdown in preview mode unless you need the full Markdown, prefer upload_document plus resource_uri when the client only has bytes, keep convert_uploaded_document as the one-shot upload plus convert path, and remember that file roots, HTTP access, OCR, upload size, and output caps are controlled by MOONBITMARK_MCP_* environment variables.",
    ),
  }

  @types.JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id,
  }
}

///|
fn McpDispatcher::handle_tools_list(
  self : McpDispatcher,
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
fn McpDispatcher::handle_resources_list(
  self : McpDispatcher,
  id : @types.JsonId?,
) -> @types.JsonResponse {
  let result = @types.McpResourcesListResult::{
    resources: self.resources.list(),
  }
  @types.JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id,
  }
}

///|
async fn McpDispatcher::handle_resources_read(
  self : McpDispatcher,
  params : @types.JsonValue?,
  id : @types.JsonId?,
) -> @types.JsonResponse {
  let parsed_params = match params {
    Some(value) => parse_read_resource_params(value)
    None => Err("Invalid params: params is required")
  }

  match parsed_params {
    Ok(read_params) =>
      match self.resources.read(read_params.uri) {
        Ok(content) => {
          let result = @types.McpResourcesReadResult::{ contents: [content] }
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
            error: Some(@types.JsonError::{
              code: -32002,
              message,
              data: Some(
                @types.Object({ "uri": @types.String(read_params.uri) }),
              ),
            }),
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
fn McpDispatcher::handle_prompts_list(
  self : McpDispatcher,
  id : @types.JsonId?,
) -> @types.JsonResponse {
  let result = @types.McpPromptsListResult::{ prompts: self.prompts.list() }
  @types.JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id,
  }
}

///|
fn McpDispatcher::handle_prompts_get(
  self : McpDispatcher,
  params : @types.JsonValue?,
  id : @types.JsonId?,
) -> @types.JsonResponse {
  let parsed_params = match params {
    Some(value) => parse_get_prompt_params(value)
    None => Err("Invalid params: params is required")
  }

  match parsed_params {
    Ok(prompt_params) =>
      match self.prompts.get(prompt_params.name, prompt_params.arguments) {
        Ok(result) =>
          @types.JsonResponse::{
            jsonrpc: "2.0",
            result: Some(result.to_json()),
            error: None,
            id,
          }
        Err(message) =>
          @types.JsonResponse::{
            jsonrpc: "2.0",
            result: None,
            error: Some(@types.JsonError::{
              code: -32602,
              message,
              data: Some(
                @types.Object({ "name": @types.String(prompt_params.name) }),
              ),
            }),
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
async fn McpDispatcher::handle_tools_call(
  self : McpDispatcher,
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
    let response = self.dispatcher.handle_jsonrpc_request(json_str)
    match response {
      Some(value) => self.transport.write_line(value.to_json().to_string())
      None => ()
    }
  }
}

///|
fn request_expects_response(request : @types.JsonRequest) -> Bool {
  match request.id {
    Some(_) => true
    None => false
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
      if jsonrpc != "2.0" {
        return Err("Unsupported jsonrpc version: " + jsonrpc)
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
fn parse_read_resource_params(
  json : @types.JsonValue,
) -> Result[@types.McpReadResourceParams, String] {
  match json {
    @types.Object(map) => {
      let uri = match map.get("uri") {
        Some(@types.String(value)) if value.trim() != "" => value
        _ => return Err("Missing or invalid 'uri' field")
      }
      Ok(@types.McpReadResourceParams::{ uri, })
    }
    _ => Err("Resource read params must be an object")
  }
}

///|
fn parse_get_prompt_params(
  json : @types.JsonValue,
) -> Result[@types.McpGetPromptParams, String] {
  match json {
    @types.Object(map) => {
      let name = match map.get("name") {
        Some(@types.String(value)) if value.trim() != "" => value
        _ => return Err("Missing or invalid 'name' field")
      }
      let arguments = match map.get("arguments") {
        Some(value) =>
          match value {
            @types.Object(_) => value
            _ => return Err("Prompt arguments must be an object")
          }
        None => @types.Object(Map::new())
      }
      Ok(@types.McpGetPromptParams::{ name, arguments })
    }
    _ => Err("Prompt get params must be an object")
  }
}
