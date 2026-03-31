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
    "upload_document" => upload_document_handler(args)
    "convert_uploaded_document" => convert_uploaded_document_handler(args)
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
  let resource_uri_schema : Map[String, @types.JsonValue] = Map::new()
  resource_uri_schema["type"] = @types.String("string")
  resource_uri_schema["description"] = @types.String(
    "Previously uploaded document resource URI such as moonbitmark://document/<id>",
  )
  inspect_properties["resource_uri"] = @types.Object(resource_uri_schema)

  let response_mode_schema : Map[String, @types.JsonValue] = Map::new()
  response_mode_schema["type"] = @types.String("string")
  response_mode_schema["description"] = @types.String(
    "Response format: text by default, json for structuredContent payloads",
  )
  response_mode_schema["enum"] = @types.Array([
    @types.String("text"),
    @types.String("json"),
  ])
  inspect_properties["response_mode"] = @types.Object(response_mode_schema)

  let inspect_schema : Map[String, @types.JsonValue] = Map::new()
  inspect_schema["type"] = @types.String("object")
  inspect_schema["properties"] = @types.Object(inspect_properties)

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
  properties["resource_uri"] = @types.Object(resource_uri_schema)
  properties["mode"] = @types.Object(mode_schema)
  properties["max_chars"] = @types.Object(max_chars_schema)
  properties["format_hint"] = @types.Object(format_hint_schema)
  properties["response_mode"] = @types.Object(response_mode_schema)

  let schema : Map[String, @types.JsonValue] = Map::new()
  schema["type"] = @types.String("object")
  schema["properties"] = @types.Object(properties)

  let filename_schema : Map[String, @types.JsonValue] = Map::new()
  filename_schema["type"] = @types.String("string")
  filename_schema["description"] = @types.String(
    "Original filename for format detection and source metadata",
  )

  let data_base64_schema : Map[String, @types.JsonValue] = Map::new()
  data_base64_schema["type"] = @types.String("string")
  data_base64_schema["description"] = @types.String(
    "Uploaded document encoded as base64; provide exactly one of data_base64 or data_bytes",
  )

  let byte_item_schema : Map[String, @types.JsonValue] = Map::new()
  byte_item_schema["type"] = @types.String("integer")
  byte_item_schema["minimum"] = @types.Number(0)
  byte_item_schema["maximum"] = @types.Number(255)

  let data_bytes_schema : Map[String, @types.JsonValue] = Map::new()
  data_bytes_schema["type"] = @types.String("array")
  data_bytes_schema["description"] = @types.String(
    "Uploaded document as raw byte values; provide exactly one of data_base64 or data_bytes",
  )
  data_bytes_schema["items"] = @types.Object(byte_item_schema)

  let mime_type_schema : Map[String, @types.JsonValue] = Map::new()
  mime_type_schema["type"] = @types.String("string")
  mime_type_schema["description"] = @types.String(
    "Optional MIME type for uploaded bytes, such as text/plain or application/pdf",
  )

  let upload_properties : Map[String, @types.JsonValue] = Map::new()
  upload_properties["filename"] = @types.Object(filename_schema)
  upload_properties["data_base64"] = @types.Object(data_base64_schema)
  upload_properties["data_bytes"] = @types.Object(data_bytes_schema)
  upload_properties["mime_type"] = @types.Object(mime_type_schema)
  upload_properties["mode"] = @types.Object(mode_schema)
  upload_properties["max_chars"] = @types.Object(max_chars_schema)
  upload_properties["format_hint"] = @types.Object(format_hint_schema)
  upload_properties["response_mode"] = @types.Object(response_mode_schema)

  let upload_required : Array[@types.JsonValue] = [@types.String("filename")]

  let upload_schema : Map[String, @types.JsonValue] = Map::new()
  upload_schema["type"] = @types.String("object")
  upload_schema["properties"] = @types.Object(upload_properties)
  upload_schema["required"] = @types.Array(upload_required)

  let store_properties : Map[String, @types.JsonValue] = Map::new()
  store_properties["filename"] = @types.Object(filename_schema)
  store_properties["data_base64"] = @types.Object(data_base64_schema)
  store_properties["data_bytes"] = @types.Object(data_bytes_schema)
  store_properties["mime_type"] = @types.Object(mime_type_schema)
  store_properties["response_mode"] = @types.Object(response_mode_schema)

  let store_required : Array[@types.JsonValue] = [@types.String("filename")]

  let store_schema : Map[String, @types.JsonValue] = Map::new()
  store_schema["type"] = @types.String("object")
  store_schema["properties"] = @types.Object(store_properties)
  store_schema["required"] = @types.Array(store_required)

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
  .register(ToolDefinition::{
    name: "upload_document",
    description: "Store uploaded bytes as a reusable moonbitmark://document/<id> resource.",
    input_schema: @types.Object(store_schema),
  })
  .register(ToolDefinition::{
    name: "convert_uploaded_document",
    description: "Convert uploaded bytes to Markdown without shared file paths; supports data_base64 or data_bytes and defaults to preview mode.",
    input_schema: @types.Object(upload_schema),
  })
}

