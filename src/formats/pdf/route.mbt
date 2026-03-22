///|
fn plan_pdf_route(raw_pages : Array[String]) -> PdfRoutePlan {
  let page_texts : Array[PdfPageText] = []
  let mut page_no = 1
  for raw_text in raw_pages {
    page_texts.push(PdfPageText::{
      number: page_no,
      raw_text,
      chunks: split_page_chunks(raw_text),
    })
    page_no = page_no + 1
  }

  let repeated_header = detect_repeated_edge_chunk(page_texts, true)
  let repeated_footer = detect_repeated_edge_chunk(page_texts, false)

  let pages : Array[PdfPageRoute] = []
  let mut native_fast_pages = 0
  let mut structured_pages = 0
  let mut recovery_pages = 0
  let mut flagged_pages = 0

  for page in page_texts {
    let route = route_pdf_page(page, repeated_header, repeated_footer)
    match route.provider {
      NativeTextFast => native_fast_pages = native_fast_pages + 1
      NativeTextStructured => structured_pages = structured_pages + 1
      OcrRecovery => recovery_pages = recovery_pages + 1
      _ => structured_pages = structured_pages + 1
    }
    if route.flags.length() > 0 {
      flagged_pages = flagged_pages + 1
    }
    pages.push(route)
  }

  let document_mode = if pages.length() > 0 && recovery_pages == pages.length() {
    RecoveryOnly
  } else if structured_pages == 0 && recovery_pages == 0 {
    FastTextOnly
  } else {
    Mixed
  }

  PdfRoutePlan::{
    document_mode,
    pages,
    summary: PdfRouteSummary::{
      total_pages: pages.length(),
      native_fast_pages,
      structured_pages,
      recovery_pages,
      flagged_pages,
    },
  }
}

///|
fn route_pdf_page(
  page : PdfPageText,
  repeated_header : String?,
  repeated_footer : String?,
) -> PdfPageRoute {
  let normalized = normalize_extracted_page_text(page.raw_text)
  let flattened = collapse_inline_whitespace(normalized)
  let lines = non_empty_lines(normalized)
  let words = tokenize_words(flattened)
  let flags : Array[PdfRouteFlag] = []

  if flattened == "" {
    push_route_flag(flags, SuspectScanned)
    return PdfPageRoute::{
      page_no: page.number,
      provider: OcrRecovery,
      text_quality: Empty,
      layout_complexity: Simple,
      flags,
    }
  }

  if page_matches_edge(page.chunks, repeated_header, true) ||
    page_matches_edge(page.chunks, repeated_footer, false) {
    push_route_flag(flags, SuspectHeaderFooter)
  }

  let digit_heavy_lines = count_digit_heavy_lines(lines)
  let numeric_value_lines = count_numeric_value_lines(lines)
  let short_lines = count_short_lines(lines)
  let long_tokens = count_long_tokens(words)
  let code_hits = count_code_hits(flattened)
  let formula_hits = count_formula_hits(flattened)
  let table_hits = count_table_hits(
    flattened, lines, digit_heavy_lines, numeric_value_lines,
  )
  let broken_spacing_hits = count_broken_spacing_hits(words, flattened)
  let multi_column_hits = count_multi_column_hits(lines, short_lines)

  if table_hits >= 2 {
    push_route_flag(flags, SuspectTable)
  }
  if code_hits >= 2 {
    push_route_flag(flags, SuspectCode)
  }
  if formula_hits >= 2 {
    push_route_flag(flags, SuspectFormula)
  }
  if broken_spacing_hits >= 2 || long_tokens >= 2 {
    push_route_flag(flags, SuspectBrokenSpacing)
  }
  if multi_column_hits >= 2 {
    push_route_flag(flags, SuspectMultiColumn)
  }

  let layout_complexity = if route_flags_contain(flags, SuspectTable) ||
    route_flags_contain(flags, SuspectMultiColumn) {
    Complex
  } else if flags.length() > 0 || lines.length() >= 12 {
    Medium
  } else {
    Simple
  }

  let provider = if route_flags_contain(flags, SuspectScanned) {
    OcrRecovery
  } else if route_flags_contain(flags, SuspectTable) ||
    route_flags_contain(flags, SuspectCode) ||
    route_flags_contain(flags, SuspectFormula) ||
    route_flags_contain(flags, SuspectMultiColumn) ||
    route_flags_contain(flags, SuspectBrokenSpacing) {
    NativeTextStructured
  } else {
    NativeTextFast
  }

  PdfPageRoute::{
    page_no: page.number,
    provider,
    text_quality: classify_text_quality(
      flattened,
      lines.length(),
      words.length(),
      long_tokens,
    ),
    layout_complexity,
    flags,
  }
}

