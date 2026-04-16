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
    "dump_normalized_ast" => dump_normalized_ast_handler(args)
    "extract_structure" => extract_structure_handler(args)
    "compare_with_baseline" => compare_with_baseline_handler(args)
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

  let baseline_schema : Map[String, @types.JsonValue] = Map::new()
  baseline_schema["type"] = @types.String("string")
  baseline_schema["description"] = @types.String(
    "Baseline tool to compare against: markitdown by default, or docling when supported.",
  )
  baseline_schema["enum"] = @types.Array([
    @types.String("markitdown"),
    @types.String("docling"),
  ])
  inspect_properties["baseline"] = @types.Object(baseline_schema)

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
  inspect_properties["format_hint"] = @types.Object(format_hint_schema)

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
    name: "dump_normalized_ast",
    description: "Return the normalized AST after shared structural passes for debugging, regression review, or downstream tooling.",
    input_schema: @types.Object(inspect_schema),
  })
  .register(ToolDefinition::{
    name: "extract_structure",
    description: "Return the canonical semantic document with section tree, roles, provenance, confidence, and diagnostics.",
    input_schema: @types.Object(inspect_schema),
  })
  .register(ToolDefinition::{
    name: "compare_with_baseline",
    description: "Run a local baseline converter such as markitdown or docling against the same document and report agreement metrics plus baseline availability.",
    input_schema: @types.Object(inspect_schema),
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
async fn dump_normalized_ast_handler(
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
  let detected_format = match detection {
    Ok(value) => value.converter_name
    Err(_) => "unknown"
  }
  let ctx = build_mcp_convert_context(config)

  try {
    let result = @engine.MarkItDown::new().convert_source(
      document.input_source,
      ctx~,
    )
    match result.normalized_document {
      Some(normalized_document) => {
        let block_count = normalized_document.blocks.length()
        let annotation_count = normalized_document.annotations.length()
        let json_content = render_ast_document_json(normalized_document)
        let summary = render_summary([
          summary_line("tool", "dump_normalized_ast"),
          summary_line("uri", document.request_uri),
          summary_line("input_kind", document.input_kind),
          summary_line("detected_format", detected_format),
          summary_line("block_count", block_count.to_string()),
          summary_line("annotation_count", annotation_count.to_string()),
          summary_line("warnings", result.warnings.length().to_string()),
          summary_line("diagnostics", result.diagnostics.length().to_string()),
        ])
        let payload = dump_normalized_ast_payload(
          document.request_uri,
          document.input_kind,
          detected_format,
          normalized_document,
          result,
        )
        tool_result_for_response_mode(
          response_mode,
          summary,
          Some(json_content),
          payload,
        )
      }
      None =>
        error_tool_result(
          "Error extracting normalized AST: conversion result did not include a normalized document",
        )
    }
  } catch {
    error =>
      error_tool_result("Error extracting normalized AST: " + error.to_string())
  }
}

///|
async fn extract_structure_handler(
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
  let detected_format = match detection {
    Ok(value) => value.converter_name
    Err(_) => "unknown"
  }
  let ctx = build_mcp_convert_context(config)

  try {
    let result = @engine.MarkItDown::new().convert_source(
      document.input_source,
      ctx~,
    )
    match result.semantic_document {
      Some(semantic_document) => {
        let section_count = count_sections(semantic_document.sections)
        let low_confidence_blocks = count_low_confidence_blocks(
          semantic_document.blocks,
        )
        let json_content = render_semantic_document_json(semantic_document)
        let summary = render_summary([
          summary_line("tool", "extract_structure"),
          summary_line("uri", document.request_uri),
          summary_line("input_kind", document.input_kind),
          summary_line("detected_format", detected_format),
          summary_line("section_count", section_count.to_string()),
          summary_line(
            "block_count",
            semantic_document.blocks.length().to_string(),
          ),
          summary_line(
            "low_confidence_blocks",
            low_confidence_blocks.to_string(),
          ),
          summary_line("warnings", result.warnings.length().to_string()),
          summary_line("diagnostics", result.diagnostics.length().to_string()),
        ])
        let payload = extract_structure_payload(
          document.request_uri,
          document.input_kind,
          detected_format,
          semantic_document,
          result,
        )
        tool_result_for_response_mode(
          response_mode,
          summary,
          Some(json_content),
          payload,
        )
      }
      None =>
        error_tool_result(
          "Error extracting structure: conversion result did not include a semantic document",
        )
    }
  } catch {
    error =>
      error_tool_result("Error extracting structure: " + error.to_string())
  }
}

///|
async fn compare_with_baseline_handler(
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
  let baseline = match baseline_arg(args) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  let format_hint = optional_string_arg(args, "format_hint")
  let document = match resolve_request_document_arg(args, config) {
    Ok(value) => value
    Err(message) => return error_tool_result(message)
  }
  if document.input_kind == "url" {
    return error_tool_result(
      "Error: compare_with_baseline currently supports local files or uploaded resources, not URLs",
    )
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
    let baseline_input_path = materialize_baseline_input(
      document, effective_format,
    ) catch {
      err =>
        return error_tool_result(
          "Error preparing baseline input: " + err.to_string(),
        )
    }
    let candidate_markdown_path = write_temp_markdown_file(
      "candidate-markdown",
      result.markdown,
    ) catch {
      err => {
        cleanup_file_if_exists(baseline_input_path)
        return error_tool_result(
          "Error preparing baseline comparison: " + err.to_string(),
        )
      }
    }
    let compare_result = run_compare_with_baseline_script(
      baseline, effective_format, baseline_input_path, candidate_markdown_path,
    )
    cleanup_file_if_exists(candidate_markdown_path)
    cleanup_file_if_exists_if_temp(document, baseline_input_path)
    match compare_result {
      Ok(payload) => {
        let summary = compare_with_baseline_summary(
          document.request_uri,
          document.input_kind,
          detected_format,
          effective_format,
          baseline,
          payload,
        )
        let payload = compare_with_baseline_payload(
          document.request_uri,
          document.input_kind,
          detected_format,
          effective_format,
          baseline,
          result,
          payload,
        )
        let baseline_markdown = json_object_nullable_string_arg(
          payload, "content",
        )
        tool_result_for_response_mode(
          response_mode, summary, baseline_markdown, payload,
        )
      }
      Err(message) => error_tool_result(message)
    }
  } catch {
    error => error_tool_result("Error comparing baseline: " + error.to_string())
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
fn baseline_arg(args : @types.JsonValue) -> Result[String, String] {
  match args.get("baseline") {
    Some(@types.String(value)) => {
      let normalized = value.trim().to_lower().to_string()
      match normalized {
        "markitdown" => Ok("markitdown")
        "docling" => Ok("docling")
        _ => Err("Error: 'baseline' must be 'markitdown' or 'docling'")
      }
    }
    Some(_) => Err("Error: 'baseline' must be 'markitdown' or 'docling'")
    None => Ok("markitdown")
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
    "explanations": @types.Object({
      "headings": @types.Array([]),
      "tables": @types.Array([]),
      "ocr": @types.Object({
        "triggered": @types.Bool(false),
        "reason": @types.String(
          "inspect_document is a preflight tool; OCR trigger explanations become concrete after conversion.",
        ),
        "may_use_ocr": @types.Bool(may_use_ocr(effective_format)),
      }),
      "uncertainties": @types.Array([
        @types.Object({
          "kind": @types.String("preflight"),
          "message": @types.String(
            "Structural explanations require convert_to_markdown, dump_normalized_ast, or extract_structure.",
          ),
        }),
      ]),
    }),
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
    "explanations": result_explanations(result),
  })
}

///|
fn dump_normalized_ast_payload(
  uri : String,
  input_kind : String,
  detected_format : String,
  document : @ast.Document,
  result : @core.ConvertResult,
) -> @types.JsonValue {
  @types.Object({
    "content": @types.String(render_ast_document_json(document)),
    "metadata": @types.Object({
      "tool": @types.String("dump_normalized_ast"),
      "uri": @types.String(uri),
      "input_kind": @types.String(input_kind),
      "detected_format": @types.String(detected_format),
      "title": json_optional_string(document.title),
      "source_type": @types.String(result.source_type),
      "document_metadata": string_map_to_json_object(document.metadata),
    }),
    "diagnostics": @types.Object({
      "warnings": string_array_to_json(result.warnings),
      "conversion_diagnostics": diagnostics_array_to_json(result.diagnostics),
    }),
    "stats": @types.Object({
      "block_count": @types.Number(document.blocks.length()),
      "annotation_count": @types.Number(document.annotations.length()),
      "converter_stats": convert_stats_to_json(result.stats),
    }),
    "explanations": result_explanations(result),
    "normalized_document": parse_structured_json(
      render_ast_document_json(document),
    ),
  })
}

///|
fn extract_structure_payload(
  uri : String,
  input_kind : String,
  detected_format : String,
  document : @semantic.SemanticDocument,
  result : @core.ConvertResult,
) -> @types.JsonValue {
  @types.Object({
    "content": @types.String(render_semantic_document_json(document)),
    "metadata": @types.Object({
      "tool": @types.String("extract_structure"),
      "uri": @types.String(uri),
      "input_kind": @types.String(input_kind),
      "detected_format": @types.String(detected_format),
      "title": json_optional_string(document.title),
      "source_type": @types.String(result.source_type),
      "document_metadata": string_map_to_json_object(result.metadata),
      "provenance": parse_structured_json(
        render_semantic_provenance_json(document.provenance),
      ),
    }),
    "diagnostics": @types.Object({
      "warnings": string_array_to_json(result.warnings),
      "conversion_diagnostics": diagnostics_array_to_json(result.diagnostics),
      "low_confidence_blocks": @types.Number(
        count_low_confidence_blocks(document.blocks),
      ),
    }),
    "stats": @types.Object({
      "section_count": @types.Number(count_sections(document.sections)),
      "block_count": @types.Number(document.blocks.length()),
      "converter_stats": convert_stats_to_json(result.stats),
    }),
    "explanations": result_explanations(result),
    "semantic_document": parse_structured_json(
      render_semantic_document_json(document),
    ),
  })
}

///|
fn compare_with_baseline_payload(
  uri : String,
  input_kind : String,
  detected_format : String,
  effective_format : String,
  baseline : String,
  result : @core.ConvertResult,
  comparison : @types.JsonValue,
) -> @types.JsonValue {
  @types.Object({
    "content": json_object_string_arg_or_null(
      comparison, "baseline_markdown", "",
    ),
    "metadata": @types.Object({
      "tool": @types.String("compare_with_baseline"),
      "uri": @types.String(uri),
      "input_kind": @types.String(input_kind),
      "detected_format": @types.String(detected_format),
      "effective_format": @types.String(effective_format),
      "baseline": @types.String(baseline),
      "title": json_optional_string(result.title),
      "source_type": @types.String(result.source_type),
      "document_metadata": string_map_to_json_object(result.metadata),
    }),
    "diagnostics": @types.Object({
      "warnings": string_array_to_json(result.warnings),
      "conversion_diagnostics": diagnostics_array_to_json(result.diagnostics),
      "baseline_available": @types.Bool(
        json_object_bool_arg_or_false(comparison, "available"),
      ),
      "baseline_supported": @types.Bool(
        json_object_bool_arg_or_false(comparison, "supported"),
      ),
      "baseline_error": json_optional_string(
        json_object_nullable_string_arg(comparison, "error"),
      ),
    }),
    "stats": @types.Object({
      "baseline_duration_ms": json_optional_int(
        json_object_nullable_int_arg(comparison, "duration_ms"),
      ),
      "baseline_chars": json_optional_int(
        json_object_nullable_int_arg(comparison, "baseline_chars"),
      ),
      "converter_stats": convert_stats_to_json(result.stats),
    }),
    "explanations": result_explanations(result),
    "comparison": comparison,
  })
}

///|
fn compare_with_baseline_summary(
  uri : String,
  input_kind : String,
  detected_format : String,
  effective_format : String,
  baseline : String,
  comparison : @types.JsonValue,
) -> String {
  let agreement = json_nested_float_arg(
    comparison, "agreement", "overall_score",
  )
  render_summary([
    summary_line("tool", "compare_with_baseline"),
    summary_line("uri", uri),
    summary_line("input_kind", input_kind),
    summary_line("detected_format", detected_format),
    summary_line("effective_format", effective_format),
    summary_line("baseline", baseline),
    summary_line(
      "baseline_available",
      bool_string(json_object_bool_arg_or_false(comparison, "available")),
    ),
    summary_line(
      "baseline_supported",
      bool_string(json_object_bool_arg_or_false(comparison, "supported")),
    ),
    summary_line("agreement_score", optional_float_string(agreement)),
    summary_line(
      "baseline_duration_ms",
      optional_int_string(
        json_object_nullable_int_arg(comparison, "duration_ms"),
      ),
    ),
    summary_line(
      "baseline_chars",
      optional_int_string(
        json_object_nullable_int_arg(comparison, "baseline_chars"),
      ),
    ),
    summary_line(
      "baseline_error",
      optional_string(json_object_nullable_string_arg(comparison, "error")),
    ),
  ])
}

///|
fn result_explanations(result : @core.ConvertResult) -> @types.JsonValue {
  @types.Object({
    "headings": heading_explanations(result),
    "tables": table_explanations(result),
    "ocr": ocr_explanation(result),
    "uncertainties": uncertainty_explanations(result),
  })
}

///|
fn heading_explanations(result : @core.ConvertResult) -> @types.JsonValue {
  let items : Array[@types.JsonValue] = []
  match result.normalized_document {
    Some(document) => {
      let annotations = @ast.normalize_annotations(
        document.annotations,
        document.blocks.length(),
      )
      let semantic_blocks = match result.semantic_document {
        Some(semantic_document) => semantic_document.blocks
        None => []
      }
      for index, block in document.blocks {
        match block {
          @ast.Heading(level, inlines) => {
            let annotation = annotations[index]
            let text = @ast.plain_text_of_inlines(inlines)
            let semantic_block = semantic_blocks.get(index)
            items.push(
              @types.Object({
                "block_id": @types.String(annotation.id),
                "index": @types.Number(index),
                "level": @types.Number(level),
                "text": @types.String(text),
                "role": json_optional_string(
                  semantic_role_label(semantic_block),
                ),
                "reason": @types.String(
                  heading_reason(
                    result.metadata,
                    document.title,
                    text,
                    annotation,
                    semantic_block,
                  ),
                ),
                "diagnostics": string_array_to_json(annotation.diagnostics),
                "provenance": semantic_provenance_json(semantic_block),
              }),
            )
          }
          _ => ()
        }
      }
    }
    None => ()
  }
  @types.Array(items)
}

///|
fn table_explanations(result : @core.ConvertResult) -> @types.JsonValue {
  let items : Array[@types.JsonValue] = []
  match result.normalized_document {
    Some(document) => {
      let annotations = @ast.normalize_annotations(
        document.annotations,
        document.blocks.length(),
      )
      let semantic_blocks = match result.semantic_document {
        Some(semantic_document) => semantic_document.blocks
        None => []
      }
      for index, block in document.blocks {
        let annotation = annotations[index]
        let semantic_block = semantic_blocks.get(index)
        match block {
          @ast.Table(headers, rows) =>
            items.push(
              @types.Object({
                "block_id": @types.String(annotation.id),
                "index": @types.Number(index),
                "outcome": @types.String("table"),
                "text": @types.String(@ast.plain_text_of_block(block)),
                "header_columns": @types.Number(headers.length()),
                "body_rows": @types.Number(rows.length()),
                "reason": @types.String(
                  table_reason(result.metadata, annotation),
                ),
                "diagnostics": string_array_to_json(annotation.diagnostics),
                "provenance": semantic_provenance_json(semantic_block),
              }),
            )
          _ =>
            match
              find_annotation_diagnostic(
                annotation, "Table-like layout was downgraded",
              ) {
              Some(reason) =>
                items.push(
                  @types.Object({
                    "block_id": @types.String(annotation.id),
                    "index": @types.Number(index),
                    "outcome": @types.String("paragraph_fallback"),
                    "text": @types.String(@ast.plain_text_of_block(block)),
                    "reason": @types.String(reason),
                    "diagnostics": string_array_to_json(annotation.diagnostics),
                    "provenance": semantic_provenance_json(semantic_block),
                  }),
                )
              None => ()
            }
        }
      }
    }
    None => ()
  }
  @types.Array(items)
}

///|
fn ocr_explanation(result : @core.ConvertResult) -> @types.JsonValue {
  let attempted = metadata_bool(result.metadata, "ocr_attempted")
  let available = metadata_bool(result.metadata, "ocr_available")
  let used = metadata_bool(result.metadata, "ocr_fallback_used")
  let recovery_pages = metadata_int(result.metadata, "route_recovery_pages")
  let recovery_page_numbers = metadata_csv_numbers(
    result.metadata,
    "route_recovery_page_numbers",
  )
  let reason = if used {
    "OCR fallback merged recovered page text back into the normalized document."
  } else if recovery_pages > 0 && attempted && !available {
    "Some pages were routed to OCR because the extracted PDF text looked empty or unusable, but no backend produced usable text."
  } else if recovery_pages > 0 {
    "Some pages were routed to OCR because the extracted PDF text looked empty or unusable."
  } else if attempted && !available {
    "OCR was requested for this conversion, but no usable backend was available."
  } else {
    "OCR was not part of the active conversion path."
  }
  @types.Object({
    "mode": json_optional_string(result.metadata.get("ocr_mode")),
    "backend": json_optional_string(result.metadata.get("ocr_backend")),
    "provider": json_optional_string(result.metadata.get("ocr_provider")),
    "attempted": @types.Bool(attempted),
    "available": @types.Bool(available),
    "used": @types.Bool(used),
    "triggered": @types.Bool(recovery_pages > 0 || attempted),
    "recovery_pages": @types.Number(recovery_pages),
    "recovery_page_numbers": recovery_page_numbers,
    "recovery_reasons": json_optional_string(
      result.metadata.get("route_recovery_reasons"),
    ),
    "reason": @types.String(reason),
    "warning": json_optional_string(first_ocr_warning(result)),
  })
}

///|
fn uncertainty_explanations(result : @core.ConvertResult) -> @types.JsonValue {
  let items : Array[@types.JsonValue] = []
  for warning in result.warnings {
    items.push(
      @types.Object({
        "kind": @types.String("warning"),
        "message": @types.String(warning),
      }),
    )
  }
  for diagnostic in result.diagnostics {
    if diagnostic.level == @core.Warning {
      items.push(
        @types.Object({
          "kind": @types.String("diagnostic"),
          "message": @types.String(diagnostic.message),
          "phase": json_optional_string(phase_label(diagnostic.phase)),
          "source": json_optional_string(source_label(diagnostic.source)),
        }),
      )
    }
  }
  match result.semantic_document {
    Some(document) =>
      for block in document.blocks {
        if block.confidence < 60 || block.diagnostics.length() > 0 {
          items.push(
            @types.Object({
              "kind": @types.String("block"),
              "block_id": @types.String(block.block_id),
              "message": @types.String(block_uncertainty_message(block)),
              "confidence": @types.Number(block.confidence),
              "provenance": parse_structured_json(
                render_semantic_provenance_json(block.provenance),
              ),
            }),
          )
        }
      }
    None => ()
  }
  @types.Array(items)
}

///|
fn heading_reason(
  metadata : Map[String, String],
  document_title : String?,
  text : String,
  annotation : @ast.BlockAnnotation,
  semantic_block : @semantic.SemanticBlock?,
) -> String {
  match
    find_annotation_diagnostic(annotation, "Normalized heading level from ") {
    Some(reason) => reason
    None =>
      match metadata.get("format") {
        Some("pptx") if looks_like_slide_heading_text(text) =>
          "PPTX slide boundary heading was synthesized from the slide order."
        Some("docx") if matches_optional_title(text, document_title) =>
          "DOCX heading text matched the document title, so it anchors the title section."
        Some("docx") =>
          "DOCX paragraph-style or title heuristics produced this heading and normalization kept the level."
        Some("html") if matches_optional_title(text, document_title) =>
          "HTML heading text matched the document title and remained the title anchor."
        Some("html") =>
          "HTML heading tags were preserved as structural headings."
        Some("pdf") =>
          "PDF structure heuristics promoted this chunk to a heading."
        Some("pptx") =>
          "PPTX slide content heading was kept below the slide separator."
        _ =>
          match semantic_block {
            Some(block) if block.role == @semantic.Title =>
              "Leading structural heading was kept as the document title."
            Some(block) if block.role == @semantic.Subtitle =>
              "Heading was retained below the title as a section heading."
            _ =>
              "Converter emitted this heading and structural normalization kept the level."
          }
      }
  }
}

///|
fn table_reason(
  metadata : Map[String, String],
  annotation : @ast.BlockAnnotation,
) -> String {
  match find_annotation_diagnostic(annotation, "Normalized table shape") {
    Some(reason) => reason
    None =>
      match metadata.get("format") {
        Some("html") =>
          "HTML table structure was preserved after row and span normalization."
        Some("docx") => "DOCX table cells were preserved as a Markdown table."
        Some("pptx") => "PPTX table cells were preserved as a Markdown table."
        Some("pdf") =>
          "PDF structure heuristics recovered a stable table grid for this page."
        _ => "Table structure was preserved by the converter."
      }
  }
}

///|
fn block_uncertainty_message(block : @semantic.SemanticBlock) -> String {
  if block.diagnostics.length() > 0 {
    block.diagnostics.join("; ")
  } else {
    "Block confidence fell below the stable threshold."
  }
}

///|
fn semantic_role_label(block : @semantic.SemanticBlock?) -> String? {
  match block {
    Some(value) => Some("\{value.role}")
    None => None
  }
}

///|
fn semantic_provenance_json(
  block : @semantic.SemanticBlock?,
) -> @types.JsonValue {
  match block {
    Some(value) =>
      parse_structured_json(render_semantic_provenance_json(value.provenance))
    None => @types.Null
  }
}

///|
fn find_annotation_diagnostic(
  annotation : @ast.BlockAnnotation,
  prefix : String,
) -> String? {
  for diagnostic in annotation.diagnostics {
    if diagnostic.has_prefix(prefix) {
      return Some(diagnostic)
    }
  }
  None
}

///|
fn metadata_bool(metadata : Map[String, String], key : String) -> Bool {
  match metadata.get(key) {
    Some("true") => true
    Some("True") => true
    Some("1") => true
    _ => false
  }
}

///|
fn metadata_int(metadata : Map[String, String], key : String) -> Int {
  match metadata.get(key) {
    Some(value) =>
      match try_parse_int(value) {
        Some(number) => number
        None => 0
      }
    None => 0
  }
}

///|
fn metadata_csv_numbers(
  metadata : Map[String, String],
  key : String,
) -> @types.JsonValue {
  let items : Array[@types.JsonValue] = []
  match metadata.get(key) {
    Some(value) =>
      for part in value.split(",").to_array() {
        match try_parse_int(part.to_string().trim().to_string()) {
          Some(number) => items.push(@types.Number(number))
          None => ()
        }
      }
    None => ()
  }
  @types.Array(items)
}

///|
fn try_parse_int(text : String) -> Int? {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return None
  }
  let mut value = 0
  for ch in trimmed {
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn first_ocr_warning(result : @core.ConvertResult) -> String? {
  for warning in result.warnings {
    if warning.contains("OCR") {
      return Some(warning)
    }
  }
  for diagnostic in result.diagnostics {
    if diagnostic.message.contains("OCR") {
      return Some(diagnostic.message)
    }
  }
  None
}

///|
fn looks_like_slide_heading_text(text : String) -> Bool {
  let trimmed = text.trim().to_string()
  trimmed.has_prefix("Slide ") &&
  try_parse_int(trimmed[6:].trim().to_string()) is Some(_)
}

///|
fn matches_optional_title(text : String, title : String?) -> Bool {
  match title {
    Some(value) =>
      text.trim().to_lower().to_string() == value.trim().to_lower().to_string()
    None => false
  }
}

///|
fn render_ast_document_json(document : @ast.Document) -> String {
  mcp_json_object([
    mcp_json_field("title", mcp_json_string_or_null(document.title)),
    mcp_json_field("metadata", mcp_json_of_string_map(document.metadata)),
    mcp_json_field("blocks", mcp_json_array_of_blocks(document.blocks)),
    mcp_json_field(
      "annotations",
      mcp_json_array_of_annotations(document.annotations),
    ),
  ])
}

///|
fn mcp_json_array_of_blocks(blocks : Array[@ast.Block]) -> String {
  let items : Array[String] = []
  for block in blocks {
    items.push(mcp_json_of_block(block))
  }
  mcp_json_array(items)
}

///|
fn mcp_json_of_block(block : @ast.Block) -> String {
  match block {
    @ast.Heading(level, inlines) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("heading")),
        mcp_json_field("level", level.to_string()),
        mcp_json_field("inlines", mcp_json_array_of_inlines(inlines)),
      ])
    @ast.Paragraph(inlines) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("paragraph")),
        mcp_json_field("inlines", mcp_json_array_of_inlines(inlines)),
      ])
    @ast.List(items, ordered) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("list")),
        mcp_json_field("ordered", if ordered { "true" } else { "false" }),
        mcp_json_field("items", mcp_json_array_of_inline_groups(items)),
      ])
    @ast.Quote(lines) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("quote")),
        mcp_json_field("lines", mcp_json_array_of_strings(lines)),
      ])
    @ast.CodeBlock(lang, content) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("code_block")),
        mcp_json_field("lang", mcp_json_string_or_null(lang)),
        mcp_json_field("content", mcp_json_string(content)),
      ])
    @ast.Table(headers, rows) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("table")),
        mcp_json_field("headers", mcp_json_array_of_inline_groups(headers)),
        mcp_json_field("rows", mcp_json_array_of_inline_rows(rows)),
      ])
    @ast.Image(alt, url, caption) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("image")),
        mcp_json_field("alt", mcp_json_string(alt)),
        mcp_json_field("url", mcp_json_string(url)),
        mcp_json_field(
          "caption",
          match caption {
            Some(inlines) => mcp_json_array_of_inlines(inlines)
            None => "null"
          },
        ),
      ])
    @ast.HorizontalRule =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("horizontal_rule")),
      ])
  }
}

