///|
pub(all) struct ImageConverter {
  dummy : Int
}

///|
pub fn ImageConverter::new() -> ImageConverter {
  ImageConverter::{ dummy: 0 }
}

///|
pub fn ImageConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) if mt.to_lower().to_string().has_prefix("image/") => true
    _ =>
      match info.extension {
        Some(ext) => is_image_extension(ext)
        None => false
      }
  }
}

///|
pub async fn ImageConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  let bytes = read_file_bytes(file_path)
  let asset_name = file_name_only(file_path)
  let asset = @core.OutputAsset::{
    placeholder: image_asset_placeholder(),
    filename: asset_name,
    bytes,
    source: Some(@core.File(file_path)),
    hint: Some(@core.InspectSourceDocument),
  }
  let ocr_result = @ocr.recognize_image_file(
    file_path,
    ctx.ocr,
    source_name=asset_name,
  )
  let metadata = Map::new()
  metadata["format"] = "image"
  metadata["ocr_mode"] = ctx.ocr.mode.label()
  metadata["ocr_backend"] = ctx.ocr.backend_or_auto()
  match ocr_result.provider {
    Some(provider) if provider != "" => metadata["ocr_provider"] = provider
    _ => ()
  }
  let warnings = collect_image_warnings(ctx.ocr, ocr_result)
  let diagnostics = image_warning_diagnostics(file_path, warnings)
  let title = file_stem(file_path)
  let doc = @ast.Document::{
    title,
    metadata,
    blocks: image_blocks(asset, ocr_result),
  }
  let markdown = @ast.render_markdown(doc)
  @core.ConvertResult::markdown_only(markdown, "image")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_assets([asset])
  .with_stats(Some(@core.stats_for_markdown(markdown)))
  .with_document(Some(doc))
}

///|
fn image_blocks(
  asset : @core.OutputAsset,
  ocr_result : @ocr.OcrResult,
) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = [
    @ast.text_heading(1, "Image OCR"),
    @ast.Paragraph([@ast.Image(asset.filename, asset.placeholder)]),
  ]
  if ocr_result.is_useful() {
    blocks.push(@ast.text_heading(2, "Recognized Text"))
    for paragraph in split_ocr_paragraphs(ocr_result.text) {
      blocks.push(@ast.text_paragraph(paragraph))
    }
  }
  blocks
}

///|
fn split_ocr_paragraphs(text : String) -> Array[String] {
  let parts : Array[String] = []
  for chunk in text.replace(old="\r\n", new="\n").split("\n\n").to_array() {
    let trimmed = chunk.trim().to_string()
    if trimmed != "" {
      parts.push(trimmed)
    }
  }
  if parts.length() == 0 && text.trim() != "" {
    [text.trim().to_string()]
  } else {
    parts
  }
}

///|
fn collect_image_warnings(
  config : @ocr.OcrConfig,
  ocr_result : @ocr.OcrResult,
) -> Array[String] {
  let warnings : Array[String] = []
  for warning in ocr_result.warnings {
    warnings.push(warning)
  }
  if config.mode != @ocr.Off && ocr_result.attempted && !ocr_result.available {
    push_unique_warning(
      warnings, "OCR requested but no available backend was found.",
    )
  }
  if ocr_result.attempted && ocr_result.available && ocr_result.text == "" {
    push_unique_warning(warnings, "OCR backend returned empty text.")
  }
  warnings
}

///|
fn image_warning_diagnostics(
  file_path : String,
  warnings : Array[String],
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    if warning == "OCR requested but no available backend was found." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("image")),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Install and expose a supported OCR backend such as tesseract, or switch to --ocr-backend mock for tests.",
            ),
          ),
        ),
      )
    } else if warning == "OCR backend returned empty text." {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("image")),
          Some(@core.File(file_path)),
          Some(@core.InspectSourceDocument),
        ),
      )
    } else if warning.has_prefix("OCR backend") ||
      warning.has_prefix("tesseract") {
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("image")),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Inspect the OCR bridge stderr or backend installation.",
            ),
          ),
        ),
      )
    }
  }
  diagnostics
}

///|
fn image_asset_placeholder() -> String {
  "moonbitmark-raw://image/1"
}

///|
fn is_image_extension(ext : String) -> Bool {
  let lowered = ext.to_lower().to_string()
  lowered == ".png" ||
  lowered == ".jpg" ||
  lowered == ".jpeg" ||
  lowered == ".gif" ||
  lowered == ".bmp" ||
  lowered == ".webp" ||
  lowered == ".tif" ||
  lowered == ".tiff"
}

///|
async fn read_file_bytes(path : String) -> Bytes {
  let file = @fs.open(path, mode=ReadOnly)
  let buffer = @buffer.new()
  while true {
    let chunk : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let read = file.read(chunk)
    if read == 0 {
      break
    }
    for i in 0..<read {
      buffer.write_byte(chunk[i])
    }
  }
  file.close()
  buffer.to_bytes()
}

///|
fn file_stem(path : String) -> String? {
  let basename = file_name_only(path)
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
fn push_unique_warning(warnings : Array[String], warning : String) -> Unit {
  for existing in warnings {
    if existing == warning {
      return
    }
  }
  warnings.push(warning)
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
