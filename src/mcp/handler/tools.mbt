// MoonBitMark MCP Handler - Tool Registry

use @types.*

///|
pub(all) struct ToolDefinition {
  name : String
  description : String
  input_schema : JsonValue
}

///|
pub(all) struct ToolRegistry {
  tools : Map[String, ToolDefinition]
}

///|
pub fn ToolRegistry::new() -> ToolRegistry {
  { tools: Map::new() }
}

///|
pub fn ToolRegistry::register(self : ToolRegistry, tool : ToolDefinition) -> ToolRegistry raise {
  if self.tools.contains(tool.name) {
    fail("Tool already registered: " + tool.name)
  }

  let tools = self.tools
  tools[tool.name] = tool
  { tools }
}

///|
pub fn ToolRegistry::list(self : ToolRegistry) -> Array[McpTool] {
  let items : Array[McpTool] = []
  for (_, tool) in self.tools {
    items.push(McpTool::{
      name: tool.name,
      description: tool.description,
      input_schema: tool.input_schema,
    })
  }
  items
}

///|
pub async fn ToolRegistry::call(
  self : ToolRegistry,
  name : String,
  args : JsonValue,
) -> McpToolResult {
  ignore(self)
  match name {
    "convert_to_markdown" => convert_to_markdown_handler(args)
    _ =>
      McpToolResult::{
        content: [
          Text(TextContent::{ type_: "text", text: "Tool not found: " + name }),
        ],
        is_error: true,
      }
  }
}

///|
pub fn ToolRegistry::register_convert_tools(self : ToolRegistry) -> ToolRegistry raise {
  let uri_schema : Map[String, JsonValue] = Map::new()
  uri_schema["type"] = String("string")
  uri_schema["description"] = String(
    "URI of the document to convert (file://, http://, https://)",
  )

  let properties : Map[String, JsonValue] = Map::new()
  properties["uri"] = Object(uri_schema)

  let required : Array[JsonValue] = [String("uri")]

  let schema : Map[String, JsonValue] = Map::new()
  schema["type"] = String("object")
  schema["properties"] = Object(properties)
  schema["required"] = Array(required)

  self.register(ToolDefinition::{
    name: "convert_to_markdown",
    description: "Convert a document to Markdown format",
    input_schema: Object(schema),
  })
}

///|
async fn convert_to_markdown_handler(args : JsonValue) -> McpToolResult {
  let uri = match args.get("uri") {
    Some(String(value)) => value
    _ =>
      return McpToolResult::{
        content: [
          Text(TextContent::{
            type_: "text",
            text: "Error: 'uri' parameter is required",
          }),
        ],
        is_error: true,
      }
  }

  let input = if uri.has_prefix("file://") {
    uri.substring(7)
  } else {
    uri
  }

  try {
    let markdown = convert_to_markdown(input)
    McpToolResult::{
      content: [
        Text(TextContent::{ type_: "text", text: markdown }),
      ],
      is_error: false,
    }
  } catch {
    error =>
      McpToolResult::{
        content: [
          Text(TextContent::{
            type_: "text",
            text: "Error converting document: " + error.to_string(),
          }),
        ],
        is_error: true,
      }
  }
}
