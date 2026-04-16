// PPTX Converter - Pure MoonBit Implementation
// Converts PowerPoint presentations (.pptx) to Markdown

///|
/// Converter for PPTX files
pub(all) struct PptxConverter {
  dummy : Int
}

///|
/// Create a new PPTX converter
pub fn PptxConverter::new() -> PptxConverter {
  PptxConverter::{ dummy: 0 }
}

///|
/// Check if this converter accepts the given file
pub fn PptxConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      ext_lower == ".pptx"
    }
    None => false
  }
}

///|
/// Convert a PPTX file to Markdown
pub async fn PptxConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  let bytes = @core.read_file_bytes(file_path)

  // 使用纯 MoonBit libzip 打开 ZIP
  match @libzip.ZipArchive::open(bytes) {
    Some(archive) =>
      // 解析 presentation.xml 获取幻灯片顺序
      match parse_presentation(archive) {
        Ok(slide_ids, parse_warnings) => {
          if slide_ids.length() == 0 {
            // 调试：检查文件列表
            let files = archive.list_entries()
            let mut file_list = "Files: "
            for f in files {
              file_list = file_list + "[" + f + "] "
            }
            fail(
              render_pptx_failure(
                @core.ConversionFailed(
                  "No slides found. \{file_list}",
                  "presentation",
                ),
                Some(@core.Parse(Some("ppt/presentation.xml"))),
                Some(@core.ArchiveEntry("ppt/presentation.xml")),
                Some(
                  @core.Custom(
                    "Verify that the PPTX contains slide references in ppt/presentation.xml.",
                  ),
                ),
              ),
            )
          }
          // 解析每张幻灯片并生成 Markdown
          let (assets, asset_warnings, asset_placeholders) = extract_pptx_assets(
            archive,
          )
          let (slide_blocks, slide_annotations, slide_warnings) = process_slides_with_assets_and_annotations(
            archive, slide_ids, asset_placeholders,
          )
          let metadata = Map::new()
          metadata["format"] = "pptx"
          metadata["slide_count"] = slide_ids.length().to_string()
          let warnings = collect_pptx_warnings(
            parse_warnings, slide_warnings, asset_warnings,
          )
          let (ocr_appendix, ocr_warnings, ocr_count, ocr_provider) = ocr_pptx_assets(
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
          let title = @core.file_stem(file_path)
          let doc = @ast.document(title, metadata, slide_blocks).with_annotations(
            slide_annotations,
          )
          let rendered_markdown = @ast.render_markdown(doc)
          let markdown_with_assets = append_pptx_asset_gallery(
            rendered_markdown, assets, ocr_appendix,
          )
          let diagnostics = pptx_warning_diagnostics(file_path, warnings)
          @core.ConvertResult::markdown_only(markdown_with_assets, "pptx")
          .with_title(title)
          .with_metadata(metadata)
          .with_warnings(warnings)
          .with_diagnostics(diagnostics)
          .with_assets(assets)
          .with_stats(Some(@core.stats_for_markdown(markdown_with_assets)))
          .with_document(Some(doc))
        }
        Err(e) => fail(render_pptx_parse_failure(e, file_path))
      }
    None =>
      fail(
        render_pptx_failure(
          @core.ZipError("Failed to open PPTX file as ZIP archive", None),
          Some(@core.Load(Some("archive"))),
          Some(@core.File(file_path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
  }
}

///|
fn collect_pptx_warnings(
  parse_warnings : Array[String],
  slide_warnings : Array[String],
  asset_warnings : Array[String],
) -> Array[String] {
  let warnings : Array[String] = []
  for warning in parse_warnings {
    warnings.push(warning)
  }
  for warning in slide_warnings {
    warnings.push(warning)
  }
  for warning in asset_warnings {
    warnings.push(warning)
  }
  warnings
}

///|
fn extract_pptx_assets(
  archive : @libzip.ZipArchive,
) -> (Array[@core.OutputAsset], Array[String], Map[String, String]) {
  let assets : Array[@core.OutputAsset] = []
  let warnings : Array[String] = []
  let placeholders : Map[String, String] = Map::new()
  let mut index = 1
  for entry in archive.list_entries() {
    if entry.has_prefix("ppt/media/") || entry.has_prefix("ppt/embeddings/") {
      match @libzip.read_file_entry_decompressed(archive, entry) {
        Some(bytes) => {
          let prefix = if entry.has_prefix("ppt/media/") {
            "pptx-image-"
          } else {
            "pptx-attachment-"
          }
          let filename = @core.numbered_asset_filename(prefix, index, entry)
          assets.push(@core.OutputAsset::{
            placeholder: pptx_asset_placeholder(index),
            filename,
            bytes,
            source: Some(@core.ArchiveEntry(entry)),
            hint: Some(@core.CheckArchiveIntegrity),
          })
          placeholders[entry] = pptx_asset_placeholder(index)
          index = index + 1
        }
        None => warnings.push("Failed to extract PPTX asset: " + entry)
      }
    }
  }
  (assets, warnings, placeholders)
}

///|
fn append_pptx_asset_gallery(
  markdown : String,
  assets : Array[@core.OutputAsset],
  ocr_appendix : String,
) -> String {
  if assets.length() == 0 && ocr_appendix == "" {
    return markdown
  }
  let lines : Array[String] = []
  if markdown != "" {
    lines.push(markdown)
    lines.push("")
  }
  if assets.length() > 0 {
    let mut has_attachment = false
    for asset in assets {
      if !asset.filename.has_prefix("pptx-image-") {
        if !has_attachment {
          lines.push("## Embedded Assets")
          lines.push("")
          has_attachment = true
        }
        lines.push("- [" + asset.filename + "](" + asset.placeholder + ")")
      }
    }
  }
  if ocr_appendix != "" {
    if lines.length() > 0 {
      lines.push("")
    }
    lines.push(ocr_appendix)
  }
  lines.join("\n")
}

///|
fn pptx_asset_placeholder(index : Int) -> String {
  @core.asset_placeholder("pptx", index)
}

///|
fn pptx_warning_diagnostics(
  file_path : String,
  warnings : Array[String],
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    if warning == "Some slide XML files could not be read from the archive." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("slides"))),
          Some(@core.File(file_path)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning == "Some slides could not be parsed as XML." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("slides"))),
          Some(@core.File(file_path)),
          Some(
            @core.Custom("Inspect malformed slide XML inside the PPTX archive."),
          ),
        ),
      )
    } else if warning == "Some slides could not be decoded as UTF-8." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("slides"))),
          Some(@core.File(file_path)),
          Some(@core.Custom("Verify slide XML encoding and archive integrity.")),
        ),
      )
    } else if warning == "Failed to read ppt/_rels/presentation.xml.rels." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("ppt/_rels/presentation.xml.rels"))),
          Some(@core.ArchiveEntry("ppt/_rels/presentation.xml.rels")),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning ==
      "Failed to decode ppt/_rels/presentation.xml.rels as UTF-8." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("ppt/_rels/presentation.xml.rels"))),
          Some(@core.ArchiveEntry("ppt/_rels/presentation.xml.rels")),
          Some(
            @core.Custom(
              "Verify the XML encoding of ppt/_rels/presentation.xml.rels before converting.",
            ),
          ),
        ),
      )
    } else if warning == "Failed to parse ppt/_rels/presentation.xml.rels." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("ppt/_rels/presentation.xml.rels"))),
          Some(@core.ArchiveEntry("ppt/_rels/presentation.xml.rels")),
          Some(
            @core.Custom(
              "Inspect malformed relationship XML inside the PPTX archive.",
            ),
          ),
        ),
      )
    } else if warning.has_prefix("Failed to read slide XML: ") {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("slide"))),
          Some(@core.ArchiveEntry(extract_pptx_warning_path(warning))),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
    } else if warning.has_prefix("Failed to decode slide XML as UTF-8: ") {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Load(Some("slide"))),
          Some(@core.ArchiveEntry(extract_pptx_warning_path(warning))),
          Some(@core.Custom("Verify slide XML encoding and archive integrity.")),
        ),
      )
    } else if warning.has_prefix("Failed to parse slide XML: ") {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Parse(Some("slide"))),
          Some(@core.ArchiveEntry(extract_pptx_warning_path(warning))),
          Some(
            @core.Custom("Inspect malformed slide XML inside the PPTX archive."),
          ),
        ),
      )
    } else {
      match
        @core.archive_asset_warning_diagnostic(
          warning, "Failed to extract PPTX asset: ",
        ) {
        Some(diagnostic) => diagnostics.push(diagnostic)
        None =>
          if warning.has_prefix(
              "PPTX slide asset relationship did not resolve to extracted asset: ",
            ) {
            let path = warning[61:].to_string()
            diagnostics.push(
              @core.warning_diagnostic(
                warning,
                Some(@core.Load(Some("asset"))),
                Some(@core.ArchiveEntry(path)),
                Some(@core.CheckArchiveIntegrity),
              ),
            )
          } else {
            match @core.embedded_ocr_warning_diagnostic("pptx", warning) {
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
async fn ocr_pptx_assets(
  assets : Array[@core.OutputAsset],
  config : @ocr.OcrConfig,
) -> (String, Array[String], Int, String?) {
  let lines : Array[String] = []
  let warnings : Array[String] = []
  let mut count = 0
  let mut provider : String? = None
  if !config.should_process_embedded_images() {
    return ("", warnings, count, provider)
  }
  for index, asset in assets {
    if !asset.filename.has_prefix("pptx-image-") {
      continue
    }
    let result = @ocr.recognize_image_bytes(
      asset.bytes,
      asset.filename,
      config,
      temp_stem="pptx-" + (index + 1).to_string(),
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
        lines.push("## Image OCR")
        lines.push("")
      }
      lines.push("### " + asset.filename)
      lines.push("")
      for paragraph in @core.split_ocr_paragraphs(result.text) {
        lines.push(paragraph)
        lines.push("")
      }
      count = count + 1
      match provider {
        Some(_) => ()
        None => provider = result.provider
      }
    }
  }
  let appendix = lines.join("\n").trim().to_string()
  (appendix, warnings, count, provider)
}

///|
fn extract_pptx_warning_path(message : String) -> String {
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
fn render_pptx_parse_failure(message : String, file_path : String) -> String {
  if message.contains("presentation.xml") {
    let is_parse = message.contains("parse")
    let phase = if is_parse {
      Some(@core.Parse(Some("ppt/presentation.xml")))
    } else {
      Some(@core.Load(Some("ppt/presentation.xml")))
    }
    let error = if is_parse {
      @core.XmlParseError(message, None)
    } else {
      @core.ZipError(message, Some("ppt/presentation.xml"))
    }
    render_pptx_failure(
      error,
      phase,
      Some(@core.ArchiveEntry("ppt/presentation.xml")),
      Some(@core.CheckArchiveIntegrity),
    )
  } else {
    render_pptx_failure(
      @core.ConversionFailed(message, "presentation"),
      Some(@core.Convert("pptx")),
      Some(@core.File(file_path)),
      Some(
        @core.Custom(
          "Inspect the PPTX archive and slide relationships for details.",
        ),
      ),
    )
  }
}

///|
fn render_pptx_failure(
  error : @core.ConversionError,
  phase : @core.ConversionPhase?,
  source : @core.DiagnosticSource?,
  hint : @core.DiagnosticHint?,
) -> String {
  @core.error_diagnostic(error, phase, source, hint).render()
}