///|
fn mcp_json_array_of_annotations(
  annotations : Array[@ast.BlockAnnotation],
) -> String {
  let items : Array[String] = []
  for annotation in annotations {
    items.push(
      mcp_json_object([
        mcp_json_field("id", mcp_json_string(annotation.id)),
        mcp_json_field(
          "source_hint",
          mcp_json_string_or_null(annotation.source_hint),
        ),
        mcp_json_field(
          "origin_hint",
          mcp_json_string_or_null(annotation.origin_hint),
        ),
        mcp_json_field(
          "diagnostics",
          mcp_json_array_of_strings(annotation.diagnostics),
        ),
      ]),
    )
  }
  mcp_json_array(items)
}

///|
fn mcp_json_array_of_inline_groups(items : Array[Array[@ast.Inline]]) -> String {
  let groups : Array[String] = []
  for item in items {
    groups.push(mcp_json_array_of_inlines(item))
  }
  mcp_json_array(groups)
}

///|
fn mcp_json_array_of_inline_rows(
  rows : Array[Array[Array[@ast.Inline]]],
) -> String {
  let rendered_rows : Array[String] = []
  for row in rows {
    rendered_rows.push(mcp_json_array_of_inline_groups(row))
  }
  mcp_json_array(rendered_rows)
}

