// JSON Converter - Converts JSON files to Markdown code blocks

///|
/// Converter for JSON files
pub(all) struct JsonConverter {
  dummy : Int
}

///|
/// Create a new JSON converter
pub fn JsonConverter::new() -> JsonConverter {
  JsonConverter::{ dummy: 0 }
}

///|
/// Accepts function - checks if file is JSON
pub fn JsonConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => mt == "application/json"
    None =>
      match info.extension {
        Some(".json") => true
        _ => false
      }
  }
}

///|
/// Convert function - converts JSON to Markdown code block
pub async fn JsonConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  JsonConverter::convert_source(@core.FileInput(file_path, None), ctx~)
}

///|
pub async fn JsonConverter::convert_source(
  input : @core.InputSource,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  ignore(ctx)
  let content = @core.strip_utf8_bom(@core.read_input_utf8(input))
  let (rendered_json, warnings, valid_json) = normalize_json_content(content)
  let source_name = match input.name() {
    Some(value) => value
    None => "document.json"
  }
  let title = @core.file_stem(source_name)
  let metadata = Map::new()
  metadata["format"] = "json"
  metadata["render_mode"] = "code_fence"
  metadata["json_valid"] = if valid_json { "true" } else { "false" }
  let doc = json_to_document(rendered_json, title, metadata)
  let markdown = @ast.render_markdown(doc)
  let diagnostics = json_warning_diagnostics(source_name, warnings)
  @core.ConvertResult::markdown_only(markdown, "json")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
  .with_document(Some(doc))
}

///|
fn normalize_json_content(content : String) -> (String, Array[String], Bool) {
  let warnings : Array[String] = []
  let parsed_result : Result[_, Error] = Ok(@corejson.parse(content)) catch {
    err => Err(err)
  }
  match parsed_result {
    Ok(value) => (value.stringify(indent=2), warnings, true)
    Err(_) => {
      warnings.push(
        "JSON input could not be parsed; emitted raw text in code fence.",
      )
      (content.trim_end().to_string(), warnings, false)
    }
  }
}

///|
fn json_to_document(
  content : String,
  title : String?,
  metadata : Map[String, String],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = [
    @ast.CodeBlock(Some("json"), content.trim_end().to_string()),
  ]
  @ast.Document::{ title, metadata, blocks }
}

///|
fn json_warning_diagnostics(
  file_path : String,
  warnings : Array[String],
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    if warning ==
      "JSON input could not be parsed; emitted raw text in code fence." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("json"))),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Inspect the source JSON for syntax errors if structured pretty-printing was expected.",
            ),
          ),
        ),
      )
    }
  }
  diagnostics
}

///|
