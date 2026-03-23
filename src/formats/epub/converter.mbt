// EPUB Converter
// Converts EPUB files to Markdown

///|
/// 将 Array[Byte] 转换为 Bytes
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}

///|
/// Helper function to find the last occurrence of a character

///|
fn find_last_char(s : String, c : Char) -> Int? {
  let mut idx = -1
  let mut i = 0
  for ch in s {
    if ch == c {
      idx = i
    }
    i = i + 1
  }
  if idx >= 0 {
    Some(idx)
  } else {
    None
  }
}

///|
pub fn EpubConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      ext_lower == ".epub"
    }
    None => false
  }
}

///|
pub async fn EpubConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  // 读取 EPUB 文件内容
  let file = @fs.open(file_path, mode=ReadOnly)
  let all_bytes : Array[Byte] = Array::new()

  // 读取文件内容
  while true {
    let buffer : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let bytes_read = file.read(buffer)
    if bytes_read == 0 {
      break
    }
    // 将读取的数据添加到数组
    let mut i = 0
    while i < bytes_read {
      all_bytes.push(buffer[i])
      i = i + 1
    }
  }
  file.close()

  // 将 Array[Byte] 转换为 Bytes
  let epub_data = bytes_from_array(all_bytes)

  // 使用纯 MoonBit libzip 打开 ZIP
  match @libzip.ZipArchive::open(epub_data) {
    Some(zip) =>
      // Parse container.xml to find OPF file
      match
        @libzip.read_file_entry_decompressed(zip, "META-INF/container.xml") {
        Some(container_data) => {
          let opf_path = parse_container_xml(container_data)

          // Get OPF directory
          let opf_dir = match find_last_char(opf_path, '/') {
            Some(idx) => opf_path[0:idx].to_string()
            None => ""
          }

          // Parse OPF file
          match @libzip.read_file_entry_decompressed(zip, opf_path) {
            Some(opf_data) => {
              let epub_pkg = parse_opf(opf_data)
              let warnings : Array[String] = []
              let blocks = build_epub_blocks(epub_pkg.metadata)

              // Process spine items
              for item in epub_pkg.spine {
                let href = epub_pkg.manifest.get(item.idref)
                match href {
                  Some(manifest_item) => {
                    let full_path = if opf_dir == "" {
                      manifest_item.href
                    } else {
                      opf_dir + "/" + manifest_item.href
                    }
                    match @libzip.read_file_entry_decompressed(zip, full_path) {
                      Some(content) =>
                        for block in parse_xhtml_blocks(content) {
                          blocks.push(block)
                        }
                      None =>
                        warnings.push(
                          "Missing spine resource in archive: " + full_path,
                        )
                    }
                  }
                  None =>
                    warnings.push(
                      "Missing manifest item for spine idref: " + item.idref,
                    )
                }
              }

              let metadata = metadata_of_epub(epub_pkg.metadata, opf_path)
              metadata["ocr_mode"] = ctx.ocr.mode.label()
              let title = epub_pkg.metadata.title
              let (assets, asset_warnings) = extract_epub_assets(
                zip,
                epub_pkg.manifest,
                opf_dir,
              )
              for warning in asset_warnings {
                warnings.push(warning)
              }
              let (ocr_blocks, ocr_warnings, ocr_count, ocr_provider) = ocr_epub_assets(
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
              let diagnostics = epub_warning_diagnostics(warnings)
              let final_blocks = append_epub_asset_blocks(
                blocks, assets, ocr_blocks,
              )
              let doc = @ast.Document::{ title, metadata, blocks: final_blocks }
              let rendered_markdown = @ast.render_markdown(doc)
              @core.ConvertResult::markdown_only(rendered_markdown, "epub")
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
                render_epub_failure(
                  @core.ZipError("Failed to read OPF file", Some(opf_path)),
                  Some(@core.Load(Some("opf"))),
                  Some(@core.ArchiveEntry(opf_path)),
                  Some(@core.CheckArchiveIntegrity),
                ),
              )
          }
        }
        None =>
          fail(
            render_epub_failure(
              @core.ZipError(
                "Failed to read container.xml",
                Some("META-INF/container.xml"),
              ),
              Some(@core.Load(Some("container"))),
              Some(@core.ArchiveEntry("META-INF/container.xml")),
              Some(@core.CheckArchiveIntegrity),
            ),
          )
      }
    None =>
      fail(
        render_epub_failure(
          @core.ZipError("Failed to open EPUB file as ZIP archive", None),
          Some(@core.Load(Some("archive"))),
          Some(@core.File(file_path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
  }
}

///|
fn parse_container_xml(data : Bytes) -> String raise {
  // 使用 UTF-8 解码
  let xml_string = @utf8.decode(data) catch {
    _ => {
      // 回退：逐字节转换（ASCII 兼容）
      let mut result = ""
      let mut i = 0
      while i < data.length() {
        let b = data[i]
        result = result + b.to_int().unsafe_to_char().to_string()
        i = i + 1
      }
      result
    }
  }

  match @xml.parse_xml(xml_string) {
    Ok(events) => {
      let mut opf_path = ""

      for event in events {
        match event {
          @xml.ElementStart(evt) =>
            if evt.name == "rootfile" {
              match evt.attributes.get("full-path") {
                Some(path) => opf_path = path
                None => ignore(())
              }
            }
          _ => ignore(())
        }
      }

      if opf_path == "" {
        fail(
          render_epub_failure(
            @core.XmlParseError(
              "Could not find OPF path in container.xml",
              None,
            ),
            Some(@core.Parse(Some("container.xml"))),
            Some(@core.ArchiveEntry("META-INF/container.xml")),
            Some(
              @core.Custom(
                "Verify META-INF/container.xml declares a rootfile full-path.",
              ),
            ),
          ),
        )
      }

      opf_path
    }
    Err(_) =>
      fail(
        render_epub_failure(
          @core.XmlParseError("Failed to parse container.xml", None),
          Some(@core.Parse(Some("container.xml"))),
          Some(@core.ArchiveEntry("META-INF/container.xml")),
          Some(
            @core.Custom(
              "Inspect META-INF/container.xml for malformed XML or invalid encoding.",
            ),
          ),
        ),
      )
  }
}

///|
fn parse_opf(data : Bytes) -> EpubPackage raise {
  // 使用 UTF-8 解码
  let xml_string = @utf8.decode(data) catch {
    _ => {
      // 回退：逐字节转换
      let mut result = ""
      let mut i = 0
      while i < data.length() {
        let b = data[i]
        result = result + b.to_int().unsafe_to_char().to_string()
        i = i + 1
      }
      result
    }
  }
  match @xml.parse_xml(xml_string) {
    Ok(events) => {
      let metadata = EpubMetadata::default()
      let manifest : Map[String, ManifestItem] = Map::new()
      let spine : Array[SpineItem] = Array::new()
      let mut current_element = ""
      let mut in_metadata = false

      for event in events {
        match event {
          @xml.ElementStart(evt) => {
            current_element = evt.name
            if evt.name == "metadata" {
              in_metadata = true
            }
            if evt.name == "item" {
              let id = evt.attributes.get("id")
              let href = evt.attributes.get("href")
              let media_type = evt.attributes.get("media-type")
              match (id, href, media_type) {
                (Some(id_val), Some(href_val), Some(mt_val)) =>
                  manifest.set(id_val, {
                    id: id_val,
                    href: href_val,
                    media_type: mt_val,
                    properties: None,
                  })
                _ => ignore(())
              }
            }
            if evt.name == "itemref" {
              match evt.attributes.get("idref") {
                Some(idref) => spine.push({ idref, linear: true })
                None => ignore(())
              }
            }
          }
          @xml.ElementEnd(evt) => {
            if evt.name == "metadata" {
              in_metadata = false
            }
            current_element = ""
          }
          @xml.TextContent(evt) =>
            if in_metadata {
              if current_element == "dc:title" {
                metadata.title = Some(evt.content)
              }
              if current_element == "dc:creator" {
                metadata.authors.push(evt.content)
              }
              if current_element == "dc:language" {
                metadata.language = Some(evt.content)
              }
              if current_element == "dc:description" {
                metadata.description = Some(evt.content)
              }
            }
        }
      }

      { metadata, manifest, spine, opf_dir: "" }
    }
    Err(_) =>
      fail(
        render_epub_failure(
          @core.XmlParseError("Failed to parse OPF file", None),
          Some(@core.Parse(Some("opf"))),
          None,
          Some(
            @core.Custom("Inspect the OPF package document for malformed XML."),
          ),
        ),
      )
  }
}

///|
fn build_epub_blocks(metadata : EpubMetadata) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  match metadata.title {
    Some(title) if title != "" => blocks.push(@ast.text_heading(1, title))
    _ => ()
  }
  match metadata.authors {
    [author, ..] => blocks.push(@ast.text_paragraph("**Author:** " + author))
    [] => ()
  }
  match metadata.language {
    Some(lang) => blocks.push(@ast.text_paragraph("**Language:** " + lang))
    None => ()
  }
  blocks
}

///|
fn parse_xhtml_blocks(data : Bytes) -> Array[@ast.Block] {
  let xml_string = @utf8.decode(data) catch {
    _ => {
      let mut result = ""
      let mut i = 0
      while i < data.length() {
        let b = data[i]
        result = result + b.to_int().unsafe_to_char().to_string()
        i = i + 1
      }
      result
    }
  }
  normalize_epub_html_blocks(@html.html_to_blocks(xml_string))
}

///|
fn normalize_epub_html_blocks(blocks : Array[@ast.Block]) -> Array[@ast.Block] {
  let result : Array[@ast.Block] = []
  for block in blocks {
    match normalize_epub_block(block) {
      Some(value) =>
        if result.length() == 0 || result[result.length() - 1] != value {
          result.push(value)
        }
      None => ()
    }
  }
  result
}

///|
fn normalize_epub_block(block : @ast.Block) -> @ast.Block? {
  match block {
    @ast.Heading(level, inlines) => {
      let text = plain_text_inlines(inlines)
      if text == "" {
        None
      } else {
        Some(@ast.text_heading(level, text))
      }
    }
    @ast.Paragraph(inlines) => {
      let text = plain_text_inlines(inlines)
      if text == "" {
        None
      } else {
        Some(@ast.text_paragraph(text))
      }
    }
    @ast.List(items, ordered) => {
      let normalized_items : Array[String] = []
      for item in items {
        let text = plain_text_markdownish(item)
        if text != "" {
          normalized_items.push(text)
        }
      }
      if normalized_items.length() == 0 {
        None
      } else {
        Some(@ast.List(normalized_items, ordered))
      }
    }
    @ast.Quote(lines) => {
      let normalized_lines : Array[String] = []
      for line in lines {
        let text = plain_text_markdownish(line)
        if text != "" {
          normalized_lines.push(text)
        }
      }
      if normalized_lines.length() == 0 {
        None
      } else {
        Some(@ast.Quote(normalized_lines))
      }
    }
    @ast.CodeBlock(_, _) => None
    @ast.Table(header, rows) => {
      let normalized_header : Array[String] = []
      for cell in header {
        normalized_header.push(plain_text_markdownish(cell))
      }
      let normalized_rows : Array[Array[String]] = []
      for row in rows {
        let normalized_row : Array[String] = []
        for cell in row {
          normalized_row.push(plain_text_markdownish(cell))
        }
        normalized_rows.push(normalized_row)
      }
      Some(@ast.Table(normalized_header, normalized_rows))
    }
    @ast.HorizontalRule => None
  }
}

///|
fn normalize_epub_text(text : String) -> String {
  let mut result = ""
  let mut previous_was_space = true
  for ch in text.replace(old="\r", new="\n").replace(old="\t", new=" ") {
    let is_space = ch == '\n' || ch == ' '
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
  result.trim().to_string()
}

///|
fn plain_text_inlines(inlines : Array[@ast.Inline]) -> String {
  let mut result = ""
  for inline in inlines {
    result = result + plain_text_inline(inline)
  }
  normalize_epub_text(result)
}

///|
fn plain_text_inline(inline : @ast.Inline) -> String {
  match inline {
    @ast.Text(text) => text
    @ast.Emphasis(children) => plain_text_inlines(children)
    @ast.Strong(children) => plain_text_inlines(children)
    @ast.Link(children, _) => plain_text_inlines(children)
    @ast.Image(_, _) => ""
    @ast.Code(text) => text
    @ast.LineBreak => "\n"
  }
}

///|
fn plain_text_markdownish(text : String) -> String {
  let mut result = ""
  let mut i = 0
  while i < text.length() {
    if text[i] == '`' {
      i = i + 1
      continue
    }
    if text[i] == '[' ||
      (text[i] == '!' && i + 1 < text.length() && text[i + 1] == '[') {
      let (label, consumed) = extract_markdown_link_label(text, i)
      match consumed {
        Some(next_index) => {
          result = result + label
          i = next_index
          continue
        }
        None => ()
      }
    }
    result = result + text[i].to_string()
    i = i + 1
  }
  normalize_epub_text(result)
}

///|
fn extract_markdown_link_label(text : String, start : Int) -> (String, Int?) {
  let mut i = start
  if text[i] == '!' {
    i = i + 1
  }
  if i >= text.length() || text[i] != '[' {
    return ("", None)
  }
  i = i + 1
  let mut label = ""
  while i < text.length() && text[i] != ']' {
    label = label + text[i].to_string()
    i = i + 1
  }
  if i >= text.length() || text[i] != ']' {
    return ("", None)
  }
  if i + 1 >= text.length() || text[i + 1] != '(' {
    return ("", None)
  }
  i = i + 2
  while i < text.length() && text[i] != ')' {
    i = i + 1
  }
  if i >= text.length() {
    return ("", None)
  }
  (label, Some(i + 1))
}

///|
fn metadata_of_epub(
  metadata_source : EpubMetadata,
  opf_path : String,
) -> Map[String, String] {
  let metadata = Map::new()
  metadata["format"] = "epub"
  metadata["opf_path"] = opf_path
  match metadata_source.language {
    Some(language) => metadata["language"] = language
    None => ()
  }
  match metadata_source.publisher {
    Some(publisher) => metadata["publisher"] = publisher
    None => ()
  }
  match metadata_source.date {
    Some(date) => metadata["date"] = date
    None => ()
  }
  match metadata_source.description {
    Some(description) => metadata["description"] = description
    None => ()
  }
  match metadata_source.identifier {
    Some(identifier) => metadata["identifier"] = identifier
    None => ()
  }
  if metadata_source.authors.length() > 0 {
    metadata["author"] = metadata_source.authors.join(", ")
  }
  metadata
}

///|
fn extract_epub_assets(
  archive : @libzip.ZipArchive,
  manifest : Map[String, ManifestItem],
  opf_dir : String,
) -> (Array[@core.OutputAsset], Array[String]) {
  let assets : Array[@core.OutputAsset] = []
  let warnings : Array[String] = []
  let mut index = 1
  for _, item in manifest {
    if is_epub_asset_media_type(item.media_type) {
      let archive_path = if opf_dir == "" {
        item.href
      } else {
        opf_dir + "/" + item.href
      }
      match @libzip.read_file_entry_decompressed(archive, archive_path) {
        Some(bytes) => {
          let filename = "epub-asset-" +
            index.to_string() +
            "." +
            asset_extension(item.href, item.media_type)
          assets.push(@core.OutputAsset::{
            placeholder: epub_asset_placeholder(index),
            filename,
            bytes,
            source: Some(@core.ArchiveEntry(archive_path)),
            hint: Some(@core.CheckArchiveIntegrity),
          })
          index = index + 1
        }
        None => warnings.push("Failed to extract EPUB asset: " + archive_path)
      }
    }
  }
  (assets, warnings)
}

///|
fn is_epub_asset_media_type(media_type : String) -> Bool {
  media_type.has_prefix("image/") ||
  media_type.has_prefix("audio/") ||
  media_type.has_prefix("video/") ||
  media_type == "application/pdf" ||
  media_type == "application/octet-stream"
}

///|
fn append_epub_asset_blocks(
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
    if is_image_asset_filename(asset.filename) {
      result.push(
        @ast.text_paragraph(
          "![" + asset.filename + "](" + asset.placeholder + ")",
        ),
      )
    } else {
      result.push(
        @ast.List(
          ["[" + asset.filename + "](" + asset.placeholder + ")"],
          false,
        ),
      )
    }
  }
  for block in ocr_blocks {
    result.push(block)
  }
  result
}

///|
fn epub_asset_placeholder(index : Int) -> String {
  "moonbitmark-raw://epub/" + index.to_string()
}

///|
fn asset_extension(path : String, media_type : String) -> String {
  match find_last_char(path, '.') {
    Some(index) =>
      if index + 1 < path.length() {
        path[index + 1:].to_lower().to_string()
      } else {
        media_type_extension(media_type)
      }
    None => media_type_extension(media_type)
  }
}

///|
fn media_type_extension(media_type : String) -> String {
  match media_type {
    "image/jpeg" => "jpg"
    "image/jpg" => "jpg"
    "image/png" => "png"
    "image/gif" => "gif"
    "image/webp" => "webp"
    "image/svg+xml" => "svg"
    "audio/mpeg" => "mp3"
    "audio/mp4" => "m4a"
    "video/mp4" => "mp4"
    "application/pdf" => "pdf"
    _ => "bin"
  }
}

///|
fn is_image_asset_filename(filename : String) -> Bool {
  filename.has_suffix(".png") ||
  filename.has_suffix(".jpg") ||
  filename.has_suffix(".jpeg") ||
  filename.has_suffix(".gif") ||
  filename.has_suffix(".webp") ||
  filename.has_suffix(".svg")
}

///|
fn epub_warning_diagnostics(
  warnings : Array[String],
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    if warning.has_prefix("Missing spine resource in archive: ") {
      let path = warning[35:].to_string()
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("spine-resource"))),
          Some(@core.ArchiveEntry(path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning.has_prefix("Missing manifest item for spine idref: ") {
      let idref = warning[39:].to_string()
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("opf-manifest"))),
          Some(@core.Generated(idref)),
          Some(
            @core.Custom(
              "Check whether every spine idref has a matching manifest item in the OPF.",
            ),
          ),
        ),
      )
    } else if warning.has_prefix("Failed to extract EPUB asset: ") {
      let path = warning[30:].to_string()
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("asset"))),
          Some(@core.ArchiveEntry(path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning == "OCR requested but no available backend was found." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("epub")),
          Some(@core.Generated("embedded-image")),
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
          Some(@core.Convert("epub")),
          Some(@core.Generated(warning[50:].to_string())),
          Some(@core.InspectSourceDocument),
        ),
      )
    } else if warning.has_prefix("OCR backend") {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("epub")),
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
async fn ocr_epub_assets(
  assets : Array[@core.OutputAsset],
  config : @ocr.OcrConfig,
) -> (Array[@ast.Block], Array[String], Int, String?) {
  let blocks : Array[@ast.Block] = []
  let warnings : Array[String] = []
  let mut count = 0
  let mut provider : String? = None
  if !config.should_process_embedded_images() {
    return (blocks, warnings, count, provider)
  }
  for index, asset in assets {
    if !is_image_asset_filename(asset.filename) {
      continue
    }
    let result = @ocr.recognize_image_bytes(
      asset.bytes,
      asset.filename,
      config,
      temp_stem="epub-" + (index + 1).to_string(),
    )
    if result.attempted && !result.available {
      push_unique_warning(
        warnings, "OCR requested but no available backend was found.",
      )
    }
    for warning in result.warnings {
      push_unique_warning(warnings, warning)
    }
    if result.attempted && result.available && result.text == "" {
      push_unique_warning(
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
fn push_unique_warning(warnings : Array[String], warning : String) -> Unit {
  for existing in warnings {
    if existing == warning {
      return
    }
  }
  warnings.push(warning)
}

///|
fn render_epub_failure(
  error : @core.ConversionError,
  phase : @core.ConversionPhase?,
  source : @core.DiagnosticSource?,
  hint : @core.DiagnosticHint?,
) -> String {
  @core.error_diagnostic(error, phase, source, hint).render()
}
