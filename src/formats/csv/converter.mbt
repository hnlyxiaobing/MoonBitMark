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
  let parsed = parse_csv(content)
  let rows = parsed.rows
  let title = @core.file_stem(file_path)
  let metadata = Map::new()
  metadata["format"] = "csv"
  metadata["delimiter"] = delimiter_label(parsed.delimiter)
  metadata["row_count"] = csv_row_count(rows).to_string()
  metadata["column_count"] = csv_column_count(rows).to_string()
  let doc = csv_rows_to_document(rows, title, metadata)
  let markdown = @ast.render_markdown(doc)
  let warnings : Array[String] = []
  for warning in parsed.warnings {
    warnings.push(warning)
  }
  if markdown == "" {
    warnings.push("CSV input produced empty Markdown output.")
  }
  let diagnostics = csv_warning_diagnostics(file_path, warnings, markdown)
  @core.ConvertResult::markdown_only(markdown, "csv")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_stats(Some(@core.stats_for_markdown(markdown)))
  .with_document(Some(doc))
}

///|
priv struct CsvParseResult {
  rows : Array[Array[String]]
  delimiter : Char
  warnings : Array[String]
}

///|
fn csv_rows_to_document(
  rows : Array[Array[String]],
  title : String?,
  metadata : Map[String, String],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  match rows {
    [header, .. tail] => {
      let header_cells : Array[Array[@ast.Inline]] = []
      for cell in header {
        header_cells.push(@ast.text_inlines(cell))
      }
      let body_rows : Array[Array[Array[@ast.Inline]]] = []
      for row in tail {
        let body_row : Array[Array[@ast.Inline]] = []
        for cell in row {
          body_row.push(@ast.text_inlines(cell))
        }
        body_rows.push(body_row)
      }
      blocks.push(@ast.Table(header_cells, body_rows))
    }
    [] => ()
  }
  @ast.Document::{ title, metadata, blocks }
}

///|
fn parse_csv(csv : String) -> CsvParseResult {
  let rows : Array[Array[String]] = []
  let warnings : Array[String] = []
  let delimiter = detect_csv_delimiter(csv)
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
    } else if ch == delimiter {
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
  if in_quotes {
    warnings.push(
      "CSV ended inside a quoted cell; emitted the final row in best-effort mode.",
    )
  }
  if csv_has_ragged_rows(rows) {
    warnings.push(
      "CSV contained ragged rows; padded missing cells to preserve table shape.",
    )
  }
  CsvParseResult::{ rows, delimiter, warnings }
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
fn detect_csv_delimiter(csv : String) -> Char {
  let candidates : Array[Char] = [',', ';', '\t', '|']
  let lines = sample_csv_lines(csv)
  let mut best = ','
  let mut best_score = -1
  for candidate in candidates {
    let score = delimiter_score(lines, candidate)
    if score > best_score {
      best = candidate
      best_score = score
    }
  }
  best
}

///|
fn sample_csv_lines(csv : String) -> Array[String] {
  let lines : Array[String] = []
  let normalized = csv.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
  for line in normalized.split("\n").to_array() {
    let trimmed = line.trim().to_string()
    if trimmed != "" {
      lines.push(trimmed)
    }
    if lines.length() >= 8 {
      break
    }
  }
  lines
}

///|
fn delimiter_score(lines : Array[String], delimiter : Char) -> Int {
  let mut score = 0
  for line in lines {
    let mut count = 0
    let mut in_quotes = false
    for ch in line {
      if ch == '"' {
        in_quotes = !in_quotes
      } else if !in_quotes && ch == delimiter {
        count = count + 1
      }
    }
    if count > 0 {
      score = score + count + 2
    }
  }
  score
}

///|
fn csv_has_ragged_rows(rows : Array[Array[String]]) -> Bool {
  if rows.length() <= 1 {
    return false
  }
  let expected = csv_column_count(rows)
  for row in rows {
    if row.length() != expected {
      return true
    }
  }
  false
}

///|
fn delimiter_label(delimiter : Char) -> String {
  if delimiter == '\t' {
    "tab"
  } else {
    delimiter.to_string()
  }
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
  warnings : Array[String],
  markdown : String,
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    if warning ==
      "CSV ended inside a quoted cell; emitted the final row in best-effort mode." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("csv"))),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Review the source CSV for unmatched quotes or truncated rows.",
            ),
          ),
        ),
      )
    } else if warning ==
      "CSV contained ragged rows; padded missing cells to preserve table shape." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Normalize(Some("table-shape"))),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Review rows with missing trailing cells if exact spreadsheet shape matters.",
            ),
          ),
        ),
      )
    }
  }
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
