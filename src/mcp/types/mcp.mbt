// MoonBitMark MCP Types - MCP Protocol Type Definitions

use @jsonrpc.*

///|
/// MCP 工具定义
pub(all) struct McpTool {
  name : String
  description : String
  input_schema : JsonValue
}

///|
/// MCP 工具调用参数
pub(all) struct McpToolCallParams {
  name : String
  arguments : JsonValue
}

///|
/// MCP 工具调用结果
pub(all) struct McpToolResult {
  content : Array[McpContent]
  isError : Bool
}

///|
/// MCP 内容类型
pub(all) type McpContent =
  | TextContent {
      type : String,
      text : String
    }

pub(all) fn McpContent::to_json(self : McpContent) -> JsonValue {
  match self {
    TextContent{type, text} => {
      let mut m = Map::empty()
      m = m.insert("type", String(type))
      m = m.insert("text", String(text))
      Object(m)
    }
  }
}

///|
/// MCP 服务器信息
pub(all) struct McpServerInfo {
  name : String
  version : String
  protocol_version : String
}

pub(all) fn McpServerInfo::to_json(self : McpServerInfo) -> JsonValue {
  let mut m = Map::empty()
  m = m.insert("name", String(self.name))
  m = m.insert("version", String(self.version))
  m = m.insert("protocolVersion", String(self.protocol_version))
  Object(m)
}

///|
/// MCP 服务器能力
pub(all) struct McpServerCapabilities {
  tools : McpServerCapabilitiesTools
}

pub(all) fn McpServerCapabilities::to_json(self : McpServerCapabilities) -> JsonValue {
  let mut caps = Map::empty()
  let mut tools_map = Map::empty()
  tools_map = tools_map.insert("listChanged", Bool(false))
  caps = caps.insert("tools", Object(tools_map))
  Object(caps)
}

pub(all) struct McpServerCapabilitiesTools {
  listChanged : Bool
}

///|
/// MCP 初始化结果
pub(all) struct McpInitializeResult {
  protocol_version : String
  capabilities : McpServerCapabilities
  server_info : McpServerInfo
}

pub(all) fn McpInitializeResult::to_json(self : McpInitializeResult) -> JsonValue {
  let mut m = Map::empty()
  m = m.insert("protocolVersion", String(self.protocol_version))
  m = m.insert("capabilities", self.capabilities.to_json())
  m = m.insert("serverInfo", self.server_info.to_json())
  Object(m)
}

///|
/// MCP 工具列表结果
pub(all) struct McpToolsListResult {
  tools : Array[McpTool]
}

pub(all) fn McpToolsListResult::to_json(self : McpToolsListResult) -> JsonValue {
  let tools_json = self.tools.map(fn(t) {
    let mut m = Map::empty()
    m = m.insert("name", String(t.name))
    m = m.insert("description", String(t.description))
    m = m.insert("inputSchema", t.input_schema)
    Object(m)
  })
  let mut m = Map::empty()
  m = m.insert("tools", Array(tools_json))
  Object(m)
}

///|
/// MCP 工具调用结果 JSON
pub(all) fn McpToolResult::to_json(self : McpToolResult) -> JsonValue {
  let content_json = self.content.map(McpContent::to_json)
  let mut m = Map::empty()
  m = m.insert("content", Array(content_json))
  m = m.insert("isError", Bool(self.isError))
  Object(m)
}
