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
  let file = @fs.open(file_path, mode=ReadOnly)
  let all_bytes : Array[Byte] = Array::new()

  while true {
    let buffer : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let bytes_read = file.read(buffer)
    if bytes_read == 0 {
      break
    }
    for i in 0..<bytes_read {
      all_bytes.push(buffer[i])
    }
  }
  file.close()

  let bytes = bytes_from_array(all_bytes)

  match @libzip.ZipArchive::open(bytes) {
    Some(archive) => {
      let relationships = parse_docx_relationships(archive)
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
            xml_string, relationships, asset_placeholders,
          )
          let metadata = Map::new()
          metadata["format"] = "docx"
          metadata["container"] = "zip"
          metadata["ocr_mode"] = ctx.ocr.mode.label()
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
          if ocr_count > 0 {
            metadata["ocr_embedded_image_count"] = ocr_count.to_string()
          }
          match ocr_provider {
            Some(provider) => metadata["ocr_provider"] = provider
            None => ()
          }
          let diagnostics = docx_warning_diagnostics(file_path, warnings)
          let title = file_stem(file_path)
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
/// Convert Array[Byte] to Bytes
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}

///|
fn extract_blocks_from_docx_xml(
  xml : String,
  relationships : Map[String, String],
  asset_placeholders : Map[String, String],
) -> (Array[@ast.Block], Array[String]) raise {
  match @xml.parse_xml(xml) {
    Ok(events) => process_docx_events(events, relationships, asset_placeholders)
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
priv struct DocxContext {
  relationships : Map[String, String]
  asset_placeholders : Map[String, String]
  mut in_paragraph : Bool
  mut in_paragraph_properties : Bool
  mut in_run_properties : Bool
  mut in_text : Bool
  mut current_text : String
  mut current_inlines : Array[@ast.Inline]
  mut heading_level : Int
  mut in_list : Bool
  mut run_bold : Bool
  mut run_italic : Bool
  mut current_hyperlink : String?
  mut pending_image_alt : String?
  blocks : Array[@ast.Block]
  warnings : Array[String]
}

///|
fn process_docx_events(
  events : Array[@xml.ParseEvent],
  relationships : Map[String, String],
  asset_placeholders : Map[String, String],
) -> (Array[@ast.Block], Array[String]) {
  let ctx = DocxContext::{
    relationships,
    asset_placeholders,
    in_paragraph: false,
    in_paragraph_properties: false,
    in_run_properties: false,
    in_text: false,
    current_text: "",
    current_inlines: [],
    heading_level: 0,
    in_list: false,
    run_bold: false,
    run_italic: false,
    current_hyperlink: None,
    pending_image_alt: None,
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
  } else if local_name == "b" && ctx.in_run_properties {
    ctx.run_bold = true
  } else if local_name == "i" && ctx.in_run_properties {
    ctx.run_italic = true
  } else if ctx.in_run_properties && is_unsupported_docx_run_style(local_name) {
    push_warning_once(
      ctx.warnings,
      "Dropped unsupported DOCX run style: " + local_name,
    )
  } else if local_name == "hyperlink" {
    ctx.current_hyperlink = resolve_docx_hyperlink(ctx.relationships, attrs)
    if ctx.current_hyperlink == None {
      match map_get_any(attrs, ["r:id", "id"]) {
        Some(rid) =>
          push_warning_once(
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
  } else if local_name == "pPr" {
    ctx.in_paragraph_properties = false
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
  ctx.current_inlines = []
  ctx.current_text = ""
  ctx.heading_level = 0
  ctx.in_list = false
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
    if ctx.heading_level > 0 {
      ctx.blocks.push(@ast.Heading(ctx.heading_level, ctx.current_inlines))
    } else if ctx.in_list {
      ctx.blocks.push(
        @ast.List([@ast.render_inlines(ctx.current_inlines)], false),
      )
    } else {
      ctx.blocks.push(@ast.Paragraph(ctx.current_inlines))
    }
  }
  ctx.in_paragraph = false
  ctx.current_inlines = []
  ctx.current_text = ""
  ctx.heading_level = 0
  ctx.in_list = false
  ctx.current_hyperlink = None
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
fn apply_docx_paragraph_style(ctx : DocxContext, style : String?) -> Unit {
  match style {
    Some(value) => {
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
                _ => file_name_only(target)
              }
              ctx.current_inlines.push(@ast.Image(alt, placeholder))
              ctx.pending_image_alt = None
            }
            None =>
              push_warning_once(
                ctx.warnings,
                "DOCX image reference did not resolve to extracted asset: " +
                target,
              )
          }
        None =>
          push_warning_once(
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
                _ => resolve_archive_target("word", target)
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
fn resolve_archive_target(base_dir : String, target : String) -> String {
  if target.contains("://") || target.has_prefix("#") {
    return target
  }
  let segments = split_path_segments(base_dir)
  for part in split_path_segments(target) {
    if part == "." || part == "" {
      continue
    }
    if part == ".." {
      ignore(segments.pop())
    } else {
      segments.push(part)
    }
  }
  segments.join("/")
}

///|
fn split_path_segments(path : String) -> Array[String] {
  let segments : Array[String] = []
  for part in path.replace(old="\\", new="/").split("/").to_array() {
    if part != "" {
      segments.push(part.to_string())
    }
  }
  segments
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
fn push_warning_once(warnings : Array[String], warning : String) -> Unit {
  for existing in warnings {
    if existing == warning {
      return
    }
  }
  warnings.push(warning)
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
fn file_name_only(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  match find_last_char(normalized, '/') {
    Some(index) => normalized[index + 1:].to_string()
    None => normalized
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
          let filename = "docx-image-" +
            index.to_string() +
            "." +
            path_extension(entry)
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
  "moonbitmark-raw://docx/" + index.to_string()
}

///|
fn path_extension(path : String) -> String {
  match find_last_char(path, '.') {
    Some(index) =>
      if index + 1 < path.length() {
        path[index + 1:].to_lower().to_string()
      } else {
        "bin"
      }
    None => "bin"
  }
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
    } else if warning.has_prefix("Failed to extract DOCX asset: ") {
      let path = warning[29:].to_string()
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("word/media"))),
          Some(@core.ArchiveEntry(path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning.has_prefix("Dropped unsupported DOCX run style: ") {
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
    } else if warning == "OCR requested but no available backend was found." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("docx")),
          Some(@core.File("embedded-image")),
          Some(
            @core.Custom(
              "Install a supported OCR backend or switch to --ocr-backend mock for tests.",
            ),
          ),
        ),
      )
    } else if warning.has_prefix(
        "OCR backend returned empty text for embedded asset: ",
      ) {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("docx")),
          Some(@core.Generated(warning[50:].to_string())),
          Some(@core.InspectSourceDocument),
        ),
      )
    } else if warning.has_prefix("OCR backend") {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("docx")),
          Some(@core.Generated("embedded-image")),
          Some(
            @core.Custom("Inspect OCR bridge stderr or backend installation."),
          ),
        ),
      )
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
      push_warning_once(
        warnings, "OCR requested but no available backend was found.",
      )
    }
    for warning in result.warnings {
      push_warning_once(warnings, warning)
    }
    if result.attempted && result.available && result.text == "" {
      push_warning_once(
        warnings,
        "OCR backend returned empty text for embedded asset: " + asset.filename,
      )
    }
    if result.is_useful() {
      if count == 0 {
        blocks.push(@ast.text_heading(2, "Image OCR"))
      }
      blocks.push(@ast.text_heading(3, asset.filename))
      for paragraph in split_ocr_paragraphs(result.text) {
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
fn split_ocr_paragraphs(text : String) -> Array[String] {
  let paragraphs : Array[String] = []
  for chunk in text.replace(old="\r\n", new="\n").split("\n\n").to_array() {
    let trimmed = chunk.trim().to_string()
    if trimmed != "" {
      paragraphs.push(trimmed)
    }
  }
  if paragraphs.length() == 0 && text.trim() != "" {
    [text.trim().to_string()]
  } else {
    paragraphs
  }
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
