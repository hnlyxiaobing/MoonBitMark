///|
fn extract_text(content : @types.McpContent) -> String {
  match content {
    @types.Text(value) => value.text
  }
}

///|
fn parse_summary_text(content : @types.McpContent) -> Map[String, String] raise {
  let text = extract_text(content)
  let entries : Map[String, String] = Map::new()
  for line in text.split("\n") {
    let rendered = line.to_string()
    match rendered.find(": ") {
      Some(index) => {
        let key = rendered[:index].to_string()
        let value = rendered[index + 2:].to_string()
        entries[key] = value
      }
      None => fail("expected key/value summary line, got: " + rendered)
    }
  }
  entries
}

///|
async fn write_test_text(path : String, text : String) -> Unit {
  ignore(
    @fs.mkdir("_build/test-tmp", permission=0o755, recursive=true) catch {
      _ => ()
    },
  )
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  file.write(@utf8.encode(text))
  file.close()
}

///|
fn temp_file_path(stem : String) -> String {
  "_build/test-tmp/" + stem + ".txt"
}

///|
fn temp_html_path(stem : String) -> String {
  "_build/test-tmp/" + stem + ".html"
}

///|
fn build_long_text() -> String {
  let lines : Array[String] = []
  for index in 0..<600 {
    lines.push("preview test line " + index.to_string())
  }
  lines.join("\n")
}

///|
fn parse_int_string(value : String) -> Int raise {
  @strconv.from_str(value[:])
}

///|
fn extract_structured_content(
  result : @types.McpToolResult,
) -> @types.JsonValue raise {
  match result.structured_content {
    Some(value) => value
    None => fail("expected structured_content")
  }
}

///|
fn json_object_field(
  value : @types.JsonValue,
  key : String,
) -> @types.JsonValue raise {
  match value {
    @types.Object(map) =>
      match map.get(key) {
        Some(field) => field
        None => fail("expected field: " + key)
      }
    _ => fail("expected object for key lookup: " + key)
  }
}

///|
fn json_array_at(
  value : @types.JsonValue,
  index : Int,
) -> @types.JsonValue raise {
  match value {
    @types.Array(items) =>
      match items.get(index) {
        Some(item) => item
        None => fail("expected array index: " + index.to_string())
      }
    _ => fail("expected array")
  }
}

///|
fn json_string_field(value : @types.JsonValue, key : String) -> String raise {
  match json_object_field(value, key) {
    @types.String(text) => text
    _ => fail("expected string field: " + key)
  }
}

///|
fn json_int_field(value : @types.JsonValue, key : String) -> Int raise {
  match json_object_field(value, key) {
    @types.Number(number) => number
    _ => fail("expected int field: " + key)
  }
}

///|
fn json_array_length(value : @types.JsonValue) -> Int raise {
  match value {
    @types.Array(items) => items.length()
    _ => fail("expected array length")
  }
}

///|
fn bytes_json_array(bytes : Bytes) -> @types.JsonValue {
  let items : Array[@types.JsonValue] = []
  for byte in bytes {
    items.push(@types.Number(byte.to_int()))
  }
  @types.Array(items)
}

