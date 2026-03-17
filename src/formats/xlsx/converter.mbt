// XLSX Converter - Pure MoonBit Implementation
// Converts Excel files (.xlsx) to Markdown tables

///|
/// Converter for XLSX files
pub(all) struct XlsxConverter {
  dummy : Int
}

///|
/// Create a new XLSX converter
pub fn XlsxConverter::new() -> XlsxConverter {
  XlsxConverter::{ dummy: 0 }
}

///|
/// Check if this converter accepts the given file
pub fn XlsxConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => ext.to_lower() == ".xlsx"
    None => false
  }
}

///|
/// Convert an XLSX file to Markdown
pub async fn XlsxConverter::convert(file_path : String) -> @core.ConvertResult {
  // Read XLSX file content
  let file = @fs.open(file_path, mode=ReadOnly)
  let all_bytes : Array[Byte] = Array::new()

  // Read file content
  while true {
    let buffer : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let bytes_read = file.read(buffer)
    if bytes_read == 0 {
      break
    }
    // Add read data to array
    let mut i = 0
    while i < bytes_read {
      all_bytes.push(buffer[i])
      i = i + 1
    }
  }
  file.close()

  // Convert Array[Byte] to Bytes
  let bytes = bytes_from_array(all_bytes)

  // Use pure MoonBit libzip to open ZIP
  match @libzip.ZipArchive::open(bytes) {
    Some(archive) => {
      // Parse workbook.xml to get sheet names
      let sheets = parse_workbook_sheets(archive)
      // Parse shared strings
      let (shared_strings, helper_warnings_a) = parse_shared_strings(archive)
      // Parse each sheet and generate markdown
      let (markdown, helper_warnings_b) = generate_markdown(
        archive, sheets, shared_strings,
      )
      let final_markdown = markdown.trim().to_string()
      let metadata = Map::new()
      metadata["format"] = "xlsx"
      metadata["sheet_count"] = sheets.length().to_string()
      metadata["shared_string_count"] = shared_strings.length().to_string()
      let warnings : Array[String] = []
      for warning in helper_warnings_a {
        warnings.push(warning)
      }
      for warning in helper_warnings_b {
        warnings.push(warning)
      }
      if sheets.length() == 0 {
        warnings.push("No sheets discovered in xl/workbook.xml.")
      }
      if final_markdown == "" {
        warnings.push("XLSX conversion produced empty Markdown output.")
      }
      let diagnostics = xlsx_warning_diagnostics(file_path, warnings)
      @core.ConvertResult::markdown_only(final_markdown, "xlsx")
      .with_title(file_stem(file_path))
      .with_metadata(metadata)
      .with_warnings(warnings)
      .with_diagnostics(diagnostics)
      .with_stats(Some(@core.stats_for_markdown(final_markdown)))
    }
    None =>
      fail(
        render_xlsx_failure(
          @core.ZipError("Failed to open XLSX file as ZIP archive", None),
          Some(@core.Load(Some("archive"))),
          Some(@core.File(file_path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
  }
}

///|
/// Convert Array[Byte] to Bytes
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}

///|
/// Parse workbook.xml to get sheet names
fn parse_workbook_sheets(
  archive : @libzip.ZipArchive,
) -> Array[(String, String)] raise {
  match @libzip.read_file_entry_decompressed(archive, "xl/workbook.xml") {
    Some(xml_bytes) => {
      let xml_string = @utf8.decode(xml_bytes) catch {
        _ =>
          fail(
            render_xlsx_failure(
              @core.InputError(
                "xl/workbook.xml contains invalid UTF-8 sequence",
                Some("xl/workbook.xml"),
              ),
              Some(@core.Load(Some("xl/workbook.xml"))),
              Some(@core.ArchiveEntry("xl/workbook.xml")),
              Some(
                @core.Custom(
                  "Verify the XML encoding of xl/workbook.xml before converting.",
                ),
              ),
            ),
          )
      }
      match @xml.parse_xml(xml_string) {
        Ok(events) => extract_sheet_info(events)
        Err(_) =>
          fail(
            render_xlsx_failure(
              @core.XmlParseError("Failed to parse xl/workbook.xml", None),
              Some(@core.Parse(Some("xl/workbook.xml"))),
              Some(@core.ArchiveEntry("xl/workbook.xml")),
              Some(
                @core.Custom(
                  "Inspect malformed workbook XML inside the XLSX archive.",
                ),
              ),
            ),
          )
      }
    }
    None =>
      fail(
        render_xlsx_failure(
          @core.ZipError(
            "Failed to read xl/workbook.xml",
            Some("xl/workbook.xml"),
          ),
          Some(@core.Load(Some("xl/workbook.xml"))),
          Some(@core.ArchiveEntry("xl/workbook.xml")),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
  }
}

///|
/// Extract sheet name and r:id from workbook.xml events
fn extract_sheet_info(
  events : Array[@xml.ParseEvent],
) -> Array[(String, String)] {
  let sheets : Array[(String, String)] = []
  let mut in_sheet = false
  let mut current_name = ""
  let mut current_rid = ""

  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let name = strip_namespace(evt.name)
        if name == "sheet" {
          in_sheet = true
          current_name = ""
          current_rid = ""
          // Extract attributes
          match evt.attributes.get("name") {
            Some(n) => current_name = n
            None => ()
          }
          match evt.attributes.get("r:id") {
            Some(rid) => current_rid = rid
            None => ()
          }
        }
      }
      @xml.ElementEnd(evt) => {
        let name = strip_namespace(evt.name)
        if name == "sheet" && in_sheet {
          in_sheet = false
          if current_name.length() > 0 && current_rid.length() > 0 {
            sheets.push((current_name, current_rid))
          }
        }
      }
      _ => ()
    }
  }

  sheets
}

///|
/// Parse sharedStrings.xml to get shared string array
fn parse_shared_strings(
  archive : @libzip.ZipArchive,
) -> (Array[String], Array[String]) {
  match @libzip.read_file_entry_decompressed(archive, "xl/sharedStrings.xml") {
    Some(xml_bytes) => {
      let xml_string = @utf8.decode(xml_bytes) catch {
        _ => return ([], ["Failed to decode xl/sharedStrings.xml as UTF-8."])
      }
      match @xml.parse_xml(xml_string) {
        Ok(events) => (extract_shared_strings(events), [])
        Err(_) => ([], ["Failed to parse xl/sharedStrings.xml."])
      }
    }
    None => ([], [])
  }
}

///|
/// Extract shared strings from XML events
fn extract_shared_strings(events : Array[@xml.ParseEvent]) -> Array[String] {
  let strings : Array[String] = []
  let mut in_si = false
  let mut in_t = false
  let mut current_string = ""

  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let name = strip_namespace(evt.name)
        if name == "si" {
          in_si = true
          current_string = ""
        } else if name == "t" && in_si {
          in_t = true
        }
      }
      @xml.ElementEnd(evt) => {
        let name = strip_namespace(evt.name)
        if name == "si" {
          in_si = false
          strings.push(current_string)
        } else if name == "t" {
          in_t = false
        }
      }
      @xml.TextContent(evt) =>
        if in_t {
          current_string = current_string + evt.content
        }
    }
  }

  strings
}