///|
fn mcp_json_array_of_inlines(inlines : Array[@ast.Inline]) -> String {
  let items : Array[String] = []
  for inline in inlines {
    items.push(mcp_json_of_inline(inline))
  }
  mcp_json_array(items)
}

///|
fn mcp_json_of_inline(inline : @ast.Inline) -> String {
  match inline {
    @ast.Text(content) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("text")),
        mcp_json_field("content", mcp_json_string(content)),
      ])
    @ast.Emphasis(children) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("emphasis")),
        mcp_json_field("children", mcp_json_array_of_inlines(children)),
      ])
    @ast.Strong(children) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("strong")),
        mcp_json_field("children", mcp_json_array_of_inlines(children)),
      ])
    @ast.Link(children, url) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("link")),
        mcp_json_field("children", mcp_json_array_of_inlines(children)),
        mcp_json_field("url", mcp_json_string(url)),
      ])
    @ast.Image(alt, url) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("image")),
        mcp_json_field("alt", mcp_json_string(alt)),
        mcp_json_field("url", mcp_json_string(url)),
      ])
    @ast.Code(content) =>
      mcp_json_object([
        mcp_json_field("type", mcp_json_string("code")),
        mcp_json_field("content", mcp_json_string(content)),
      ])
    @ast.LineBreak =>
      mcp_json_object([mcp_json_field("type", mcp_json_string("line_break"))])
  }
}

