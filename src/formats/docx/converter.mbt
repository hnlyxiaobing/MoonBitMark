// DOCX Converter - Pure MoonBit Implementation
// Converts Word documents (.docx) to Markdown

///|
/// Converter for DOCX files
pub(all) struct DocxConverter {
  dummy : Int
}

///|
/// Create a new DOCX converter
pub fn DocxConverter::new() -> DocxConverter {
  DocxConverter::{ dummy: 0 }
}

///|
/// Check if this converter accepts the given file
pub fn DocxConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      ext_lower == ".docx"
    }
    None => false
  }
}

///|
/// Convert a DOCX file to Markdown
pub async fn DocxConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  let bytes = @core.read_file_bytes(file_path)

  match @libzip.ZipArchive::open(bytes) {
    Some(archive) => {
      let relationships = parse_docx_relationships(archive)
      let numbering = parse_docx_numbering(archive)
      let (assets, asset_warnings, asset_placeholders) = extract_docx_media_assets(
        archive,
      )
      match @libzip.read_file_entry_decompressed(archive, "word/document.xml") {
        Some(xml_bytes) => {
          let xml_string = @utf8.decode(xml_bytes) catch {
            _ =>
              fail(
                render_docx_failure(
                  @core.InputError(
                    "document.xml contains invalid UTF-8 sequence",
                    Some("word/document.xml"),
                  ),
                  Some(@core.Load(Some("word/document.xml"))),
                  Some(@core.ArchiveEntry("word/document.xml")),
                  Some(
                    @core.Custom(
                      "Verify the XML encoding of word/document.xml before converting.",
                    ),
                  ),
                ),
              )
          }
          let (content_blocks, docx_warnings) = extract_blocks_from_docx_xml(
            xml_string, relationships, numbering, asset_placeholders,
          )
          let metadata = Map::new()
          metadata["format"] = "docx"
          metadata["container"] = "zip"
          let warnings : Array[String] = []
          if content_blocks.length() == 0 && assets.length() == 0 {
            warnings.push("No text content extracted from word/document.xml.")
          }
          for warning in docx_warnings {
            warnings.push(warning)
          }
          for warning in asset_warnings {
            warnings.push(warning)
          }
          let (ocr_blocks, ocr_warnings, ocr_count, ocr_provider) = ocr_docx_assets(
            assets,
            ctx.ocr,
          )
          for warning in ocr_warnings {
            warnings.push(warning)
          }
          @core.apply_ocr_metadata(
            metadata,
            ctx.ocr,
            ocr_provider,
            embedded_image_count=ocr_count,
            attempted=ocr_count > 0,
            available=ocr_provider != None,
          )
          let diagnostics = docx_warning_diagnostics(file_path, warnings)
          let title = @core.file_stem(file_path)
          let blocks = append_docx_asset_blocks(
            content_blocks, assets, ocr_blocks,
          )
          let doc = @ast.Document::{ title, metadata, blocks }
          let rendered_markdown = @ast.render_markdown(doc)
          @core.ConvertResult::markdown_only(rendered_markdown, "docx")
          .with_title(title)
          .with_metadata(metadata)
          .with_warnings(warnings)
          .with_diagnostics(diagnostics)
          .with_assets(assets)
          .with_stats(Some(@core.stats_for_markdown(rendered_markdown)))
          .with_document(Some(doc))
        }
        None =>
          fail(
            render_docx_failure(
              @core.ZipError(
                "Failed to read document.xml from DOCX",
                Some("word/document.xml"),
              ),
              Some(@core.Load(Some("word/document.xml"))),
              Some(@core.ArchiveEntry("word/document.xml")),
              Some(@core.CheckArchiveIntegrity),
            ),
          )
      }
    }
    None =>
      fail(
        render_docx_failure(
          @core.ZipError("Failed to open DOCX file as ZIP archive", None),
          Some(@core.Load(Some("archive"))),
          Some(@core.File(file_path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
  }
}

///|
fn extract_blocks_from_docx_xml(
  xml : String,
  relationships : Map[String, String],
  numbering : DocxNumbering,
  asset_placeholders : Map[String, String],
) -> (Array[@ast.Block], Array[String]) raise {
  match @xml.parse_xml(xml) {
    Ok(events) =>
      process_docx_events(events, relationships, numbering, asset_placeholders)
    Err(_) =>
      fail(
        render_docx_failure(
          @core.XmlParseError("Failed to parse word/document.xml", None),
          Some(@core.Parse(Some("word/document.xml"))),
          Some(@core.ArchiveEntry("word/document.xml")),
          Some(
            @core.Custom(
              "Inspect malformed XML in word/document.xml inside the DOCX archive.",
            ),
          ),
        ),
      )
  }
}

///|
priv struct DocxNumbering {
  num_to_abstract : Map[String, String]
  level_formats : Map[String, String]
}

///|
priv struct DocxContext {
  relationships : Map[String, String]
  numbering : DocxNumbering
  asset_placeholders : Map[String, String]
  mut in_paragraph : Bool
  mut in_paragraph_properties : Bool
  mut in_numbering_properties : Bool
  mut in_run_properties : Bool
  mut in_text : Bool
  mut current_text : String
  mut current_inlines : Array[@ast.Inline]
  mut current_paragraph_style : String?
  mut heading_level : Int
  mut in_list : Bool
  mut current_list_num_id : String?
  mut current_list_level : Int
  mut run_bold : Bool
  mut run_italic : Bool
  mut current_hyperlink : String?
  mut pending_image_alt : String?
  mut has_pending_list : Bool
  mut pending_list_ordered : Bool
  mut pending_list_items : Array[Array[@ast.Inline]]
  mut in_table : Bool
  mut in_table_cell : Bool
  mut current_cell_paragraphs : Array[String]
  mut current_table_row : Array[String]
  mut current_table_rows : Array[Array[String]]
  blocks : Array[@ast.Block]
  warnings : Array[String]
}

///|
fn process_docx_events(
  events : Array[@xml.ParseEvent],
  relationships : Map[String, String],
  numbering : DocxNumbering,
  asset_placeholders : Map[String, String],
) -> (Array[@ast.Block], Array[String]) {
  let ctx = DocxContext::{
    relationships,
    numbering,
    asset_placeholders,
    in_paragraph: false,
    in_paragraph_properties: false,
    in_numbering_properties: false,
    in_run_properties: false,
    in_text: false,
    current_text: "",
    current_inlines: [],
    current_paragraph_style: None,
    heading_level: 0,
    in_list: false,
    current_list_num_id: None,
    current_list_level: 0,
    run_bold: false,
    run_italic: false,
    current_hyperlink: None,
    pending_image_alt: None,
    has_pending_list: false,
    pending_list_ordered: false,
    pending_list_items: [],
    in_table: false,
    in_table_cell: false,
    current_cell_paragraphs: [],
    current_table_row: [],
    current_table_rows: [],
    blocks: [],
    warnings: [],
  }

  for event in events {
    match event {
      @xml.ElementStart(evt) =>
        handle_element_start(ctx, evt.name, evt.attributes)
      @xml.ElementEnd(evt) => handle_element_end(ctx, evt.name)
      @xml.TextContent(evt) =>
        if ctx.in_text && ctx.in_paragraph {
          ctx.current_text = ctx.current_text + evt.content
        }
    }
  }

  finalize_docx_paragraph(ctx)
  flush_docx_pending_list(ctx)
  (ctx.blocks, ctx.warnings)
}

///|
fn handle_element_start(
  ctx : DocxContext,
  name : String,
  attrs : Map[String, String],
) -> Unit {
  let local_name = strip_namespace(name)

  if local_name == "p" {
    begin_docx_paragraph(ctx)
  } else if local_name == "tbl" {
    finalize_docx_paragraph(ctx)
    flush_docx_pending_list(ctx)
    begin_docx_table(ctx)
  } else if local_name == "tr" && ctx.in_table {
    ctx.current_table_row = []
  } else if local_name == "tc" && ctx.in_table {
    ctx.in_table_cell = true
    ctx.current_cell_paragraphs = []
  } else if local_name == "pPr" {
    ctx.in_paragraph_properties = true
  } else if local_name == "r" {
    begin_docx_run(ctx)
  } else if local_name == "rPr" {
    ctx.in_run_properties = true
  } else if local_name == "t" {
    ctx.in_text = true
  } else if local_name == "tab" {
    ctx.current_text = ctx.current_text + "\t"
  } else if local_name == "br" || local_name == "cr" {
    flush_docx_text(ctx)
    ctx.current_inlines.push(@ast.LineBreak)
  } else if local_name == "pStyle" && ctx.in_paragraph_properties {
    let style = map_get_any(attrs, ["w:val", "val"])
    apply_docx_paragraph_style(ctx, style)
  } else if local_name == "numPr" && ctx.in_paragraph_properties {
    ctx.in_list = true
    ctx.in_numbering_properties = true
  } else if local_name == "numId" && ctx.in_numbering_properties {
    ctx.current_list_num_id = map_get_any(attrs, ["w:val", "val"])
  } else if local_name == "ilvl" && ctx.in_numbering_properties {
    ctx.current_list_level = docx_parse_level(
      map_get_any(attrs, ["w:val", "val"]),
    )
  } else if local_name == "b" && ctx.in_run_properties {
    ctx.run_bold = true
  } else if local_name == "i" && ctx.in_run_properties {
    ctx.run_italic = true
  } else if ctx.in_run_properties && is_unsupported_docx_run_style(local_name) {
    @core.push_unique_warning(
      ctx.warnings,
      "Dropped unsupported DOCX run style: " + local_name,
    )
  } else if local_name == "hyperlink" {
    ctx.current_hyperlink = resolve_docx_hyperlink(ctx.relationships, attrs)
    if ctx.current_hyperlink == None {
      match map_get_any(attrs, ["r:id", "id"]) {
        Some(rid) =>
          @core.push_unique_warning(
            ctx.warnings,
            "Missing DOCX hyperlink target: " + rid,
          )
        None => ()
      }
    }
  } else if local_name == "docPr" {
    ctx.pending_image_alt = docx_image_alt(attrs)
  } else if local_name == "blip" {
    handle_docx_blip(ctx, attrs)
  }
}

///|
fn handle_element_end(ctx : DocxContext, name : String) -> Unit {
  let local_name = strip_namespace(name)

  if local_name == "p" {
    finalize_docx_paragraph(ctx)
  } else if local_name == "tbl" {
    finish_docx_table(ctx)
  } else if local_name == "tr" {
    finish_docx_table_row(ctx)
  } else if local_name == "tc" {
    finish_docx_table_cell(ctx)
  } else if local_name == "pPr" {
    ctx.in_paragraph_properties = false
  } else if local_name == "numPr" {
    ctx.in_numbering_properties = false
  } else if local_name == "r" {
    flush_docx_text(ctx)
    ctx.in_run_properties = false
  } else if local_name == "rPr" {
    ctx.in_run_properties = false
  } else if local_name == "t" {
    ctx.in_text = false
  } else if local_name == "hyperlink" {
    flush_docx_text(ctx)
    ctx.current_hyperlink = None
  }
}

///|
fn begin_docx_paragraph(ctx : DocxContext) -> Unit {
  finalize_docx_paragraph(ctx)
  ctx.in_paragraph = true
  ctx.in_paragraph_properties = false
  ctx.in_numbering_properties = false
  ctx.current_inlines = []
  ctx.current_text = ""
  ctx.current_paragraph_style = None
  ctx.heading_level = 0
  ctx.in_list = false
  ctx.current_list_num_id = None
  ctx.current_list_level = 0
  ctx.current_hyperlink = None
  ctx.pending_image_alt = None
}

///|
fn begin_docx_run(ctx : DocxContext) -> Unit {
  flush_docx_text(ctx)
  ctx.in_run_properties = false
  ctx.in_text = false
  ctx.current_text = ""
  ctx.run_bold = false
  ctx.run_italic = false
}

///|
fn finalize_docx_paragraph(ctx : DocxContext) -> Unit {
  if !ctx.in_paragraph {
    return
  }
  flush_docx_text(ctx)
  if ctx.current_inlines.length() > 0 {
    if ctx.in_table && ctx.in_table_cell {
      append_docx_table_cell_paragraph(ctx, ctx.current_inlines)
    } else if ctx.heading_level > 0 {
      flush_docx_pending_list(ctx)
      ctx.blocks.push(
        @ast.text_heading(
          ctx.heading_level,
          render_docx_heading_text(ctx.current_inlines),
        ),
      )
    } else if ctx.in_list {
      append_docx_list_item(
        ctx,
        ctx.current_inlines,
        docx_list_is_ordered(ctx),
        ctx.current_list_level,
      )
    } else if ctx.blocks.length() == 0 &&
      docx_is_promotable_title(ctx.current_inlines) {
      flush_docx_pending_list(ctx)
      ctx.blocks.push(
        @ast.text_heading(1, render_docx_heading_text(ctx.current_inlines)),
      )
    } else {
      flush_docx_pending_list(ctx)
      ctx.blocks.push(@ast.Paragraph(ctx.current_inlines))
    }
  }
  ctx.in_paragraph = false
  ctx.current_inlines = []
  ctx.current_text = ""
  ctx.current_paragraph_style = None
  ctx.heading_level = 0
  ctx.in_list = false
  ctx.current_list_num_id = None
  ctx.current_list_level = 0
  ctx.current_hyperlink = None
}

///|
fn append_docx_list_item(
  ctx : DocxContext,
  inlines : Array[@ast.Inline],
  ordered : Bool,
  level : Int,
) -> Unit {
  let normalized = if level > 0 {
    docx_prefixed_inlines("  ".repeat(level), inlines)
  } else {
    inlines
  }
  if ctx.has_pending_list && ctx.pending_list_ordered != ordered {
    flush_docx_pending_list(ctx)
  }
  if !ctx.has_pending_list {
    ctx.pending_list_items = []
    ctx.pending_list_ordered = ordered
    ctx.has_pending_list = true
  }
  ctx.pending_list_items.push(normalized)
}

///|
fn flush_docx_pending_list(ctx : DocxContext) -> Unit {
  if ctx.has_pending_list && ctx.pending_list_items.length() > 0 {
    ctx.blocks.push(@ast.List(ctx.pending_list_items, ctx.pending_list_ordered))
  }
  ctx.pending_list_items = []
  ctx.has_pending_list = false
  ctx.pending_list_ordered = false
}

///|
fn docx_prefixed_inlines(
  prefix : String,
  inlines : Array[@ast.Inline],
) -> Array[@ast.Inline] {
  if prefix == "" {
    return inlines
  }
  let prefixed : Array[@ast.Inline] = []
  let mut is_first = true
  for inline in inlines {
    if is_first {
      match inline {
        @ast.Text(text) => prefixed.push(@ast.Text(prefix + text))
        _ => {
          prefixed.push(@ast.Text(prefix))
          prefixed.push(inline)
        }
      }
      is_first = false
    } else {
      prefixed.push(inline)
    }
  }
  if is_first {
    [@ast.Text(prefix)]
  } else {
    prefixed
  }
}

///|
fn docx_list_is_ordered(ctx : DocxContext) -> Bool {
  match ctx.current_paragraph_style {
    Some(style) => {
      let lowered = style.to_lower().to_string()
      if lowered.contains("number") || lowered.contains("ordered") {
        return true
      }
      if lowered.contains("bullet") {
        return false
      }
    }
    None => ()
  }
  match ctx.current_list_num_id {
    Some(num_id) =>
      docx_numbering_is_ordered(ctx.numbering, num_id, ctx.current_list_level)
    None => false
  }
}

///|
fn flush_docx_text(ctx : DocxContext) -> Unit {
  if ctx.current_text == "" {
    return
  }
  let text = ctx.current_text
  ctx.current_text = ""
  let base : @ast.Inline = @ast.Text(text)
  let styled = apply_docx_run_style(base, ctx.run_bold, ctx.run_italic)
  let linked = match ctx.current_hyperlink {
    Some(url) if url != "" => @ast.Link([styled], url)
    _ => styled
  }
  ctx.current_inlines.push(linked)
}

///|
fn apply_docx_run_style(
  base : @ast.Inline,
  bold : Bool,
  italic : Bool,
) -> @ast.Inline {
  let with_italic = if italic { @ast.Emphasis([base]) } else { base }
  if bold {
    @ast.Strong([with_italic])
  } else {
    with_italic
  }
}

///|
fn normalize_docx_heading_inlines(
  inlines : Array[@ast.Inline],
) -> Array[@ast.Inline] {
  let normalized : Array[@ast.Inline] = []
  for inline in inlines {
    normalized.push(normalize_docx_heading_inline(inline))
  }
  normalized
}

///|
fn render_docx_heading_text(inlines : Array[@ast.Inline]) -> String {
  normalize_docx_heading_text(@ast.render_inlines(inlines))
}

///|
fn normalize_docx_heading_inline(inline : @ast.Inline) -> @ast.Inline {
  match inline {
    @ast.Text(text) => @ast.Text(normalize_docx_heading_text(text))
    @ast.Emphasis(children) =>
      @ast.Emphasis(normalize_docx_heading_inlines(children))
    @ast.Strong(children) =>
      @ast.Strong(normalize_docx_heading_inlines(children))
    @ast.Link(children, href) =>
      @ast.Link(normalize_docx_heading_inlines(children), href)
    @ast.Image(alt, src) => @ast.Image(alt, src)
    @ast.Code(text) => @ast.Code(normalize_docx_heading_text(text))
    @ast.LineBreak => @ast.LineBreak
  }
}

///|
fn normalize_docx_heading_text(text : String) -> String {
  let mut result = ""
  let mut previous : Char? = None
  for ch in text {
    match previous {
      Some(prev) =>
        if is_docx_ascii_letter(prev) &&
          ch >= '0' &&
          ch <= '9' &&
          !result.has_suffix(" ") {
          result = result + " "
        }
      None => ()
    }
    result = result + ch.to_string()
    previous = Some(ch)
  }
  result
}

///|
fn is_docx_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn docx_is_promotable_title(inlines : Array[@ast.Inline]) -> Bool {
  let text = @ast.render_inlines(inlines).trim().to_string()
  if text == "" || text.length() > 80 || text.contains("\n") {
    return false
  }
  if text.has_suffix(".") || text.has_suffix("!") || text.has_suffix("?") {
    return false
  }
  let mut has_letter = false
  for ch in text {
    if is_docx_ascii_letter(ch) {
      has_letter = true
      break
    }
  }
  has_letter && text.split(" ").to_array().length() <= 8
}

///|
fn apply_docx_paragraph_style(ctx : DocxContext, style : String?) -> Unit {
  match style {
    Some(value) => {
      ctx.current_paragraph_style = Some(value)
      let lowered = value.to_lower().to_string()
      if lowered.has_prefix("heading") {
        ctx.heading_level = parse_heading_level(value)
      } else if lowered.contains("list") {
        ctx.in_list = true
      }
    }
    None => ()
  }
}

///|
fn parse_heading_level(style : String) -> Int {
  let mut digits = ""
  for ch in style {
    if ch >= '0' && ch <= '9' {
      digits = digits + ch.to_string()
    }
  }
  if digits == "" {
    return 1
  }
  let level = parse_decimal_digits(digits)
  if level <= 0 {
    1
  } else if level > 6 {
    6
  } else {
    level
  }
}

///|
fn parse_decimal_digits(text : String) -> Int {
  let mut value = 0
  for ch in text {
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  value
}

///|
fn docx_parse_level(value : String?) -> Int {
  match value {
    Some(text) if text != "" => parse_decimal_digits(text)
    _ => 0
  }
}

///|
fn handle_docx_blip(ctx : DocxContext, attrs : Map[String, String]) -> Unit {
  flush_docx_text(ctx)
  let rid = map_get_any(attrs, ["r:embed", "embed"])
  match rid {
    Some(value) =>
      match ctx.relationships.get(value) {
        Some(target) =>
          match ctx.asset_placeholders.get(target) {
            Some(placeholder) => {
              let alt = match ctx.pending_image_alt {
                Some(text) if text != "" => text
                _ => @core.file_name_only(target)
              }
              ctx.current_inlines.push(@ast.Image(alt, placeholder))
              ctx.pending_image_alt = None
            }
            None =>
              @core.push_unique_warning(
                ctx.warnings,
                "DOCX image reference did not resolve to extracted asset: " +
                target,
              )
          }
        None =>
          @core.push_unique_warning(
            ctx.warnings,
            "Missing DOCX relationship target: " + value,
          )
      }
    None => ()
  }
}

///|
fn resolve_docx_hyperlink(
  relationships : Map[String, String],
  attrs : Map[String, String],
) -> String? {
  match map_get_any(attrs, ["r:id", "id"]) {
    Some(rid) => relationships.get(rid)
    None => None
  }
}

///|
fn parse_docx_relationships(
  archive : @libzip.ZipArchive,
) -> Map[String, String] {
  match
    @libzip.read_file_entry_decompressed(
      archive, "word/_rels/document.xml.rels",
    ) {
    Some(bytes) => {
      let xml_string = @utf8.decode(bytes) catch { _ => return Map::new() }
      match @xml.parse_xml(xml_string) {
        Ok(events) => extract_docx_relationships(events)
        Err(_) => Map::new()
      }
    }
    None => Map::new()
  }
}

///|
fn extract_docx_relationships(
  events : Array[@xml.ParseEvent],
) -> Map[String, String] {
  let relationships : Map[String, String] = Map::new()
  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let local_name = strip_namespace(evt.name)
        if local_name == "Relationship" {
          match
            (
              map_get_any(evt.attributes, ["Id"]),
              map_get_any(evt.attributes, ["Target"]),
            ) {
            (Some(id), Some(target)) => {
              let target_mode = map_get_any(evt.attributes, ["TargetMode"])
              let resolved = match target_mode {
                Some(mode) if mode == "External" => target
                _ => @core.join_path("word", target)
              }
              relationships[id] = resolved
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }
  relationships
}

///|
fn parse_docx_numbering(archive : @libzip.ZipArchive) -> DocxNumbering {
  let numbering = DocxNumbering::{
    num_to_abstract: Map::new(),
    level_formats: Map::new(),
  }
  match @libzip.read_file_entry_decompressed(archive, "word/numbering.xml") {
    Some(bytes) => {
      let xml_string = @utf8.decode(bytes) catch { _ => return numbering }
      match @xml.parse_xml(xml_string) {
        Ok(events) => extract_docx_numbering(events, numbering)
        Err(_) => ()
      }
    }
    None => ()
  }
  numbering
}

///|
priv struct DocxNumberingContext {
  numbering : DocxNumbering
  mut current_abstract_id : String?
  mut current_level : Int?
  mut current_level_format : String?
  mut current_num_id : String?
  mut current_num_abstract_id : String?
}

///|
fn extract_docx_numbering(
  events : Array[@xml.ParseEvent],
  numbering : DocxNumbering,
) -> Unit {
  let ctx = DocxNumberingContext::{
    numbering,
    current_abstract_id: None,
    current_level: None,
    current_level_format: None,
    current_num_id: None,
    current_num_abstract_id: None,
  }
  for event in events {
    match event {
      @xml.ElementStart(evt) =>
        handle_docx_numbering_start(
          ctx,
          strip_namespace(evt.name),
          evt.attributes,
        )
      @xml.ElementEnd(evt) =>
        handle_docx_numbering_end(ctx, strip_namespace(evt.name))
      _ => ()
    }
  }
}

///|
fn handle_docx_numbering_start(
  ctx : DocxNumberingContext,
  local_name : String,
  attrs : Map[String, String],
) -> Unit {
  if local_name == "abstractNum" {
    ctx.current_abstract_id = map_get_any(attrs, [
      "w:abstractNumId", "abstractNumId",
    ])
  } else if local_name == "lvl" {
    ctx.current_level = Some(
      docx_parse_level(map_get_any(attrs, ["w:ilvl", "ilvl"])),
    )
    ctx.current_level_format = None
  } else if local_name == "numFmt" && ctx.current_abstract_id != None {
    ctx.current_level_format = map_get_any(attrs, ["w:val", "val"])
  } else if local_name == "num" {
    ctx.current_num_id = map_get_any(attrs, ["w:numId", "numId"])
    ctx.current_num_abstract_id = None
  } else if local_name == "abstractNumId" && ctx.current_num_id != None {
    ctx.current_num_abstract_id = map_get_any(attrs, ["w:val", "val"])
  }
}

///|
fn handle_docx_numbering_end(
  ctx : DocxNumberingContext,
  local_name : String,
) -> Unit {
  if local_name == "lvl" {
    match
      (ctx.current_abstract_id, ctx.current_level, ctx.current_level_format) {
      (Some(abstract_id), Some(level), Some(format_name)) =>
        ctx.numbering.level_formats[docx_numbering_key(abstract_id, level)] = format_name
      _ => ()
    }
    ctx.current_level = None
    ctx.current_level_format = None
  } else if local_name == "abstractNum" {
    ctx.current_abstract_id = None
  } else if local_name == "num" {
    match (ctx.current_num_id, ctx.current_num_abstract_id) {
      (Some(num_id), Some(abstract_id)) =>
        ctx.numbering.num_to_abstract[num_id] = abstract_id
      _ => ()
    }
    ctx.current_num_id = None
    ctx.current_num_abstract_id = None
  }
}

///|
fn docx_numbering_key(abstract_id : String, level : Int) -> String {
  abstract_id + ":" + level.to_string()
}

///|
fn docx_numbering_is_ordered(
  numbering : DocxNumbering,
  num_id : String,
  level : Int,
) -> Bool {
  match numbering.num_to_abstract.get(num_id) {
    Some(abstract_id) =>
      match
        numbering.level_formats.get(docx_numbering_key(abstract_id, level)) {
        Some(format_name) => docx_numfmt_is_ordered(format_name)
        None => false
      }
    None => false
  }
}

///|
fn docx_numfmt_is_ordered(format_name : String) -> Bool {
  let lowered = format_name.to_lower().to_string()
  lowered != "bullet" && lowered != "none" && lowered != "picture"
}

///|
fn begin_docx_table(ctx : DocxContext) -> Unit {
  ctx.in_table = true
  ctx.in_table_cell = false
  ctx.current_cell_paragraphs = []
  ctx.current_table_row = []
  ctx.current_table_rows = []
}

///|
fn append_docx_table_cell_paragraph(
  ctx : DocxContext,
  inlines : Array[@ast.Inline],
) -> Unit {
  let mut text = @ast.plain_text_of_inlines(inlines).trim().to_string()
  if text == "" {
    return
  }
  if ctx.in_list {
    text = docx_table_list_prefix(docx_list_is_ordered(ctx)) + text
  }
  ctx.current_cell_paragraphs.push(text)
}

///|
fn docx_table_list_prefix(ordered : Bool) -> String {
  if ordered {
    "1. "
  } else {
    "- "
  }
}

///|
fn finish_docx_table_cell(ctx : DocxContext) -> Unit {
  if !ctx.in_table || !ctx.in_table_cell {
    return
  }
  ctx.current_table_row.push(ctx.current_cell_paragraphs.join("\n"))
  ctx.current_cell_paragraphs = []
  ctx.in_table_cell = false
}

///|
fn finish_docx_table_row(ctx : DocxContext) -> Unit {
  if !ctx.in_table {
    return
  }
  if ctx.current_table_row.length() > 0 {
    ctx.current_table_rows.push(copy_docx_table_row(ctx.current_table_row))
  }
  ctx.current_table_row = []
}

///|
fn finish_docx_table(ctx : DocxContext) -> Unit {
  if !ctx.in_table {
    return
  }
  let rows = docx_compact_table_rows(ctx.current_table_rows)
  if rows.length() > 0 {
    ctx.blocks.push(docx_table_block(rows))
  }
  ctx.in_table = false
  ctx.in_table_cell = false
  ctx.current_cell_paragraphs = []
  ctx.current_table_row = []
  ctx.current_table_rows = []
}

///|
fn copy_docx_table_row(row : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for cell in row {
    copied.push(cell)
  }
  copied
}

///|
fn docx_compact_table_rows(rows : Array[Array[String]]) -> Array[Array[String]] {
  let compacted : Array[Array[String]] = []
  for row in rows {
    if row.length() == 0 {
      continue
    }
    let normalized : Array[String] = []
    let mut has_content = false
    for cell in row {
      let value = cell.trim().to_string()
      if value != "" {
        has_content = true
      }
      normalized.push(value)
    }
    if has_content {
      compacted.push(normalized)
    }
  }
  compacted
}

///|
fn docx_table_block(rows : Array[Array[String]]) -> @ast.Block {
  let headers : Array[Array[@ast.Inline]] = []
  for cell in rows[0] {
    headers.push(@ast.text_inlines(cell))
  }
  let body_rows : Array[Array[Array[@ast.Inline]]] = []
  let mut index = 1
  while index < rows.length() {
    let body_row : Array[Array[@ast.Inline]] = []
    for cell in rows[index] {
      body_row.push(@ast.text_inlines(cell))
    }
    body_rows.push(body_row)
    index = index + 1
  }
  @ast.Table(headers, body_rows)
}

///|
fn map_get_any(map : Map[String, String], keys : Array[String]) -> String? {
  for key in keys {
    match map.get(key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn is_unsupported_docx_run_style(local_name : String) -> Bool {
  local_name == "u" ||
  local_name == "strike" ||
  local_name == "highlight" ||
  local_name == "color" ||
  local_name == "smallCaps" ||
  local_name == "vertAlign"
}

///|
fn strip_namespace(name : String) -> String {
  match name.find(":") {
    Some(pos) => name[pos + 1:].to_string()
    None => name
  }
}

///|
fn docx_image_alt(attrs : Map[String, String]) -> String? {
  match map_get_any(attrs, ["descr", "title", "name"]) {
    Some(value) if value != "" => Some(value)
    _ => None
  }
}

///|
fn extract_docx_media_assets(
  archive : @libzip.ZipArchive,
) -> (Array[@core.OutputAsset], Array[String], Map[String, String]) {
  let assets : Array[@core.OutputAsset] = []
  let warnings : Array[String] = []
  let placeholders : Map[String, String] = Map::new()
  let mut index = 1
  for entry in archive.list_entries() {
    if entry.has_prefix("word/media/") {
      match @libzip.read_file_entry_decompressed(archive, entry) {
        Some(bytes) => {
          let filename = @core.numbered_asset_filename(
            "docx-image-", index, entry,
          )
          let placeholder = docx_asset_placeholder(index)
          assets.push(@core.OutputAsset::{
            placeholder,
            filename,
            bytes,
            source: Some(@core.ArchiveEntry(entry)),
            hint: Some(@core.CheckArchiveIntegrity),
          })
          placeholders[entry] = placeholder
          index = index + 1
        }
        None => warnings.push("Failed to extract DOCX asset: " + entry)
      }
    }
  }
  (assets, warnings, placeholders)
}

///|
fn append_docx_asset_blocks(
  blocks : Array[@ast.Block],
  assets : Array[@core.OutputAsset],
  ocr_blocks : Array[@ast.Block],
) -> Array[@ast.Block] {
  if assets.length() == 0 && ocr_blocks.length() == 0 {
    return blocks
  }
  let result = blocks
  if result.length() > 0 {
    result.push(@ast.HorizontalRule)
  }
  result.push(@ast.text_heading(2, "Embedded Assets"))
  for asset in assets {
    result.push(@ast.Paragraph([@ast.Image(asset.filename, asset.placeholder)]))
  }
  for block in ocr_blocks {
    result.push(block)
  }
  result
}

///|
fn docx_asset_placeholder(index : Int) -> String {
  @core.asset_placeholder("docx", index)
}

///|
fn docx_warning_diagnostics(
  _file_path : String,
  warnings : Array[String],
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    if warning == "No text content extracted from word/document.xml." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("word/document.xml"))),
          Some(@core.ArchiveEntry("word/document.xml")),
          Some(
            @core.Custom(
              "Verify the DOCX contains visible text in word/document.xml.",
            ),
          ),
        ),
      )
    } else {
      match
        @core.archive_asset_warning_diagnostic(
          warning, "Failed to extract DOCX asset: ",
        ) {
        Some(diagnostic) => diagnostics.push(diagnostic)
        None =>
          if warning.has_prefix("Dropped unsupported DOCX run style: ") {
            diagnostics.push(
              @core.warning_diagnostic(
                warning,
                Some(@core.Normalize(Some("word/document.xml"))),
                Some(@core.ArchiveEntry("word/document.xml")),
                Some(
                  @core.Custom(
                    "Formatting not representable in the current Markdown AST was omitted.",
                  ),
                ),
              ),
            )
          } else if warning.has_prefix("Missing DOCX hyperlink target: ") {
            let rid = warning[31:].to_string()
            diagnostics.push(
              @core.warning_diagnostic(
                warning,
                Some(@core.Load(Some("document.xml.rels"))),
                Some(@core.Generated(rid)),
                Some(@core.CheckArchiveIntegrity),
              ),
            )
          } else if warning.has_prefix("Missing DOCX relationship target: ") {
            let rid = warning[34:].to_string()
            diagnostics.push(
              @core.warning_diagnostic(
                warning,
                Some(@core.Load(Some("document.xml.rels"))),
                Some(@core.Generated(rid)),
                Some(@core.CheckArchiveIntegrity),
              ),
            )
          } else if warning.has_prefix(
              "DOCX image reference did not resolve to extracted asset: ",
            ) {
            let path = warning[56:].to_string()
            diagnostics.push(
              @core.warning_diagnostic(
                warning,
                Some(@core.Load(Some("word/media"))),
                Some(@core.ArchiveEntry(path)),
                Some(@core.CheckArchiveIntegrity),
              ),
            )
          } else {
            match @core.embedded_ocr_warning_diagnostic("docx", warning) {
              Some(diagnostic) => diagnostics.push(diagnostic)
              None => ()
            }
          }
      }
    }
  }
  diagnostics
}

///|
async fn ocr_docx_assets(
  assets : Array[@core.OutputAsset],
  config : @ocr.OcrConfig,
) -> (Array[@ast.Block], Array[String], Int, String?) {
  let blocks : Array[@ast.Block] = []
  let warnings : Array[String] = []
  let mut count = 0
  let mut provider : String? = None
  if !config.should_process_embedded_images() || assets.length() == 0 {
    return (blocks, warnings, count, provider)
  }
  for index, asset in assets {
    let result = @ocr.recognize_image_bytes(
      asset.bytes,
      asset.filename,
      config,
      temp_stem="docx-" + (index + 1).to_string(),
    )
    if result.attempted && !result.available {
      @core.push_unique_warning(
        warnings, @core.embedded_ocr_unavailable_warning,
      )
    }
    for warning in result.warnings {
      @core.push_unique_warning(warnings, warning)
    }
    if result.attempted && result.available && result.text == "" {
      @core.push_unique_warning(
        warnings,
        @core.embedded_ocr_empty_warning(asset.filename),
      )
    }
    if result.is_useful() {
      if count == 0 {
        blocks.push(@ast.text_heading(2, "Image OCR"))
      }
      blocks.push(@ast.text_heading(3, asset.filename))
      for paragraph in @core.split_ocr_paragraphs(result.text) {
        blocks.push(@ast.text_paragraph(paragraph))
      }
      count = count + 1
      match provider {
        Some(_) => ()
        None => provider = result.provider
      }
    }
  }
  (blocks, warnings, count, provider)
}

///|
fn render_docx_failure(
  error : @core.ConversionError,
  phase : @core.ConversionPhase?,
  source : @core.DiagnosticSource?,
  hint : @core.DiagnosticHint?,
) -> String {
  @core.error_diagnostic(error, phase, source, hint).render()
}
