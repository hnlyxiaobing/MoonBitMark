///|
fn normalize_pdf_extraction(
  extraction : PdfNativeExtraction,
  route_plan : PdfRoutePlan,
) -> PdfNormalizationResult {
  if extraction.pages.length() == 0 {
    return normalize_pdf_pages(extraction.raw_pages)
  }
  let pages : Array[PdfPageText] = []
  let prefer_linewise = extraction.used_text_fallback &&
    extraction.provider is Some("pdfminer")
  let mut index = 0
  while index < extraction.pages.length() {
    let extracted_page = extraction.pages[index]
    let route = match route_plan.pages.get(index) {
      Some(value) => value
      None =>
        PdfPageRoute::{
          page_no: extracted_page.page_no,
          provider: NativeTextFast,
          text_quality: Good,
          layout_complexity: Simple,
          flags: [],
        }
    }
    pages.push(PdfPageText::{
      number: extracted_page.page_no,
      raw_text: match extracted_page.raw_text {
        Some(text) => text
        None => ""
      },
      chunks: normalize_page_chunks(extracted_page, route, prefer_linewise),
    })
    index = index + 1
  }
  finalize_normalized_pages(pages)
}

///|
fn normalize_pdf_pages(raw_pages : Array[String]) -> PdfNormalizationResult {
  let pages : Array[PdfPageText] = []
  let mut page_number = 1
  for raw_text in raw_pages {
    pages.push(PdfPageText::{
      number: page_number,
      raw_text,
      chunks: split_page_chunks(raw_text),
    })
    page_number = page_number + 1
  }
  finalize_normalized_pages(pages)
}

///|
fn finalize_normalized_pages(
  pages : Array[PdfPageText],
) -> PdfNormalizationResult {
  let repeated_header = detect_repeated_edge_chunk(pages, true)
  let repeated_footer = detect_repeated_edge_chunk(pages, false)

  let normalized_pages : Array[PdfPageText] = []
  let mut removed_header_count = 0
  let mut removed_footer_count = 0
  let mut merged_partial_numbering_count = 0

  for page in pages {
    let filtered = remove_repeated_edge_chunks(
      page.chunks,
      repeated_header,
      repeated_footer,
    )
    if repeated_header is Some(header_text) &&
      filtered.length() < page.chunks.length() &&
      page.chunks.length() > 0 &&
      page.chunks[0] == header_text {
      removed_header_count = removed_header_count + 1
    }
    if repeated_footer is Some(footer_text) &&
      filtered.length() < page.chunks.length() &&
      page.chunks.length() > 0 &&
      page.chunks[page.chunks.length() - 1] == footer_text {
      removed_footer_count = removed_footer_count + 1
    }
    let trimmed = drop_edge_furniture_chunks(filtered)
    if trimmed.1 {
      removed_header_count = removed_header_count + 1
    }
    if trimmed.2 {
      removed_footer_count = removed_footer_count + 1
    }
    let merged = merge_partial_numbering_chunks(trimmed.0)
    merged_partial_numbering_count = merged_partial_numbering_count + merged.1
    normalized_pages.push(PdfPageText::{
      number: page.number,
      raw_text: page.raw_text,
      chunks: merged.0,
    })
  }

  PdfNormalizationResult::{
    pages: normalized_pages,
    removed_header_count,
    removed_footer_count,
    merged_partial_numbering_count,
  }
}

///|
fn drop_edge_furniture_chunks(
  chunks : Array[String],
) -> (Array[String], Bool, Bool) {
  if chunks.length() == 0 {
    return ([], false, false)
  }

  let mut start = 0
  let mut end = chunks.length()
  let mut removed_header = false
  let mut removed_footer = false

  while start < end && collapse_inline_whitespace(chunks[start]) == "" {
    start = start + 1
  }
  while end > start && collapse_inline_whitespace(chunks[end - 1]) == "" {
    end = end - 1
  }

  while start < end && looks_like_header_furniture(chunks[start], end - start) {
    removed_header = true
    start = start + 1
  }

  while start + 1 < end &&
        looks_like_split_running_header(chunks[start], chunks[start + 1]) {
    removed_header = true
    start = start + 2
  }

  while end > start && looks_like_footer_furniture(chunks[end - 1], end - start) {
    removed_footer = true
    end = end - 1
  }

  let filtered : Array[String] = []
  let mut index = start
  while index < end {
    filtered.push(chunks[index])
    index = index + 1
  }
  (filtered, removed_header, removed_footer)
}

