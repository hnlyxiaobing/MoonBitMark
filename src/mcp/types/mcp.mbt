// MoonBitMark MCP Types - MCP Protocol Models

///|
pub(all) struct McpTool {
  name : String
  description : String
  input_schema : JsonValue
}

///|
pub(all) struct McpToolCallParams {
  name : String
  arguments : JsonValue
}

///|
pub(all) struct TextContent {
  type_ : String
  text : String
}

///|
pub(all) enum McpContent {
  Text(TextContent)
}

///|
pub(all) struct McpToolResult {
  content : Array[McpContent]
  is_error : Bool
}

///|
pub(all) struct McpServerInfo {
  name : String
  version : String
  protocol_version : String
}

///|
pub(all) struct McpServerCapabilitiesTools {
  list_changed : Bool
}

///|
pub(all) struct McpServerCapabilities {
  tools : McpServerCapabilitiesTools
}

///|
pub(all) struct McpInitializeResult {
  protocol_version : String
  capabilities : McpServerCapabilities
  server_info : McpServerInfo
}

///|
pub(all) struct McpToolsListResult {
  tools : Array[McpTool]
}

///|
pub fn TextContent::to_json(self : TextContent) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["type"] = String(self.type_)
  map["text"] = String(self.text)
  Object(map)
}

///|
pub fn McpContent::to_json(self : McpContent) -> JsonValue {
  match self {
    Text(content) => content.to_json()
  }
}

///|
pub fn McpTool::to_json(self : McpTool) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["name"] = String(self.name)
  map["description"] = String(self.description)
  map["inputSchema"] = self.input_schema
  Object(map)
}

///|
pub fn McpToolResult::to_json(self : McpToolResult) -> JsonValue {
  let items : Array[JsonValue] = []
  for content in self.content {
    items.push(content.to_json())
  }

  let map : Map[String, JsonValue] = Map::new()
  map["content"] = Array(items)
  map["isError"] = Bool(self.is_error)
  Object(map)
}

///|
pub fn McpServerInfo::to_json(self : McpServerInfo) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["name"] = String(self.name)
  map["version"] = String(self.version)
  map["protocolVersion"] = String(self.protocol_version)
  Object(map)
}

///|
pub fn McpServerCapabilities::to_json(
  self : McpServerCapabilities,
) -> JsonValue {
  let tools_map : Map[String, JsonValue] = Map::new()
  tools_map["listChanged"] = Bool(self.tools.list_changed)

  let map : Map[String, JsonValue] = Map::new()
  map["tools"] = Object(tools_map)
  Object(map)
}

///|
pub fn McpInitializeResult::to_json(self : McpInitializeResult) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["protocolVersion"] = String(self.protocol_version)
  map["capabilities"] = self.capabilities.to_json()
  map["serverInfo"] = self.server_info.to_json()
  Object(map)
}

///|
pub fn McpToolsListResult::to_json(self : McpToolsListResult) -> JsonValue {
  let items : Array[JsonValue] = []
  for tool in self.tools {
    items.push(tool.to_json())
  }

  let map : Map[String, JsonValue] = Map::new()
  map["tools"] = Array(items)
  Object(map)
}