///|
test "tool registry lists inspect and convert with agent-facing schema" {
  let registry = ToolRegistry::new().register_convert_tools()
  let tools = registry.list()
  inspect(tools.length(), content="7")
  inspect(tools[0].name, content="inspect_document")
  inspect(tools[1].name, content="convert_to_markdown")
  inspect(tools[2].name, content="dump_normalized_ast")
  inspect(tools[3].name, content="extract_structure")
  inspect(tools[4].name, content="compare_with_baseline")
  inspect(tools[5].name, content="upload_document")
  inspect(tools[6].name, content="convert_uploaded_document")
  inspect(tools[1].description.contains("preview"), content="true")
  match tools[1].input_schema.get("properties") {
    Some(@types.Object(properties)) => {
      inspect(properties.contains("mode"), content="true")
      inspect(properties.contains("max_chars"), content="true")
      inspect(properties.contains("format_hint"), content="true")
      inspect(properties.contains("response_mode"), content="true")
    }
    _ => fail("expected object properties in convert_to_markdown schema")
  }
  match tools[2].input_schema.get("properties") {
    Some(@types.Object(properties)) => {
      inspect(properties.contains("uri"), content="true")
      inspect(properties.contains("resource_uri"), content="true")
      inspect(properties.contains("response_mode"), content="true")
    }
    _ => fail("expected object properties in dump_normalized_ast schema")
  }
  match tools[3].input_schema.get("properties") {
    Some(@types.Object(properties)) => {
      inspect(properties.contains("uri"), content="true")
      inspect(properties.contains("resource_uri"), content="true")
      inspect(properties.contains("response_mode"), content="true")
    }
    _ => fail("expected object properties in extract_structure schema")
  }
  match tools[4].input_schema.get("properties") {
    Some(@types.Object(properties)) => {
      inspect(properties.contains("baseline"), content="true")
      inspect(properties.contains("format_hint"), content="true")
      inspect(properties.contains("uri"), content="true")
      inspect(properties.contains("resource_uri"), content="true")
      inspect(properties.contains("response_mode"), content="true")
    }
    _ => fail("expected object properties in compare_with_baseline schema")
  }
  match tools[5].input_schema.get("properties") {
    Some(@types.Object(properties)) => {
      inspect(properties.contains("filename"), content="true")
      inspect(properties.contains("data_base64"), content="true")
      inspect(properties.contains("data_bytes"), content="true")
      inspect(properties.contains("response_mode"), content="true")
    }
    _ => fail("expected object properties in upload_document schema")
  }
  match tools[6].input_schema.get("properties") {
    Some(@types.Object(properties)) => {
      inspect(properties.contains("filename"), content="true")
      inspect(properties.contains("data_base64"), content="true")
      inspect(properties.contains("data_bytes"), content="true")
      inspect(properties.contains("mime_type"), content="true")
    }
    _ => fail("expected object properties in convert_uploaded_document schema")
  }
}

///|
async test "upload_document returns reusable resource_uri" {
  let upload = upload_document_handler(
    @types.Object({
      "filename": @types.String("uploaded-resource.txt"),
      "data_base64": @types.String(
        @base64.encode(@utf8.encode("resource line 1")),
      ),
      "response_mode": @types.String("json"),
    }),
  )
  inspect(upload.is_error, content="false")
  let payload = extract_structured_content(upload)
  let resource_uri = match payload {
    @types.Object(map) =>
      match map.get("metadata") {
        Some(@types.Object(metadata)) =>
          match metadata.get("resource_uri") {
            Some(@types.String(value)) => value
            _ => fail("expected resource_uri metadata")
          }
        _ => fail("expected metadata object")
      }
    _ => fail("expected object payload")
  }
  let inspect_result = inspect_document_handler(
    @types.Object({ "resource_uri": @types.String(resource_uri) }),
  )
  inspect(inspect_result.is_error, content="false")
  let inspect_summary = parse_summary_text(inspect_result.content[0])
  inspect(inspect_summary["input_kind"], content="resource")
  let convert_result = convert_to_markdown_handler(
    @types.Object({
      "resource_uri": @types.String(resource_uri),
      "mode": @types.String("full"),
    }),
  )
  inspect(convert_result.is_error, content="false")
  assert_true(
    extract_text(convert_result.content[1]).contains("resource line 1"),
  )
}