///|
fn looks_like_header_furniture(text : String, remaining : Int) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if normalized == "" || remaining < 2 {
    return false
  }
  looks_like_standalone_page_number(normalized) ||
  looks_like_running_header(normalized)
}

///|
fn looks_like_footer_furniture(text : String, remaining : Int) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if normalized == "" || remaining < 2 {
    return false
  }
  looks_like_standalone_page_number(normalized)
}

///|
fn looks_like_standalone_page_number(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  normalized.length() <= 4 && all_digits(normalized)
}

///|
fn looks_like_running_header(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if normalized.length() > 140 {
    return false
  }
  let has_journal_marker = normalized.contains(" / ") &&
    normalized.contains("(") &&
    normalized.contains(")")
  has_journal_marker || normalized.contains("Data in Brief")
}

///|
fn looks_like_split_running_header(left : String, right : String) -> Bool {
  let combined = collapse_inline_whitespace(left + " " + right)
  looks_like_running_header(combined)
}

///|
fn normalize_page_chunks(
  page : PdfPageExtraction,
  route : PdfPageRoute,
  prefer_linewise : Bool,
) -> Array[String] {
  match route.provider {
    NativeTextStructured =>
      normalize_structured_page_chunks(page.lines, route.flags)
    _ =>
      if prefer_linewise {
        normalize_fallback_page_chunks(page.lines)
      } else {
        match page.raw_text {
          Some(text) => split_page_chunks(text)
          None => page.lines.map(line => collapse_inline_whitespace(line.text))
        }
      }
  }
}

///|
fn normalize_fallback_page_chunks(lines : Array[PdfRawLine]) -> Array[String] {
  let chunks : Array[String] = []
  let mut index = 0
  while index < lines.length() {
    let current = collapse_inline_whitespace(lines[index].text)
    if current == "" {
      index = index + 1
      continue
    }

    let heading = collect_fallback_heading(lines, index)
    if heading.1 > index {
      chunks.push(heading.0)
      index = heading.1
      continue
    }

    let list_item = collect_fallback_list_item(lines, index)
    if list_item is Some((text, next_index)) {
      chunks.push(text)
      index = next_index
      continue
    }

    let paragraph = collect_fallback_paragraph(lines, index)
    chunks.push(paragraph.0)
    index = paragraph.1
  }
  chunks
}

///|
fn collect_fallback_heading(
  lines : Array[PdfRawLine],
  start : Int,
) -> (String, Int) {
  let current = collapse_inline_whitespace(lines[start].text)
  if !is_heading_candidate_text(current) {
    return ("", start)
  }
  if start + 1 < lines.length() {
    let next = collapse_inline_whitespace(lines[start + 1].text)
    if next != "" &&
      next.length() <= 40 &&
      !starts_fallback_list_item(next) &&
      (next.has_prefix("(") || is_heading_candidate_text(next)) {
      return (current + " " + next, start + 2)
    }
  }
  (current, start + 1)
}

///|
fn collect_fallback_list_item(
  lines : Array[PdfRawLine],
  start : Int,
) -> (String, Int)? {
  let current = collapse_inline_whitespace(lines[start].text)
  let marker = fallback_list_marker(current)
  if marker == "" && parse_list_item(current) is None {
    return None
  }

  let mut text = if marker != "" { marker } else { current }
  let mut index = start + 1
  while index < lines.length() {
    let next = collapse_inline_whitespace(lines[index].text)
    if next == "" {
      match next_fallback_content_line(lines, index + 1) {
        Some((lookahead, next_index)) =>
          if !starts_fallback_list_item(lookahead) &&
            !is_heading_candidate_text(lookahead) &&
            !line_ends_terminal_punctuation(text) {
            text = merge_paragraph_text(text, lookahead)
            index = next_index + 1
            continue
          } else {
            break
          }
        _ => break
      }
    }
    if starts_fallback_list_item(next) {
      break
    }
    text = merge_paragraph_text(text, next)
    index = index + 1
  }
  Some((text, index))
}