///|
async fn inspect_document_handler(
  args : @types.JsonValue,
) -> @types.McpToolResult {
  let response_mode = match response_mode_arg(args) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let config = match load_mcp_security_config() {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let document = match resolve_request_document_arg(args, config) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let engine = @engine.MarkItDown::new()
  let detection = try? engine.detect_source(document.input_source)
  match detection {
    Ok(result) => {
      let effective_format = result.converter_name
      let file_size_bytes = document.byte_size
      let preview_recommended = should_recommend_preview(
        effective_format,
        file_size_bytes,
        document.input_kind == "url",
      )
      let summary = render_summary([
        summary_line("tool", "inspect_document"),
        summary_line("uri", document.request_uri),
        summary_line("input_kind", document.input_kind),
        summary_line("detected_format", result.converter_name),
        summary_line("effective_format", effective_format),
        summary_line("file_size_bytes", optional_int_string(file_size_bytes)),
        summary_line("extension", optional_string(result.stream_info.extension)),
        summary_line("filename", optional_string(result.stream_info.filename)),
        summary_line("may_use_ocr", bool_string(may_use_ocr(effective_format))),
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
            document.input_kind == "url",
          ),
        ),
      ])
      let payload = inspect_document_payload(
        document.request_uri,
        document.input_kind,
        result.converter_name,
        effective_format,
        result.stream_info.extension,
        result.stream_info.filename,
        file_size_bytes,
        config,
        preview_recommended,
        document.input_kind == "url",
      )
      tool_result_for_response_mode(response_mode, summary, None, payload)
    }
    Err(error) =>
      error_tool_result("Error inspecting document: " + error.to_string())
  }
}

