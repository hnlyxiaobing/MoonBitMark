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
    "inspect_document" => inspect_document_handler(args)
    "convert_to_markdown" => convert_to_markdown_handler(args)
    _ => error_tool_result("Tool not found: " + name)
  }
}

///|
pub fn ToolRegistry::register_convert_tools(
  self : ToolRegistry,
) -> ToolRegistry raise {
  let inspect_uri_schema : Map[String, @types.JsonValue] = Map::new()
  inspect_uri_schema["type"] = @types.String("string")
  inspect_uri_schema["description"] = @types.String(
    "Path or URL to inspect before conversion",
  )

  let inspect_properties : Map[String, @types.JsonValue] = Map::new()
  inspect_properties["uri"] = @types.Object(inspect_uri_schema)

  let inspect_required : Array[@types.JsonValue] = [@types.String("uri")]

  let inspect_schema : Map[String, @types.JsonValue] = Map::new()
  inspect_schema["type"] = @types.String("object")
  inspect_schema["properties"] = @types.Object(inspect_properties)
  inspect_schema["required"] = @types.Array(inspect_required)

  let uri_schema : Map[String, @types.JsonValue] = Map::new()
  uri_schema["type"] = @types.String("string")
  uri_schema["description"] = @types.String("Path or URL to convert")

  let mode_schema : Map[String, @types.JsonValue] = Map::new()
  mode_schema["type"] = @types.String("string")
  mode_schema["description"] = @types.String(
    "preview by default; use full only when you need the whole Markdown",
  )
  mode_schema["enum"] = @types.Array([
    @types.String("preview"),
    @types.String("full"),
  ])

  let max_chars_schema : Map[String, @types.JsonValue] = Map::new()
  max_chars_schema["type"] = @types.String("integer")
  max_chars_schema["description"] = @types.String(
    "Optional output cap in characters",
  )

  let format_hint_schema : Map[String, @types.JsonValue] = Map::new()
  format_hint_schema["type"] = @types.String("string")
  format_hint_schema["description"] = @types.String(
    "Advisory format hint such as pdf, docx, html, or text",
  )

  let properties : Map[String, @types.JsonValue] = Map::new()
  properties["uri"] = @types.Object(uri_schema)
  properties["mode"] = @types.Object(mode_schema)
  properties["max_chars"] = @types.Object(max_chars_schema)
  properties["format_hint"] = @types.Object(format_hint_schema)

  let required : Array[@types.JsonValue] = [@types.String("uri")]

  let schema : Map[String, @types.JsonValue] = Map::new()
  schema["type"] = @types.String("object")
  schema["properties"] = @types.Object(properties)
  schema["required"] = @types.Array(required)

  self
  .register(ToolDefinition::{
    name: "inspect_document",
    description: "Inspect document: detect format, size, OCR/bridge risk, preview recommendation.",
    input_schema: @types.Object(inspect_schema),
  })
  .register(ToolDefinition::{
    name: "convert_to_markdown",
    description: "Convert to Markdown: preview by default, full when explicitly requested.",
    input_schema: @types.Object(schema),
  })
}