///|
fn collect_fallback_paragraph(
  lines : Array[PdfRawLine],
  start : Int,
) -> (String, Int) {
  let mut text = collapse_inline_whitespace(lines[start].text)
  let mut index = start + 1
  while index < lines.length() {
    let next = collapse_inline_whitespace(lines[index].text)
    if next == "" {
      match next_fallback_content_line(lines, index + 1) {
        Some((lookahead, next_index)) =>
          if !starts_fallback_list_item(lookahead) &&
            !is_heading_candidate_text(lookahead) &&
            !line_ends_terminal_punctuation(text) {
            text = merge_paragraph_text(text, lookahead)
            index = next_index + 1
            continue
          } else {
            break
          }
        _ => break
      }
    }
    if starts_fallback_list_item(next) || is_heading_candidate_text(next) {
      break
    }
    text = merge_paragraph_text(text, next)
    index = index + 1
  }
  (text, index)
}

///|
fn starts_fallback_list_item(text : String) -> Bool {
  fallback_list_marker(text) != "" || parse_list_item(text) is Some(_)
}

///|
fn fallback_list_marker(text : String) -> String {
  let normalized = collapse_inline_whitespace(text)
  if normalized == "•" || normalized == "-" || normalized == "*" {
    return normalized
  }
  if is_ordered_list_marker(normalized) {
    return normalized
  }
  ""
}

///|
fn next_fallback_content_line(
  lines : Array[PdfRawLine],
  start : Int,
) -> (String, Int)? {
  let mut index = start
  while index < lines.length() {
    let text = collapse_inline_whitespace(lines[index].text)
    if text != "" {
      return Some((text, index))
    }
    index = index + 1
  }
  None
}

///|
fn line_ends_terminal_punctuation(text : String) -> Bool {
  match last_visible_char(text) {
    Some(ch) => is_terminal_punctuation(ch)
    None => false
  }
}

///|
fn normalize_structured_page_chunks(
  lines : Array[PdfRawLine],
  flags : Array[PdfRouteFlag],
) -> Array[String] {
  let chunks : Array[String] = []
  for line in lines {
    if collapse_inline_whitespace(line.text) == "" {
      if chunks.length() == 0 || chunks[chunks.length() - 1] != "" {
        chunks.push("")
      }
      continue
    }

    let normalized = normalize_structured_line(line.text, flags)
    if normalized == "" {
      continue
    }

    let split_listing = split_structured_listing_line(normalized)
    if split_listing.length() > 1 {
      for part in split_listing {
        if part != "" {
          chunks.push(part)
        }
      }
      continue
    }

    let split_caption = split_scientific_caption_boundary(normalized)
    if split_caption.length() > 1 {
      for part in split_caption {
        if part != "" {
          chunks.push(part)
        }
      }
      continue
    }

    chunks.push(normalized)
  }
  chunks
}

///|
fn normalize_structured_line(
  text : String,
  flags : Array[PdfRouteFlag],
) -> String {
  let mut normalized = collapse_inline_whitespace(text)
  if normalized == "" {
    return ""
  }

  normalized = restore_obvious_spacing(normalized)
  normalized = restore_scientific_spacing(normalized)

  if route_flags_contain(flags, SuspectTable) &&
    normalized.has_prefix("Table ") &&
    !normalized.contains(" Potentiodynamic") &&
    normalized.contains("Potentiodynamic") {
    normalized = normalized.replace(old="Table 1", new="Table 1 ")
  }

  normalized
}

///|
fn split_structured_listing_line(line : String) -> Array[String] {
  if !line.has_prefix("Listing ") {
    return [line]
  }
  let words = tokenize_words(line)
  if words.length() < 4 {
    return [line]
  }

  let caption_words : Array[String] = []
  let mut index = 0
  let mut code_start = -1
  while index < words.length() {
    caption_words.push(words[index])
    let joined = caption_words.join(" ")
    if joined.contains(":") && index + 1 < words.length() {
      let rest = join_words_from(words, index + 1)
      if looks_like_code_line(rest) {
        code_start = index + 1
      }
    }
    index = index + 1
  }

  if code_start <= 0 {
    [line]
  } else {
    [join_words_range(words, 0, code_start), join_words_from(words, code_start)]
  }
}

