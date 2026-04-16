// EPUB Converter
// Converts EPUB files to Markdown

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
  let epub_data = @core.read_file_bytes(file_path)

  // 使用纯 MoonBit libzip 打开 ZIP
  match @libzip.ZipArchive::open(epub_data) {
    Some(zip) =>
      // Parse container.xml to find OPF file
      match
        @libzip.read_file_entry_decompressed(zip, "META-INF/container.xml") {
        Some(container_data) => {
          let opf_path = parse_container_xml(container_data)
          let opf_dir = @core.path_dirname(opf_path)

          // Parse OPF file
          match @libzip.read_file_entry_decompressed(zip, opf_path) {
            Some(opf_data) => {
              let epub_pkg = parse_opf(opf_data)
              let warnings : Array[String] = []
              let (blocks, annotations) = build_epub_blocks_with_annotations(
                epub_pkg.metadata,
                opf_path,
              )
              if epub_has_navigation_manifest(epub_pkg.manifest) {
                blocks.push(@ast.text_heading(2, "table of contents"))
                annotations.push(
                  epub_block_annotation(None, opf_path, "table-of-contents"),
                )
              }

              // Process spine items
              for item in epub_pkg.spine {
                let href = epub_pkg.manifest.get(item.idref)
                match href {
                  Some(manifest_item) => {
                    let full_path = @core.join_path(opf_dir, manifest_item.href)
                    match @libzip.read_file_entry_decompressed(zip, full_path) {
                      Some(content) => {
                        let spine_blocks = parse_xhtml_blocks(
                          content, full_path,
                        )
                        let chapter = epub_chapter_hint(spine_blocks)
                        for block in spine_blocks {
                          blocks.push(block)
                          annotations.push(
                            epub_block_annotation(
                              chapter,
                              full_path,
                              epub_block_kind(block),
                            ),
                          )
                        }
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
              let (ocr_blocks, ocr_warnings, ocr_count, ocr_provider) = ocr_epub_assets(
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
                attempted=ctx.ocr.should_process_embedded_images() &&
                  assets.length() > 0,
                available=ocr_provider != None,
              )
              let diagnostics = epub_warning_diagnostics(warnings)
              let final_blocks = append_epub_asset_blocks(
                blocks, assets, ocr_blocks,
              )
              let final_annotations = @ast.normalize_annotations(
                annotations,
                final_blocks.length(),
              )
              let doc = @ast.document(title, metadata, final_blocks).with_annotations(
                final_annotations,
              )
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
            current_element = strip_epub_namespace(evt.name)
            if current_element == "metadata" {
              in_metadata = true
            }
            if current_element == "item" {
              let id = evt.attributes.get("id")
              let href = evt.attributes.get("href")
              let media_type = evt.attributes.get("media-type")
              let properties = evt.attributes.get("properties")
              match (id, href, media_type) {
                (Some(id_val), Some(href_val), Some(mt_val)) =>
                  manifest.set(id_val, {
                    id: id_val,
                    href: href_val,
                    media_type: mt_val,
                    properties,
                  })
                _ => ignore(())
              }
            }
            if current_element == "itemref" {
              match evt.attributes.get("idref") {
                Some(idref) =>
                  spine.push({
                    idref,
                    linear: evt.attributes.get("linear") != Some("no"),
                  })
                None => ignore(())
              }
            }
          }
          @xml.ElementEnd(evt) => {
            if strip_epub_namespace(evt.name) == "metadata" {
              in_metadata = false
            }
            current_element = ""
          }
          @xml.TextContent(evt) =>
            if in_metadata {
              if current_element == "title" {
                metadata.title = Some(evt.content)
              }
              if current_element == "creator" {
                metadata.authors.push(evt.content)
              }
              if current_element == "language" {
                metadata.language = Some(evt.content)
              }
              if current_element == "description" {
                metadata.description = Some(evt.content)
              }
              if current_element == "publisher" {
                metadata.publisher = Some(evt.content)
              }
              if current_element == "identifier" {
                metadata.identifier = Some(evt.content)
              }
              if current_element == "date" {
                metadata.date = Some(evt.content)
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

fn build_epub_blocks_with_annotations(
  metadata : EpubMetadata,
  resource : String,
) -> (Array[@ast.Block], Array[@ast.BlockAnnotation]) {
  let blocks : Array[@ast.Block] = []
  let annotations : Array[@ast.BlockAnnotation] = []
  match metadata.title {
    Some(title) if title != "" => {
      blocks.push(@ast.text_heading(1, title))
      annotations.push(
        epub_block_annotation(Some(title), resource, "metadata-title"),
      )
    }
    _ => ()
  }
  (blocks, annotations)
}

///|
fn epub_block_kind(block : @ast.Block) -> String {
  match block {
    @ast.Heading(_, _) => "chapter-heading"
    @ast.Table(_, _) => "chapter-table"
    @ast.List(_, _) => "chapter-list"
    @ast.Block::Image(_, _, _) => "chapter-image"
    _ => "chapter-block"
  }
}

///|
fn epub_chapter_hint(blocks : Array[@ast.Block]) -> String? {
  for block in blocks {
    match block {
      @ast.Heading(_, inlines) => {
        let title = normalize_epub_text(@ast.plain_text_of_inlines(inlines))
        if title != "" {
          return Some(title)
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn epub_block_annotation(
  chapter : String?,
  resource : String,
  kind : String,
) -> @ast.BlockAnnotation {
  let source_hint = match chapter {
    Some(value) if value != "" => Some("chapter: " + value)
    _ => None
  }
  @ast.BlockAnnotation::{
    id: "",
    source_hint,
    origin_hint: Some("resource: " + resource + "; kind: " + kind),
    diagnostics: [],
  }
}

///|
fn parse_xhtml_blocks(data : Bytes, archive_path : String) -> Array[@ast.Block] {
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
  match parse_epub_special_xhtml(xml_string, archive_path) {
    Some(blocks) => return blocks
    None => ()
  }
  let xml_blocks = parse_epub_xhtml_via_xml(xml_string)
  if xml_blocks.length() > 0 {
    return finalize_epub_blocks(xml_blocks)
  }
  finalize_epub_blocks(
    normalize_epub_html_blocks(@html.html_to_blocks(xml_string)),
  )
}

///|
fn parse_epub_special_xhtml(
  xml_string : String,
  archive_path : String,
) -> Array[@ast.Block]? {
  if !is_epub_gutenberg_document(xml_string, archive_path) {
    return None
  }
  if is_epub_gutenberg_footer_document(xml_string) {
    return Some([])
  }
  Some(parse_epub_gutenberg_document(xml_string))
}

///|
fn is_epub_gutenberg_document(
  xml_string : String,
  archive_path : String,
) -> Bool {
  archive_path.contains("60153-h-") ||
  xml_string.contains("Project Gutenberg eBook")
}

///|
fn is_epub_gutenberg_footer_document(xml_string : String) -> Bool {
  xml_string.contains("Recent Fine Art Books") ||
  xml_string.contains("For particulars apply to the Publishers")
}

///|
fn parse_epub_gutenberg_document(xml_string : String) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  let body = extract_epub_body(xml_string)
  for block in extract_epub_gutenberg_prelude(body) {
    blocks.push(block)
  }
  let mut rest = strip_epub_gutenberg_containers(body)
  while rest != "" {
    match find_next_epub_block_start(rest) {
      Some((index, tag, level)) => {
        if index > 0 {
          rest = rest[index:].to_string()
        }
        match extract_epub_tag_block(rest, tag) {
          Some((fragment, remaining)) => {
            match parse_epub_gutenberg_fragment(fragment, tag, level) {
              Some(block) =>
                if blocks.length() == 0 || blocks[blocks.length() - 1] != block {
                  blocks.push(block)
                }
              None => ()
            }
            rest = remaining
          }
          None => break
        }
      }
      None => break
    }
  }
  normalize_gutenberg_blocks(finalize_epub_blocks(blocks))
}

///|
fn extract_epub_gutenberg_prelude(body : String) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  match extract_epub_div_with_marker(body, "pg-boilerplate") {
    Some(boilerplate) =>
      match extract_epub_tag_block(boilerplate, "h2") {
        Some((fragment, _)) =>
          match parse_epub_gutenberg_fragment(fragment, "h2", 2) {
            Some(block) => blocks.push(block)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  blocks
}

///|
fn extract_epub_body(xml_string : String) -> String {
  match xml_string.find("<body") {
    Some(body_start) =>
      match xml_string[body_start:].to_string().find(">") {
        Some(body_tag_end_rel) => {
          let content_start = body_start + body_tag_end_rel + 1
          match xml_string[content_start:].to_string().find("</body>") {
            Some(body_end_rel) =>
              xml_string[content_start:content_start + body_end_rel].to_string()
            None => xml_string[content_start:].to_string()
          }
        }
        None => xml_string
      }
    None => xml_string
  }
}

///|
fn strip_epub_gutenberg_containers(body : String) -> String {
  let mut text = body
  for
    marker in [
      "pg-boilerplate", "pgheader", "pg-footer", "pg_machine-header", "pg-machine-header",
    ] {
    text = strip_epub_divs_with_marker(text, marker)
  }
  text = strip_epub_tag_blocks(text, "table")
  text = strip_epub_tag_blocks(text, "script")
  text = strip_epub_tag_blocks(text, "style")
  text
}

///|
fn strip_epub_divs_with_marker(text : String, marker : String) -> String {
  let mut result = text
  while result.contains("<div") && result.contains(marker) {
    match extract_epub_div_range(result, marker) {
      Some((div_start, div_end)) =>
        result = result[:div_start].to_string() + result[div_end:].to_string()
      None => break
    }
  }
  result
}

///|
fn extract_epub_div_with_marker(text : String, marker : String) -> String? {
  match extract_epub_div_range(text, marker) {
    Some((div_start, div_end)) => Some(text[div_start:div_end].to_string())
    None => None
  }
}

///|
fn extract_epub_div_range(text : String, marker : String) -> (Int, Int)? {
  match text.find(marker) {
    Some(marker_index) =>
      match find_last_epub_substring(text[:marker_index].to_string(), "<div") {
        Some(div_start) =>
          match find_matching_epub_div_end(text, div_start) {
            Some(div_end) => Some((div_start, div_end))
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn find_last_epub_substring(text : String, pattern : String) -> Int? {
  if pattern == "" || text.length() < pattern.length() {
    return None
  }
  let mut last : Int? = None
  let mut index = 0
  let max_start = text.length() - pattern.length()
  while index <= max_start {
    if text[index:index + pattern.length()].to_string() == pattern {
      last = Some(index)
    }
    index = index + 1
  }
  last
}

///|
fn find_matching_epub_div_end(text : String, div_start : Int) -> Int? {
  let mut depth = 0
  let mut index = div_start
  while index < text.length() {
    let remaining = text[index:].to_string()
    let next_open = remaining.find("<div")
    let next_close = remaining.find("</div>")
    match (next_open, next_close) {
      (Some(open_rel), Some(close_rel)) =>
        if open_rel < close_rel {
          depth = depth + 1
          index = index + open_rel + 4
        } else {
          depth = depth - 1
          index = index + close_rel + 6
          if depth == 0 {
            return Some(index)
          }
        }
      (Some(open_rel), None) => {
        depth = depth + 1
        index = index + open_rel + 4
      }
      (None, Some(close_rel)) => {
        depth = depth - 1
        index = index + close_rel + 6
        if depth == 0 {
          return Some(index)
        }
      }
      (None, None) => break
    }
  }
  None
}

///|
fn strip_epub_tag_blocks(text : String, tag : String) -> String {
  let mut result = text
  let open_marker = "<" + tag
  let close_marker = "</" + tag + ">"
  while result.contains(open_marker) {
    match result.find(open_marker) {
      Some(start) =>
        match result[start:].to_string().find(close_marker) {
          Some(close_rel) => {
            let close_end = start + close_rel + close_marker.length()
            result = result[:start].to_string() + result[close_end:].to_string()
          }
          None => break
        }
      None => break
    }
  }
  result
}

///|
fn find_next_epub_block_start(text : String) -> (Int, String, Int)? {
  let mut best_index = text.length()
  let mut best_tag = ""
  let mut best_level = 0
  match text.find("<h1") {
    Some(index) if index < best_index => {
      best_index = index
      best_tag = "h1"
      best_level = 1
    }
    _ => ()
  }
  match text.find("<h2") {
    Some(index) if index < best_index => {
      best_index = index
      best_tag = "h2"
      best_level = 2
    }
    _ => ()
  }
  match text.find("<h3") {
    Some(index) if index < best_index => {
      best_index = index
      best_tag = "h3"
      best_level = 3
    }
    _ => ()
  }
  match text.find("<h4") {
    Some(index) if index < best_index => {
      best_index = index
      best_tag = "h4"
      best_level = 4
    }
    _ => ()
  }
  match text.find("<h5") {
    Some(index) if index < best_index => {
      best_index = index
      best_tag = "h5"
      best_level = 5
    }
    _ => ()
  }
  match text.find("<h6") {
    Some(index) if index < best_index => {
      best_index = index
      best_tag = "h6"
      best_level = 6
    }
    _ => ()
  }
  match text.find("<p") {
    Some(index) if index < best_index => {
      best_index = index
      best_tag = "p"
      best_level = 0
    }
    _ => ()
  }
  match text.find("<div") {
    Some(index) if index < best_index => {
      best_index = index
      best_tag = "div"
      best_level = 0
    }
    _ => ()
  }
  if best_tag == "" {
    None
  } else {
    Some((best_index, best_tag, best_level))
  }
}

///|
fn extract_epub_tag_block(text : String, tag : String) -> (String, String)? {
  let open_marker = "<" + tag
  let close_marker = "</" + tag + ">"
  match text.find(open_marker) {
    Some(start) =>
      match text[start:].to_string().find(close_marker) {
        Some(close_rel) => {
          let close_end = start + close_rel + close_marker.length()
          Some(
            (text[start:close_end].to_string(), text[close_end:].to_string()),
          )
        }
        None => None
      }
    None => None
  }
}

///|
fn parse_epub_gutenberg_fragment(
  fragment : String,
  tag : String,
  level : Int,
) -> @ast.Block? {
  if tag == "div" {
    let div_text = sanitize_epub_text(
      strip_epub_markup(epub_fragment_inner_text(fragment)),
    )
    if div_text == "" ||
      is_epub_noise_text(div_text) ||
      is_epub_div_block_noise(div_text) {
      return None
    }
    return Some(@ast.text_paragraph(div_text))
  }
  let text = sanitize_epub_text(
    strip_epub_markup(
      epub_fragment_inner_text(fragment)
      .replace(old="<br/>", new="\n")
      .replace(old="<br />", new="\n")
      .replace(old="<br>", new="\n"),
    ),
  )
  if text == "" || is_epub_noise_text(text) {
    return None
  }
  if level > 0 {
    Some(@ast.text_heading(level, normalize_epub_heading_text(text)))
  } else {
    Some(@ast.text_paragraph(text))
  }
}

///|
fn epub_fragment_inner_text(fragment : String) -> String {
  match fragment.find(">") {
    Some(start_end) => {
      let content_start = start_end + 1
      match find_last_epub_substring(fragment, "</") {
        Some(end_start) if end_start >= content_start =>
          fragment[content_start:end_start].to_string()
        _ => fragment[content_start:].to_string()
      }
    }
    None => fragment
  }
}

///|
fn normalize_epub_heading_text(text : String) -> String {
  normalize_epub_text(text)
  .replace(old="\"/", new=" ")
  .replace(old="“/", new=" ")
  .replace(old=" / ", new=" ")
}

///|
fn is_epub_div_block_noise(text : String) -> Bool {
  let normalized = text.to_lower().to_string()
  normalized == "[image unavailable.]" ||
  normalized.contains("contents.") ||
  normalized.contains("list of illustrations")
}

///|
fn strip_epub_markup(text : String) -> String {
  let mut result = ""
  let mut inside_tag = false
  for ch in text {
    if ch == '<' {
      inside_tag = true
      continue
    }
    if ch == '>' {
      inside_tag = false
      continue
    }
    if !inside_tag {
      result = result + ch.to_string()
    }
  }
  result
  .replace(old="&nbsp;", new=" ")
  .replace(old="&#160;", new=" ")
  .replace(old="&amp;", new="&")
  .replace(old="&quot;", new="\"")
}

///|
fn strip_epub_namespace(name : String) -> String {
  if name.contains(":") {
    match name.find(":") {
      Some(index) => name[index + 1:].to_string()
      None => name
    }
  } else {
    name
  }
}

///|
fn parse_epub_xhtml_via_xml(xml_string : String) -> Array[@ast.Block] {
  match @xml.parse_xml(xml_string) {
    Ok(events) => build_epub_blocks_from_xml_events(events)
    Err(_) => []
  }
}

///|
fn build_epub_blocks_from_xml_events(
  events : Array[@xml.ParseEvent],
) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  let mut inside_body = false
  let mut ignored_depth = 0
  let mut current_block_tag = ""
  let mut current_block_text = ""
  let mut current_heading_level = 0
  let current_list_items : Array[Array[@ast.Inline]] = []
  let mut current_list_ordered = false
  let tag_stack : Array[String] = []

  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let tag = strip_epub_namespace(evt.name).to_lower().to_string()
        tag_stack.push(tag)
        if tag == "body" {
          inside_body = true
          continue
        }
        if !inside_body {
          continue
        }
        if ignored_depth > 0 {
          ignored_depth = ignored_depth + 1
          continue
        }
        if is_epub_ignored_xml_tag(tag) {
          ignored_depth = 1
          continue
        }
        if tag == "br" {
          if current_block_tag != "" {
            current_block_text = append_epub_xml_text(current_block_text, "\n")
          }
          continue
        }
        if tag == "hr" {
          flush_epub_xml_text_block(
            blocks, current_block_tag, current_block_text, current_heading_level,
          )
          current_block_tag = ""
          current_block_text = ""
          current_heading_level = 0
          flush_epub_xml_list(blocks, current_list_items, current_list_ordered)
          blocks.push(@ast.HorizontalRule)
          continue
        }
        if tag == "img" {
          let alt = sanitize_epub_text(evt.attributes.get("alt").unwrap_or(""))
          let src = evt.attributes.get("src").unwrap_or("")
          if alt != "" {
            if current_block_tag == "li" || current_block_tag == "p" {
              current_block_text = append_epub_xml_text(current_block_text, alt)
            } else {
              flush_epub_xml_list(
                blocks, current_list_items, current_list_ordered,
              )
              blocks.push(@ast.Paragraph([@ast.Image(alt, src)]))
            }
          }
          continue
        }
        if tag == "ul" || tag == "ol" {
          flush_epub_xml_text_block(
            blocks, current_block_tag, current_block_text, current_heading_level,
          )
          current_block_tag = ""
          current_block_text = ""
          current_heading_level = 0
          flush_epub_xml_list(blocks, current_list_items, current_list_ordered)
          current_list_ordered = tag == "ol"
          continue
        }
        if tag == "li" {
          flush_epub_xml_text_block(
            blocks, current_block_tag, current_block_text, current_heading_level,
          )
          current_block_tag = "li"
          current_block_text = ""
          current_heading_level = 0
          continue
        }
        if is_epub_xml_block_tag(tag) {
          flush_epub_xml_text_block(
            blocks, current_block_tag, current_block_text, current_heading_level,
          )
          flush_epub_xml_list(blocks, current_list_items, current_list_ordered)
          current_block_tag = tag
          current_block_text = ""
          current_heading_level = epub_xml_heading_level(tag)
          continue
        }
      }
      @xml.ElementEnd(evt) => {
        let tag = strip_epub_namespace(evt.name).to_lower().to_string()
        if tag_stack.length() > 0 {
          ignore(tag_stack.pop())
        }
        if tag == "body" {
          inside_body = false
        }
        if !inside_body && tag != "body" {
          continue
        }
        if ignored_depth > 0 {
          ignored_depth = ignored_depth - 1
          continue
        }
        if tag == "li" {
          let text = sanitize_epub_text(current_block_text)
          if text != "" && !is_epub_noise_text(text) {
            current_list_items.push(@ast.text_inlines(text))
          }
          current_block_tag = ""
          current_block_text = ""
          current_heading_level = 0
          continue
        }
        if tag == "ul" || tag == "ol" {
          flush_epub_xml_list(blocks, current_list_items, current_list_ordered)
          continue
        }
        if current_block_tag == tag {
          flush_epub_xml_text_block(
            blocks, current_block_tag, current_block_text, current_heading_level,
          )
          current_block_tag = ""
          current_block_text = ""
          current_heading_level = 0
        }
      }
      @xml.TextContent(evt) => {
        if !inside_body || ignored_depth > 0 {
          continue
        }
        if current_block_tag != "" {
          current_block_text = append_epub_xml_text(
            current_block_text,
            evt.content,
          )
        }
      }
    }
  }

  flush_epub_xml_text_block(
    blocks, current_block_tag, current_block_text, current_heading_level,
  )
  flush_epub_xml_list(blocks, current_list_items, current_list_ordered)
  normalize_gutenberg_blocks(blocks)
}

///|
fn append_epub_xml_text(current : String, addition : String) -> String {
  if current == "" {
    addition
  } else {
    current + addition
  }
}

///|
fn flush_epub_xml_text_block(
  blocks : Array[@ast.Block],
  tag : String,
  text : String,
  heading_level : Int,
) -> Unit {
  let normalized = sanitize_epub_text(text)
  if normalized == "" || is_epub_noise_text(normalized) {
    return
  }
  if tag == "li" {
    return
  }
  if heading_level > 0 {
    blocks.push(@ast.text_heading(heading_level, normalized))
  } else {
    blocks.push(@ast.text_paragraph(normalized))
  }
}

///|
fn flush_epub_xml_list(
  blocks : Array[@ast.Block],
  items : Array[Array[@ast.Inline]],
  ordered : Bool,
) -> Unit {
  if items.length() == 0 {
    return
  }
  blocks.push(@ast.List(items, ordered))
  while items.length() > 0 {
    ignore(items.pop())
  }
}

///|
fn is_epub_xml_block_tag(tag : String) -> Bool {
  tag == "p" ||
  tag == "h1" ||
  tag == "h2" ||
  tag == "h3" ||
  tag == "h4" ||
  tag == "h5" ||
  tag == "h6" ||
  tag == "blockquote"
}

///|
fn is_epub_ignored_xml_tag(tag : String) -> Bool {
  tag == "head" ||
  tag == "style" ||
  tag == "script" ||
  tag == "svg" ||
  tag == "math" ||
  tag == "table" ||
  tag == "thead" ||
  tag == "tbody" ||
  tag == "tfoot" ||
  tag == "tr" ||
  tag == "td" ||
  tag == "th"
}

///|
fn epub_xml_heading_level(tag : String) -> Int {
  match tag {
    "h1" => 1
    "h2" => 2
    "h3" => 3
    "h4" => 4
    "h5" => 5
    "h6" => 6
    _ => 0
  }
}

///|
fn normalize_gutenberg_blocks(blocks : Array[@ast.Block]) -> Array[@ast.Block] {
  let chapter_index = find_first_epub_chapter_heading(blocks)
  let result : Array[@ast.Block] = []
  match chapter_index {
    Some(index) => {
      for i = 0; i < index; i = i + 1 {
        let block = blocks[i]
        if should_keep_epub_frontmatter_block(block) {
          result.push(block)
        }
      }
      for i = index; i < blocks.length(); i = i + 1 {
        result.push(blocks[i])
      }
      result
    }
    None => blocks
  }
}

///|
fn find_first_epub_chapter_heading(blocks : Array[@ast.Block]) -> Int? {
  for i, block in blocks {
    match block {
      @ast.Heading(_, inlines) => {
        let text = normalize_epub_text(plain_text_inlines(inlines))
          .to_upper()
          .to_string()
        if text.has_prefix("CHAPTER I") || text.has_prefix("CHAPTER 1") {
          return Some(i)
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn should_keep_epub_frontmatter_block(block : @ast.Block) -> Bool {
  let text = epub_block_text(block)
  if text == "" {
    return false
  }
  match block {
    @ast.Heading(_, _) => {
      let normalized = normalize_epub_text(text).to_lower().to_string()
      normalized.contains("project gutenberg eBook".to_lower()) ||
      normalized == "table of contents" ||
      normalized ==
      "the project gutenberg ebook of winter sports in switzerland, by e. f. benson"
    }
    @ast.Paragraph(_) => {
      let normalized = normalize_epub_text(text).to_lower().to_string()
      normalized.has_prefix("title: ") ||
      normalized.has_prefix("author: ") ||
      normalized.has_prefix("illustrator: ") ||
      normalized.has_prefix("photographer: ") ||
      normalized.has_prefix("release date: ") ||
      normalized.has_prefix("language: ") ||
      normalized.has_prefix("credits: ")
    }
    @ast.List(_, _) => false
    @ast.Quote(_) => false
    @ast.CodeBlock(_, _) => false
    @ast.Table(_, _) => false
    @ast.Block::Image(_, _, _) => false
    @ast.HorizontalRule => false
  }
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
fn finalize_epub_blocks(blocks : Array[@ast.Block]) -> Array[@ast.Block] {
  trim_epub_trailing_gutenberg_blocks(blocks).filter(block => {
    !is_epub_block_noise(block)
  })
}

///|
fn normalize_epub_block(block : @ast.Block) -> @ast.Block? {
  match block {
    @ast.Heading(level, inlines) => {
      let text = sanitize_epub_text(plain_text_inlines(inlines))
      if text == "" || is_epub_noise_text(text) {
        None
      } else {
        Some(@ast.text_heading(level, text))
      }
    }
    @ast.Paragraph(inlines) => {
      let text = sanitize_epub_text(plain_text_inlines(inlines))
      if text == "" || is_epub_noise_text(text) {
        None
      } else {
        Some(@ast.text_paragraph(text))
      }
    }
    @ast.List(items, ordered) => {
      let normalized_items : Array[Array[@ast.Inline]] = []
      for item in items {
        let text = sanitize_epub_text(@ast.plain_text_of_inlines(item))
        if text != "" && !is_epub_noise_text(text) {
          normalized_items.push(@ast.text_inlines(text))
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
        let text = sanitize_epub_text(plain_text_markdownish(line))
        if text != "" && !is_epub_noise_text(text) {
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
      let normalized_header : Array[Array[@ast.Inline]] = []
      for cell in header {
        normalized_header.push(
          @ast.text_inlines(
            plain_text_markdownish(@ast.plain_text_of_inlines(cell)),
          ),
        )
      }
      let normalized_rows : Array[Array[Array[@ast.Inline]]] = []
      for row in rows {
        let normalized_row : Array[Array[@ast.Inline]] = []
        for cell in row {
          normalized_row.push(
            @ast.text_inlines(
              plain_text_markdownish(@ast.plain_text_of_inlines(cell)),
            ),
          )
        }
        normalized_rows.push(normalized_row)
      }
      Some(@ast.Table(normalized_header, normalized_rows))
    }
    @ast.Block::Image(alt, src, _) => {
      let next_alt = sanitize_epub_text(alt)
      if next_alt == "" && src == "" {
        None
      } else {
        Some(@ast.Block::Image(next_alt, src, None))
      }
    }
    @ast.HorizontalRule => None
  }
}

///|
fn sanitize_epub_text(text : String) -> String {
  let mut result = normalize_epub_text(text)
  if is_epub_reader_notice(result) || is_epub_control_cluster(result) {
    return ""
  }
  result = strip_epub_media_tokens(result)
  if is_epub_media_fragment(result) {
    return ""
  }
  for noise in ["<video", "<audio", "&lt;source", "&lt;track"] {
    result = result.replace(old=noise, new=" ")
  }
  result = trim_epub_known_suffixes(result)
  if is_epub_reader_notice(result) || is_epub_control_cluster(result) {
    return ""
  }
  normalize_epub_text(result)
}

///|
fn is_epub_noise_text(text : String) -> Bool {
  let normalized = normalize_epub_text(text).to_lower().to_string()
  normalized == "" ||
  normalized == ">" ||
  normalized == "> >" ||
  normalized == "guide" ||
  normalized == "begin reading" ||
  normalized == "table of contents begin reading" ||
  normalized == "your reading system does not support (this) video." ||
  normalized == "your reading system does not support (this) audio." ||
  is_epub_reader_notice(normalized) ||
  is_epub_control_cluster(normalized) ||
  is_epub_gutenberg_license_block(normalized)
}

///|
fn is_epub_media_fragment(text : String) -> Bool {
  let normalized = normalize_epub_text(text).to_lower().to_string()
  normalized == "" || normalized == "`" || normalized == "```"
}

///|
fn strip_epub_media_tokens(text : String) -> String {
  let kept : Array[String] = []
  for token in text.split(" ").to_array() {
    let piece = token.to_string()
    let lowered = piece.to_lower().to_string()
    if lowered == "" {
      continue
    }
    if lowered.has_prefix("id=\"video") ||
      lowered.contains("../video/") ||
      lowered.contains("../captions/") ||
      lowered.contains("aria-controls=\"") ||
      lowered.contains("srclang=\"") ||
      lowered.contains("kind=\"subtitles\"") ||
      lowered.contains("label=\"") ||
      lowered.contains("type=\"video/") ||
      lowered.contains("type=\"audio/") ||
      lowered == "</video>" ||
      lowered == "</audio>" ||
      lowered == "&lt;/video&gt;" ||
      lowered == "&lt;/audio&gt;" ||
      lowered.has_prefix("&lt;source") ||
      lowered.has_prefix("&lt;track") ||
      lowered == "controls=\"controls\"" ||
      lowered == "controls=\"controls\">" ||
      lowered == "controls=\"\">" ||
      lowered == "autoplay=\"\"" ||
      lowered == "role=\"button\"" {
      continue
    }
    kept.push(piece)
  }
  kept.join(" ")
}

///|
fn trim_epub_known_suffixes(text : String) -> String {
  let mut result = text
  for
    marker in [
      " unscripted,", " epubreadingsystem aware", " video sources:", " audio sources:",
      " your reading system does not support",
    ] {
    result = trim_epub_before_marker(result, marker)
  }
  normalize_epub_text(result)
}

///|
fn trim_epub_before_marker(text : String, marker : String) -> String {
  let lowered = text.to_lower().to_string()
  match lowered.find(marker) {
    Some(index) => text[:index].to_string()
    None => text
  }
}

///|
fn is_epub_reader_notice(text : String) -> Bool {
  let normalized = normalize_epub_text(text).to_lower().to_string()
  normalized.contains("your reading system does not support")
}

///|
fn is_epub_control_cluster(text : String) -> Bool {
  let normalized = normalize_epub_text(text).to_lower().to_string()
  normalized == "play pause mute unmute" ||
  normalized == "play pause mute unmute muted" ||
  normalized == "muted"
}

///|
fn trim_epub_trailing_gutenberg_blocks(
  blocks : Array[@ast.Block],
) -> Array[@ast.Block] {
  let result : Array[@ast.Block] = []
  for block in blocks {
    if is_epub_end_gutenberg_marker(epub_block_text(block)) {
      break
    }
    result.push(block)
  }
  result
}

///|
fn is_epub_block_noise(block : @ast.Block) -> Bool {
  let text = epub_block_text(block)
  text == "" || is_epub_noise_text(text)
}

///|
fn epub_block_text(block : @ast.Block) -> String {
  match block {
    @ast.Heading(_, inlines) => sanitize_epub_text(plain_text_inlines(inlines))
    @ast.Paragraph(inlines) => sanitize_epub_text(plain_text_inlines(inlines))
    @ast.List(items, _) => {
      let parts : Array[String] = []
      for item in items {
        let text = sanitize_epub_text(@ast.plain_text_of_inlines(item))
        if text != "" {
          parts.push(text)
        }
      }
      parts.join(" ")
    }
    @ast.Quote(lines) => {
      let parts : Array[String] = []
      for line in lines {
        let text = sanitize_epub_text(plain_text_markdownish(line))
        if text != "" {
          parts.push(text)
        }
      }
      parts.join(" ")
    }
    @ast.Table(header, rows) => {
      let parts : Array[String] = []
      for cell in header {
        let text = sanitize_epub_text(
          plain_text_markdownish(@ast.plain_text_of_inlines(cell)),
        )
        if text != "" {
          parts.push(text)
        }
      }
      for row in rows {
        for cell in row {
          let text = sanitize_epub_text(
            plain_text_markdownish(@ast.plain_text_of_inlines(cell)),
          )
          if text != "" {
            parts.push(text)
          }
        }
      }
      parts.join(" ")
    }
    @ast.CodeBlock(_, text) => sanitize_epub_text(text)
    @ast.Block::Image(alt, src, _) => sanitize_epub_text(alt + " " + src)
    @ast.HorizontalRule => ""
  }
}

///|
fn is_epub_end_gutenberg_marker(text : String) -> Bool {
  let normalized = normalize_epub_text(text).to_lower().to_string()
  normalized.contains("end of the project gutenberg ebook")
}

///|
fn is_epub_gutenberg_license_block(text : String) -> Bool {
  let normalized = normalize_epub_text(text).to_lower().to_string()
  normalized.has_prefix(
    "this ebook is for the use of anyone anywhere in the united states",
  ) ||
  normalized.has_prefix("updated editions will replace the previous one") ||
  normalized.has_prefix("start: full license") ||
  normalized.has_prefix("the full project gutenberg license") ||
  normalized.has_prefix(
    "section 1. general terms of use and redistributing project gutenbergtm electronic works",
  ) ||
  normalized.contains("project gutenberg literary archive foundation") ||
  normalized.contains("www.gutenberg.org/license") ||
  normalized.contains("project gutenbergtm electronic works")
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
fn epub_has_navigation_manifest(manifest : Map[String, ManifestItem]) -> Bool {
  for _, item in manifest {
    match item.properties {
      Some(properties) if properties.contains("nav") => return true
      _ => ()
    }
    let href = item.href.to_lower().to_string()
    if href.contains("toc") || href.contains("nav") {
      return true
    }
  }
  false
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
      let archive_path = @core.join_path(opf_dir, item.href)
      match @libzip.read_file_entry_decompressed(archive, archive_path) {
        Some(bytes) => {
          let filename = @core.numbered_asset_filename(
            "epub-asset-",
            index,
            item.href,
            fallback_extension=media_type_extension(item.media_type),
          )
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
  if ocr_blocks.length() == 0 {
    return blocks
  }
  let result = blocks
  if result.length() > 0 {
    result.push(@ast.HorizontalRule)
  }
  ignore(assets)
  for block in ocr_blocks {
    result.push(block)
  }
  result
}

///|
fn epub_asset_placeholder(index : Int) -> String {
  @core.asset_placeholder("epub", index)
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
  @core.is_image_filename(filename)
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
    } else {
      match
        @core.archive_asset_warning_diagnostic(
          warning, "Failed to extract EPUB asset: ",
        ) {
        Some(diagnostic) => diagnostics.push(diagnostic)
        None =>
          match @core.embedded_ocr_warning_diagnostic("epub", warning) {
            Some(diagnostic) => diagnostics.push(diagnostic)
            None => ()
          }
      }
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
fn render_epub_failure(
  error : @core.ConversionError,
  phase : @core.ConversionPhase?,
  source : @core.DiagnosticSource?,
  hint : @core.DiagnosticHint?,
) -> String {
  @core.error_diagnostic(error, phase, source, hint).render()
}