///|
async test "inspect_document reports detection size and preview recommendation" {
  let path = temp_file_path("mcp-inspect")
  write_test_text(path, build_long_text())
  let result = inspect_document_handler(
    @types.Object({ "uri": @types.String(path) }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="1")
  let summary = parse_summary_text(result.content[0])
  inspect(summary["tool"], content="inspect_document")
  inspect(summary["detected_format"], content="text")
  inspect(summary["preview_recommended"], content="true")
  let size = parse_int_string(summary["file_size_bytes"]) catch {
    _ => fail("expected numeric file_size_bytes")
  }
  assert_true(size > 12000)
}

///|
async test "inspect_document supports json response mode with stable keys" {
  let path = temp_file_path("mcp-inspect-json")
  write_test_text(path, build_long_text())
  let result = inspect_document_handler(
    @types.Object({
      "uri": @types.String(path),
      "response_mode": @types.String("json"),
    }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="1")
  let payload = extract_structured_content(result)
  match payload {
    @types.Object(map) => {
      inspect(map.contains("content"), content="true")
      inspect(map.contains("metadata"), content="true")
      inspect(map.contains("diagnostics"), content="true")
      inspect(map.contains("stats"), content="true")
      inspect(map.contains("explanations"), content="true")
      match map.get("metadata") {
        Some(@types.Object(metadata)) =>
          match metadata.get("detected_format") {
            Some(@types.String(value)) => inspect(value, content="text")
            _ => fail("expected detected_format string")
          }
        _ => fail("expected metadata object")
      }
    }
    _ => fail("expected object structured payload")
  }
}

///|
async test "convert_to_markdown defaults to preview and truncates large output" {
  let path = temp_file_path("mcp-preview")
  write_test_text(path, build_long_text())
  let result = convert_to_markdown_handler(
    @types.Object({ "uri": @types.String(path) }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="2")
  let summary = parse_summary_text(result.content[0])
  let markdown = extract_text(result.content[1])
  inspect(summary["mode"], content="preview")
  inspect(summary["truncated"], content="true")
  let returned_chars = parse_int_string(summary["returned_chars"]) catch {
    _ => fail("expected numeric returned_chars")
  }
  let total_chars = parse_int_string(summary["total_chars"]) catch {
    _ => fail("expected numeric total_chars")
  }
  assert_true(returned_chars <= 4000)
  assert_true(total_chars > 4000)
  assert_true(markdown.contains("preview test line 0"))
}

///|
async test "dump_normalized_ast returns normalized document text payload" {
  let path = temp_file_path("mcp-normalized-ast")
  write_test_text(path, "  alpha\n\nbeta  gamma")
  let result = dump_normalized_ast_handler(
    @types.Object({ "uri": @types.String(path) }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="2")
  let summary = parse_summary_text(result.content[0])
  let payload = extract_text(result.content[1])
  inspect(summary["tool"], content="dump_normalized_ast")
  inspect(summary["detected_format"], content="text")
  assert_true(payload.contains("\"blocks\""))
  assert_true(payload.contains("\"annotations\""))
}

///|
async test "dump_normalized_ast supports json response mode with stable keys" {
  let path = temp_file_path("mcp-normalized-ast-json")
  write_test_text(path, "alpha")
  let result = dump_normalized_ast_handler(
    @types.Object({
      "uri": @types.String(path),
      "response_mode": @types.String("json"),
    }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="1")
  let payload = extract_structured_content(result)
  match payload {
    @types.Object(map) => {
      inspect(map.contains("content"), content="true")
      inspect(map.contains("metadata"), content="true")
      inspect(map.contains("diagnostics"), content="true")
      inspect(map.contains("stats"), content="true")
      inspect(map.contains("explanations"), content="true")
      inspect(map.contains("normalized_document"), content="true")
      match map.get("stats") {
        Some(@types.Object(stats)) =>
          match stats.get("block_count") {
            Some(@types.Number(value)) => inspect(value, content="1")
            _ => fail("expected block_count integer")
          }
        _ => fail("expected stats object")
      }
    }
    _ => fail("expected object structured payload")
  }
}

///|
test "normalizer explanation replays per-block decisions" {
  let raw_document = @ast.Document::{
    title: Some("Demo"),
    metadata: { "format": "html" },
    blocks: [
      @ast.Heading(9, [@ast.Text("Title")]),
      @ast.List([[@ast.Text("keep")], []], false),
      @ast.Table([], [[[@ast.Text("A")], [@ast.Text("B")]], [[@ast.Text("1")]]]),
      @ast.Paragraph([@ast.Text("alpha   beta")]),
    ],
    annotations: [
      @ast.BlockAnnotation::{
        id: "block-1",
        source_hint: Some("tag:h9"),
        origin_hint: Some("html"),
        diagnostics: ["Normalized heading level from 9 to 6"],
      },
      @ast.BlockAnnotation::{
        id: "block-2",
        source_hint: Some("tag:ul"),
        origin_hint: Some("html"),
        diagnostics: ["Removed empty list items during normalization"],
      },
      @ast.BlockAnnotation::{
        id: "block-3",
        source_hint: Some("tag:table"),
        origin_hint: Some("html"),
        diagnostics: ["Normalized table shape to a rectangular layout"],
      },
      @ast.BlockAnnotation::{
        id: "block-4",
        source_hint: Some("tag:p"),
        origin_hint: Some("html"),
        diagnostics: ["Normalized paragraph whitespace"],
      },
    ],
  }
  let normalized_document = @ast.Document::{
    title: Some("Demo"),
    metadata: { "format": "html" },
    blocks: [
      @ast.Heading(6, [@ast.Text("Title")]),
      @ast.List([[@ast.Text("keep")]], false),
      @ast.Table([[@ast.Text("A")], [@ast.Text("B")]], [[[@ast.Text("1")], []]]),
      @ast.Paragraph([@ast.Text("alpha beta")]),
    ],
    annotations: raw_document.annotations,
  }
  let result = @core.ConvertResult::markdown_only("# Demo", "html").with_ast_views(
    Some(raw_document),
    Some(normalized_document),
    Some(@semantic.semantic_document_of(normalized_document)),
  )
  let payload = normalizer_explanation(result)
  inspect(json_int_field(payload, "block_count"), content="4")
  inspect(json_int_field(payload, "changed_blocks"), content="4")
  let first_block = json_array_at(json_object_field(payload, "blocks"), 0)
  let first_decision = json_array_at(
    json_object_field(first_block, "decisions"),
    0,
  )
  inspect(json_string_field(first_decision, "step"), content="heading_levels")
  inspect(json_string_field(first_decision, "status"), content="changed")
  let second_block = json_array_at(json_object_field(payload, "blocks"), 1)
  let second_decision = json_array_at(
    json_object_field(second_block, "decisions"),
    1,
  )
  inspect(json_string_field(second_decision, "step"), content="list_items")
  inspect(json_string_field(second_decision, "status"), content="changed")
  let third_block = json_array_at(json_object_field(payload, "blocks"), 2)
  let third_decision = json_array_at(
    json_object_field(third_block, "decisions"),
    2,
  )
  inspect(json_string_field(third_decision, "step"), content="table_shape")
  inspect(json_string_field(third_decision, "status"), content="changed")
  let fourth_block = json_array_at(json_object_field(payload, "blocks"), 3)
  let fourth_decision = json_array_at(
    json_object_field(fourth_block, "decisions"),
    3,
  )
  inspect(
    json_string_field(fourth_decision, "step"),
    content="inline_whitespace",
  )
  inspect(json_string_field(fourth_decision, "status"), content="changed")
}

///|
async test "convert_to_markdown supports json response mode with stable keys" {
  let path = temp_file_path("mcp-full-json")
  write_test_text(path, build_long_text())
  let result = convert_to_markdown_handler(
    @types.Object({
      "uri": @types.String(path),
      "mode": @types.String("full"),
      "max_chars": @types.Number(120),
      "response_mode": @types.String("json"),
    }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="1")
  let payload = extract_structured_content(result)
  match payload {
    @types.Object(map) => {
      inspect(map.contains("content"), content="true")
      inspect(map.contains("metadata"), content="true")
      inspect(map.contains("diagnostics"), content="true")
      inspect(map.contains("stats"), content="true")
      inspect(map.contains("explanations"), content="true")
      match map.get("content") {
        Some(@types.String(markdown)) =>
          inspect(markdown.length(), content="120")
        _ => fail("expected string content")
      }
      match map.get("stats") {
        Some(@types.Object(stats)) => {
          match stats.get("returned_chars") {
            Some(@types.Number(value)) => inspect(value, content="120")
            _ => fail("expected returned_chars integer")
          }
          inspect(stats.contains("converter_stats"), content="true")
        }
        _ => fail("expected stats object")
      }
    }
    _ => fail("expected object structured payload")
  }
}

///|
async test "convert_to_markdown full mode honors max_chars" {
  let path = temp_file_path("mcp-full")
  write_test_text(path, build_long_text())
  let result = convert_to_markdown_handler(
    @types.Object({
      "uri": @types.String(path),
      "mode": @types.String("full"),
      "max_chars": @types.Number(120),
      "format_hint": @types.String("text"),
    }),
  )
  inspect(result.is_error, content="false")
  let summary = parse_summary_text(result.content[0])
  let markdown = extract_text(result.content[1])
  inspect(summary["mode"], content="full")
  inspect(summary["format_hint_applied"], content="true")
  inspect(summary["truncated"], content="true")
  let returned_chars = parse_int_string(summary["returned_chars"]) catch {
    _ => fail("expected numeric returned_chars")
  }
  assert_eq(returned_chars, 120)
  inspect(markdown.length(), content="120")
}

///|
async test "extract_structure returns semantic document text payload" {
  let path = temp_file_path("mcp-extract-structure")
  write_test_text(path, "Title\n\nNote: review this")
  let result = extract_structure_handler(
    @types.Object({ "uri": @types.String(path) }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="2")
  let summary = parse_summary_text(result.content[0])
  let payload = extract_text(result.content[1])
  inspect(summary["tool"], content="extract_structure")
  inspect(summary["detected_format"], content="text")
  assert_true(payload.contains("\"sections\""))
  assert_true(payload.contains("\"blocks\""))
}

///|
async test "extract_structure supports json response mode with stable keys" {
  let path = temp_file_path("mcp-extract-structure-json")
  write_test_text(path, "Title\n\nbody")
  let result = extract_structure_handler(
    @types.Object({
      "uri": @types.String(path),
      "response_mode": @types.String("json"),
    }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="1")
  let payload = extract_structured_content(result)
  match payload {
    @types.Object(map) => {
      inspect(map.contains("content"), content="true")
      inspect(map.contains("metadata"), content="true")
      inspect(map.contains("diagnostics"), content="true")
      inspect(map.contains("stats"), content="true")
      inspect(map.contains("explanations"), content="true")
      inspect(map.contains("semantic_document"), content="true")
      match map.get("stats") {
        Some(@types.Object(stats)) => {
          inspect(stats.contains("section_count"), content="true")
          inspect(stats.contains("block_count"), content="true")
        }
        _ => fail("expected stats object")
      }
      match map.get("metadata") {
        Some(@types.Object(metadata)) =>
          inspect(metadata.contains("provenance"), content="true")
        _ => fail("expected metadata object")
      }
    }
    _ => fail("expected object structured payload")
  }
}

///|
async test "extract_structure json payload serializes as valid jsonrpc response" {
  let path = temp_html_path("mcp-extract-structure-escaped")
  write_test_text(
    path, "<html><head><title>\"Quoted\" Demo</title></head><body><h1>Line 1</h1><table><tr><th>A</th><th>B</th></tr><tr><td>x</td><td>line 1\nline 2</td></tr></table></body></html>",
  )
  let result = extract_structure_handler(
    @types.Object({
      "uri": @types.String(path),
      "response_mode": @types.String("json"),
    }),
  )
  inspect(result.is_error, content="false")
  let response = @types.JsonResponse::{
    jsonrpc: "2.0",
    result: Some(result.to_json()),
    error: None,
    id: Some(@types.NumberId(99)),
  }
  match @types.parse_json(response.to_json().to_string()) {
    Ok(@types.Object(root)) => {
      inspect(root.contains("result"), content="true")
      inspect(root.contains("id"), content="true")
    }
    Ok(_) => fail("expected jsonrpc object")
    Err(message) =>
      fail("expected valid jsonrpc response, got: " + message.to_string())
  }
}

///|
async test "compare_with_baseline reports unsupported docling format without error" {
  let path = temp_file_path("mcp-compare-baseline-unsupported")
  write_test_text(path, "plain text body")
  let result = compare_with_baseline_handler(
    @types.Object({
      "uri": @types.String(path),
      "baseline": @types.String("docling"),
    }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="1")
  let summary = parse_summary_text(result.content[0])
  inspect(summary["tool"], content="compare_with_baseline")
  inspect(summary["baseline"], content="docling")
  inspect(summary["baseline_supported"], content="false")
}

///|
async test "compare_with_baseline supports json response mode with stable keys" {
  let path = temp_file_path("mcp-compare-baseline-json")
  write_test_text(path, "plain text body")
  let result = compare_with_baseline_handler(
    @types.Object({
      "uri": @types.String(path),
      "baseline": @types.String("docling"),
      "response_mode": @types.String("json"),
    }),
  )
  inspect(result.is_error, content="false")
  inspect(result.content.length(), content="1")
  let payload = extract_structured_content(result)
  match payload {
    @types.Object(map) => {
      inspect(map.contains("content"), content="true")
      inspect(map.contains("metadata"), content="true")
      inspect(map.contains("diagnostics"), content="true")
      inspect(map.contains("stats"), content="true")
      inspect(map.contains("explanations"), content="true")
      inspect(map.contains("comparison"), content="true")
      match map.get("metadata") {
        Some(@types.Object(metadata)) =>
          match metadata.get("baseline") {
            Some(@types.String(value)) => inspect(value, content="docling")
            _ => fail("expected baseline metadata")
          }
        _ => fail("expected metadata object")
      }
      match map.get("diagnostics") {
        Some(@types.Object(diagnostics)) =>
          match diagnostics.get("baseline_supported") {
            Some(@types.Bool(value)) => inspect(value, content="false")
            _ => fail("expected baseline_supported bool")
          }
        _ => fail("expected diagnostics object")
      }
      let explanations = json_object_field(payload, "explanations")
      let comparison_debug = json_object_field(explanations, "comparison_debug")
      inspect(
        json_string_field(comparison_debug, "status"),
        content="unsupported_format",
      )
    }
    _ => fail("expected object structured payload")
  }
}

///|
test "comparison debug explanation reports metrics and highlights" {
  let comparison = @types.Object({
    "tool": @types.String("markitdown"),
    "format": @types.String("pdf"),
    "available": @types.Bool(true),
    "supported": @types.Bool(true),
    "python_exe": @types.String("python"),
    "duration_ms": @types.Number(42),
    "baseline_markdown": @types.String("# Baseline"),
    "baseline_chars": @types.Number(10),
    "comparison_basis": @types.String("candidate_vs_baseline"),
    "agreement": @types.Object({
      "overall_score": @types.Float(0.88),
      "sequence_similarity": @types.Float(0.91),
      "token_f1": @types.Float(0.9),
      "structure_similarity": @types.Float(0.83),
      "table_similarity": @types.Float(0.55),
      "heading_structure_score": @types.Float(0.99),
      "list_nesting_score": @types.Float(0.92),
      "table_shape_score": @types.Float(0.52),
      "paragraph_segmentation_score": @types.Float(0.79),
      "asset_link_score": @types.Float(1.0),
    }),
  })
  let payload = comparison_debug_explanation(
    @core.ConvertResult::markdown_only("# Candidate", "pdf"),
    comparison,
  )
  inspect(json_string_field(payload, "status"), content="compared")
  inspect(
    json_array_length(json_object_field(payload, "metrics")).to_string(),
    content="10",
  )
  let highlights = json_object_field(payload, "highlights")
  assert_true(json_array_length(highlights) >= 2)
  let first_highlight = json_array_at(highlights, 0)
  inspect(json_string_field(first_highlight, "kind"), content="risk")
}

///|
async test "convert_uploaded_document supports base64 payload with json mode" {
  let bytes = @utf8.encode(build_long_text())
  let result = convert_uploaded_document_handler(
    @types.Object({
      "filename": @types.String("uploaded.txt"),
      "data_base64": @types.String(@base64.encode(bytes)),
      "mime_type": @types.String("text/plain"),
      "response_mode": @types.String("json"),
    }),
  )
  inspect(result.is_error, content="false")
  let payload = extract_structured_content(result)
  match payload {
    @types.Object(map) => {
      match map.get("metadata") {
        Some(@types.Object(metadata)) => {
          match metadata.get("tool") {
            Some(@types.String(value)) =>
              inspect(value, content="convert_uploaded_document")
            _ => fail("expected tool metadata")
          }
          match metadata.get("source_filename") {
            Some(@types.String(value)) => inspect(value, content="uploaded.txt")
            _ => fail("expected source_filename metadata")
          }
          match metadata.get("upload_encoding") {
            Some(@types.String(value)) => inspect(value, content="base64")
            _ => fail("expected upload_encoding metadata")
          }
        }
        _ => fail("expected metadata object")
      }
      match map.get("stats") {
        Some(@types.Object(stats)) =>
          assert_true(stats.contains("uploaded_bytes"))
        _ => fail("expected stats object")
      }
      match map.get("content") {
        Some(@types.String(markdown)) =>
          assert_true(markdown.contains("preview test line 0"))
        _ => fail("expected string content")
      }
    }
    _ => fail("expected object structured payload")
  }
}

///|
async test "convert_uploaded_document supports byte array payload" {
  let result = convert_uploaded_document_handler(
    @types.Object({
      "filename": @types.String("uploaded-bytes.txt"),
      "data_bytes": bytes_json_array(
        @utf8.encode("uploaded bytes line 1\nuploaded bytes line 2"),
      ),
      "mode": @types.String("full"),
    }),
  )
  inspect(result.is_error, content="false")
  let summary = parse_summary_text(result.content[0])
  let markdown = extract_text(result.content[1])
  inspect(summary["tool"], content="convert_uploaded_document")
  inspect(summary["input_kind"], content="uploaded_document")
  inspect(summary["upload_encoding"], content="bytes")
  assert_true(markdown.contains("uploaded bytes line 1"))
}

///|
async test "convert_uploaded_document rejects ambiguous payload fields" {
  let result = convert_uploaded_document_handler(
    @types.Object({
      "filename": @types.String("uploaded.txt"),
      "data_base64": @types.String(@base64.encode(@utf8.encode("demo"))),
      "data_bytes": bytes_json_array(@utf8.encode("demo")),
    }),
  )
  inspect(result.is_error, content="true")
  inspect(
    extract_text(result.content[0]),
    content="Error: provide exactly one of 'data_base64' or 'data_bytes'",
  )
}

///|
async test "tools reject invalid response_mode" {
  let result = inspect_document_handler(
    @types.Object({
      "uri": @types.String("demo.txt"),
      "response_mode": @types.String("yaml"),
    }),
  )
  inspect(result.is_error, content="true")
  inspect(
    extract_text(result.content[0]),
    content="Error: 'response_mode' must be 'text' or 'json'",
  )
}

///|
async test "compare_with_baseline rejects invalid baseline" {
  let result = compare_with_baseline_handler(
    @types.Object({
      "uri": @types.String("demo.txt"),
      "baseline": @types.String("pandoc"),
    }),
  )
  inspect(result.is_error, content="true")
  inspect(
    extract_text(result.content[0]),
    content="Error: 'baseline' must be 'markitdown' or 'docling'",
  )
}

///|
async test "convert_to_markdown rejects invalid mode" {
  let result = convert_to_markdown_handler(
    @types.Object({
      "uri": @types.String("demo.txt"),
      "mode": @types.String("invalid"),
    }),
  )
  inspect(result.is_error, content="true")
  inspect(
    extract_text(result.content[0]),
    content="Error: 'mode' must be 'preview' or 'full'",
  )
}
