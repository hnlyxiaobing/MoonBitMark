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
pub async fn TextConverter::convert(file_path : String) -> @core.ConvertResult {
  let file = @fs.open(file_path, mode=ReadOnly)
  let mut content = ""
  while file.read_until("\n") is Some(line) {
    content = content + line + "\n"
  }
  file.close()
  let title = file_stem(file_path)
  let metadata = Map::new()
  metadata["format"] = "plain_text"
  metadata["line_count"] = count_lines(content).to_string()
  let doc = text_to_document(content, title, metadata)
  let markdown = @ast.render_markdown(doc)
  @core.ConvertResult::markdown_only(markdown, "text")
  .with_title(title)
  .with_metadata(metadata)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
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
fn file_stem(path : String) -> String? {
  let normalized = path.replace(old="\\", new="/")
  let basename = match find_last_char(normalized, '/') {
    Some(index) => normalized[index + 1:].to_string()
    None => normalized
  }
  match find_last_char(basename, '.') {
    Some(index) =>
      if index > 0 {
        Some(basename[0:index].to_string())
      } else {
        None
      }
    None => if basename != "" { Some(basename) } else { None }
  }
}

///|
fn find_last_char(s : String, target : Char) -> Int? {
  let mut found = -1
  let mut i = 0
  for ch in s {
    if ch == target {
      found = i
    }
    i = i + 1
  }
  if found >= 0 {
    Some(found)
  } else {
    None
  }
}