///|
fn render_semantic_document_json(
  document : @semantic.SemanticDocument,
) -> String {
  mcp_json_object([
    mcp_json_field("title", mcp_json_string_or_null(document.title)),
    mcp_json_field(
      "provenance",
      render_semantic_provenance_json(document.provenance),
    ),
    mcp_json_field("sections", mcp_json_array_of_sections(document.sections)),
    mcp_json_field("blocks", mcp_json_array_of_semantic_blocks(document.blocks)),
  ])
}

///|
fn mcp_json_array_of_sections(sections : Array[@semantic.Section]) -> String {
  let items : Array[String] = []
  for section in sections {
    items.push(mcp_json_of_section(section))
  }
  mcp_json_array(items)
}

///|
fn mcp_json_of_section(section : @semantic.Section) -> String {
  mcp_json_object([
    mcp_json_field("id", mcp_json_string(section.id)),
    mcp_json_field("title", mcp_json_string_or_null(section.title)),
    mcp_json_field("level", section.level.to_string()),
    mcp_json_field("role", mcp_json_string("\{section.role}")),
    mcp_json_field(
      "block_indices",
      mcp_json_array_of_ints(section.block_indices),
    ),
    mcp_json_field(
      "diagnostics",
      mcp_json_array_of_strings(section.diagnostics),
    ),
    mcp_json_field(
      "provenance",
      render_semantic_provenance_json(section.provenance),
    ),
    mcp_json_field("children", mcp_json_array_of_sections(section.children)),
  ])
}

