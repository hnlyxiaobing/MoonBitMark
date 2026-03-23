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
  let content = @core.strip_utf8_bom(@core.read_utf8_file(file_path))
  let rows = parse_csv_rows(content)
  let title = @core.file_stem(file_path)
  let metadata = Map::new()
  metadata["format"] = "csv"
  metadata["row_count"] = csv_row_count(rows).to_string()
  metadata["column_count"] = csv_column_count(rows).to_string()
  let doc = csv_rows_to_document(rows, title, metadata)
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
fn csv_rows_to_document(
  rows : Array[Array[String]],
  title : String?,
  metadata : Map[String, String],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  match rows {
    [header, .. tail] => blocks.push(@ast.Table(header, tail.to_array()))
    [] => ()
  }
  @ast.Document::{ title, metadata, blocks }
}

///|
fn parse_csv_rows(csv : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  let chars = csv_chars(csv)
  let mut current_row : Array[String] = []
  let mut current_cell = ""
  let mut in_quotes = false
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if in_quotes {
      if ch == '"' {
        if index + 1 < chars.length() && chars[index + 1] == '"' {
          current_cell = current_cell + "\""
          index = index + 2
        } else {
          in_quotes = false
          index = index + 1
        }
      } else {
        current_cell = current_cell + ch.to_string()
        index = index + 1
      }
    } else if ch == '"' {
      in_quotes = true
      index = index + 1
    } else if ch == ',' {
      current_row.push(current_cell)
      current_cell = ""
      index = index + 1
    } else if ch == '\n' {
      current_row.push(current_cell)
      push_csv_row(rows, current_row)
      current_row = []
      current_cell = ""
      index = index + 1
    } else {
      current_cell = current_cell + ch.to_string()
      index = index + 1
    }
  }
  if current_row.length() > 0 || current_cell != "" {
    current_row.push(current_cell)
    push_csv_row(rows, current_row)
  }
  rows
}

///|
fn csv_chars(csv : String) -> Array[Char] {
  let original : Array[Char] = []
  for ch in csv {
    original.push(ch)
  }
  let chars : Array[Char] = []
  let mut index = 0
  while index < original.length() {
    let ch = original[index]
    if ch == '\r' {
      chars.push('\n')
      if index + 1 < original.length() && original[index + 1] == '\n' {
        index = index + 2
      } else {
        index = index + 1
      }
    } else {
      chars.push(ch)
      index = index + 1
    }
  }
  chars
}

///|
fn push_csv_row(rows : Array[Array[String]], row : Array[String]) -> Unit {
  if row.length() == 1 && row[0].trim() == "" {
    return
  }
  rows.push(row)
}

///|
fn csv_row_count(rows : Array[Array[String]]) -> Int {
  rows.length()
}

///|
fn csv_column_count(rows : Array[Array[String]]) -> Int {
  let mut max_columns = 0
  for row in rows {
    if row.length() > max_columns {
      max_columns = row.length()
    }
  }
  max_columns
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