///|
fn bind_route_to_native_extraction(
  extraction : PdfNativeExtraction,
  route_plan : PdfRoutePlan,
) -> PdfNativeExtraction {
  let pages : Array[PdfPageExtraction] = []
  let mut index = 0
  while index < extraction.pages.length() {
    let page = extraction.pages[index]
    let source_kind = match route_plan.pages.get(index) {
      Some(route) => route.provider
      None => page.source_kind
    }
    pages.push(PdfPageExtraction::{ ..page, source_kind, })
    index = index + 1
  }
  PdfNativeExtraction::{ ..extraction, pages, }
}

///|
fn PdfDocumentMode::label(self : PdfDocumentMode) -> String {
  match self {
    FastTextOnly => "fast_text_only"
    Mixed => "mixed"
    RecoveryOnly => "recovery_only"
  }
}

///|
fn PdfPageProviderKind::label(self : PdfPageProviderKind) -> String {
  match self {
    NativeTextFast => "native_text_fast"
    NativeTextStructured => "native_text_structured"
    LayoutEnhanced => "layout_enhanced"
    OcrRecovery => "ocr_recovery"
    Hybrid => "hybrid"
  }
}

///|
fn PdfRouteFlag::label(self : PdfRouteFlag) -> String {
  match self {
    SuspectTable => "table"
    SuspectCode => "code"
    SuspectFormula => "formula"
    SuspectMultiColumn => "multi_column"
    SuspectScanned => "scanned"
    SuspectHeaderFooter => "header_footer"
    SuspectBrokenSpacing => "broken_spacing"
  }
}

///|
fn summarize_route_flags(route_plan : PdfRoutePlan) -> String {
  let counts : Map[String, Int] = {}
  for page in route_plan.pages {
    for flag in page.flags {
      let label = flag.label()
      counts[label] = match counts.get(label) {
        Some(existing) => existing + 1
        None => 1
      }
    }
  }
  if counts.length() == 0 {
    return ""
  }

  let parts : Array[String] = []
  for
    label in [
      "table", "code", "formula", "multi_column", "scanned", "header_footer", "broken_spacing",
    ] {
    match counts.get(label) {
      Some(count) => parts.push(label + ":" + count.to_string())
      None => ()
    }
  }
  parts.join(",")
}

///|
fn summarize_route_providers(route_plan : PdfRoutePlan) -> String {
  let counts : Map[String, Int] = {}
  for page in route_plan.pages {
    let label = page.provider.label()
    counts[label] = match counts.get(label) {
      Some(existing) => existing + 1
      None => 1
    }
  }
  if counts.length() == 0 {
    return ""
  }

  let parts : Array[String] = []
  for provider in reserved_provider_kinds() {
    let label = provider.label()
    match counts.get(label) {
      Some(count) => parts.push(label + ":" + count.to_string())
      None => ()
    }
  }
  parts.join(",")
}

///|
fn reserved_provider_kinds() -> Array[PdfPageProviderKind] {
  [NativeTextFast, NativeTextStructured, LayoutEnhanced, OcrRecovery, Hybrid]
}

///|
fn non_empty_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  for raw_line in normalize_extracted_page_text(text).split("\n").to_array() {
    let line = collapse_inline_whitespace(raw_line.to_string())
    if line != "" {
      lines.push(line)
    }
  }
  lines
}

///|
fn count_digit_heavy_lines(lines : Array[String]) -> Int {
  let mut count = 0
  for line in lines {
    let mut digits = 0
    let mut letters = 0
    for ch in line {
      if is_digit_ascii(ch) {
        digits = digits + 1
      } else if is_lower_ascii(ch) || is_upper_ascii(ch) {
        letters = letters + 1
      }
    }
    if digits >= 3 && digits >= letters {
      count = count + 1
    }
  }
  count
}

///|
fn count_short_lines(lines : Array[String]) -> Int {
  let mut count = 0
  for line in lines {
    if line.length() <= 48 {
      count = count + 1
    }
  }
  count
}

///|
fn count_numeric_value_lines(lines : Array[String]) -> Int {
  let mut count = 0
  for line in lines {
    let tokens = tokenize_words(line)
    if tokens.length() == 0 {
      continue
    }
    let mut numeric = true
    for token in tokens {
      if !looks_like_table_value(token) {
        numeric = false
      }
    }
    if numeric {
      count = count + 1
    }
  }
  count
}

///|
fn count_long_tokens(words : Array[String]) -> Int {
  let mut count = 0
  for word in words {
    let normalized = normalize_word_token(word)
    if normalized.length() >= 18 {
      count = count + 1
    }
  }
  count
}

