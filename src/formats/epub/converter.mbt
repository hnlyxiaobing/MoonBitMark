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
pub async fn EpubConverter::convert(file_path : String) -> @core.ConvertResult {
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
              let title = epub_pkg.metadata.title
              let (assets, asset_warnings) = extract_epub_assets(
                zip,
                epub_pkg.manifest,
                opf_dir,
              )
              for warning in asset_warnings {
                warnings.push(warning)
              }
              let diagnostics = epub_warning_diagnostics(warnings)
              let final_blocks = append_epub_asset_blocks(blocks, assets)
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
  @html.html_to_blocks(xml_string)
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
) -> Array[@ast.Block] {
  if assets.length() == 0 {
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
    }
  }
  diagnostics
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
