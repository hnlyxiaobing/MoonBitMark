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
pub async fn XlsxConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  ignore(ctx)
  let bytes = @core.read_file_bytes(file_path)

  // Use pure MoonBit libzip to open ZIP
  match @libzip.ZipArchive::open(bytes) {
    Some(archive) => {
      // Parse workbook.xml to get sheet names
      let sheets = parse_workbook_sheets(archive)
      // Parse shared strings
      let (shared_strings, helper_warnings_a) = parse_shared_strings(archive)
      // Parse each sheet and generate markdown
      let (blocks, helper_warnings_b) = generate_blocks(
        archive, sheets, shared_strings,
      )
      let metadata = Map::new()
      metadata["format"] = "xlsx"
      metadata["sheet_count"] = sheets.length().to_string()
      metadata["shared_string_count"] = shared_strings.length().to_string()
      let (assets, asset_warnings) = extract_xlsx_assets(archive)
      let warnings : Array[String] = []
      for warning in helper_warnings_a {
        warnings.push(warning)
      }
      for warning in helper_warnings_b {
        warnings.push(warning)
      }
      for warning in asset_warnings {
        warnings.push(warning)
      }
      if sheets.length() == 0 {
        warnings.push("No sheets discovered in xl/workbook.xml.")
      }
      let title = @core.file_stem(file_path)
      let doc = @ast.document(title, metadata, blocks)
      let rendered_markdown = @ast.render_markdown(doc)
      if rendered_markdown == "" {
        warnings.push("XLSX conversion produced empty Markdown output.")
      }
      let markdown_with_assets = append_xlsx_asset_gallery(
        rendered_markdown, assets,
      )
      let diagnostics = xlsx_warning_diagnostics(file_path, warnings)
      @core.ConvertResult::markdown_only(markdown_with_assets, "xlsx")
      .with_title(title)
      .with_metadata(metadata)
      .with_warnings(warnings)
      .with_diagnostics(diagnostics)
      .with_assets(assets)
      .with_stats(Some(@core.stats_for_markdown(markdown_with_assets)))
      .with_document(Some(doc))
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
/// Generate AST blocks from all sheets
fn generate_blocks(
  archive : @libzip.ZipArchive,
  sheets : Array[(String, String)],
  shared_strings : Array[String],
) -> (Array[@ast.Block], Array[String]) {
  let (sheet_paths, warnings) = parse_sheet_paths(archive)
  let blocks : Array[@ast.Block] = []

  let mut idx = 0
  while idx < sheets.length() {
    let (sheet_name, rid) = sheets[idx]
    let sheet_path = find_sheet_path(rid, sheet_paths)
    match sheet_path {
      Some(path) => {
        let (sheet_blocks, sheet_warnings) = parse_worksheet_to_blocks(
          archive, path, sheet_name, shared_strings,
        )
        for warning in sheet_warnings {
          warnings.push(warning)
        }
        blocks.push(@ast.text_heading(2, sheet_name))
        let normalized_blocks = normalize_sheet_blocks(sheet_blocks, sheet_name)
        for block in normalized_blocks {
          blocks.push(block)
        }
      }
      None =>
        warnings.push(
          "Missing worksheet relationship for sheet '\{sheet_name}' (r:id=\{rid}).",
        )
    }
    idx = idx + 1
  }

  (blocks, warnings)
}

///|
fn normalize_sheet_blocks(
  blocks : Array[@ast.Block],
  sheet_name : String,
) -> Array[@ast.Block] {
  if blocks.length() == 0 {
    return blocks
  }
  match blocks[0] {
    @ast.Heading(3, inlines) =>
      if @ast.plain_text_of_inlines(inlines) == sheet_name {
        let normalized : Array[@ast.Block] = []
        let mut index = 1
        while index < blocks.length() {
          normalized.push(blocks[index])
          index = index + 1
        }
        normalized
      } else {
        blocks
      }
    _ => blocks
  }
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
  match paths.get(rid) {
    Some(target) => Some(@core.join_path("xl", target))
    None => None
  }
}

///|
fn parse_worksheet_to_blocks(
  archive : @libzip.ZipArchive,
  sheet_path : String,
  sheet_name : String,
  shared_strings : Array[String],
) -> (Array[@ast.Block], Array[String]) {
  let full_path = sheet_path

  match @libzip.read_file_entry_decompressed(archive, full_path) {
    Some(xml_bytes) => {
      let xml_string = @utf8.decode(xml_bytes) catch {
        _ =>
          return (
            [],
            [
              "Failed to decode worksheet XML as UTF-8: \{sheet_name} (\{full_path}).",
            ],
          )
      }
      match @xml.parse_xml(xml_string) {
        Ok(events) => {
          let sheet_data = extract_sheet_data(events, shared_strings)
          (sheet_data_to_blocks(sheet_data), [])
        }
        Err(_) =>
          ([], ["Failed to parse worksheet XML: \{sheet_name} (\{full_path})."])
      }
    }
    None =>
      ([], ["Failed to read worksheet XML: \{sheet_name} (\{full_path})."])
  }
}

///|
/// Sheet data structure
priv struct SheetData {
  rows : Array[Array[String]]
  mut max_cols : Int
}

///|
priv struct SheetCellPos {
  row : Int
  col : Int
}

///|
priv struct SheetRegion {
  min_row : Int
  max_row : Int
  min_col : Int
  max_col : Int
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
  let mut in_formula = false
  let mut in_inline_str = false
  let mut in_inline_t = false
  let mut current_row : Array[String] = []
  let mut current_cell_ref = ""
  let mut current_cell_type = ""
  let mut current_content = ""
  let mut current_formula = ""

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
            current_formula = ""
          }
          "v" => if in_cell { in_value = true }
          "f" => if in_cell { in_formula = true }
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
              current_cell_type, current_content, current_formula, shared_strings,
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
          "f" => in_formula = false
          "is" => in_inline_str = false
          "t" => in_inline_t = false
          _ => ()
        }
      }
      @xml.TextContent(evt) =>
        if in_value {
          current_content = current_content + evt.content
        } else if in_formula {
          current_formula = current_formula + evt.content
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
  formula : String,
  shared_strings : Array[String],
) -> String {
  let resolved = if cell_type == "s" {
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
    // Number or other
  } else if raw_value != "" {
    raw_value
  } else if formula != "" {
    "=" + formula
  } else {
    ""
  }
  normalize_xlsx_cell_text(resolved)
}