///|
async fn inspect_document_handler(
  args : @types.JsonValue,
) -> @types.McpToolResult {
  let uri = match required_string_arg(args, "uri") {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let config = match load_mcp_security_config() {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let input = match enforce_mcp_input_boundary(uri, config) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let engine = @engine.MarkItDown::new()
  let detection = try? engine.detect(input)
  match detection {
    Ok(result) => {
      let effective_format = result.converter_name
      let file_size_bytes = file_size_bytes(input)
      let preview_recommended = should_recommend_preview(
        effective_format,
        file_size_bytes,
        is_url_input(input),
      )
      ok_tool_result(
        render_summary([
          summary_line("tool", "inspect_document"),
          summary_line("uri", uri),
          summary_line("input_kind", input_kind(input)),
          summary_line("detected_format", result.converter_name),
          summary_line("effective_format", effective_format),
          summary_line("file_size_bytes", optional_int_string(file_size_bytes)),
          summary_line(
            "extension",
            optional_string(result.stream_info.extension),
          ),
          summary_line("filename", optional_string(result.stream_info.filename)),
          summary_line(
            "may_use_ocr",
            bool_string(may_use_ocr(effective_format)),
          ),
          summary_line(
            "may_use_bridge",
            bool_string(may_use_bridge(effective_format)),
          ),
          summary_line("http_allowed", bool_string(config.allow_http)),
          summary_line("ocr_enabled_by_env", bool_string(config.enable_ocr)),
          summary_line(
            "env_max_output_chars",
            optional_int_string(config.max_output_chars),
          ),
          summary_line("preview_recommended", bool_string(preview_recommended)),
          summary_line(
            "reason",
            preview_reason(
              effective_format,
              file_size_bytes,
              is_url_input(input),
            ),
          ),
        ]),
      )
    }
    Err(error) =>
      error_tool_result("Error inspecting document: " + error.to_string())
  }
}

///|
async fn convert_to_markdown_handler(
  args : @types.JsonValue,
) -> @types.McpToolResult {
  let uri = match required_string_arg(args, "uri") {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let config = match load_mcp_security_config() {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let mode = match convert_mode_arg(args) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let max_chars = match optional_positive_int_arg(args, "max_chars") {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let format_hint = optional_string_arg(args, "format_hint")
  let input = match enforce_mcp_input_boundary(uri, config) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let engine = @engine.MarkItDown::new()
  let detection = try? engine.detect(input)
  let detected_format = match detection {
    Ok(value) => value.converter_name
    Err(_) => "unknown"
  }
  let effective_format = advisory_format(detected_format, format_hint)
  let ctx = build_mcp_convert_context(config)

  try {
    let result = @engine.MarkItDown::new().convert(input, ctx~)
    let total_chars = result.markdown.length()
    let requested_limit = effective_max_chars(mode, max_chars)
    let limit = clamp_mcp_output_chars(requested_limit, config)
    let returned_markdown = limit_markdown(result.markdown, limit)
    let truncated = returned_markdown.length() < total_chars
    let recommended_preview = should_recommend_preview(
      effective_format,
      file_size_bytes(input),
      is_url_input(input),
    )
    @types.McpToolResult::{
      content: [
        @types.Text(@types.TextContent::{
          type_: "text",
          text: render_summary([
            summary_line("tool", "convert_to_markdown"),
            summary_line("uri", uri),
            summary_line("mode", mode),
            summary_line("detected_format", detected_format),
            summary_line("effective_format", effective_format),
            summary_line("format_hint", optional_string(format_hint)),
            summary_line(
              "format_hint_applied",
              bool_string(format_hint != None),
            ),
            summary_line("requested_max_chars", optional_int_string(max_chars)),
            summary_line("effective_max_chars", optional_int_string(limit)),
            summary_line("http_allowed", bool_string(config.allow_http)),
            summary_line("ocr_enabled_by_env", bool_string(config.enable_ocr)),
            summary_line(
              "env_max_output_chars",
              optional_int_string(config.max_output_chars),
            ),
            summary_line(
              "returned_chars",
              returned_markdown.length().to_string(),
            ),
            summary_line("total_chars", total_chars.to_string()),
            summary_line("truncated", bool_string(truncated)),
            summary_line("warnings", result.warnings.length().to_string()),
            summary_line("diagnostics", result.diagnostics.length().to_string()),
            summary_line("asset_count", result.assets.length().to_string()),
            summary_line(
              "preview_recommended",
              bool_string(recommended_preview),
            ),
            summary_line(
              "may_use_ocr",
              bool_string(may_use_ocr(effective_format)),
            ),
            summary_line(
              "may_use_bridge",
              bool_string(may_use_bridge(effective_format)),
            ),
            summary_line("next_step", next_step(mode, truncated)),
          ]),
        }),
        @types.Text(@types.TextContent::{
          type_: "text",
          text: returned_markdown,
        }),
      ],
      is_error: false,
    }
  } catch {
    error =>
      error_tool_result("Error converting document: " + error.to_string())
  }
}

///|
fn required_string_arg(
  args : @types.JsonValue,
  key : String,
) -> Result[String, String] {
  match args.get(key) {
    Some(@types.String(value)) if value.trim() != "" => Ok(value)
    _ => Err("Error: '" + key + "' parameter is required")
  }
}

///|
fn optional_string_arg(args : @types.JsonValue, key : String) -> String? {
  match args.get(key) {
    Some(@types.String(value)) if value.trim() != "" =>
      Some(value.trim().to_lower().to_string())
    _ => None
  }
}

///|
fn optional_positive_int_arg(
  args : @types.JsonValue,
  key : String,
) -> Result[Int?, String] {
  match args.get(key) {
    Some(@types.Number(value)) =>
      if value > 0 {
        Ok(Some(value))
      } else {
        Err("Error: '" + key + "' must be a positive integer")
      }
    Some(@types.Float(_)) => Err("Error: '" + key + "' must be an integer")
    Some(_) => Err("Error: '" + key + "' must be an integer")
    None => Ok(None)
  }
}

///|
fn convert_mode_arg(args : @types.JsonValue) -> Result[String, String] {
  match args.get("mode") {
    Some(@types.String(value)) => {
      let normalized = value.trim().to_lower().to_string()
      match normalized {
        "preview" => Ok("preview")
        "full" => Ok("full")
        _ => Err("Error: 'mode' must be 'preview' or 'full'")
      }
    }
    Some(_) => Err("Error: 'mode' must be 'preview' or 'full'")
    None => Ok("preview")
  }
}

///|
fn input_kind(input : String) -> String {
  if is_url_input(input) {
    "url"
  } else {
    "file"
  }
}

///|
fn is_url_input(input : String) -> Bool {
  input.has_prefix("http://") || input.has_prefix("https://")
}

///|
async fn file_size_bytes(input : String) -> Int? {
  if is_url_input(input) {
    None
  } else {
    let file = @fs.open(input, mode=ReadOnly) catch { _ => return None }
    let size = file.size() catch {
      _ => {
        file.close()
        return None
      }
    }
    file.close()
    if size > 2147483647 {
      Some(2147483647)
    } else {
      Some(size.to_int())
    }
  }
}

///|
fn advisory_format(detected_format : String, format_hint : String?) -> String {
  match format_hint {
    Some(value) => value
    None => detected_format
  }
}

///|
fn effective_max_chars(mode : String, max_chars : Int?) -> Int? {
  match max_chars {
    Some(value) => Some(value)
    None => if mode == "preview" { Some(4000) } else { None }
  }
}

///|
fn limit_markdown(markdown : String, max_chars : Int?) -> String {
  match max_chars {
    Some(limit) =>
      if markdown.length() > limit {
        markdown[:limit].to_string()
      } else {
        markdown
      }
    None => markdown
  }
}

///|
fn should_recommend_preview(
  format : String,
  file_size_bytes : Int?,
  is_url : Bool,
) -> Bool {
  if is_url {
    true
  } else if format == "pdf" ||
    format == "docx" ||
    format == "pptx" ||
    format == "xlsx" ||
    format == "epub" ||
    format == "html" ||
    format == "image" {
    true
  } else {
    match file_size_bytes {
      Some(value) => value >= 12000
      None => false
    }
  }
}

///|
fn preview_reason(
  format : String,
  file_size_bytes : Int?,
  is_url : Bool,
) -> String {
  if is_url {
    "URLs can expand after fetch; preview first."
  } else if format == "pdf" ||
    format == "docx" ||
    format == "pptx" ||
    format == "xlsx" ||
    format == "epub" ||
    format == "html" ||
    format == "image" {
    "Structured formats are more likely to produce long Markdown."
  } else {
    match file_size_bytes {
      Some(value) if value >= 12000 =>
        "Input size is large enough that preview is safer for agents."
      _ => "Input looks small enough for direct conversion if needed."
    }
  }
}

///|
fn may_use_ocr(format : String) -> Bool {
  format == "image" ||
  format == "pdf" ||
  format == "docx" ||
  format == "pptx" ||
  format == "epub"
}

///|
fn may_use_bridge(format : String) -> Bool {
  format == "image" || format == "pdf"
}

///|
fn next_step(mode : String, truncated : Bool) -> String {
  if mode == "preview" {
    "Inspect the preview summary, then re-run with mode=full if you need the complete Markdown."
  } else if truncated {
    "Increase max_chars or omit it to receive more Markdown."
  } else {
    "Full Markdown returned."
  }
}

///|
fn optional_string(value : String?) -> String {
  match value {
    Some(text) => text
    None => "null"
  }
}

///|
fn optional_int_string(value : Int?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "null"
  }
}

///|
fn ok_tool_result(summary : String) -> @types.McpToolResult {
  @types.McpToolResult::{
    content: [@types.Text(@types.TextContent::{ type_: "text", text: summary })],
    is_error: false,
  }
}

///|
fn error_tool_result(message : String) -> @types.McpToolResult {
  @types.McpToolResult::{
    content: [@types.Text(@types.TextContent::{ type_: "text", text: message })],
    is_error: true,
  }
}

///|
fn summary_line(key : String, value : String) -> String {
  key + ": " + value
}

///|
fn render_summary(lines : Array[String]) -> String {
  lines.join("\n")
}

///|
fn bool_string(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}
