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
  ignore(ctx)
  let content = @core.strip_utf8_bom(@core.read_utf8_file(file_path))
  let title = @core.file_stem(file_path)
  let metadata = Map::new()
  metadata["format"] = "json"
  metadata["render_mode"] = "code_fence"
  let doc = json_to_document(content, title, metadata)
  let markdown = @ast.render_markdown(doc)
  @core.ConvertResult::markdown_only(markdown, "json")
  .with_title(title)
  .with_metadata(metadata)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
  .with_document(Some(doc))
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
