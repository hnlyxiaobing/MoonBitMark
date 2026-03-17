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
pub async fn PptxConverter::convert(file_path : String) -> @core.ConvertResult {
  // 读取 PPTX 文件内容
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
  let bytes = bytes_from_array(all_bytes)

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
          let (markdown, slide_warnings) = process_slides(archive, slide_ids)
          let final_markdown = markdown.trim().to_string()
          let metadata = Map::new()
          metadata["format"] = "pptx"
          metadata["slide_count"] = slide_ids.length().to_string()
          let warnings = collect_pptx_warnings(
            final_markdown, parse_warnings, slide_warnings,
          )
          let diagnostics = pptx_warning_diagnostics(file_path, warnings)
          @core.ConvertResult::markdown_only(final_markdown, "pptx")
          .with_title(file_stem(file_path))
          .with_metadata(metadata)
          .with_warnings(warnings)
          .with_diagnostics(diagnostics)
          .with_stats(Some(@core.stats_for_markdown(final_markdown)))
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
/// 将 Array[Byte] 转换为 Bytes
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}

///|
fn collect_pptx_warnings(
  markdown : String,
  parse_warnings : Array[String],
  slide_warnings : Array[String],
) -> Array[String] {
  let warnings : Array[String] = []
  for warning in parse_warnings {
    warnings.push(warning)
  }
  for warning in slide_warnings {
    warnings.push(warning)
  }
  if markdown.contains("Unable to read") {
    warnings.push("Some slide XML files could not be read from the archive.")
  }
  if markdown.contains("Parse error") {
    warnings.push("Some slides could not be parsed as XML.")
  }
  if markdown.contains("Failed to decode slide") {
    warnings.push("Some slides could not be decoded as UTF-8.")
  }
  warnings
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
    }
  }
  diagnostics
}

///|
fn extract_pptx_warning_path(message : String) -> String {
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
