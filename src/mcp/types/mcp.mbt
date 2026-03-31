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
  structured_content : JsonValue?
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
pub(all) struct McpServerCapabilitiesResources {
  subscribe : Bool
  list_changed : Bool
}

///|
pub(all) struct McpServerCapabilitiesPrompts {
  list_changed : Bool
}

///|
pub(all) struct McpServerCapabilities {
  tools : McpServerCapabilitiesTools
  resources : McpServerCapabilitiesResources?
  prompts : McpServerCapabilitiesPrompts?
}

///|
pub(all) struct McpInitializeResult {
  protocol_version : String
  capabilities : McpServerCapabilities
  server_info : McpServerInfo
  instructions : String?
}

///|
pub(all) struct McpToolsListResult {
  tools : Array[McpTool]
}

///|
pub(all) struct McpResource {
  uri : String
  name : String
  title : String?
  description : String?
  mime_type : String?
  size : Int?
}

///|
pub(all) struct McpReadResourceParams {
  uri : String
}

///|
pub(all) struct McpResourceContents {
  uri : String
  mime_type : String?
  text : String
}

///|
pub(all) struct McpResourcesListResult {
  resources : Array[McpResource]
}

///|
pub(all) struct McpResourcesReadResult {
  contents : Array[McpResourceContents]
}

///|
pub(all) struct McpPromptArgument {
  name : String
  description : String?
  required : Bool?
}

///|
pub(all) struct McpPrompt {
  name : String
  title : String?
  description : String?
  arguments : Array[McpPromptArgument]?
}

///|
pub(all) struct McpPromptMessage {
  role : String
  content : TextContent
}

///|
pub(all) struct McpGetPromptParams {
  name : String
  arguments : JsonValue
}

///|
pub(all) struct McpPromptsListResult {
  prompts : Array[McpPrompt]
}

///|
pub(all) struct McpGetPromptResult {
  description : String?
  messages : Array[McpPromptMessage]
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
  match self.structured_content {
    Some(value) => map["structuredContent"] = value
    None => ()
  }
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
  match self.resources {
    Some(value) => map["resources"] = value.to_json()
    None => ()
  }
  match self.prompts {
    Some(value) => map["prompts"] = value.to_json()
    None => ()
  }
  Object(map)
}

///|
pub fn McpServerCapabilitiesResources::to_json(
  self : McpServerCapabilitiesResources,
) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["subscribe"] = Bool(self.subscribe)
  map["listChanged"] = Bool(self.list_changed)
  Object(map)
}

///|
pub fn McpServerCapabilitiesPrompts::to_json(
  self : McpServerCapabilitiesPrompts,
) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["listChanged"] = Bool(self.list_changed)
  Object(map)
}

///|
pub fn McpInitializeResult::to_json(self : McpInitializeResult) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["protocolVersion"] = String(self.protocol_version)
  map["capabilities"] = self.capabilities.to_json()
  map["serverInfo"] = self.server_info.to_json()
  match self.instructions {
    Some(value) => map["instructions"] = String(value)
    None => ()
  }
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

///|
pub fn McpResource::to_json(self : McpResource) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["uri"] = String(self.uri)
  map["name"] = String(self.name)
  match self.title {
    Some(value) => map["title"] = String(value)
    None => ()
  }
  match self.description {
    Some(value) => map["description"] = String(value)
    None => ()
  }
  match self.mime_type {
    Some(value) => map["mimeType"] = String(value)
    None => ()
  }
  match self.size {
    Some(value) => map["size"] = Number(value)
    None => ()
  }
  Object(map)
}

///|
pub fn McpResourceContents::to_json(self : McpResourceContents) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["uri"] = String(self.uri)
  match self.mime_type {
    Some(value) => map["mimeType"] = String(value)
    None => ()
  }
  map["text"] = String(self.text)
  Object(map)
}

///|
pub fn McpResourcesListResult::to_json(
  self : McpResourcesListResult,
) -> JsonValue {
  let items : Array[JsonValue] = []
  for resource in self.resources {
    items.push(resource.to_json())
  }

  let map : Map[String, JsonValue] = Map::new()
  map["resources"] = Array(items)
  Object(map)
}

///|
pub fn McpResourcesReadResult::to_json(
  self : McpResourcesReadResult,
) -> JsonValue {
  let items : Array[JsonValue] = []
  for resource in self.contents {
    items.push(resource.to_json())
  }

  let map : Map[String, JsonValue] = Map::new()
  map["contents"] = Array(items)
  Object(map)
}

///|
pub fn McpPromptArgument::to_json(self : McpPromptArgument) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["name"] = String(self.name)
  match self.description {
    Some(value) => map["description"] = String(value)
    None => ()
  }
  match self.required {
    Some(value) => map["required"] = Bool(value)
    None => ()
  }
  Object(map)
}

///|
pub fn McpPrompt::to_json(self : McpPrompt) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["name"] = String(self.name)
  match self.title {
    Some(value) => map["title"] = String(value)
    None => ()
  }
  match self.description {
    Some(value) => map["description"] = String(value)
    None => ()
  }
  match self.arguments {
    Some(value) => {
      let items : Array[JsonValue] = []
      for argument in value {
        items.push(argument.to_json())
      }
      map["arguments"] = Array(items)
    }
    None => ()
  }
  Object(map)
}

///|
pub fn McpPromptMessage::to_json(self : McpPromptMessage) -> JsonValue {
  let map : Map[String, JsonValue] = Map::new()
  map["role"] = String(self.role)
  map["content"] = self.content.to_json()
  Object(map)
}

///|
pub fn McpPromptsListResult::to_json(self : McpPromptsListResult) -> JsonValue {
  let items : Array[JsonValue] = []
  for prompt in self.prompts {
    items.push(prompt.to_json())
  }

  let map : Map[String, JsonValue] = Map::new()
  map["prompts"] = Array(items)
  Object(map)
}

///|
pub fn McpGetPromptResult::to_json(self : McpGetPromptResult) -> JsonValue {
  let items : Array[JsonValue] = []
  for message in self.messages {
    items.push(message.to_json())
  }

  let map : Map[String, JsonValue] = Map::new()
  match self.description {
    Some(value) => map["description"] = String(value)
    None => ()
  }
  map["messages"] = Array(items)
  Object(map)
}