///|
fn mcp_json_array_of_semantic_blocks(
  blocks : Array[@semantic.SemanticBlock],
) -> String {
  let items : Array[String] = []
  for block in blocks {
    items.push(
      mcp_json_object([
        mcp_json_field("block_id", mcp_json_string(block.block_id)),
        mcp_json_field("index", block.index.to_string()),
        mcp_json_field("role", mcp_json_string("\{block.role}")),
        mcp_json_field("text", mcp_json_string(block.text)),
        mcp_json_field(
          "source_hint",
          mcp_json_string_or_null(block.source_hint),
        ),
        mcp_json_field(
          "origin_hint",
          mcp_json_string_or_null(block.origin_hint),
        ),
        mcp_json_field(
          "diagnostics",
          mcp_json_array_of_strings(block.diagnostics),
        ),
        mcp_json_field("confidence", block.confidence.to_string()),
        mcp_json_field(
          "provenance",
          render_semantic_provenance_json(block.provenance),
        ),
      ]),
    )
  }
  mcp_json_array(items)
}

///|
fn render_semantic_provenance_json(provenance : @semantic.Provenance) -> String {
  mcp_json_object([
    mcp_json_field(
      "source_path",
      mcp_json_string_or_null(provenance.source_path),
    ),
    mcp_json_field("source_url", mcp_json_string_or_null(provenance.source_url)),
    mcp_json_field(
      "page_no",
      match provenance.page_no {
        Some(value) => value.to_string()
        None => "null"
      },
    ),
    mcp_json_field(
      "slide_no",
      match provenance.slide_no {
        Some(value) => value.to_string()
        None => "null"
      },
    ),
    mcp_json_field("sheet_name", mcp_json_string_or_null(provenance.sheet_name)),
    mcp_json_field("chapter", mcp_json_string_or_null(provenance.chapter)),
    mcp_json_field("resource", mcp_json_string_or_null(provenance.resource)),
  ])
}

