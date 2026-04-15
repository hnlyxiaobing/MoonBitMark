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
  TextConverter::convert_source(@core.FileInput(file_path, None), ctx~)
}

///|
pub async fn TextConverter::convert_source(
  input : @core.InputSource,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  ignore(ctx)
  let content = normalize_text_content(
    @core.strip_utf8_bom(@core.read_input_utf8(input)),
  )
  let source_name = match input.name() {
    Some(value) => value
    None => "text.txt"
  }
  let title = @core.file_stem(source_name)
  let metadata = Map::new()
  metadata["format"] = "plain_text"
  metadata["line_count"] = count_lines(content).to_string()
  let doc = text_to_document(content, title, metadata)
  let markdown = @ast.render_markdown(doc)
  let warnings : Array[String] = []
  if markdown == "" {
    warnings.push("Text input produced empty Markdown output.")
  }
  let diagnostics = text_warning_diagnostics(source_name, warnings)
  @core.ConvertResult::markdown_only(markdown, "text")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
  .with_document(Some(doc))
}

///|
fn normalize_text_content(content : String) -> String {
  let mut result = ""
  let mut previous_was_cr = false
  for ch in content {
    if ch == '\r' {
      result = result + "\n"
      previous_was_cr = true
    } else if ch == '\n' && previous_was_cr {
      previous_was_cr = false
    } else {
      result = result + ch.to_string()
      previous_was_cr = false
    }
  }
  result
}

///|
fn text_to_document(
  content : String,
  title : String?,
  metadata : Map[String, String],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  for chunk in split_text_chunks(content) {
    match parse_text_chunk(chunk) {
      Some(block) => blocks.push(block)
      None => ()
    }
  }
  @ast.document(title, metadata, blocks)
}

///|
fn split_text_chunks(content : String) -> Array[String] {
  let chunks : Array[String] = []
  let mut current = ""
  for line in normalize_text_content(content).split("\n").to_array() {
    let text = line.to_string()
    if text.trim() == "" {
      if current != "" {
        chunks.push(current)
        current = ""
      }
    } else if current == "" {
      current = text
    } else {
      current = current + "\n" + text
    }
  }
  if current != "" {
    chunks.push(current)
  }
  chunks
}

///|
fn parse_text_chunk(chunk : String) -> @ast.Block? {
  match text_chunk_to_list(chunk) {
    Some(list_block) => Some(list_block)
    None => {
      let trimmed = normalize_text_paragraph(
        chunk,
        preserve_lines=should_preserve_text_lines(chunk),
      )
      if trimmed == "" {
        None
      } else {
        Some(@ast.text_paragraph(trimmed))
      }
    }
  }
}

///|
fn text_chunk_to_list(chunk : String) -> @ast.Block? {
  let items : Array[String] = []
  let mut current_item = ""
  let mut ordered : Bool? = None
  let mut base_indent : Int? = None

  for raw_line in chunk.split("\n").to_array() {
    let line = raw_line.to_string()
    if line.trim() == "" {
      continue
    }
    match parse_text_list_marker(line) {
      Some((line_ordered, indent, content)) => {
        match ordered {
          Some(existing) if existing != line_ordered => return None
          None => ordered = Some(line_ordered)
          _ => ()
        }
        match base_indent {
          None => {
            base_indent = Some(indent)
            current_item = content
          }
          Some(base) =>
            if indent <= base {
              if current_item != "" {
                items.push(current_item)
              }
              current_item = content
            } else {
              current_item = append_text_list_line(
                current_item,
                line.trim_end().to_string(),
              )
            }
        }
      }
      None =>
        if ordered == None {
          return None
        } else {
          current_item = append_text_list_line(
            current_item,
            normalize_text_paragraph(line),
          )
        }
    }
  }

  match ordered {
    Some(is_ordered) => {
      if current_item != "" {
        items.push(current_item)
      }
      if !is_ordered {
        match base_indent {
          Some(indent) if indent > 0 && items.length() > 1 => {
            let mut nested = items[0]
            let mut index = 1
            while index < items.length() {
              nested = nested + "\n   - " + items[index]
              index = index + 1
            }
            return Some(@ast.List([@ast.text_inlines(nested)], false))
          }
          _ => ()
        }
      }
      if items.length() == 0 {
        None
      } else {
        Some(list_block_from_strings(items, is_ordered))
      }
    }
    None => None
  }
}

///|
fn list_block_from_strings(items : Array[String], ordered : Bool) -> @ast.Block {
  let inline_items : Array[Array[@ast.Inline]] = []
  for item in items {
    inline_items.push(@ast.text_inlines(item))
  }
  @ast.List(inline_items, ordered)
}

///|
fn append_text_list_line(current : String, next_line : String) -> String {
  if current == "" {
    next_line
  } else {
    current + "\n" + next_line
  }
}

///|
fn parse_text_list_marker(line : String) -> (Bool, Int, String)? {
  let indent = line.length() - line.trim_start().length()
  let trimmed = line.trim_start().to_string()
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("+ ") {
    return Some(
      (
        false,
        indent,
        normalize_text_paragraph(trimmed[2:].to_string(), preserve_lines=false),
      ),
    )
  }
  let mut idx = 0
  while idx < trimmed.length() && trimmed[idx] >= '0' && trimmed[idx] <= '9' {
    idx = idx + 1
  }
  if idx > 0 &&
    idx + 1 < trimmed.length() &&
    (trimmed[idx] == '.' || trimmed[idx] == ')') &&
    trimmed[idx + 1] == ' ' {
    return Some(
      (
        true,
        indent,
        normalize_text_paragraph(
          trimmed[idx + 2:].to_string(),
          preserve_lines=false,
        ),
      ),
    )
  }
  None
}

///|
fn should_preserve_text_lines(chunk : String) -> Bool {
  let lines = chunk.split("\n").to_array()
  lines.length() >= 6
}

///|
fn normalize_text_paragraph(
  chunk : String,
  preserve_lines? : Bool = false,
) -> String {
  if preserve_lines {
    let lines : Array[String] = []
    for line in chunk.split("\n").to_array() {
      let trimmed = line.trim().to_string()
      if trimmed != "" {
        lines.push(trimmed)
      }
    }
    return lines.join("\n")
  }
  let mut result = ""
  let mut previous_was_space = true
  for ch in chunk.trim() {
    let is_space = ch == '\n' || ch == '\t' || ch == ' '
    if is_space {
      if !previous_was_space {
        result = result + " "
      }
      previous_was_space = true
    } else {
      result = result + ch.to_string()
      previous_was_space = false
    }
  }
  result
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
fn text_warning_diagnostics(
  file_path : String,
  warnings : Array[String],
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    if warning == "Text input produced empty Markdown output." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Render(Some("markdown"))),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Check whether the text file only contains whitespace or an empty payload.",
            ),
          ),
        ),
      )
    }
  }
  diagnostics
}

///|