///|
fn count_code_hits(text : String) -> Int {
  let mut hits = 0
  let keywords = [
    "function", "return", "class", "const", "let", "var", "public", "private", "import",
    "console.", "def ", "int main",
  ]
  for keyword in keywords {
    if text.contains(keyword) {
      hits = hits + 1
    }
  }
  if text.contains("{") && text.contains("}") {
    hits = hits + 1
  }
  hits
}

///|
fn count_formula_hits(text : String) -> Int {
  let mut hits = 0
  let keywords = ["Formula", "Theorem", "Lemma", "Proof", "=>", "∑", "∫"]
  for keyword in keywords {
    if text.contains(keyword) {
      hits = hits + 1
    }
  }
  let mut operator_count = 0
  for ch in text {
    if ch == '=' || ch == '+' || ch == '−' || ch == '-' || ch == '/' {
      operator_count = operator_count + 1
    }
  }
  if text.contains("Formula") && operator_count >= 3 {
    hits = hits + 1
  }
  if operator_count >= 6 {
    hits = hits + 1
  }
  hits
}

///|
fn count_table_hits(
  text : String,
  lines : Array[String],
  digit_heavy_lines : Int,
  numeric_value_lines : Int,
) -> Int {
  let mut hits = 0
  if text.contains("Table ") || text.contains("TABLE ") {
    hits = hits + 1
  }
  if digit_heavy_lines >= 2 {
    hits = hits + 1
  }
  if numeric_value_lines >= 6 {
    hits = hits + 1
  }
  let mut separator_lines = 0
  for line in lines {
    if line.contains("|") ||
      line.contains("  ") ||
      (line.contains("%") && line.contains(".")) {
      separator_lines = separator_lines + 1
    }
  }
  if separator_lines >= 2 {
    hits = hits + 1
  }
  hits
}

///|
fn count_broken_spacing_hits(words : Array[String], text : String) -> Int {
  let mut hits = 0
  for word in words {
    if looks_like_broken_spacing_token(word) {
      hits = hits + 1
    }
  }
  if text.contains("Table1") || text.contains("Listing1") {
    hits = hits + 1
  }
  hits
}

///|
fn looks_like_broken_spacing_token(word : String) -> Bool {
  let normalized = normalize_word_token(word)
  if normalized.length() < 12 {
    return false
  }

  let mut lower_to_upper = 0
  let mut letter_to_digit = 0
  let mut prev : Char? = None
  for ch in normalized {
    match prev {
      Some(existing) => {
        if is_lower_ascii(existing) && is_upper_ascii(ch) {
          lower_to_upper = lower_to_upper + 1
        }
        if (is_lower_ascii(existing) || is_upper_ascii(existing)) &&
          is_digit_ascii(ch) {
          letter_to_digit = letter_to_digit + 1
        }
      }
      None => ()
    }
    prev = Some(ch)
  }
  lower_to_upper >= 1 || letter_to_digit >= 1
}

///|
fn count_multi_column_hits(lines : Array[String], short_lines : Int) -> Int {
  if lines.length() < 12 {
    return 0
  }
  let mut no_terminal = 0
  for line in lines {
    match last_visible_char(line) {
      Some(ch) if !is_terminal_punctuation(ch) => no_terminal = no_terminal + 1
      _ => ()
    }
  }

  let mut hits = 0
  if short_lines * 10 >= lines.length() * 6 {
    hits = hits + 1
  }
  if no_terminal * 10 >= lines.length() * 7 {
    hits = hits + 1
  }
  hits
}

///|
fn classify_text_quality(
  flattened : String,
  line_count : Int,
  word_count : Int,
  long_tokens : Int,
) -> PdfTextQuality {
  if flattened == "" {
    return Empty
  }
  if flattened.length() < 40 || word_count < 8 {
    return VeryPoor
  }
  if flattened.length() < 140 || line_count <= 2 || long_tokens >= 3 {
    return Weak
  }
  if flattened.length() >= 500 && word_count >= 80 && long_tokens == 0 {
    Strong
  } else {
    Good
  }
}

///|
fn page_matches_edge(
  chunks : Array[String],
  repeated_edge : String?,
  header : Bool,
) -> Bool {
  if chunks.length() == 0 {
    return false
  }
  match repeated_edge {
    Some(expected) =>
      if header {
        chunks[0] == expected
      } else {
        chunks[chunks.length() - 1] == expected
      }
    None => false
  }
}

///|
fn push_route_flag(flags : Array[PdfRouteFlag], flag : PdfRouteFlag) -> Unit {
  if !route_flags_contain(flags, flag) {
    flags.push(flag)
  }
}

///|
fn route_flags_contain(
  flags : Array[PdfRouteFlag],
  target : PdfRouteFlag,
) -> Bool {
  for flag in flags {
    if flag == target {
      return true
    }
  }
  false
}