///|
fn mcp_json_array_of_ints(values : Array[Int]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(value.to_string())
  }
  mcp_json_array(items)
}

///|
fn mcp_json_of_string_map(values : Map[String, String]) -> String {
  let fields : Array[String] = []
  for key, value in values {
    fields.push(mcp_json_field(key, mcp_json_string(value)))
  }
  mcp_json_object(fields)
}

///|
fn mcp_json_array_of_strings(values : Array[String]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(mcp_json_string(value))
  }
  mcp_json_array(items)
}

///|
fn mcp_json_field(key : String, value : String) -> String {
  "\"" + mcp_escape_json_string(key) + "\":" + value
}

///|
fn mcp_json_object(fields : Array[String]) -> String {
  "{" + fields.join(",") + "}"
}

///|
fn mcp_json_array(items : Array[String]) -> String {
  "[" + items.join(",") + "]"
}

///|
fn mcp_json_string(value : String) -> String {
  "\"" + mcp_escape_json_string(value) + "\""
}

///|
fn mcp_json_string_or_null(value : String?) -> String {
  match value {
    Some(text) => mcp_json_string(text)
    None => "null"
  }
}

///|
fn mcp_escape_json_string(value : String) -> String {
  let mut escaped = ""
  for ch in value {
    if ch == '\\' {
      escaped = escaped + "\\\\"
    } else if ch == '"' {
      escaped = escaped + "\\\""
    } else if ch == '\n' {
      escaped = escaped + "\\n"
    } else if ch == '\r' {
      escaped = escaped + "\\r"
    } else if ch == '\t' {
      escaped = escaped + "\\t"
    } else {
      escaped = escaped + ch.to_string()
    }
  }
  escaped
}