///|
async fn convert_to_markdown_handler(
  args : @types.JsonValue,
) -> @types.McpToolResult {
  let response_mode = match response_mode_arg(args) {
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
  let document = match resolve_request_document_arg(args, config) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let engine = @engine.MarkItDown::new()
  let detection = try? engine.detect_source(document.input_source)
  let detected_format = match detection {
    Ok(value) => value.converter_name
    Err(_) => "unknown"
  }
  let effective_format = advisory_format(detected_format, format_hint)
  let ctx = build_mcp_convert_context(config)

  try {
    let result = @engine.MarkItDown::new().convert_source(
      document.input_source,
      ctx~,
    )
    let total_chars = result.markdown.length()
    let requested_limit = effective_max_chars(mode, max_chars)
    let limit = clamp_mcp_output_chars(requested_limit, config)
    let returned_markdown = limit_markdown(result.markdown, limit)
    let truncated = returned_markdown.length() < total_chars
    let recommended_preview = should_recommend_preview(
      effective_format,
      document.byte_size,
      document.input_kind == "url",
    )
    let summary = render_summary([
      summary_line("tool", "convert_to_markdown"),
      summary_line("uri", document.request_uri),
      summary_line("input_kind", document.input_kind),
      summary_line("mode", mode),
      summary_line("detected_format", detected_format),
      summary_line("effective_format", effective_format),
      summary_line("format_hint", optional_string(format_hint)),
      summary_line("format_hint_applied", bool_string(format_hint != None)),
      summary_line("requested_max_chars", optional_int_string(max_chars)),
      summary_line("effective_max_chars", optional_int_string(limit)),
      summary_line("http_allowed", bool_string(config.allow_http)),
      summary_line("ocr_enabled_by_env", bool_string(config.enable_ocr)),
      summary_line(
        "env_max_output_chars",
        optional_int_string(config.max_output_chars),
      ),
      summary_line("returned_chars", returned_markdown.length().to_string()),
      summary_line("total_chars", total_chars.to_string()),
      summary_line("truncated", bool_string(truncated)),
      summary_line("warnings", result.warnings.length().to_string()),
      summary_line("diagnostics", result.diagnostics.length().to_string()),
      summary_line("asset_count", result.assets.length().to_string()),
      summary_line("preview_recommended", bool_string(recommended_preview)),
      summary_line("may_use_ocr", bool_string(may_use_ocr(effective_format))),
      summary_line(
        "may_use_bridge",
        bool_string(may_use_bridge(effective_format)),
      ),
      summary_line("next_step", next_step(mode, truncated)),
    ])
    let payload = convert_to_markdown_payload(
      document.request_uri,
      document.input_kind,
      mode,
      detected_format,
      effective_format,
      format_hint,
      max_chars,
      limit,
      returned_markdown,
      total_chars,
      truncated,
      config,
      recommended_preview,
      result,
    )
    tool_result_for_response_mode(
      response_mode,
      summary,
      Some(returned_markdown),
      payload,
    )
  } catch {
    error =>
      error_tool_result("Error converting document: " + error.to_string())
  }
}

///|
async fn upload_document_handler(
  args : @types.JsonValue,
) -> @types.McpToolResult {
  let response_mode = match response_mode_arg(args) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let config = match load_mcp_security_config() {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let document = match
    resolve_inline_upload_document(
      args,
      config,
      uploaded_request_uri("staged-upload"),
    ) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let source_filename = match document.source_filename {
    Some(value) => value
    None => "upload.bin"
  }
  let bytes = match document.input_source {
    @core.BytesInput(_, payload, _) => payload
    _ =>
      return error_tool_result("Error: upload_document expected uploaded bytes")
  }
  let stored = store_document_resource(
    source_filename,
    bytes,
    document.mime_type,
  ) catch {
    err =>
      return error_tool_result(
        "Error storing uploaded document: " + err.to_string(),
      )
  }
  let summary = render_summary([
    summary_line("tool", "upload_document"),
    summary_line("resource_uri", stored.resource_uri),
    summary_line("source_filename", stored.filename),
    summary_line("mime_type", optional_string(stored.mime_type)),
    summary_line("uploaded_bytes", stored.byte_size.to_string()),
    summary_line("max_upload_bytes", config.max_upload_bytes.to_string()),
    summary_line(
      "next_step", "Call inspect_document or convert_to_markdown with resource_uri.",
    ),
  ])
  let payload = @types.Object({
    "content": @types.String(summary),
    "metadata": @types.Object({
      "tool": @types.String("upload_document"),
      "resource_uri": @types.String(stored.resource_uri),
      "source_filename": @types.String(stored.filename),
      "mime_type": json_optional_string(stored.mime_type),
    }),
    "diagnostics": @types.Object({
      "stored": @types.Bool(true),
      "next_step": @types.String(
        "Call inspect_document or convert_to_markdown with resource_uri.",
      ),
    }),
    "stats": @types.Object({
      "uploaded_bytes": @types.Number(stored.byte_size),
      "max_upload_bytes": @types.Number(config.max_upload_bytes),
    }),
  })
  tool_result_for_response_mode(response_mode, summary, None, payload)
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
fn response_mode_arg(args : @types.JsonValue) -> Result[String, String] {
  match args.get("response_mode") {
    Some(@types.String(value)) => {
      let normalized = value.trim().to_lower().to_string()
      match normalized {
        "text" => Ok("text")
        "json" => Ok("json")
        _ => Err("Error: 'response_mode' must be 'text' or 'json'")
      }
    }
    Some(_) => Err("Error: 'response_mode' must be 'text' or 'json'")
    None => Ok("text")
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
fn inspect_document_payload(
  uri : String,
  input_kind : String,
  detected_format : String,
  effective_format : String,
  extension : String?,
  filename : String?,
  file_size_bytes : Int?,
  config : McpSecurityConfig,
  preview_recommended : Bool,
  is_url : Bool,
) -> @types.JsonValue {
  let metadata : Map[String, @types.JsonValue] = {
    "tool": @types.String("inspect_document"),
    "uri": @types.String(uri),
    "input_kind": @types.String(input_kind),
    "detected_format": @types.String(detected_format),
    "effective_format": @types.String(effective_format),
    "extension": json_optional_string(extension),
    "filename": json_optional_string(filename),
  }
  let diagnostics : Map[String, @types.JsonValue] = {
    "preview_recommended": @types.Bool(preview_recommended),
    "reason": @types.String(
      preview_reason(effective_format, file_size_bytes, is_url),
    ),
    "may_use_ocr": @types.Bool(may_use_ocr(effective_format)),
    "may_use_bridge": @types.Bool(may_use_bridge(effective_format)),
    "http_allowed": @types.Bool(config.allow_http),
    "ocr_enabled_by_env": @types.Bool(config.enable_ocr),
    "warnings": @types.Array([]),
    "conversion_diagnostics": @types.Array([]),
  }
  let stats : Map[String, @types.JsonValue] = {
    "file_size_bytes": json_optional_int(file_size_bytes),
    "env_max_output_chars": json_optional_int(config.max_output_chars),
  }
  @types.Object({
    "content": @types.String(
      render_summary([
        summary_line("tool", "inspect_document"),
        summary_line("uri", uri),
        summary_line("input_kind", input_kind),
        summary_line("detected_format", detected_format),
        summary_line("effective_format", effective_format),
        summary_line("file_size_bytes", optional_int_string(file_size_bytes)),
        summary_line("extension", optional_string(extension)),
        summary_line("filename", optional_string(filename)),
        summary_line("may_use_ocr", bool_string(may_use_ocr(effective_format))),
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
          preview_reason(effective_format, file_size_bytes, is_url),
        ),
      ]),
    ),
    "metadata": @types.Object(metadata),
    "diagnostics": @types.Object(diagnostics),
    "stats": @types.Object(stats),
  })
}

///|
fn convert_to_markdown_payload(
  uri : String,
  input_kind : String,
  mode : String,
  detected_format : String,
  effective_format : String,
  format_hint : String?,
  requested_max_chars : Int?,
  effective_max_chars : Int?,
  returned_markdown : String,
  total_chars : Int,
  truncated : Bool,
  config : McpSecurityConfig,
  preview_recommended : Bool,
  result : @core.ConvertResult,
) -> @types.JsonValue {
  let metadata : Map[String, @types.JsonValue] = {
    "tool": @types.String("convert_to_markdown"),
    "uri": @types.String(uri),
    "input_kind": @types.String(input_kind),
    "mode": @types.String(mode),
    "detected_format": @types.String(detected_format),
    "effective_format": @types.String(effective_format),
    "format_hint": json_optional_string(format_hint),
    "format_hint_applied": @types.Bool(format_hint != None),
    "title": json_optional_string(result.title),
    "source_type": @types.String(result.source_type),
    "document_metadata": string_map_to_json_object(result.metadata),
  }
  let diagnostics : Map[String, @types.JsonValue] = {
    "truncated": @types.Bool(truncated),
    "preview_recommended": @types.Bool(preview_recommended),
    "may_use_ocr": @types.Bool(may_use_ocr(effective_format)),
    "may_use_bridge": @types.Bool(may_use_bridge(effective_format)),
    "http_allowed": @types.Bool(config.allow_http),
    "ocr_enabled_by_env": @types.Bool(config.enable_ocr),
    "next_step": @types.String(next_step(mode, truncated)),
    "warnings": string_array_to_json(result.warnings),
    "conversion_diagnostics": diagnostics_array_to_json(result.diagnostics),
  }
  let stats : Map[String, @types.JsonValue] = {
    "requested_max_chars": json_optional_int(requested_max_chars),
    "effective_max_chars": json_optional_int(effective_max_chars),
    "env_max_output_chars": json_optional_int(config.max_output_chars),
    "returned_chars": @types.Number(returned_markdown.length()),
    "total_chars": @types.Number(total_chars),
    "warning_count": @types.Number(result.warnings.length()),
    "diagnostic_count": @types.Number(result.diagnostics.length()),
    "asset_count": @types.Number(result.assets.length()),
    "converter_stats": convert_stats_to_json(result.stats),
  }
  @types.Object({
    "content": @types.String(returned_markdown),
    "metadata": @types.Object(metadata),
    "diagnostics": @types.Object(diagnostics),
    "stats": @types.Object(stats),
  })
}

///|
fn json_optional_string(value : String?) -> @types.JsonValue {
  match value {
    Some(text) => @types.String(text)
    None => @types.Null
  }
}

///|
fn json_optional_int(value : Int?) -> @types.JsonValue {
  match value {
    Some(number) => @types.Number(number)
    None => @types.Null
  }
}

///|
fn string_array_to_json(values : Array[String]) -> @types.JsonValue {
  let items : Array[@types.JsonValue] = []
  for value in values {
    items.push(@types.String(value))
  }
  @types.Array(items)
}

///|
fn string_map_to_json_object(values : Map[String, String]) -> @types.JsonValue {
  let map : Map[String, @types.JsonValue] = Map::new()
  for key, value in values {
    map[key] = @types.String(value)
  }
  @types.Object(map)
}

///|
fn diagnostics_array_to_json(
  diagnostics : Array[@core.ConversionDiagnostic],
) -> @types.JsonValue {
  let items : Array[@types.JsonValue] = []
  for diagnostic in diagnostics {
    items.push(
      @types.Object({
        "level": @types.String(diagnostic.level.label()),
        "category": @types.String(diagnostic.category()),
        "phase": json_optional_string(phase_label(diagnostic.phase)),
        "source": json_optional_string(source_label(diagnostic.source)),
        "message": @types.String(diagnostic.message),
        "hint": json_optional_string(hint_message(diagnostic.hint)),
        "rendered": @types.String(diagnostic.render()),
      }),
    )
  }
  @types.Array(items)
}

///|
fn convert_stats_to_json(stats : @core.ConvertStats?) -> @types.JsonValue {
  match stats {
    Some(value) =>
      @types.Object({
        "char_count": @types.Number(value.char_count),
        "block_count": @types.Number(value.block_count),
        "duration_ms": json_optional_int(value.duration_ms),
        "used_fallback": @types.Bool(value.used_fallback),
      })
    None => @types.Null
  }
}

///|
fn phase_label(phase : @core.ConversionPhase?) -> String? {
  match phase {
    Some(value) => Some(value.label())
    None => None
  }
}

///|
fn source_label(source : @core.DiagnosticSource?) -> String? {
  match source {
    Some(value) => Some(value.label())
    None => None
  }
}

///|
fn hint_message(hint : @core.DiagnosticHint?) -> String? {
  match hint {
    Some(value) => Some(value.message())
    None => None
  }
}

///|
fn tool_result_for_response_mode(
  response_mode : String,
  summary : String,
  markdown : String?,
  payload : @types.JsonValue,
) -> @types.McpToolResult {
  if response_mode == "json" {
    structured_tool_result(summary, payload)
  } else {
    match markdown {
      Some(body) => ok_tool_result_with_markdown(summary, body)
      None => ok_tool_result(summary)
    }
  }
}

///|
fn ok_tool_result(summary : String) -> @types.McpToolResult {
  @types.McpToolResult::{
    content: [@types.Text(@types.TextContent::{ type_: "text", text: summary })],
    is_error: false,
    structured_content: None,
  }
}

///|
fn ok_tool_result_with_markdown(
  summary : String,
  markdown : String,
) -> @types.McpToolResult {
  @types.McpToolResult::{
    content: [
      @types.Text(@types.TextContent::{ type_: "text", text: summary }),
      @types.Text(@types.TextContent::{ type_: "text", text: markdown }),
    ],
    is_error: false,
    structured_content: None,
  }
}

///|
fn structured_tool_result(
  fallback_text : String,
  payload : @types.JsonValue,
) -> @types.McpToolResult {
  @types.McpToolResult::{
    content: [
      @types.Text(@types.TextContent::{ type_: "text", text: fallback_text }),
    ],
    is_error: false,
    structured_content: Some(payload),
  }
}

///|
fn error_tool_result(message : String) -> @types.McpToolResult {
  @types.McpToolResult::{
    content: [@types.Text(@types.TextContent::{ type_: "text", text: message })],
    is_error: true,
    structured_content: None,
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
