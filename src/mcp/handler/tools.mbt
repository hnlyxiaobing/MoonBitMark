// MoonBitMark MCP Handler - Tool Registry and Handlers

use @types.*
use @jsonrpc.*
use @converter_bridge.*
use @util.*

///|
/// 工具函数类型
pub(all) type ToolHandler = (JsonValue) -> Future[McpToolResult]

///|
/// 工具定义
pub(all) struct ToolDefinition {
  name : String
  description : String
  handler : ToolHandler
  input_schema : JsonValue
}

///|
/// 工具注册表
pub(all) struct ToolRegistry {
  tools : Map[String, ToolDefinition]
}

///|
/// 创建空工具注册表
pub fn ToolRegistry::new() -> ToolRegistry {
  { tools: Map::empty() }
}

///|
/// 注册工具
pub fn ToolRegistry::register(self : ToolRegistry, tool : ToolDefinition) -> ToolRegistry raise {
  if self.tools.contains(tool.name) {
    fail("Tool already registered: " + tool.name)
  } else {
    { tools: self.tools.insert(tool.name, tool) }
  }
}

///|
/// 调用工具 (async)
pub fn ToolRegistry::call(self : ToolRegistry, name : String, args : JsonValue) -> Future[McpToolResult] {
  match self.tools.get(name) {
    Some(tool) => tool.handler(args)
    None => {
      Future::ready(McpToolResult::{
        content: [
          TextContent::{
            type: "text",
            text: "Tool not found: " + name
          }
        ],
        isError: true
      })
    }
  }
}

///|
/// 列出所有工具
pub fn ToolRegistry::list(self : ToolRegistry) -> Array[McpTool] {
  self.tools.values().map(fn(t) {
    McpTool::{
      name: t.name,
      description: t.description,
      input_schema: t.input_schema
    }
  }).to_array()
}

///|
/// 注册文档转换工具
pub fn ToolRegistry::register_convert_tools(self : ToolRegistry) -> ToolRegistry raise {
  // 创建输入 schema
  let mut props = Map::empty()
  props = props.insert("uri",
    Object(
      let mut uri_schema = Map::empty()
      uri_schema = uri_schema.insert("type", String("string"))
      uri_schema = uri_schema.insert("description",
        String("URI of the document to convert (file://, http://, https://)"))
      uri_schema
    )
  )

  let mut schema = Map::empty()
  schema = schema.insert("type", String("object"))
  schema = schema.insert("properties", Object(props))

  let mut required_arr = Array::empty()
  required_arr = required_arr.push(String("uri"))
  schema = schema.insert("required", Array(required_arr))

  let convert_tool = ToolDefinition::{
    name: "convert_to_markdown",
    description: "Convert a document (PDF, DOCX, HTML, etc.) to Markdown format",
    input_schema: Object(schema),
    handler: convert_to_markdown_handler
  }

  self.register(convert_tool)?
}

///|
/// 文档转换处理函数
fn convert_to_markdown_handler(args : JsonValue) -> Future[McpToolResult] {
  // 解析 URI 参数
  let uri = match args.get("uri") {
    Some(String(u)) => u
    _ => {
      return Future::ready(McpToolResult::{
        content: [
          TextContent::{
            type: "text",
            text: "Error: 'uri' parameter is required"
          }
        ],
        isError: true
      })
    }
  }

  // 检查 URI 类型
  let markdown_future = if uri.starts_with("http://") || uri.starts_with("https://") {
    // URL 转换
    convert_from_url(uri)
  } else if uri.starts_with("file://") {
    // 文件路径转换
    let file_path = uri.substring(7)
    convert_from_file(file_path)
  } else {
    // 直接当作文件路径处理
    convert_from_file(uri)
  }

  // Map future result to tool result
  map_future(markdown_future, fn(markdown) {
    match markdown {
      Ok(md) => {
        McpToolResult::{
          content: [
            TextContent::{
              type: "text",
              text: md
            }
          ],
          isError: false
        }
      }
      Err(e) => {
        McpToolResult::{
          content: [
            TextContent::{
              type: "text",
              text: "Error converting document: " + e.to_string()
            }
          ],
          isError: true
        }
      }
    }
  })
}

///|
/// Map over future values
fn map_future[T, U](future : Future[T], f : (T) -> U) -> Future[U] {
  // For now, this is a simplified implementation
  // In a real async runtime, this would chain futures
  match future.await() {
    Ok(value) => Future::ready(f(value))
    Err(e) => Future::error(e)
  }
}

///|
/// 从文件转换
fn convert_from_file(file_path : String) -> Future[String] {
  // 使用转换器桥接来处理所有支持的格式
  convert_to_markdown(file_path)
}

///|
/// 从 URL 转换
fn convert_from_url(url : String) -> Future[String] {
  // 使用转换器桥接处理 URL
  convert_to_markdown(url)
}
