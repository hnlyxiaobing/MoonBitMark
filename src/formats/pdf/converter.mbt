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
  let extraction = bind_route_to_native_extraction(raw_extraction, route_plan)
  let title = file_stem(file_path)
  let assembly = assemble_pdf_document(title, extraction, route_plan)

  let flattened_text = extraction.raw_pages.join("\n\n")
  let ocr_warning = pdf_ocr_warning(ctx.ocr, flattened_text)
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