///|
fn normalize_xlsx_cell_text(text : String) -> String {
  text
  .replace(old="\r\n", new="\n")
  .replace(old="\r", new="\n")
  .trim()
  .to_string()
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
fn sheet_data_to_blocks(data : SheetData) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  let normalized_rows = normalize_sheet_rows(data)
  let regions = detect_sheet_regions(normalized_rows)
  if regions.length() == 0 {
    blocks.push(@ast.text_paragraph("*(Empty sheet)*"))
    return blocks
  }
  for region in regions {
    let region_rows = sheet_region_rows(normalized_rows, region)
    for block in sheet_region_to_blocks(region_rows) {
      blocks.push(block)
    }
  }
  blocks
}

///|
fn normalize_sheet_rows(data : SheetData) -> Array[Array[String]] {
  let normalized_rows : Array[Array[String]] = []
  for row in data.rows {
    let extended_row = row
    while extended_row.length() < data.max_cols {
      extended_row.push("")
    }
    normalized_rows.push(extended_row)
  }
  normalized_rows
}

///|
fn detect_sheet_regions(rows : Array[Array[String]]) -> Array[SheetRegion] {
  let cell_map : Map[String, String] = Map::new()
  let positions : Array[SheetCellPos] = []
  for row_index, row in rows {
    for col_index, cell in row {
      if cell != "" {
        cell_map[sheet_cell_key(row_index, col_index)] = cell
        positions.push(SheetCellPos::{ row: row_index, col: col_index })
      }
    }
  }
  let visited : Map[String, Bool] = Map::new()
  let regions : Array[SheetRegion] = []
  for position in positions {
    let key = sheet_cell_key(position.row, position.col)
    if visited.get(key) == Some(true) {
      continue
    }
    visited[key] = true
    let queue : Array[SheetCellPos] = [position]
    let mut queue_index = 0
    let mut min_row = position.row
    let mut max_row = position.row
    let mut min_col = position.col
    let mut max_col = position.col
    while queue_index < queue.length() {
      let current = queue[queue_index]
      queue_index = queue_index + 1
      if current.row < min_row {
        min_row = current.row
      }
      if current.row > max_row {
        max_row = current.row
      }
      if current.col < min_col {
        min_col = current.col
      }
      if current.col > max_col {
        max_col = current.col
      }
      for neighbor in sheet_neighbors(current) {
        let neighbor_key = sheet_cell_key(neighbor.row, neighbor.col)
        if cell_map.get(neighbor_key) != None &&
          visited.get(neighbor_key) != Some(true) {
          visited[neighbor_key] = true
          queue.push(neighbor)
        }
      }
    }
    regions.push(SheetRegion::{ min_row, max_row, min_col, max_col })
  }
  regions
}

///|
fn sheet_neighbors(position : SheetCellPos) -> Array[SheetCellPos] {
  let neighbors : Array[SheetCellPos] = []
  if position.row > 0 {
    neighbors.push(SheetCellPos::{ row: position.row - 1, col: position.col })
  }
  neighbors.push(SheetCellPos::{ row: position.row + 1, col: position.col })
  if position.col > 0 {
    neighbors.push(SheetCellPos::{ row: position.row, col: position.col - 1 })
  }
  neighbors.push(SheetCellPos::{ row: position.row, col: position.col + 1 })
  neighbors
}

///|
fn sheet_cell_key(row : Int, col : Int) -> String {
  row.to_string() + ":" + col.to_string()
}

