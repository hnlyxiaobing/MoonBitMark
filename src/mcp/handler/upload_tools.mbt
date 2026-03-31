// MoonBitMark MCP Handler - Uploaded Document Tools

///|
async fn convert_uploaded_document_handler(
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
  let document = match
    resolve_inline_upload_document(
      args,
      config,
      uploaded_request_uri(
        match required_string_arg(args, "filename") {
          Ok(value) => uploaded_filename(value)
          Err(_) => "upload.bin"
        },
      ),
    ) {
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
    let convert_result = @engine.MarkItDown::new().convert_source(
      document.input_source,
      ctx~,
    )
    let total_chars = convert_result.markdown.length()
    let requested_limit = effective_max_chars(mode, max_chars)
    let limit = clamp_mcp_output_chars(requested_limit, config)
    let returned_markdown = limit_markdown(convert_result.markdown, limit)
    let truncated = returned_markdown.length() < total_chars
    let preview_recommended = should_recommend_preview(
      effective_format,
      document.byte_size,
      false,
    )
    let summary = render_summary([
      summary_line("tool", "convert_uploaded_document"),
      summary_line("uri", document.request_uri),
      summary_line("input_kind", document.input_kind),
      summary_line("source_filename", optional_string(document.source_filename)),
      summary_line("upload_encoding", optional_string(document.upload_encoding)),
      summary_line("mime_type", optional_string(document.mime_type)),
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
      summary_line("max_upload_bytes", config.max_upload_bytes.to_string()),
      summary_line("uploaded_bytes", optional_int_string(document.byte_size)),
      summary_line("returned_chars", returned_markdown.length().to_string()),
      summary_line("total_chars", total_chars.to_string()),
      summary_line("truncated", bool_string(truncated)),
      summary_line("warnings", convert_result.warnings.length().to_string()),
      summary_line(
        "diagnostics",
        convert_result.diagnostics.length().to_string(),
      ),
      summary_line("asset_count", convert_result.assets.length().to_string()),
      summary_line("preview_recommended", bool_string(preview_recommended)),
      summary_line("may_use_ocr", bool_string(may_use_ocr(effective_format))),
      summary_line(
        "may_use_bridge",
        bool_string(may_use_bridge(effective_format)),
      ),
      summary_line("next_step", next_step(mode, truncated)),
    ])
    let payload = @types.Object({
      "content": @types.String(returned_markdown),
      "metadata": @types.Object({
        "tool": @types.String("convert_uploaded_document"),
        "uri": @types.String(document.request_uri),
        "input_kind": @types.String(document.input_kind),
        "source_filename": json_optional_string(document.source_filename),
        "upload_encoding": json_optional_string(document.upload_encoding),
        "mime_type": json_optional_string(document.mime_type),
        "mode": @types.String(mode),
        "detected_format": @types.String(detected_format),
        "effective_format": @types.String(effective_format),
        "format_hint": json_optional_string(format_hint),
        "format_hint_applied": @types.Bool(format_hint != None),
        "title": json_optional_string(convert_result.title),
        "source_type": @types.String(convert_result.source_type),
        "document_metadata": string_map_to_json_object(convert_result.metadata),
      }),
      "diagnostics": @types.Object({
        "truncated": @types.Bool(truncated),
        "preview_recommended": @types.Bool(preview_recommended),
        "may_use_ocr": @types.Bool(may_use_ocr(effective_format)),
        "may_use_bridge": @types.Bool(may_use_bridge(effective_format)),
        "http_allowed": @types.Bool(config.allow_http),
        "ocr_enabled_by_env": @types.Bool(config.enable_ocr),
        "next_step": @types.String(next_step(mode, truncated)),
        "warnings": string_array_to_json(convert_result.warnings),
        "conversion_diagnostics": diagnostics_array_to_json(
          convert_result.diagnostics,
        ),
      }),
      "stats": @types.Object({
        "uploaded_bytes": json_optional_int(document.byte_size),
        "max_upload_bytes": @types.Number(config.max_upload_bytes),
        "requested_max_chars": json_optional_int(max_chars),
        "effective_max_chars": json_optional_int(limit),
        "env_max_output_chars": json_optional_int(config.max_output_chars),
        "returned_chars": @types.Number(returned_markdown.length()),
        "total_chars": @types.Number(total_chars),
        "warning_count": @types.Number(convert_result.warnings.length()),
        "diagnostic_count": @types.Number(convert_result.diagnostics.length()),
        "asset_count": @types.Number(convert_result.assets.length()),
        "converter_stats": convert_stats_to_json(convert_result.stats),
      }),
    })
    tool_result_for_response_mode(
      response_mode,
      summary,
      Some(returned_markdown),
      payload,
    )
  } catch {
    error =>
      error_tool_result(
        "Error converting uploaded document: " + error.to_string(),
      )
  }
}