///|
fn parse_structured_json(json : String) -> @types.JsonValue {
  match @types.parse_json(json) {
    Ok(value) => value
    Err(_) => @types.String(json)
  }
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

///|
fn count_sections(sections : Array[@semantic.Section]) -> Int {
  let mut total = 0
  for section in sections {
    total = total + 1 + count_sections(section.children)
  }
  total
}

///|
fn count_low_confidence_blocks(blocks : Array[@semantic.SemanticBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    if block.confidence < 60 {
      total = total + 1
    }
  }
  total
}

///|
async fn run_compare_with_baseline_script(
  baseline : String,
  format_name : String,
  input_path : String,
  candidate_markdown_path : String,
) -> Result[@types.JsonValue, String] {
  let repo_root = locate_repo_root() catch {
    err => return Err("Error locating repository root: " + err.to_string())
  }
  let resolved_input_path = resolve_process_path(input_path)
  let resolved_candidate_markdown_path = resolve_process_path(
    candidate_markdown_path,
  )
  let script_path = @core.join_path(
    repo_root, "tests/conversion_eval/scripts/run_eval.py",
  )
  let args : Array[String] = [
    script_path, "compare-baseline", "--tool", baseline, "--format", format_name,
    "--input", resolved_input_path, "--candidate-markdown", resolved_candidate_markdown_path,
  ]
  let env : Map[String, String] = {
    "PYTHONUTF8": "1",
    "PYTHONIOENCODING": "utf-8",
  }
  let (exit_code, stdout, stderr) = @process.collect_output(
    "python",
    args,
    extra_env=env,
    inherit_env=true,
    cwd=repo_root,
  ) catch {
    err => return Err("Error running baseline script: " + err.to_string())
  }
  let stdout_text = stdout.text() catch {
    err => return Err("Error decoding baseline output: " + err.to_string())
  }
  let stderr_text = stderr.text() catch { _ => "" }
  if exit_code != 0 {
    let detail = if stderr_text.trim() != "" {
      stderr_text.trim().to_string()
    } else if stdout_text.trim() != "" {
      stdout_text.trim().to_string()
    } else {
      "baseline helper exited with code " + exit_code.to_string()
    }
    return Err("Error comparing baseline: " + detail)
  }
  match @types.parse_json(stdout_text) {
    Ok(value) => Ok(value)
    Err(err) => Err("Error parsing baseline payload: " + err.to_string())
  }
}

///|
async fn locate_repo_root() -> String {
  let start = current_working_dir_or_dot()
  locate_repo_root_from(start)
}

///|
async fn locate_repo_root_from(path : String) -> String {
  if @fs.exists(@core.join_path(path, "moon.mod.json")) {
    path
  } else {
    let parent = @core.path_dirname(path)
    if parent == "" || parent == path {
      current_working_dir_or_dot()
    } else {
      locate_repo_root_from(parent)
    }
  }
}

///|
fn current_working_dir_or_dot() -> String {
  match @env.current_dir() {
    Some(dir) if dir.trim() != "" => @core.normalize_path(dir)
    _ => "."
  }
}

///|
fn resolve_process_path(path : String) -> String {
  let normalized = canonicalize_process_path(@core.normalize_path(path))
  if is_absolute_process_path(normalized) {
    normalized
  } else {
    canonicalize_process_path(current_working_dir_or_dot() + "/" + normalized)
  }
}

///|
fn canonicalize_process_path(path : String) -> String {
  let normalized = @core.normalize_path(path)
  let prefix = process_path_prefix(normalized)
  let start = prefix.length()
  let remainder = normalized[start:]
  let segments : Array[String] = []
  for raw_segment in remainder.split("/").to_array() {
    let segment = raw_segment.to_string()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      ignore(segments.pop())
    } else {
      segments.push(segment)
    }
  }
  match prefix {
    "/" => "/" + segments.join("/")
    "" => segments.join("/")
    _ =>
      if segments.length() == 0 {
        prefix + "/"
      } else {
        prefix + "/" + segments.join("/")
      }
  }
}

///|
fn process_path_prefix(path : String) -> String {
  if path.length() >= 2 &&
    is_ascii_letter(path[0]) &&
    path[1:2].to_string() == ":" {
    path[0:2].to_string()
  } else if path.has_prefix("/") {
    "/"
  } else {
    ""
  }
}

