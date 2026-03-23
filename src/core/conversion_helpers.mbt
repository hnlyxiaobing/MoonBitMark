///|
pub let embedded_ocr_unavailable_warning = "OCR requested but no available backend was found."

///|
pub fn embedded_ocr_empty_warning(asset_name : String) -> String {
  "OCR backend returned empty text for embedded asset: " + asset_name
}

///|
pub fn asset_placeholder(format_name : String, index : Int) -> String {
  "moonbitmark-raw://" + format_name + "/" + index.to_string()
}

///|
pub fn push_unique_warning(warnings : Array[String], warning : String) -> Unit {
  for existing in warnings {
    if existing == warning {
      return
    }
  }
  warnings.push(warning)
}

///|
pub fn split_ocr_paragraphs(text : String) -> Array[String] {
  let paragraphs : Array[String] = []
  for chunk in text.replace(old="\r\n", new="\n").split("\n\n").to_array() {
    let trimmed = chunk.trim().to_string()
    if trimmed != "" {
      paragraphs.push(trimmed)
    }
  }
  if paragraphs.length() == 0 && text.trim() != "" {
    [text.trim().to_string()]
  } else {
    paragraphs
  }
}

///|
pub fn apply_ocr_metadata(
  metadata : Map[String, String],
  config : @ocr.OcrConfig,
  provider : String?,
  embedded_image_count? : Int = 0,
  attempted? : Bool = false,
  available? : Bool = false,
  fallback_used? : Bool = false,
) -> Unit {
  metadata["ocr_mode"] = config.mode.label()
  metadata["ocr_backend"] = config.backend_or_auto()
  metadata["ocr_lang"] = config.language
  metadata["ocr_images"] = if config.enable_embedded_images {
    "true"
  } else {
    "false"
  }
  match config.timeout_ms {
    Some(value) => metadata["ocr_timeout"] = value.to_string()
    None => ()
  }
  metadata["ocr_attempted"] = if attempted { "true" } else { "false" }
  metadata["ocr_available"] = if available { "true" } else { "false" }
  if fallback_used {
    metadata["ocr_fallback_used"] = "true"
  }
  if embedded_image_count > 0 {
    metadata["ocr_embedded_image_count"] = embedded_image_count.to_string()
  }
  match provider {
    Some(value) if value != "" => metadata["ocr_provider"] = value
    _ => ()
  }
}

///|
pub fn archive_asset_warning_diagnostic(
  warning : String,
  prefix : String,
) -> ConversionDiagnostic? {
  if warning.has_prefix(prefix) {
    let path = warning[prefix.length():].to_string()
    Some(
      warning_diagnostic(
        warning,
        Some(Load(Some("asset"))),
        Some(ArchiveEntry(path)),
        Some(CheckArchiveIntegrity),
      ),
    )
  } else {
    None
  }
}

///|
pub fn embedded_ocr_warning_diagnostic(
  format_name : String,
  warning : String,
) -> ConversionDiagnostic? {
  if warning == embedded_ocr_unavailable_warning {
    Some(
      warning_diagnostic(
        warning,
        Some(Convert(format_name)),
        Some(Generated("embedded-image")),
        Some(
          Custom(
            "Install a supported OCR backend or switch to --ocr-backend mock for tests.",
          ),
        ),
      ),
    )
  } else if warning.has_prefix(
      "OCR backend returned empty text for embedded asset: ",
    ) {
    Some(
      warning_diagnostic(
        warning,
        Some(Convert(format_name)),
        Some(Generated(warning[50:].to_string())),
        Some(InspectSourceDocument),
      ),
    )
  } else if warning.has_prefix("OCR backend") {
    Some(
      warning_diagnostic(
        warning,
        Some(Convert(format_name)),
        Some(Generated("embedded-image")),
        Some(Custom("Inspect OCR bridge stderr or backend installation.")),
      ),
    )
  } else {
    None
  }
}

///|
pub fn file_ocr_warning_diagnostic(
  format_name : String,
  file_path : String,
  warning : String,
) -> ConversionDiagnostic? {
  if warning == embedded_ocr_unavailable_warning {
    Some(
      warning_diagnostic(
        warning,
        Some(Convert(format_name)),
        Some(File(file_path)),
        Some(
          Custom(
            "Install and expose a supported OCR backend such as tesseract, or switch to --ocr-backend mock for tests.",
          ),
        ),
      ),
    )
  } else if warning == "OCR backend returned empty text." {
    Some(
      warning_diagnostic(
        warning,
        Some(Convert(format_name)),
        Some(File(file_path)),
        Some(InspectSourceDocument),
      ),
    )
  } else if warning.has_prefix("OCR backend") || warning.has_prefix("tesseract") {
    Some(
      warning_diagnostic(
        warning,
        Some(Convert(format_name)),
        Some(File(file_path)),
        Some(Custom("Inspect the OCR bridge stderr or backend installation.")),
      ),
    )
  } else {
    None
  }
}
