///|
fn pdf_warning_messages(
  route_plan : PdfRoutePlan,
  extraction : PdfNativeExtraction,
  normalization : PdfNormalizationResult,
  ocr_warning : String?,
) -> Array[String] {
  let warnings : Array[String] = []
  if extraction.used_fallback {
    warnings.push(
      "PDF text extraction used fallback provider: " +
      describe_pdf_text_provider(extraction.provider) +
      ".",
    )
  }
  for warning in extraction.warnings {
    warnings.push("PDF bridge warning: " + warning)
  }
  if route_plan.summary.recovery_pages > 0 &&
    ocr_warning != Some("PDF OCR recovery supplemented low-text pages.") {
    warnings.push(
      "Some PDF pages appear to require OCR recovery, but only native text extraction is currently active.",
    )
  }
  if normalization.merged_partial_numbering_count > 0 {
    warnings.push("Merged partial numbering lines during PDF post-processing.")
  }
  if normalization.removed_header_count > 0 ||
    normalization.removed_footer_count > 0 {
    warnings.push(
      "Removed repeated page header/footer lines during PDF normalization.",
    )
  }
  match ocr_warning {
    Some(warning) => warnings.push(warning)
    None => ()
  }
  warnings
}

///|
fn pdf_warning_diagnostics(
  file_path : String,
  route_plan : PdfRoutePlan,
  extraction : PdfNativeExtraction,
  normalization : PdfNormalizationResult,
  ocr_warning : String?,
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for diagnostic in pdf_route_diagnostics(file_path, route_plan) {
    diagnostics.push(diagnostic)
  }
  if extraction.used_fallback {
    diagnostics.push(
      @core.warning_diagnostic(
        "PDF text extraction used fallback provider: " +
        describe_pdf_text_provider(extraction.provider) +
        ".",
        Some(@core.Parse(Some("pdf-bridge"))),
        Some(@core.File(file_path)),
        Some(
          @core.Custom(
            "Review fallback output if page layout, formulas, or tables still look degraded.",
          ),
        ),
      ),
    )
  }
  for warning in extraction.warnings {
    diagnostics.push(
      @core.warning_diagnostic(
        "PDF bridge warning: " + warning,
        Some(@core.Parse(Some("pdf-bridge"))),
        Some(@core.File(file_path)),
        Some(
          @core.Custom(
            "Inspect the fallback extraction output if important pages are still missing or truncated.",
          ),
        ),
      ),
    )
  }
  if normalization.merged_partial_numbering_count > 0 {
    diagnostics.push(
      @core.warning_diagnostic(
        "Merged partial numbering lines during PDF post-processing.",
        Some(@core.Postprocess(Some("numbering-merge"))),
        Some(@core.File(file_path)),
        Some(
          @core.Custom(
            "Review merged numbering if the PDF relies on strict line boundaries.",
          ),
        ),
      ),
    )
  }
  if normalization.removed_header_count > 0 ||
    normalization.removed_footer_count > 0 {
    diagnostics.push(
      @core.warning_diagnostic(
        "Removed repeated page header/footer lines during PDF normalization.",
        Some(@core.Normalize(Some("headers-footers"))),
        Some(@core.File(file_path)),
        Some(
          @core.Custom(
            "Review the output if the PDF uses repeated running headers as semantic content.",
          ),
        ),
      ),
    )
  }
  match ocr_warning {
    Some("PDF OCR recovery supplemented low-text pages.") =>
      diagnostics.push(
        @core.warning_diagnostic(
          "PDF OCR recovery supplemented low-text pages.",
          Some(@core.Convert("pdf")),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Review OCR-recovered text on scanned or image-only pages before relying on it downstream.",
            ),
          ),
        ),
      )
    Some(warning) =>
      diagnostics.push(
        @core.warning_diagnostic(
          warning,
          Some(@core.Convert("pdf")),
          Some(@core.File(file_path)),
          Some(
            @core.Custom(
              "Configure a PDF page-rendering OCR backend before expecting scanned-PDF fallback.",
            ),
          ),
        ),
      )
    None => ()
  }
  diagnostics
}

///|
fn pdf_route_diagnostics(
  file_path : String,
  route_plan : PdfRoutePlan,
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  let flag_summary = summarize_route_flags(route_plan)

  if route_plan.summary.structured_pages > 0 {
    let mut message = "Routed " +
      route_plan.summary.structured_pages.to_string() +
      " PDF page(s) to the structured native path based on route heuristics."
    if flag_summary != "" {
      message = message + " Flags: " + flag_summary + "."
    }
    diagnostics.push(
      @core.warning_diagnostic(
        message,
        Some(@core.Convert("pdf-route")),
        Some(@core.File(file_path)),
        Some(
          @core.Custom(
            "Structured pages keep the native extractor for now, but later stages can upgrade these routes to layout or OCR providers.",
          ),
        ),
      ),
    )
  }

  if route_plan.summary.recovery_pages > 0 {
    diagnostics.push(
      @core.warning_diagnostic(
        "Routed some PDF pages to OCR recovery because the extracted text looked empty or unusable.",
        Some(@core.Convert("pdf-route")),
        Some(@core.File(file_path)),
        Some(
          @core.Custom(
            "Add a PDF page-rendering OCR backend before expecting scanned-PDF recovery to produce content.",
          ),
        ),
      ),
    )
  }

  diagnostics
}

///|
fn pdf_ocr_warning(
  config : @ocr.OcrConfig,
  route_plan : PdfRoutePlan,
  extracted_text : String,
  ocr_result : @ocr.OcrResult,
  ocr_used : Bool,
) -> String? {
  if ocr_used {
    return Some("PDF OCR recovery supplemented low-text pages.")
  }
  if config.mode == @ocr.Off {
    return None
  }
  if route_plan.summary.recovery_pages == 0 &&
    !@ocr.should_attempt_for_native_text(config, extracted_text) {
    return None
  }
  if ocr_result.attempted && !ocr_result.available {
    return Some(
      "PDF OCR recovery attempted but no available backend produced usable text.",
    )
  }
  if ocr_result.attempted && ocr_result.available && ocr_result.text == "" {
    return Some("PDF OCR recovery returned empty text.")
  }
  Some("OCR skipped for PDF because no page-rendering backend is configured.")
}

///|
fn describe_pdf_text_provider(provider : String?) -> String {
  match provider {
    Some(name) if name != "" => name
    _ => "unknown"
  }
}

///|
