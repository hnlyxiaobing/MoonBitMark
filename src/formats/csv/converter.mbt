// CSV Converter - Converts CSV files to Markdown tables

///|
/// Converter for CSV files
pub(all) struct CsvConverter {
  dummy : Int
}

///|
/// Create a new CSV converter
pub fn CsvConverter::new() -> CsvConverter {
  CsvConverter::{ dummy: 0 }
}

///|
/// Accepts function - checks if file is CSV
pub fn CsvConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => mt == "text/csv"
    None =>
      match info.extension {
        Some(".csv") => true
        _ => false
      }
  }
}

///|
/// Convert function - converts CSV to Markdown table
pub async fn CsvConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  ignore(ctx)
  let file = @fs.open(file_path, mode=ReadOnly)
  let mut content = ""
  let mut is_first = true
  while file.read_until("\n") is Some(line) {
    if is_first {
      // Trim BOM and leading whitespace
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
  metadata["format"] = "csv"
  metadata["row_count"] = csv_row_count(content).to_string()
  metadata["column_count"] = csv_column_count(content).to_string()
  let doc = csv_to_document(content, title, metadata)
  let markdown = @ast.render_markdown(doc)
  let warnings : Array[String] = []
  if markdown == "" {
    warnings.push("CSV input produced empty Markdown output.")
  }
  let diagnostics = csv_warning_diagnostics(file_path, markdown)
  @core.ConvertResult::markdown_only(markdown, "csv")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
  .with_document(Some(doc))
}

///|
fn csv_to_document(
  csv : String,
  title : String?,
  metadata : Map[String, String],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  let rows = parse_csv_rows(csv)
  match rows {
    [header, .. tail] => blocks.push(@ast.Table(header, tail.to_array()))
    [] => ()
  }
  @ast.Document::{ title, metadata, blocks }
}

///|
fn parse_csv_rows(csv : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  for line in csv.split("\n").to_array() {
    if line.trim() == "" {
      continue
    }
    rows.push(line.split(",").to_array().map(cell => cell.to_string()))
  }
  rows
}

///|
fn csv_row_count(csv : String) -> Int {
  csv.split("\n").to_array().filter(line => line.trim() != "").length()
}

///|
fn csv_column_count(csv : String) -> Int {
  let lines = csv.split("\n").to_array()
  for line in lines {
    if line.trim() != "" {
      return line.split(",").to_array().length()
    }
  }
  0
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
fn csv_warning_diagnostics(
  file_path : String,
  markdown : String,
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  if markdown == "" {
    diagnostics.push(
      @core.warning_diagnostic(
        "CSV input produced empty Markdown output.",
        Some(@core.Render(Some("markdown"))),
        Some(@core.File(file_path)),
        Some(
          @core.Custom(
            "Check whether the CSV contains at least one non-empty row.",
          ),
        ),
      ),
    )
  }
  diagnostics
}
