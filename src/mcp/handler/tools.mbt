// MoonBitMark MCP Handler - Tool Registry

///|
pub(all) struct ToolDefinition {
  name : String
  description : String
  input_schema : @types.JsonValue
}

///|
pub(all) struct ToolRegistry {
  tools : Map[String, ToolDefinition]
}

///|
pub fn ToolRegistry::new() -> ToolRegistry {
  ToolRegistry::{ tools: Map::new() }
}

///|
pub fn ToolRegistry::register(
  self : ToolRegistry,
  tool : ToolDefinition,
) -> ToolRegistry raise {
  if self.tools.contains(tool.name) {
    fail("Tool already registered: " + tool.name)
  }

  let tools = self.tools
  tools[tool.name] = tool
  ToolRegistry::{ tools, }
}

///|
pub fn ToolRegistry::list(self : ToolRegistry) -> Array[@types.McpTool] {
  let items : Array[@types.McpTool] = []
  for _, tool in self.tools {
    items.push(@types.McpTool::{
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
  args : @types.JsonValue,
) -> @types.McpToolResult {
  ignore(self)
  match name {
    "convert_to_markdown" => convert_to_markdown_handler(args)
    _ =>
      @types.McpToolResult::{
        content: [
          @types.Text(@types.TextContent::{
            type_: "text",
            text: "Tool not found: " + name,
          }),
        ],
        is_error: true,
      }
  }
}

///|
pub fn ToolRegistry::register_convert_tools(
  self : ToolRegistry,
) -> ToolRegistry raise {
  let uri_schema : Map[String, @types.JsonValue] = Map::new()
  uri_schema["type"] = @types.String("string")
  uri_schema["description"] = @types.String(
    "URI of the document to convert (file://, http://, https://)",
  )

  let properties : Map[String, @types.JsonValue] = Map::new()
  properties["uri"] = @types.Object(uri_schema)

  let required : Array[@types.JsonValue] = [@types.String("uri")]

  let schema : Map[String, @types.JsonValue] = Map::new()
  schema["type"] = @types.String("object")
  schema["properties"] = @types.Object(properties)
  schema["required"] = @types.Array(required)

  self.register(ToolDefinition::{
    name: "convert_to_markdown",
    description: "Convert a document to Markdown format",
    input_schema: @types.Object(schema),
  })
}

///|
async fn convert_to_markdown_handler(
  args : @types.JsonValue,
) -> @types.McpToolResult {
  let uri = match args.get("uri") {
    Some(@types.String(value)) => value
    _ =>
      return @types.McpToolResult::{
        content: [
          @types.Text(@types.TextContent::{
            type_: "text",
            text: "Error: 'uri' parameter is required",
          }),
        ],
        is_error: true,
      }
  }

  let input = if uri.has_prefix("file://") { uri[7:].to_string() } else { uri }

  try {
    let markdown = convert_document_to_markdown(input)
    @types.McpToolResult::{
      content: [
        @types.Text(@types.TextContent::{ type_: "text", text: markdown }),
      ],
      is_error: false,
    }
  } catch {
    error =>
      @types.McpToolResult::{
        content: [
          @types.Text(@types.TextContent::{
            type_: "text",
            text: "Error converting document: " + error.to_string(),
          }),
        ],
        is_error: true,
      }
  }
}