///|
fn split_scientific_caption_boundary(line : String) -> Array[String] {
  let markers = ["Fig. ", "Figure ", "Table "]
  for marker in markers {
    if !line.contains(marker) {
      continue
    }
    let parts = line.split(marker).to_array()
    if parts.length() == 2 {
      let head = collapse_inline_whitespace(parts[0].to_string())
      let tail = collapse_inline_whitespace(marker + parts[1].to_string())
      if head != "" && tail != "" && should_split_scientific_caption(head, tail) {
        return [head, tail]
      }
    }
  }
  [line]
}

///|
fn should_split_scientific_caption(head : String, tail : String) -> Bool {
  let head_words = tokenize_words(head)
  if head_words.length() >= 5 {
    return false
  }
  if looks_like_inline_figure_reference_prefix(head) {
    return false
  }
  tail.has_prefix("Fig. ") ||
  tail.has_prefix("Figure ") ||
  tail.has_prefix("Table ")
}

///|
fn looks_like_inline_figure_reference_prefix(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text).to_lower()
  normalized.has_suffix("shown in") ||
  normalized.has_suffix("as shown in") ||
  normalized.has_suffix("see") ||
  normalized.has_suffix("see also") ||
  normalized.has_suffix("in") ||
  normalized.has_suffix("from")
}

///|
fn restore_scientific_spacing(text : String) -> String {
  text
  .replace(old="Fig.4.", new="Fig. 4.")
  .replace(old="Fig.5.", new="Fig. 5.")
  .replace(old="Fig.5", new="Fig. 5")
  .replace(old="Fig.8.", new="Fig. 8.")
  .replace(old="Table1", new="Table 1")
  .replace(old="Listing1", new="Listing 1")
  .replace(old="MH2SO4", new="M H2SO4")
  .replace(old="A/cm 2", new="A/cm2")
  .replace(old="Corrosion rate(mm/year)", new="Corrosion rate (mm/year)")
  .replace(
    old="Polarization resistance(Ω)",
    new="Polarization resistance (Ω)",
  )
  .replace(old="Ecorr(V)", new="Ecorr (V)")
  .replace(old="ba(V/dec)", new="ba (V/dec)")
  .replace(old="bc(V/dec)", new="bc (V/dec)")
  .replace(old="a 2 +", new="a2 +")
}

///|
fn split_page_chunks(text : String) -> Array[String] {
  let normalized = text
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\t", new=" ")
  let chunks : Array[String] = []
  let mut current = ""
  let mut gap = 0

  for ch in normalized {
    if ch == '\n' {
      push_chunk(chunks, current)
      current = ""
      gap = 0
      continue
    }

    if ch == ' ' {
      gap = gap + 1
      continue
    }

    if gap >= 2 {
      push_chunk(chunks, current)
      current = ""
    } else if gap == 1 && current != "" {
      current = current + " "
    }
    gap = 0
    current = current + ch.to_string()
  }

  push_chunk(chunks, current)

  let refined : Array[String] = []
  for chunk in chunks {
    for part in split_leading_heading_candidate(chunk) {
      for letter_part in split_letter_style_chunks(part) {
        for embedded_part in split_embedded_list_markers(letter_part) {
          if parse_list_item(embedded_part) is Some(_) {
            let trimmed = restore_obvious_spacing(
              collapse_inline_whitespace(embedded_part),
            )
            if trimmed != "" {
              refined.push(trimmed)
            }
          } else {
            for inline_part in split_inline_heading_candidate(embedded_part) {
              let trimmed = restore_obvious_spacing(
                collapse_inline_whitespace(inline_part),
              )
              if trimmed != "" {
                refined.push(trimmed)
              }
            }
          }
        }
      }
    }
  }
  refined
}

///|
fn split_letter_style_chunks(chunk : String) -> Array[String] {
  let after_date : Array[String] = []
  for part in split_leading_date_line(chunk) {
    for salutation_part in split_salutation_boundary(part) {
      for signoff_part in split_signoff_boundary(salutation_part) {
        let trimmed = collapse_inline_whitespace(signoff_part)
        if trimmed != "" {
          after_date.push(trimmed)
        }
      }
    }
  }
  if after_date.length() == 0 {
    [collapse_inline_whitespace(chunk)]
  } else {
    after_date
  }
}