///|
fn is_absolute_process_path(path : String) -> Bool {
  path.has_prefix("/") ||
  (
    path.length() >= 2 &&
    is_ascii_letter(path[0]) &&
    path[1:2].to_string() == ":"
  )
}

///|
async fn materialize_baseline_input(
  document : ResolvedMcpDocument,
  effective_format : String,
) -> String {
  match document.input_source {
    @core.FileInput(path, _) => path
    @core.BytesInput(name, bytes, _) => {
      let temp_dir = mcp_baseline_temp_dir_absolute()
      ensure_mcp_baseline_temp_dir(temp_dir)
      let filename = temp_baseline_filename(name, effective_format)
      let path = temp_dir + "/" + filename
      write_bytes_to_file(path, bytes)
      path
    }
    @core.UrlInput(_, _) =>
      fail(
        "compare_with_baseline currently supports local files or uploaded resources, not URLs",
      )
  }
}

///|
async fn write_temp_markdown_file(stem : String, markdown : String) -> String {
  let temp_dir = mcp_baseline_temp_dir_absolute()
  ensure_mcp_baseline_temp_dir(temp_dir)
  let path = temp_dir +
    "/" +
    sanitize_temp_stem(stem) +
    "-" +
    @async.now().to_string() +
    ".md"
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  file.write(@utf8.encode(markdown))
  file.close()
  path
}

///|
async fn ensure_mcp_baseline_temp_dir(path : String) -> Unit {
  ignore(@fs.mkdir(path, permission=0o755, recursive=true) catch { _ => () })
}

///|
fn mcp_baseline_temp_dir() -> String {
  "_build/mcp-baseline-tmp"
}

///|
async fn mcp_baseline_temp_dir_absolute() -> String {
  let repo_root = locate_repo_root() catch { _ => current_working_dir_or_dot() }
  @core.join_path(repo_root, mcp_baseline_temp_dir())
}

///|
async fn cleanup_file_if_exists(path : String) -> Unit {
  ignore(@fs.remove(path) catch { _ => () })
}

///|
async fn cleanup_file_if_exists_if_temp(
  document : ResolvedMcpDocument,
  path : String,
) -> Unit {
  match document.input_source {
    @core.FileInput(_, _) => ()
    _ => cleanup_file_if_exists(path)
  }
}

///|
fn temp_baseline_filename(name : String?, effective_format : String) -> String {
  let raw_name = match name {
    Some(value) => value
    None => "baseline-input"
  }
  let stem = sanitize_temp_stem(raw_name)
  let extension = filename_extension(stem)
  let suffix = if extension == "" {
    format_extension(effective_format)
  } else {
    ""
  }
  stem + "-" + @async.now().to_string() + suffix
}

///|
async fn write_bytes_to_file(path : String, bytes : Bytes) -> Unit {
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  file.write(bytes)
  file.close()
}

///|
fn sanitize_temp_stem(name : String) -> String {
  let mut result = ""
  for ch in name.replace(old="\\", new="/") {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == '-' ||
      ch == '_' {
      result = result + ch.to_string()
    } else {
      result = result + "-"
    }
  }
  let trimmed = result.trim().to_string()
  if trimmed == "" {
    "baseline-input"
  } else {
    trimmed
  }
}

///|
fn filename_extension(name : String) -> String {
  match find_last_char(name, '.') {
    Some(index) if index >= 0 && index < name.length() =>
      name[index:].to_string()
    _ => ""
  }
}

///|
fn format_extension(format_name : String) -> String {
  match format_name {
    "text" => ".txt"
    "csv" => ".csv"
    "json" => ".json"
    "pdf" => ".pdf"
    "html" => ".html"
    "docx" => ".docx"
    "pptx" => ".pptx"
    "xlsx" => ".xlsx"
    "epub" => ".epub"
    "image" => ".png"
    _ => ".bin"
  }
}

///|
fn find_last_char(text : String, target : Char) -> Int? {
  let mut found : Int? = None
  let mut index = 0
  for ch in text {
    if ch == target {
      found = Some(index)
    }
    index = index + 1
  }
  found
}

///|
fn json_object_bool_arg_or_false(
  value : @types.JsonValue,
  key : String,
) -> Bool {
  match value {
    @types.Object(map) =>
      match map.get(key) {
        Some(@types.Bool(flag)) => flag
        _ => false
      }
    _ => false
  }
}

///|
fn json_object_nullable_string_arg(
  value : @types.JsonValue,
  key : String,
) -> String? {
  match value {
    @types.Object(map) =>
      match map.get(key) {
        Some(@types.String(text)) => Some(text)
        _ => None
      }
    _ => None
  }
}

///|
fn json_object_string_arg_or_null(
  value : @types.JsonValue,
  key : String,
  fallback : String,
) -> @types.JsonValue {
  match json_object_nullable_string_arg(value, key) {
    Some(text) => @types.String(text)
    None => if fallback == "" { @types.Null } else { @types.String(fallback) }
  }
}

///|
fn json_object_nullable_int_arg(value : @types.JsonValue, key : String) -> Int? {
  match value {
    @types.Object(map) =>
      match map.get(key) {
        Some(@types.Number(number)) => Some(number)
        _ => None
      }
    _ => None
  }
}

///|
fn json_nested_float_arg(
  value : @types.JsonValue,
  object_key : String,
  key : String,
) -> Float? {
  match value {
    @types.Object(map) =>
      match map.get(object_key) {
        Some(@types.Object(inner)) =>
          match inner.get(key) {
            Some(@types.Float(number)) => Some(number)
            Some(@types.Number(number)) => Some(Float::from_int(number))
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn optional_float_string(value : Float?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "null"
  }
}
