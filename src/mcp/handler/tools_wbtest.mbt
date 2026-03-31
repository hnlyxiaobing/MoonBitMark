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
test "tool registry lists inspect and convert with agent-facing schema" {
  let registry = ToolRegistry::new().register_convert_tools()
  let tools = registry.list()
  inspect(tools.length(), content="2")
  inspect(tools[0].name, content="inspect_document")
  inspect(tools[1].name, content="convert_to_markdown")
  inspect(tools[1].description.contains("preview"), content="true")
  match tools[1].input_schema.get("properties") {
    Some(@types.Object(properties)) => {
      inspect(properties.contains("mode"), content="true")
      inspect(properties.contains("max_chars"), content="true")
      inspect(properties.contains("format_hint"), content="true")
    }
    _ => fail("expected object properties in convert_to_markdown schema")
  }
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
