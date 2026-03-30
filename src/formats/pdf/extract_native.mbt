///|
async fn extract_pdf_native(file_path : String) -> PdfNativeExtraction {
  let pdf = @pdfread.pdf_of_file(None, None, file_path)
  if @pdfcrypt.is_encrypted(pdf) {
    fail("PDF file is encrypted and cannot be processed.")
  }

  let native_pages = @pdftextlib.extract_text_by_page(pdf)
  let actual_page_count = @pdfpage.pages_of_pagetree_quick(pdf)
  let native_route = plan_pdf_route(native_pages)
  let bridge = if should_attempt_pdf_bridge(
      native_pages, native_route, actual_page_count,
    ) {
    try_extract_pdf_bridge_pages(file_path)
  } else {
    PdfBridgeResponse::{
      available: false,
      provider: None,
      pages: [],
      warnings: [],
    }
  }
  let use_bridge = should_prefer_pdf_bridge_pages(
    native_pages,
    native_route,
    bridge.pages,
    actual_page_count,
    bridge.available,
  )
  let raw_pages = if use_bridge { bridge.pages } else { native_pages }
  let pages : Array[PdfPageExtraction] = []
  let mut page_no = 1
  for raw_text in raw_pages {
    let lines : Array[PdfRawLine] = []
    for line in normalize_extracted_page_text(raw_text).split("\n").to_array() {
      let trimmed = collapse_inline_whitespace(line.to_string())
      lines.push(PdfRawLine::{ text: trimmed })
    }
    pages.push(PdfPageExtraction::{
      page_no,
      source_kind: NativeTextFast,
      raw_text: Some(raw_text),
      lines,
    })
    page_no = page_no + 1
  }

  PdfNativeExtraction::{
    raw_pages,
    pages,
    provider: if use_bridge {
      bridge.provider
    } else {
      Some("mbtpdf")
    },
    warnings: bridge.warnings,
    used_text_fallback: use_bridge,
  }
}

///|
fn should_attempt_pdf_bridge(
  native_pages : Array[String],
  native_route : PdfRoutePlan,
  actual_page_count : Int,
) -> Bool {
  if native_pages.length() < actual_page_count {
    return true
  }

  if native_pages_show_broken_spacing(native_pages) &&
    pdf_bridge_is_small_enough(native_pages, actual_page_count) {
    return true
  }

  route_has_bridge_worthy_flags(native_route) &&
  pdf_bridge_is_small_enough(native_pages, actual_page_count)
}

///|
fn pdf_bridge_page_limit() -> Int {
  8
}

///|
fn pdf_bridge_char_limit() -> Int {
  120000
}

///|
fn pdf_bridge_is_small_enough(
  native_pages : Array[String],
  actual_page_count : Int,
) -> Bool {
  actual_page_count <= pdf_bridge_page_limit() &&
  total_pdf_chars(native_pages) <= pdf_bridge_char_limit()
}

///|
fn should_prefer_pdf_bridge_pages(
  native_pages : Array[String],
  native_route : PdfRoutePlan,
  bridge_pages : Array[String],
  actual_page_count : Int,
  bridge_available : Bool,
) -> Bool {
  if !bridge_available || bridge_pages.length() == 0 {
    return false
  }

  if native_pages.length() < actual_page_count &&
    bridge_pages.length() >= actual_page_count {
    return true
  }

  let native_chars = total_pdf_chars(native_pages)
  let bridge_chars = total_pdf_chars(bridge_pages)
  if native_pages_show_broken_spacing(native_pages) &&
    bridge_chars * 10 >= native_chars * 8 {
    return true
  }

  if route_has_bridge_preference_flags(native_route) &&
    bridge_chars * 10 >= native_chars * 8 {
    return true
  }

  let bridge_route = plan_pdf_route(bridge_pages)
  let native_flags = count_problem_route_flags(native_route)
  let bridge_flags = count_problem_route_flags(bridge_route)
  if bridge_flags + 2 < native_flags && bridge_chars >= native_chars {
    return true
  }

  false
}

///|
fn route_has_bridge_preference_flags(route_plan : PdfRoutePlan) -> Bool {
  for page in route_plan.pages {
    if route_flags_contain(page.flags, SuspectTable) ||
      route_flags_contain(page.flags, SuspectCode) ||
      route_flags_contain(page.flags, SuspectFormula) {
      return true
    }
  }
  false
}

///|
fn route_has_bridge_worthy_flags(route_plan : PdfRoutePlan) -> Bool {
  for page in route_plan.pages {
    if route_flags_contain(page.flags, SuspectTable) ||
      route_flags_contain(page.flags, SuspectCode) ||
      route_flags_contain(page.flags, SuspectFormula) ||
      route_flags_contain(page.flags, SuspectMultiColumn) {
      return true
    }
  }
  false
}

///|
fn native_pages_show_broken_spacing(pages : Array[String]) -> Bool {
  for page in pages {
    let words = tokenize_words(collapse_inline_whitespace(page))
    if count_long_tokens(words) >= 4 {
      return true
    }
  }
  false
}

///|
fn total_pdf_chars(pages : Array[String]) -> Int {
  let mut total = 0
  for page in pages {
    total = total + collapse_inline_whitespace(page).length()
  }
  total
}

///|
fn count_problem_route_flags(route_plan : PdfRoutePlan) -> Int {
  let mut count = 0
  for page in route_plan.pages {
    for flag in page.flags {
      if flag != SuspectHeaderFooter {
        count = count + 1
      }
    }
  }
  count
}
