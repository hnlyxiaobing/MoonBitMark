// Plain Text Converter

///|
/// Converter for plain text files
pub(all) struct TextConverter {
  dummy : Int
}

///|
/// Create a new text converter
pub fn TextConverter::new() -> TextConverter {
  TextConverter::{ dummy: 0 }
}

///|
/// Accepts function - checks if file is text
pub fn TextConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => mt == "text/plain"
    None =>
      match info.extension {
        Some(".txt") => true
        _ => false
      }
  }
}

///|
/// Convert function - reads file and returns content
pub async fn TextConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  ignore(ctx)
  let file = @fs.open(file_path, mode=ReadOnly)
  let mut content = ""
  while file.read_until("\n") is Some(line) {
    content = content + line + "\n"
  }
  file.close()
  let title = @core.file_stem(file_path)
  let metadata = Map::new()
  metadata["format"] = "plain_text"
  metadata["line_count"] = count_lines(content).to_string()
  let doc = text_to_document(content, title, metadata)
  let markdown = @ast.render_markdown(doc)
  @core.ConvertResult::markdown_only(markdown, "text")
  .with_title(title)
  .with_metadata(metadata)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
  .with_document(Some(doc))
}

///|
fn text_to_document(
  content : String,
  title : String?,
  metadata : Map[String, String],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  for chunk in content.split("\n\n").to_array() {
    let trimmed = chunk.trim().to_string()
    if trimmed != "" {
      blocks.push(@ast.text_paragraph(trimmed))
    }
  }
  @ast.Document::{ title, metadata, blocks }
}

///|
fn count_lines(content : String) -> Int {
  if content == "" {
    0
  } else {
    content.split("\n").to_array().length()
  }
}

///|