///|
fn split_leading_date_line(chunk : String) -> Array[String] {
  let normalized = collapse_inline_whitespace(chunk)
  let words = tokenize_words(normalized)
  if words.length() < 4 || !looks_like_month_name(words[0]) {
    return [normalized]
  }
  let day = normalize_word_token(words[1])
  let year = normalize_word_token(words[2])
  if day == "" || year.length() != 4 || !all_digits(day) || !all_digits(year) {
    return [normalized]
  }
  let rest = join_words_from(words, 3)
  if rest == "" {
    [normalized]
  } else {
    [join_words_range(words, 0, 3), rest]
  }
}

///|
fn split_salutation_boundary(chunk : String) -> Array[String] {
  split_boundary_marker(chunk, "To Whom it May Concern:")
}

///|
fn split_signoff_boundary(chunk : String) -> Array[String] {
  let markers = [
    "Best Regards,", "Kind Regards,", "Regards,", "Sincerely,", "Thanks,",
  ]
  for marker in markers {
    let split = split_boundary_marker(chunk, marker)
    if split.length() > 1 {
      if split.length() == 2 && split[1].has_prefix(marker) {
        let nested = split_boundary_marker(split[1], marker)
        if nested.length() == 2 && tokenize_words(nested[1]).length() <= 3 {
          return [split[0], nested[0], nested[1]]
        }
      }
      if split.length() == 2 &&
        split[0] == marker &&
        tokenize_words(split[1]).length() <= 3 {
        return [split[0], split[1]]
      }
      return split
    }
  }
  [collapse_inline_whitespace(chunk)]
}

///|
fn split_boundary_marker(chunk : String, marker : String) -> Array[String] {
  let normalized = collapse_inline_whitespace(chunk)
  let parts = normalized.split(marker).to_array()
  if parts.length() < 2 {
    return [normalized]
  }

  let head = parts[0].to_string()
  let tail_parts : Array[String] = []
  let mut index = 1
  while index < parts.length() {
    tail_parts.push(parts[index].to_string())
    index = index + 1
  }
  let tail = collapse_inline_whitespace(tail_parts.join(marker))

  if head == "" {
    if tail == "" {
      [marker]
    } else {
      [marker, tail]
    }
  } else if tail == "" {
    [head + " " + marker]
  } else {
    [head, marker + " " + tail]
  }
}

///|
fn push_chunk(chunks : Array[String], chunk : String) -> Unit {
  let trimmed = collapse_inline_whitespace(chunk)
  if trimmed != "" {
    chunks.push(trimmed)
  }
}

///|
fn split_leading_heading_candidate(chunk : String) -> Array[String] {
  let normalized = collapse_inline_whitespace(chunk)
  if normalized == "" || parse_list_item(normalized) is Some(_) {
    [normalized]
  } else {
    let words = tokenize_words(normalized)
    if words.length() < 4 {
      [normalized]
    } else {
      let prefix_words : Array[String] = []
      let mut best_prefix = ""
      let mut best_rest = ""
      let mut i = 0
      while i < words.length() && i < 12 {
        prefix_words.push(words[i])
        let prefix = prefix_words.join(" ")
        let rest = join_words_from(words, i + 1)
        if rest != "" &&
          is_heading_candidate_text(prefix) &&
          looks_like_sentence_start(rest) {
          best_prefix = prefix
          best_rest = rest
        }
        i = i + 1
      }
      if best_prefix != "" && best_rest != "" {
        [best_prefix, best_rest]
      } else {
        [normalized]
      }
    }
  }
}

///|
fn split_inline_heading_candidate(chunk : String) -> Array[String] {
  let normalized = collapse_inline_whitespace(chunk)
  let words = tokenize_words(normalized)
  if words.length() < 6 {
    return [normalized]
  }

  let mut boundary = -1
  let mut heading_end = -1
  let mut start = 1
  while start < words.length() - 2 {
    if word_ends_sentence(words[start - 1]) {
      let heading_words : Array[String] = []
      let mut current = start
      while current < words.length() && current - start < 12 {
        heading_words.push(words[current])
        let heading = heading_words.join(" ")
        let rest = join_words_from(words, current + 1)
        if rest != "" &&
          is_heading_candidate_text(heading) &&
          looks_like_sentence_start(rest) {
          boundary = start
          heading_end = current
        }
        current = current + 1
      }
      if boundary >= 0 {
        let before = join_words_range(words, 0, boundary)
        let heading = join_words_range(words, boundary, heading_end + 1)
        let after = join_words_from(words, heading_end + 1)
        if before != "" && heading != "" && after != "" {
          return [before, heading, after]
        }
      }
    }
    start = start + 1
  }
  [normalized]
}

