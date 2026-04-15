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
  let bytes = @core.read_file_bytes(file_path)
  let asset_name = @core.file_name_only(file_path)
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
  @core.apply_ocr_metadata(
    metadata,
    ctx.ocr,
    ocr_result.provider,
    attempted=ocr_result.attempted,
    available=ocr_result.available,
  )
  let warnings = collect_image_warnings(ctx.ocr, ocr_result)
  let diagnostics = image_warning_diagnostics(file_path, warnings)
  let title = @core.file_stem(file_path)
  let doc = @ast.document(title, metadata, image_blocks(asset, ocr_result))
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
    for paragraph in @core.split_ocr_paragraphs(ocr_result.text) {
      blocks.push(@ast.text_paragraph(paragraph))
    }
  }
  blocks
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
    @core.push_unique_warning(warnings, @core.embedded_ocr_unavailable_warning)
  }
  if ocr_result.attempted && ocr_result.available && ocr_result.text == "" {
    @core.push_unique_warning(warnings, "OCR backend returned empty text.")
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
    match @core.file_ocr_warning_diagnostic("image", file_path, warning) {
      Some(diagnostic) => diagnostics.push(diagnostic)
      None => ()
    }
  }
  diagnostics
}

///|
fn image_asset_placeholder() -> String {
  @core.asset_placeholder("image", 1)
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