///|
/// Generate Markdown from all sheets
fn generate_markdown(
  archive : @libzip.ZipArchive,
  sheets : Array[(String, String)],
  shared_strings : Array[String],
) -> (String, Array[String]) {
  // First, get sheet path mapping from workbook.xml.rels
  let (sheet_paths, warnings) = parse_sheet_paths(archive)

  let markdown_parts : Array[String] = []

  // Iterate over sheets array
  let mut idx = 0
  while idx < sheets.length() {
    let (sheet_name, rid) = sheets[idx]
    // Find sheet path by r:id
    let sheet_path = find_sheet_path(rid, sheet_paths)
    match sheet_path {
      Some(path) => {
        let (sheet_md, sheet_warnings) = parse_worksheet_to_markdown(
          archive, path, sheet_name, shared_strings,
        )
        for warning in sheet_warnings {
          warnings.push(warning)
        }
        let header = "## " + sheet_name + "\n\n"
        markdown_parts.push(header + sheet_md)
      }
      None =>
        warnings.push(
          "Missing worksheet relationship for sheet '\{sheet_name}' (r:id=\{rid}).",
        )
    }
    idx = idx + 1
  }

  (markdown_parts.join("\n\n"), warnings)
}

///|
/// Parse workbook.xml.rels to get r:id -> sheet path mapping
fn parse_sheet_paths(
  archive : @libzip.ZipArchive,
) -> (Map[String, String], Array[String]) {
  match
    @libzip.read_file_entry_decompressed(archive, "xl/_rels/workbook.xml.rels") {
    Some(xml_bytes) => {
      let xml_string = @utf8.decode(xml_bytes) catch {
        _ =>
          return (
            Map::new(),
            ["Failed to decode xl/_rels/workbook.xml.rels as UTF-8."],
          )
      }
      match @xml.parse_xml(xml_string) {
        Ok(events) => (extract_sheet_paths(events), [])
        Err(_) => (Map::new(), ["Failed to parse xl/_rels/workbook.xml.rels."])
      }
    }
    None => (Map::new(), ["Failed to read xl/_rels/workbook.xml.rels."])
  }
}

