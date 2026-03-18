// PDF Converter - Converts PDF files to Markdown (Stage 4: Advanced Post-processing)

///|
/// Converter for PDF files
pub(all) struct PdfConverter {
  dummy : Int
}

///|
/// Create a new PDF converter
pub fn PdfConverter::new() -> PdfConverter {
  PdfConverter::{ dummy: 0 }
}

///|
/// Accepts function - checks if file is PDF
pub fn PdfConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => mt.has_prefix("application/pdf")
    None =>
      match info.extension {
        Some(".pdf") => true
        _ => false
      }
  }
}

///|
/// Normalize whitespace in PDF text
/// - Replace multiple consecutive newlines with double newline (paragraph break)
/// - Trim leading/trailing whitespace from each line
/// - Remove trailing whitespace from the entire text
fn normalize_whitespace(text : String) -> String {
  let lines = text.split("\n")
  let lines_array = lines.to_array()
  let result_lines = Array::new()
  let mut prev_empty = false

  for line in lines_array {
    let trimmed = line.trim()
    let is_empty = trimmed.length() == 0

    if is_empty {
      // Only add one empty line between paragraphs
      if !prev_empty && result_lines.length() > 0 {
        result_lines.push("")
      }
      prev_empty = true
    } else {
      result_lines.push(trimmed.to_string())
      prev_empty = false
    }
  }

  // Join lines and trim final result
  let joined = result_lines.join("\n")
  joined.trim().to_string()
}

///|
/// Check if a string is a MasterFormat partial numbering (e.g., ".1", ".2", ".10")
fn is_partial_numbering(s : String) -> Bool {
  if !s.has_prefix(".") || s.length() < 2 {
    return false
  }
  // Check if rest contains only digits using simple iteration
  let mut i = 1
  while i < s.length() {
    let c = s.at(i)
    if c < 48 || c > 57 { // ASCII '0' = 48, '9' = 57
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Merge MasterFormat-style partial numbering lines
/// Merges lines like ".1" with the following line
/// Example: ".1\nThe intent..." → ".1 The intent..."
fn merge_partial_numbering(text : String) -> String {
  let lines = text.split("\n")
  let lines_array = lines.to_array()
  let result_lines = Array::new()
  let mut i = 0

  while i < lines_array.length() {
    let line = lines_array[i]
    let stripped = line.trim().to_string()

    if is_partial_numbering(stripped) && i + 1 < lines_array.length() {
      // Find next non-empty line
      let mut j = i + 1
      while j < lines_array.length() && lines_array[j].trim().length() == 0 {
        j = j + 1
      }

      if j < lines_array.length() {
        // Merge with next line
        let next_line = lines_array[j].trim().to_string()
        result_lines.push(stripped + " " + next_line)
        i = j + 1
        continue
      }
    }

    result_lines.push(stripped)
    i = i + 1
  }

  result_lines.join("\n")
}

///|
/// Convert function - extracts text from PDF and returns as Markdown
/// Stage 4: With advanced post-processing (whitespace, MasterFormat merging)
pub async fn PdfConverter::convert(file_path : String) -> @core.ConvertResult {
  // Read PDF file
  let pdf = @pdfread.pdf_of_file(None, None, file_path)

  // Check if PDF is encrypted
  if @pdfcrypt.is_encrypted(pdf) {
    fail("PDF file is encrypted and cannot be processed.")
  }

  // Extract text using mbtpdf with page break separator
  let text = @pdftextlib.extract_text(pdf, page_break="\n\n---\n\n")

  // Post-processing pipeline
  let normalized = normalize_whitespace(text)
  let merged = merge_partial_numbering(normalized)
  let metadata = Map::new()
  metadata["format"] = "pdf"
  let warnings : Array[String] = []
  if normalized != merged {
    warnings.push("Merged partial numbering lines during PDF post-processing.")
  }
  let diagnostics = pdf_warning_diagnostics(file_path, normalized, merged)
  let page_breaks = count_occurrences(merged, "\n\n---\n\n")
  if page_breaks > 0 {
    metadata["page_break_count"] = page_breaks.to_string()
  }
  let title = file_stem(file_path)
  let doc = pdf_to_document(merged, title, metadata)
  let markdown = @ast.render_markdown(doc)

  @core.ConvertResult::markdown_only(markdown, "pdf")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
}

///|
fn pdf_to_document(
  text : String,
  title : String?,
  metadata : Map[String, String],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  let pages = text.split("\n\n---\n\n").to_array()
  let mut index = 0
  while index < pages.length() {
    let page = pages[index].trim().to_string()
    if page != "" {
      for paragraph in page.split("\n\n").to_array() {
        let trimmed = paragraph.trim().to_string()
        if trimmed != "" {
          blocks.push(@ast.text_paragraph(trimmed))
        }
      }
    }
    if index + 1 < pages.length() {
      blocks.push(@ast.HorizontalRule)
    }
    index = index + 1
  }
  @ast.Document::{ title, metadata, blocks }
}

///|
fn count_occurrences(text : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start < text.length() {
    let remaining = text[start:].to_string()
    match remaining.find(needle[:]) {
      Some(index) => {
        count = count + 1
        start = start + index + needle.length()
      }
      None => break
    }
  }
  count
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

///|
fn pdf_warning_diagnostics(
  file_path : String,
  normalized : String,
  merged : String,
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  if normalized != merged {
    diagnostics.push(
      @core.warning_diagnostic(
        "Merged partial numbering lines during PDF post-processing.",
        Some(@core.Postprocess(Some("numbering-merge"))),
        Some(@core.File(file_path)),
        Some(
          @core.Custom(
            "Review merged numbering if the PDF relies on strict line boundaries.",
          ),
        ),
      ),
    )
  }
  diagnostics
}