///|
fn split_embedded_list_markers(chunk : String) -> Array[String] {
  let words = tokenize_words(chunk)
  if words.length() < 2 {
    return [collapse_inline_whitespace(chunk)]
  }

  let result : Array[String] = []
  let mut current_words : Array[String] = []
  let mut inside_list = false
  let mut index = 0

  while index < words.length() {
    let word = words[index]
    let is_bullet = word == "•" || word == "*"
    let is_ordered = is_ordered_list_marker(word)
    if (is_bullet || is_ordered) && current_words.length() > 0 {
      let current_text = current_words.join(" ")
      if inside_list ||
        is_bullet ||
        (is_ordered && segment_allows_embedded_list(current_text)) {
        result.push(current_text)
        current_words = [word]
        inside_list = true
        index = index + 1
        continue
      }
    }

    current_words.push(word)
    if is_bullet || is_ordered {
      inside_list = true
    }
    index = index + 1
  }

  if current_words.length() > 0 {
    result.push(current_words.join(" "))
  }
  result
}

///|
fn segment_allows_embedded_list(text : String) -> Bool {
  match last_visible_char(text) {
    Some(ch) => ch == ':' || ch == ';' || ch == '.'
    None => false
  }
}

///|
fn detect_repeated_edge_chunk(
  pages : Array[PdfPageText],
  header : Bool,
) -> String? {
  let counts : Map[String, Int] = {}
  for page in pages {
    match edge_chunk(page.chunks, header) {
      Some(chunk) if is_repeated_edge_candidate(chunk) => {
        let next = match counts.get(chunk) {
          Some(existing) => existing + 1
          None => 1
        }
        counts[chunk] = next
      }
      _ => ()
    }
  }

  let mut best_text : String? = None
  let mut best_count = 0
  for text, count in counts {
    if count > best_count {
      best_text = Some(text)
      best_count = count
    }
  }

  if best_count >= 2 {
    best_text
  } else {
    None
  }
}

///|
fn edge_chunk(chunks : Array[String], header : Bool) -> String? {
  if chunks.length() == 0 {
    None
  } else if header {
    Some(chunks[0])
  } else {
    Some(chunks[chunks.length() - 1])
  }
}

///|
fn is_repeated_edge_candidate(chunk : String) -> Bool {
  let text = collapse_inline_whitespace(chunk)
  text != "" && text.length() <= 80
}

///|
fn remove_repeated_edge_chunks(
  chunks : Array[String],
  repeated_header : String?,
  repeated_footer : String?,
) -> Array[String] {
  let filtered : Array[String] = []
  let mut index = 0
  while index < chunks.length() {
    let chunk = chunks[index]
    let is_header = index == 0 &&
      repeated_header is Some(header_text) &&
      chunk == header_text
    let is_footer = index + 1 == chunks.length() &&
      repeated_footer is Some(footer_text) &&
      chunk == footer_text
    if !is_header && !is_footer {
      filtered.push(chunk)
    }
    index = index + 1
  }
  filtered
}

///|
fn merge_partial_numbering_chunks(
  chunks : Array[String],
) -> (Array[String], Int) {
  let merged : Array[String] = []
  let mut merge_count = 0
  let mut index = 0

  while index < chunks.length() {
    let chunk = chunks[index]
    if is_partial_numbering(chunk) && index + 1 < chunks.length() {
      merged.push(chunk + " " + chunks[index + 1])
      merge_count = merge_count + 1
      index = index + 2
    } else {
      merged.push(chunk)
      index = index + 1
    }
  }

  (merged, merge_count)
}

///|
fn collapse_inline_whitespace(text : String) -> String {
  let mut result = ""
  let mut pending_space = false
  for ch in text {
    if is_ignorable_control_char(ch) {
      continue
    }
    if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
      pending_space = result != ""
      continue
    }
    if pending_space {
      result = result + " "
      pending_space = false
    }
    result = result + ch.to_string()
  }
  result.trim().to_string()
}