///|
fn sheet_region_rows(
  rows : Array[Array[String]],
  region : SheetRegion,
) -> Array[Array[String]] {
  let region_rows : Array[Array[String]] = []
  let mut row_index = region.min_row
  while row_index <= region.max_row {
    let extracted : Array[String] = []
    let mut col_index = region.min_col
    while col_index <= region.max_col {
      let row = rows[row_index]
      extracted.push(if col_index < row.length() { row[col_index] } else { "" })
      col_index = col_index + 1
    }
    region_rows.push(extracted)
    row_index = row_index + 1
  }
  region_rows
}

///|
fn sheet_region_to_blocks(rows : Array[Array[String]]) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  let trimmed_rows = trim_empty_region_rows(rows)
  if trimmed_rows.length() == 0 {
    return blocks
  }
  let (title, table_rows) = extract_sheet_region_title(trimmed_rows)
  match title {
    Some(text) => blocks.push(@ast.text_heading(3, text))
    None => ()
  }
  if table_rows.length() == 0 {
    return blocks
  }
  let header_cells : Array[Array[@ast.Inline]] = []
  for cell in table_rows[0] {
    header_cells.push(@ast.text_inlines(cell))
  }
  let body_rows : Array[Array[Array[@ast.Inline]]] = []
  let mut row_index = 1
  while row_index < table_rows.length() {
    let body_row : Array[Array[@ast.Inline]] = []
    for cell in table_rows[row_index] {
      body_row.push(@ast.text_inlines(cell))
    }
    body_rows.push(body_row)
    row_index = row_index + 1
  }
  blocks.push(@ast.Table(header_cells, body_rows))
  blocks
}

///|
fn trim_empty_region_rows(rows : Array[Array[String]]) -> Array[Array[String]] {
  let trimmed : Array[Array[String]] = []
  for row in rows {
    if count_non_empty_cells(row) > 0 {
      trimmed.push(row)
    }
  }
  trimmed
}

///|
fn extract_sheet_region_title(
  rows : Array[Array[String]],
) -> (String?, Array[Array[String]]) {
  if rows.length() > 1 && count_non_empty_cells(rows[0]) == 1 {
    let title = first_non_empty_cell(rows[0])
    let remaining : Array[Array[String]] = []
    let mut index = 1
    while index < rows.length() {
      remaining.push(rows[index])
      index = index + 1
    }
    (title, remaining)
  } else {
    (None, rows)
  }
}

///|
fn count_non_empty_cells(row : Array[String]) -> Int {
  let mut count = 0
  for cell in row {
    if cell != "" {
      count = count + 1
    }
  }
  count
}

///|
fn first_non_empty_cell(row : Array[String]) -> String? {
  for cell in row {
    if cell != "" {
      return Some(cell)
    }
  }
  None
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
fn extract_xlsx_assets(
  archive : @libzip.ZipArchive,
) -> (Array[@core.OutputAsset], Array[String]) {
  let assets : Array[@core.OutputAsset] = []
  let warnings : Array[String] = []
  let mut index = 1
  for entry in archive.list_entries() {
    if entry.has_prefix("xl/media/") || entry.has_prefix("xl/embeddings/") {
      match @libzip.read_file_entry_decompressed(archive, entry) {
        Some(bytes) => {
          let prefix = if entry.has_prefix("xl/media/") {
            "xlsx-image-"
          } else {
            "xlsx-attachment-"
          }
          let filename = @core.numbered_asset_filename(prefix, index, entry)
          assets.push(@core.OutputAsset::{
            placeholder: xlsx_asset_placeholder(index),
            filename,
            bytes,
            source: Some(@core.ArchiveEntry(entry)),
            hint: Some(@core.CheckArchiveIntegrity),
          })
          index = index + 1
        }
        None => warnings.push("Failed to extract XLSX asset: " + entry)
      }
    }
  }
  (assets, warnings)
}

///|
fn append_xlsx_asset_gallery(
  markdown : String,
  assets : Array[@core.OutputAsset],
) -> String {
  if assets.length() == 0 {
    return markdown
  }
  let lines : Array[String] = []
  if markdown != "" {
    lines.push(markdown)
    lines.push("")
  }
  lines.push("## Embedded Assets")
  lines.push("")
  for asset in assets {
    if asset.filename.has_prefix("xlsx-image-") {
      lines.push("![" + asset.filename + "](" + asset.placeholder + ")")
    } else {
      lines.push("- [" + asset.filename + "](" + asset.placeholder + ")")
    }
  }
  lines.join("\n")
}

///|
fn xlsx_asset_placeholder(index : Int) -> String {
  @core.asset_placeholder("xlsx", index)
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
    } else if warning.has_prefix("Failed to extract XLSX asset: ") {
      let path = warning[30:].to_string()
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("asset"))),
          Some(@core.ArchiveEntry(path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    }
  }
  diagnostics
}

///|
fn extract_warning_path(message : String) -> String {
  match @core.find_last_char(message, '(') {
    Some(start) =>
      match @core.find_last_char(message, ')') {
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