///|
/// Extract r:id -> Target path mapping from rels XML
fn extract_sheet_paths(events : Array[@xml.ParseEvent]) -> Map[String, String] {
  let paths : Map[String, String] = Map::new()

  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let name = strip_namespace(evt.name)
        if name == "Relationship" {
          // Extract attributes
          match evt.attributes.get("Id") {
            Some(id) =>
              match evt.attributes.get("Target") {
                Some(target) => paths[id] = target
                None => ()
              }
            None => ()
          }
        }
      }
      _ => ()
    }
  }

  paths
}

///|
/// Find sheet path by r:id
fn find_sheet_path(rid : String, paths : Map[String, String]) -> String? {
  paths.get(rid)
}

///|
/// Parse a single worksheet and convert to Markdown
fn parse_worksheet_to_markdown(
  archive : @libzip.ZipArchive,
  sheet_path : String,
  sheet_name : String,
  shared_strings : Array[String],
) -> (String, Array[String]) {
  // Ensure path starts with xl/
  let full_path = if sheet_path.has_prefix("xl/") {
    sheet_path
  } else {
    "xl/" + sheet_path
  }

  match @libzip.read_file_entry_decompressed(archive, full_path) {
    Some(xml_bytes) => {
      let xml_string = @utf8.decode(xml_bytes) catch {
        _ =>
          return (
            "",
            [
              "Failed to decode worksheet XML as UTF-8: \{sheet_name} (\{full_path}).",
            ],
          )
      }
      match @xml.parse_xml(xml_string) {
        Ok(events) => {
          let sheet_data = extract_sheet_data(events, shared_strings)
          (sheet_data_to_markdown(sheet_data), [])
        }
        Err(_) =>
          ("", ["Failed to parse worksheet XML: \{sheet_name} (\{full_path})."])
      }
    }
    None =>
      ("", ["Failed to read worksheet XML: \{sheet_name} (\{full_path})."])
  }
}

///|
/// Sheet data structure
priv struct SheetData {
  rows : Array[Array[String]]
  mut max_cols : Int
}