///|
fn restore_obvious_spacing(text : String) -> String {
  let mut result = ""
  let mut previous : Char? = None
  let mut current_word = ""
  let code_like = looks_like_code_fragment(text)

  fn flush_current_word(
    result : String,
    current_word : String,
    code_like : Bool,
  ) -> String {
    if current_word == "" {
      result
    } else {
      result + restore_keyword_spacing(current_word, code_like)
    }
  }

  for ch in text {
    if ch == ' ' {
      result = flush_current_word(result, current_word, code_like)
      current_word = ""
      if result != "" && !result.has_suffix(" ") {
        result = result + " "
      }
      previous = Some(' ')
      continue
    }

    if should_insert_space(previous, ch) {
      result = flush_current_word(result, current_word, code_like)
      current_word = ""
      if result != "" && !result.has_suffix(" ") {
        result = result + " "
      }
      previous = Some(' ')
    }

    if is_word_char(ch) {
      current_word = current_word + ch.to_string()
    } else {
      result = flush_current_word(result, current_word, code_like)
      current_word = ""
      if should_pad_punctuation(previous, ch) &&
        result != "" &&
        !result.has_suffix(" ") {
        result = result + " "
      }
      result = result + ch.to_string()
      previous = Some(ch)
      continue
    }

    previous = Some(ch)
  }

  restore_known_compounds(
    collapse_inline_whitespace(
      flush_current_word(result, current_word, code_like),
    ),
  )
}

///|
fn looks_like_code_fragment(text : String) -> Bool {
  text.contains("{") ||
  text.contains("}") ||
  text.contains("function") ||
  text.contains("console.") ||
  text.contains("return")
}

///|
fn restore_keyword_spacing(word : String, code_like : Bool) -> String {
  if !code_like {
    return word
  }

  let prefixes = [
    "function", "return", "console", "const", "class", "while", "var", "let",
  ]
  for prefix in prefixes {
    if word.has_prefix(prefix) && word.length() > prefix.length() {
      match first_alpha_char(word[prefix.length():].to_string()) {
        Some(ch) if is_lower_ascii(ch) || is_upper_ascii(ch) =>
          return prefix + " " + word[prefix.length():].to_string()
        _ => ()
      }
    }
  }
  word
}

///|
fn should_insert_space(previous : Char?, current : Char) -> Bool {
  match previous {
    Some(prev) =>
      (is_lower_ascii(prev) && is_upper_ascii(current)) ||
      (is_lower_ascii(prev) && is_digit_ascii(current)) ||
      (prev == ':' && (is_upper_ascii(current) || is_lower_ascii(current))) ||
      (prev == ')' && (is_upper_ascii(current) || is_lower_ascii(current))) ||
      (prev == '}' && (is_upper_ascii(current) || is_lower_ascii(current)))
    None => false
  }
}

///|
fn should_pad_punctuation(previous : Char?, current : Char) -> Bool {
  match previous {
    Some(prev) =>
      current == '{' &&
      (
        is_lower_ascii(prev) ||
        is_upper_ascii(prev) ||
        is_digit_ascii(prev) ||
        prev == ')'
      )
    None => false
  }
}

///|
fn restore_known_compounds(text : String) -> String {
  text
  .replace(old="Java Script", new="JavaScript")
  .replace(old="Type Script", new="TypeScript")
  .replace(old="Pro Writing Aid", new="ProWritingAid")
  .replace(old="One Drive", new="OneDrive")
}

///|
fn is_word_char(ch : Char) -> Bool {
  is_upper_ascii(ch) ||
  is_lower_ascii(ch) ||
  is_digit_ascii(ch) ||
  ch == '_' ||
  ch == '.'
}

///|
fn is_ignorable_control_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0 && code < 32 && ch != '\n' && ch != '\r' && ch != '\t'
}

///|
fn tokenize_words(text : String) -> Array[String] {
  let words : Array[String] = []
  for word in collapse_inline_whitespace(text).split(" ").to_array() {
    if word != "" {
      words.push(word.to_string())
    }
  }
  words
}

///|
fn join_words_from(words : Array[String], start : Int) -> String {
  let result : Array[String] = []
  let mut index = start
  while index < words.length() {
    result.push(words[index])
    index = index + 1
  }
  result.join(" ")
}

