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
  .with_stats(
    Some({ ..stats, used_fallback: extraction.used_text_fallback || ocr_used }),
  )
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
    page_numbers=recovery_page_numbers(route_plan),
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
  config.is_enabled() && route_plan.summary.recovery_pages > 0
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
  let ocr_pages = split_pdf_ocr_page_texts(ocr_text)
  let page_aligned = ocr_pages.length() == raw_pages.length()
  let recovery_aligned = ocr_pages.length() == route_plan.summary.recovery_pages
  let mut index = 0
  let mut recovery_index = 0
  while index < raw_pages.length() {
    let raw_text = raw_pages[index]
    let next_text = match route_plan.pages.get(index) {
      Some(route) if route.provider == OcrRecovery =>
        recovery_page_text(
          raw_text, ocr_pages, index, recovery_index, page_aligned, recovery_aligned,
        )
      _ => raw_text
    }
    match route_plan.pages.get(index) {
      Some(route) if route.provider == OcrRecovery =>
        recovery_index = recovery_index + 1
      _ => ()
    }
    pages.push(next_text)
    index = index + 1
  }
  pages
}

///|
fn split_pdf_ocr_page_texts(ocr_text : String) -> Array[String] {
  let normalized = normalize_extracted_page_text(ocr_text)
  if normalized.contains(pdf_ocr_page_break_marker()) {
    let pages : Array[String] = []
    for chunk in normalized.split(pdf_ocr_page_break_marker()).to_array() {
      pages.push(chunk.trim().to_string())
    }
    trim_trailing_empty_ocr_pages(pages)
  } else {
    let trimmed = normalized.trim().to_string()
    if trimmed == "" {
      []
    } else {
      [trimmed]
    }
  }
}

///|
fn pdf_ocr_page_break_marker() -> String {
  "[[[MOONBITMARK_PDF_PAGE_BREAK]]]"
}

///|
fn trim_trailing_empty_ocr_pages(pages : Array[String]) -> Array[String] {
  let trimmed = copy_string_array(pages)
  while trimmed.length() > 0 && trimmed[trimmed.length() - 1] == "" {
    ignore(trimmed.pop())
  }
  trimmed
}

///|
fn recovery_page_text(
  raw_text : String,
  ocr_pages : Array[String],
  page_index : Int,
  recovery_index : Int,
  page_aligned : Bool,
  recovery_aligned : Bool,
) -> String {
  if ocr_pages.length() == 0 {
    return raw_text
  }
  let candidate = if page_aligned {
    ocr_pages[page_index]
  } else if recovery_aligned && recovery_index < ocr_pages.length() {
    ocr_pages[recovery_index]
  } else if ocr_pages.length() == 1 {
    ocr_pages[0]
  } else if recovery_index < ocr_pages.length() {
    ocr_pages[recovery_index]
  } else {
    ""
  }
  if candidate == "" {
    raw_text
  } else {
    candidate
  }
}

///|
fn recovery_page_numbers(route_plan : PdfRoutePlan) -> Array[Int] {
  let page_numbers : Array[Int] = []
  for page in route_plan.pages {
    if page.provider == OcrRecovery {
      page_numbers.push(page.page_no)
    }
  }
  page_numbers
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
    used_text_fallback: extraction.used_text_fallback,
  }
}