///|
/// Extract sheet data from XML events
fn extract_sheet_data(
  events : Array[@xml.ParseEvent],
  shared_strings : Array[String],
) -> SheetData {
  let data = SheetData::{ rows: [], max_cols: 0 }

  let mut in_cell = false
  let mut in_value = false
  let mut in_inline_str = false
  let mut in_inline_t = false
  let mut current_row : Array[String] = []
  let mut current_cell_ref = ""
  let mut current_cell_type = ""
  let mut current_content = ""

  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let name = strip_namespace(evt.name)
        match name {
          "row" => current_row = []
          "c" => {
            in_cell = true
            current_cell_ref = match evt.attributes.get("r") {
              Some(r) => r
              None => ""
            }
            current_cell_type = match evt.attributes.get("t") {
              Some(t) => t
              None => ""
            }
            current_content = ""
          }
          "v" => if in_cell { in_value = true }
          "is" => if in_cell { in_inline_str = true }
          "t" => if in_inline_str { in_inline_t = true }
          _ => ()
        }
      }
      @xml.ElementEnd(evt) => {
        let name = strip_namespace(evt.name)
        match name {
          "row" => {
            // Add row to data
            data.rows.push(current_row)
            current_row = []
          }
          "c" => {
            in_cell = false
            // Resolve cell value
            let cell_value = get_cell_value(
              current_cell_type, current_content, shared_strings,
            )
            // Parse cell reference to get column index
            let col_idx = cell_ref_to_col_index(current_cell_ref)
            // Extend row if needed
            while current_row.length() <= col_idx {
              current_row.push("")
            }
            if col_idx < current_row.length() {
              current_row[col_idx] = cell_value
            }
            if col_idx >= data.max_cols {
              data.max_cols = col_idx + 1
            }
          }
          "v" => in_value = false
          "is" => in_inline_str = false
          "t" => in_inline_t = false
          _ => ()
        }
      }
      @xml.TextContent(evt) =>
        if in_value {
          current_content = current_content + evt.content
        } else if in_inline_t {
          current_content = current_content + evt.content
        }
    }
  }

  data
}

///|
/// Get cell value based on type
fn get_cell_value(
  cell_type : String,
  raw_value : String,
  shared_strings : Array[String],
) -> String {
  if cell_type == "s" {
    // Shared string - lookup in shared strings array
    match parse_int(raw_value) {
      Some(idx) =>
        if idx >= 0 && idx < shared_strings.length() {
          shared_strings[idx]
        } else {
          ""
        }
      None => ""
    }
  } else if cell_type == "b" {
    // Boolean
    if raw_value == "1" {
      "TRUE"
    } else {
      "FALSE"
    }
  } else if cell_type == "e" {
    // Error
    raw_value
  } else if cell_type == "inlineStr" {
    // Inline string
    raw_value
  } else {
    // Number or other
    raw_value
  }
}

///|
/// Parse integer from string
fn parse_int(s : String) -> Int? {
  let mut result = 0
  let mut i = 0
  while i < s.length() {
    let ch = s[i]
    if ch >= '0' && ch <= '9' {
      result = result * 10 + (ch.to_int() - '0'.to_int())
      i = i + 1
    } else {
      return None
    }
  }
  Some(result)
}

///|
/// Convert cell reference (e.g., "A1", "C10") to column index
fn cell_ref_to_col_index(cell_ref : String) -> Int {
  let mut col_idx = 0
  let chars = cell_ref.iter()
  for ch in chars {
    if ch >= 'A' && ch <= 'Z' {
      col_idx = col_idx * 26 + (ch.to_int() - 'A'.to_int() + 1)
    } else if ch >= 'a' && ch <= 'z' {
      col_idx = col_idx * 26 + (ch.to_int() - 'a'.to_int() + 1)
    } else {
      // Reached the row number part
      break
    }
  }
  col_idx - 1 // Convert to 0-based
}

///|
/// Convert sheet data to Markdown table
fn sheet_data_to_markdown(data : SheetData) -> String {
  if data.rows.is_empty() {
    return "*(Empty sheet)*"
  }

  let mut markdown = ""
  let col_count = data.max_cols

  // Generate rows
  let mut row_idx = 0
  for row in data.rows {
    // Extend row to match max columns
    let extended_row = row
    while extended_row.length() < col_count {
      extended_row.push("")
    }

    // Format row
    let row_str = "| " + extended_row.join(" | ") + " |"
    markdown = markdown + row_str + "\n"

    // Add separator after first row (header)
    if row_idx == 0 && data.rows.length() > 1 {
      let separator = "| " + Array::make(col_count, "---").join(" | ") + " |"
      markdown = markdown + separator + "\n"
    }

    row_idx = row_idx + 1
  }

  markdown.trim().to_string()
}

