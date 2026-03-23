///|
/// Converter for PDF files
pub(all) struct PdfConverter {
  dummy : Int
}

///|
/// Create a new PDF converter
pub fn PdfConverter::new() -> PdfConverter {
  PdfConverter::{ dummy: 0 }
}

///|
/// Accepts function - checks if file is PDF
pub fn PdfConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => mt.has_prefix("application/pdf")
    None =>
      match info.extension {
        Some(".pdf") => true
        _ => false
      }
  }
}

///|
/// Convert function - extracts text from PDF and returns as Markdown
pub async fn PdfConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  let started = @async.now()
  let raw_extraction = extract_pdf_native(file_path)
  let route_plan = plan_pdf_route(raw_extraction.raw_pages)
  let (extraction, ocr_result, ocr_used) = apply_pdf_ocr_recovery(
    file_path,
    raw_extraction,
    route_plan,
    ctx.ocr,
  )
  let title = @core.file_stem(file_path)
  let assembly = assemble_pdf_document(title, extraction, route_plan)
  @core.apply_ocr_metadata(
    assembly.metadata,
    ctx.ocr,
    ocr_result.provider,
    attempted=ocr_result.attempted,
    available=ocr_result.available,
    fallback_used=ocr_used,
  )

  let flattened_text = extraction.raw_pages.join("\n\n")
  let ocr_warning = pdf_ocr_warning(
    ctx.ocr,
    route_plan,
    flattened_text,
    ocr_result,
    ocr_used,
  )
  let warnings = pdf_warning_messages(
    route_plan,
    extraction,
    assembly.normalization,
    ocr_warning,
  )
  let diagnostics = pdf_warning_diagnostics(
    file_path,
    route_plan,
    extraction,
    assembly.normalization,
    ocr_warning,
  )
  let markdown = @ast.render_markdown(assembly.document)
  let duration_ms = (@async.now() - started).to_int()
  let stats = @core.stats_for_markdown(markdown, duration_ms~)

  @core.ConvertResult::markdown_only(markdown, "pdf")
  .with_title(title)
  .with_metadata(assembly.metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_stats(Some({ ..stats, used_fallback: extraction.used_fallback }))
  .with_document(Some(assembly.document))
}

///|
async fn apply_pdf_ocr_recovery(
  file_path : String,
  extraction : PdfNativeExtraction,
  route_plan : PdfRoutePlan,
  config : @ocr.OcrConfig,
) -> (PdfNativeExtraction, @ocr.OcrResult, Bool) {
  if !should_attempt_pdf_ocr_recovery(route_plan, config) {
    return (
      bind_route_to_native_extraction(extraction, route_plan),
      @ocr.OcrResult::not_attempted(),
      false,
    )
  }
  let ocr_result = @ocr.recognize_image_file(
    file_path,
    config,
    source_name=pdf_ocr_source_name(file_path),
  )
  if !ocr_result.is_useful() {
    return (
      bind_route_to_native_extraction(extraction, route_plan),
      ocr_result,
      false,
    )
  }
  let ocr_pages = inject_pdf_ocr_pages(
    extraction.raw_pages,
    route_plan,
    ocr_result.text,
  )
  let recovered_extraction = extraction_with_pages(
    extraction, route_plan, ocr_pages,
  )
  (recovered_extraction, ocr_result, true)
}

///|
fn should_attempt_pdf_ocr_recovery(
  route_plan : PdfRoutePlan,
  config : @ocr.OcrConfig,
) -> Bool {
  config.is_enabled() &&
  route_plan.summary.recovery_pages > 0 &&
  route_plan.summary.recovery_pages == route_plan.summary.total_pages
}

///|
fn pdf_ocr_source_name(file_path : String) -> String {
  match @core.file_stem(file_path) {
    Some(value) if value != "" => value + ".pdf"
    _ => "pdf-ocr.pdf"
  }
}

///|
fn inject_pdf_ocr_pages(
  raw_pages : Array[String],
  route_plan : PdfRoutePlan,
  ocr_text : String,
) -> Array[String] {
  let pages : Array[String] = []
  let recovery_text = if ocr_text.trim() == "" {
    ""
  } else {
    ocr_text.trim().to_string()
  }
  let mut index = 0
  while index < raw_pages.length() {
    let raw_text = raw_pages[index]
    let next_text = match route_plan.pages.get(index) {
      Some(route) if route.provider == OcrRecovery && recovery_text != "" =>
        recovery_text
      _ => raw_text
    }
    pages.push(next_text)
    index = index + 1
  }
  pages
}

///|
fn extraction_with_pages(
  extraction : PdfNativeExtraction,
  route_plan : PdfRoutePlan,
  raw_pages : Array[String],
) -> PdfNativeExtraction {
  let pages : Array[PdfPageExtraction] = []
  let mut page_no = 1
  for raw_text in raw_pages {
    let lines : Array[PdfRawLine] = []
    for line in normalize_extracted_page_text(raw_text).split("\n").to_array() {
      let trimmed = collapse_inline_whitespace(line.to_string())
      lines.push(PdfRawLine::{ text: trimmed })
    }
    let source_kind = match route_plan.pages.get(page_no - 1) {
      Some(route) => route.provider
      None => NativeTextFast
    }
    pages.push(PdfPageExtraction::{
      page_no,
      source_kind,
      raw_text: Some(raw_text),
      lines,
    })
    page_no = page_no + 1
  }
  PdfNativeExtraction::{
    raw_pages,
    pages,
    provider: extraction.provider,
    warnings: extraction.warnings,
    used_fallback: extraction.used_fallback || raw_pages != extraction.raw_pages,
  }
}