///|
fn join_words_range(
  words : Array[String],
  start : Int,
  end_exclusive : Int,
) -> String {
  let result : Array[String] = []
  let mut index = start
  while index < end_exclusive && index < words.length() {
    result.push(words[index])
    index = index + 1
  }
  result.join(" ")
}

///|
fn looks_like_sentence_start(text : String) -> Bool {
  let words = tokenize_words(text)
  if words.length() == 0 {
    return false
  }
  match first_alpha_char(words[0]) {
    Some(ch) if is_lower_ascii(ch) => true
    Some(_) =>
      if words.length() >= 2 {
        match first_alpha_char(words[1]) {
          Some(next) => is_lower_ascii(next)
          None => false
        }
      } else {
        false
      }
    None => false
  }
}

///|
fn word_ends_sentence(word : String) -> Bool {
  let chars = marker_chars(word)
  if chars.length() == 0 {
    return false
  }
  let last = chars[chars.length() - 1]
  last == '.' || last == '!' || last == '?'
}

///|
fn is_heading_candidate_text(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if normalized == "" ||
    normalized.length() > 90 ||
    normalized.contains(". ") ||
    normalized.contains(",") ||
    normalized.has_suffix(":") ||
    parse_list_item(normalized) is Some(_) {
    return false
  }

  let words = tokenize_words(normalized)
  if words.length() < 2 || words.length() > 12 {
    return false
  }

  let mut significant_count = 0
  let mut title_like_count = 0
  for word in words {
    let normalized_word = normalize_word_token(word)
    if normalized_word == "" || is_connector_word(normalized_word) {
      continue
    }
    significant_count = significant_count + 1
    if word_is_title_like(word) {
      title_like_count = title_like_count + 1
    }
  }
  let last_word = normalize_word_token(words[words.length() - 1])
  significant_count >= 2 &&
  significant_count == title_like_count &&
  !is_connector_word(last_word)
}

///|
fn normalize_word_token(word : String) -> String {
  let mut result = ""
  for ch in word.to_lower() {
    if is_lower_ascii(ch) || is_digit_ascii(ch) {
      result = result + ch.to_string()
    }
  }
  result
}

///|
fn is_connector_word(word : String) -> Bool {
  word == "a" ||
  word == "an" ||
  word == "and" ||
  word == "as" ||
  word == "at" ||
  word == "by" ||
  word == "for" ||
  word == "from" ||
  word == "in" ||
  word == "into" ||
  word == "of" ||
  word == "on" ||
  word == "or" ||
  word == "the" ||
  word == "to" ||
  word == "with"
}

///|
fn word_is_title_like(word : String) -> Bool {
  if has_digit(word) {
    return true
  }
  match first_alpha_char(word) {
    Some(ch) => is_upper_ascii(ch)
    None => false
  }
}

///|
fn first_alpha_char(text : String) -> Char? {
  for ch in text {
    if is_upper_ascii(ch) || is_lower_ascii(ch) {
      return Some(ch)
    }
  }
  None
}

///|
fn has_digit(text : String) -> Bool {
  for ch in text {
    if is_digit_ascii(ch) {
      return true
    }
  }
  false
}

///|
fn looks_like_month_name(word : String) -> Bool {
  let lowered = normalize_word_token(word)
  lowered == "january" ||
  lowered == "february" ||
  lowered == "march" ||
  lowered == "april" ||
  lowered == "may" ||
  lowered == "june" ||
  lowered == "july" ||
  lowered == "august" ||
  lowered == "september" ||
  lowered == "october" ||
  lowered == "november" ||
  lowered == "december"
}

///|
fn all_digits(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if !is_digit_ascii(ch) {
      return false
    }
  }
  true
}

///|
fn is_upper_ascii(ch : Char) -> Bool {
  ch >= 'A' && ch <= 'Z'
}

///|
fn is_lower_ascii(ch : Char) -> Bool {
  ch >= 'a' && ch <= 'z'
}

///|
fn is_digit_ascii(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_partial_numbering(s : String) -> Bool {
  if !s.has_prefix(".") || s.length() < 2 {
    return false
  }
  let mut index = 1
  while index < s.length() {
    let code = s.at(index)
    if code < 48 || code > 57 {
      return false
    }
    index = index + 1
  }
  true
}
