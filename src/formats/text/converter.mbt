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
  let content = normalize_text_content(
    @core.strip_utf8_bom(@core.read_utf8_file(file_path)),
  )
  let title = @core.file_stem(file_path)
  let metadata = Map::new()
  metadata["format"] = "plain_text"
  metadata["line_count"] = count_lines(content).to_string()
  let doc = text_to_document(content, title, metadata)
  let markdown = @ast.render_markdown(doc)
  let warnings : Array[String] = []
  if markdown == "" {
    warnings.push("Text input produced empty Markdown output.")
  }
  let diagnostics = text_warning_diagnostics(file_path, warnings)
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
  content.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}

///|
fn text_to_document(
  content : String,
  title : String?,
  metadata : Map[String, String],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  for chunk in content.split("\n\n").to_array() {
    let trimmed = normalize_text_paragraph(chunk.to_string())
    if trimmed != "" {
      blocks.push(@ast.text_paragraph(trimmed))
    }
  }
  @ast.Document::{ title, metadata, blocks }
}

///|
fn normalize_text_paragraph(chunk : String) -> String {
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