///|
/// Strip XML namespace prefix
fn strip_namespace(name : String) -> String {
  match name.find(":") {
    Some(pos) => {
      let mut result = ""
      let mut i = pos + 1
      while i < name.length() {
        let ch = name[i]
        result = result + ch.to_string()
        i = i + 1
      }
      result
    }
    None => name
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

///|
fn xlsx_warning_diagnostics(
  file_path : String,
  warnings : Array[String],
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    if warning == "No sheets discovered in xl/workbook.xml." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("xl/workbook.xml"))),
          Some(@core.ArchiveEntry("xl/workbook.xml")),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning == "XLSX conversion produced empty Markdown output." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Render(Some("markdown"))),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Check whether the workbook contains visible sheet data.",
            ),
          ),
        ),
      )
    } else if warning == "Failed to decode xl/sharedStrings.xml as UTF-8." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("xl/sharedStrings.xml"))),
          Some(@core.ArchiveEntry("xl/sharedStrings.xml")),
          Some(
            @core.Custom(
              "Verify the XML encoding of xl/sharedStrings.xml before converting.",
            ),
          ),
        ),
      )
    } else if warning == "Failed to parse xl/sharedStrings.xml." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("xl/sharedStrings.xml"))),
          Some(@core.ArchiveEntry("xl/sharedStrings.xml")),
          Some(
            @core.Custom(
              "Inspect malformed shared strings XML inside the XLSX archive.",
            ),
          ),
        ),
      )
    } else if warning == "Failed to read xl/_rels/workbook.xml.rels." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("xl/_rels/workbook.xml.rels"))),
          Some(@core.ArchiveEntry("xl/_rels/workbook.xml.rels")),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning == "Failed to decode xl/_rels/workbook.xml.rels as UTF-8." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("xl/_rels/workbook.xml.rels"))),
          Some(@core.ArchiveEntry("xl/_rels/workbook.xml.rels")),
          Some(
            @core.Custom(
              "Verify the XML encoding of xl/_rels/workbook.xml.rels before converting.",
            ),
          ),
        ),
      )
    } else if warning == "Failed to parse xl/_rels/workbook.xml.rels." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("xl/_rels/workbook.xml.rels"))),
          Some(@core.ArchiveEntry("xl/_rels/workbook.xml.rels")),
          Some(
            @core.Custom(
              "Inspect malformed workbook relationship XML inside the XLSX archive.",
            ),
          ),
        ),
      )
    } else if warning.has_prefix("Missing worksheet relationship for sheet '") {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("xl/_rels/workbook.xml.rels"))),
          Some(@core.ArchiveEntry("xl/_rels/workbook.xml.rels")),
          Some(
            @core.Custom(
              "Verify workbook relationship entries for the missing worksheet mapping.",
            ),
          ),
        ),
      )
    } else if warning.has_prefix("Failed to read worksheet XML: ") {
      let path = extract_warning_path(warning)
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("worksheet"))),
          Some(@core.ArchiveEntry(path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning.has_prefix("Failed to decode worksheet XML as UTF-8: ") {
      let path = extract_warning_path(warning)
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("worksheet"))),
          Some(@core.ArchiveEntry(path)),
          Some(
            @core.Custom(
              "Verify worksheet XML encoding before converting the sheet.",
            ),
          ),
        ),
      )
    } else if warning.has_prefix("Failed to parse worksheet XML: ") {
      let path = extract_warning_path(warning)
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("worksheet"))),
          Some(@core.ArchiveEntry(path)),
          Some(
            @core.Custom(
              "Inspect malformed worksheet XML inside the XLSX archive.",
            ),
          ),
        ),
      )
    }
  }
  diagnostics
}

///|
fn extract_warning_path(message : String) -> String {
  match find_last_char(message, '(') {
    Some(start) =>
      match find_last_char(message, ')') {
        Some(end) =>
          if end > start {
            message[start + 1:end].to_string()
          } else {
            message
          }
        None => message
      }
    None => message
  }
}

///|
fn render_xlsx_failure(
  error : @core.ConversionError,
  phase : @core.ConversionPhase?,
  source : @core.DiagnosticSource?,
  hint : @core.DiagnosticHint?,
) -> String {
  @core.error_diagnostic(error, phase, source, hint).render()
}
