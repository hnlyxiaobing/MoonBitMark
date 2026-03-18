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
pub async fn JsonConverter::convert(file_path : String) -> @core.ConvertResult {
  let file = @fs.open(file_path, mode=ReadOnly)
  let mut content = ""
  let mut is_first = true
  while file.read_until("\n") is Some(line) {
    if is_first {
      let trimmed = line.trim_start()
      content = content + trimmed.to_string() + "\n"
      is_first = false
    } else {
      content = content + line + "\n"
    }
  }
  file.close()
  let title = file_stem(file_path)
  let metadata = Map::new()
  metadata["format"] = "json"
  metadata["render_mode"] = "code_fence"
  let doc = json_to_document(content, title, metadata)
  let markdown = @ast.render_markdown(doc)
  @core.ConvertResult::markdown_only(markdown, "json")
  .with_title(title)
  .with_metadata(metadata)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
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
