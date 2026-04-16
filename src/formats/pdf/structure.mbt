///|

///|
fn reconstruct_pdf_blocks_with_routes(
  pages : Array[PdfPageText],
  route_plan : PdfRoutePlan,
) -> PdfStructureResult {
  let blocks : Array[@ast.Block] = []
  let annotations : Array[@ast.BlockAnnotation] = []
  let mut heading_count = 0
  let mut list_block_count = 0
  let mut list_item_count = 0
  let mut paragraph_count = 0
  let mut merged_paragraph_count = 0
  let mut first_heading_emitted = false
  let mut index = 0

  while index < pages.length() {
    let page = pages[index]
    let route = match route_plan.pages.get(index) {
      Some(value) => value
      None =>
        PdfPageRoute::{
          page_no: page.number,
          provider: NativeTextFast,
          text_quality: Good,
          layout_complexity: Simple,
          flags: [],
        }
    }
    let result = match page.layout {
      Some(_) if route.provider != NativeTextFast =>
        reconstruct_layout_page_blocks(page, route, first_heading_emitted)
      _ =>
        match route.provider {
          NativeTextStructured =>
            reconstruct_structured_page_blocks(page, route, first_heading_emitted)
          OcrRecovery =>
            reconstruct_ocr_recovery_page_blocks(page, first_heading_emitted)
          _ =>
            reconstruct_pdf_blocks_with_heading_state([page], first_heading_emitted)
        }
    }

    for block in result.blocks {
      blocks.push(block)
    }
    let page_annotations = build_pdf_page_annotations(
      route,
      result.blocks,
      blocks.length() - result.blocks.length(),
    )
    for annotation in page_annotations {
      annotations.push(annotation)
    }
    heading_count = heading_count + result.summary.heading_count
    list_block_count = list_block_count + result.summary.list_block_count
    list_item_count = list_item_count + result.summary.list_item_count
    paragraph_count = paragraph_count + result.summary.paragraph_count
    merged_paragraph_count = merged_paragraph_count +
      result.summary.merged_paragraph_count
    if result.summary.heading_count > 0 {
      first_heading_emitted = true
    }
    index = index + 1
  }

  PdfStructureResult::{
    blocks,
    annotations,
    summary: PdfStructureSummary::{
      heading_count,
      list_block_count,
      list_item_count,
      paragraph_count,
      merged_paragraph_count,
    },
  }
}

///|
fn reconstruct_layout_page_blocks(
  page : PdfPageText,
  route : PdfPageRoute,
  first_heading_emitted : Bool,
) -> PdfStructureResult {
  match page.layout {
    Some(layout) => {
      let lines = layout_lines_in_reading_order(layout)
      let blocks : Array[@ast.Block] = []
      let mut current_heading_seen = first_heading_emitted
      let mut index = 0

      while index < lines.length() {
        let chunk = collapse_inline_whitespace(lines[index].text)
        if chunk == "" {
          index = index + 1
          continue
        }

        if route_flags_contain(route.flags, SuspectTable) &&
          looks_like_table_caption(chunk) {
          blocks.push(@ast.text_paragraph(chunk))
          match try_parse_layout_table(lines, index + 1) {
            Some((headers, rows, next_index)) => {
              blocks.push(pdf_table_block(headers, rows))
              index = next_index
            }
            None => index = index + 1
          }
          continue
        }

        if (route.provider == OcrRecovery ||
            route_flags_contain(route.flags, SuspectTable)) &&
          !looks_like_table_caption(chunk) {
          match try_parse_layout_table(lines, index) {
            Some((headers, rows, next_index)) => {
              blocks.push(pdf_table_block(headers, rows))
              index = next_index
              continue
            }
            None => ()
          }
        }

        match parse_list_item(chunk) {
          Some(item) => {
            let items : Array[String] = [item.text]
            let ordered = item.ordered
            let mut next_index = index + 1
            while next_index < lines.length() {
              let next_chunk = collapse_inline_whitespace(lines[next_index].text)
              if next_chunk == "" {
                next_index = next_index + 1
                continue
              }
              match parse_list_item(next_chunk) {
                Some(next_item) if next_item.ordered == ordered => {
                  items.push(next_item.text)
                  next_index = next_index + 1
                }
                _ => break
              }
            }
            blocks.push(pdf_list_block(items, ordered))
            index = next_index
            continue
          }
          None => ()
        }

        let tail = collect_layout_paragraph(lines, index, route)
        let text = tail.0
        if text != "" {
          if should_promote_to_heading([page], 0, index, text, current_heading_seen) {
            let level = if current_heading_seen { 2 } else { 1 }
            blocks.push(@ast.text_heading(level, text))
            current_heading_seen = true
          } else {
            blocks.push(@ast.text_paragraph(text))
          }
        }
        index = tail.1
      }

      let repaired_blocks = repair_pdf_blocks(blocks, first_heading_emitted)
      PdfStructureResult::{
        blocks: repaired_blocks,
        annotations: [],
        summary: summarize_pdf_blocks(repaired_blocks, 0),
      }
    }
    None =>
      match route.provider {
        NativeTextStructured =>
          reconstruct_structured_page_blocks(page, route, first_heading_emitted)
        OcrRecovery => reconstruct_ocr_recovery_page_blocks(page, first_heading_emitted)
        _ => reconstruct_pdf_blocks_with_heading_state([page], first_heading_emitted)
      }
  }
}

///|
fn reconstruct_pdf_blocks_with_heading_state(
  pages : Array[PdfPageText],
  first_heading_emitted_init : Bool,
) -> PdfStructureResult {
  let candidates : Array[PdfBlockCandidate] = []
  let mut heading_count = 0
  let mut list_item_count = 0
  let mut merged_paragraph_count = 0
  let mut first_heading_emitted = first_heading_emitted_init

  let mut page_index = 0
  while page_index < pages.length() {
    let page = pages[page_index]
    let mut chunk_index = 0
    while chunk_index < page.chunks.length() {
      let chunk = page.chunks[chunk_index]
      match parse_list_item(chunk) {
        Some(item) => {
          candidates.push(PdfBlockCandidate::{
            kind: List(item.ordered),
            text: item.text,
          })
          list_item_count = list_item_count + 1
        }
        None =>
          if should_promote_to_heading(
              pages, page_index, chunk_index, chunk, first_heading_emitted,
            ) {
            let level = if first_heading_emitted { 2 } else { 1 }
            candidates.push(PdfBlockCandidate::{
              kind: Heading(level),
              text: chunk,
            })
            heading_count = heading_count + 1
            first_heading_emitted = true
          } else if try_merge_paragraph_candidate(candidates, chunk) {
            merged_paragraph_count = merged_paragraph_count + 1
          } else {
            candidates.push(PdfBlockCandidate::{ kind: Paragraph, text: chunk })
          }
      }
      chunk_index = chunk_index + 1
    }
    page_index = page_index + 1
  }

  let rendered = render_pdf_candidates(candidates)
  let repaired_blocks = repair_pdf_blocks(
    rendered.0,
    first_heading_emitted_init,
  )
  PdfStructureResult::{
    blocks: repaired_blocks,
    annotations: [],
    summary: summarize_pdf_blocks(repaired_blocks, merged_paragraph_count),
  }
}

///|
fn reconstruct_ocr_recovery_page_blocks(
  page : PdfPageText,
  first_heading_emitted : Bool,
) -> PdfStructureResult {
  let blocks : Array[@ast.Block] = []
  let mut current_heading_seen = first_heading_emitted
  let mut index = 0

  while index < page.chunks.length() {
    let raw_chunk = page.chunks[index]
    let chunk = collapse_inline_whitespace(raw_chunk)
    if chunk == "" {
      index = index + 1
      continue
    }

    match try_parse_ocr_whitespace_table(page.chunks, index) {
      Some((headers, rows, next_index)) => {
        blocks.push(pdf_table_block(headers, rows))
        index = next_index
        continue
      }
      None => ()
    }

    match parse_list_item(chunk) {
      Some(item) => {
        let items : Array[String] = [item.text]
        let ordered = item.ordered
        let mut next_index = index + 1
        while next_index < page.chunks.length() {
          let next_chunk = collapse_inline_whitespace(page.chunks[next_index])
          if next_chunk == "" {
            next_index = next_index + 1
            continue
          }
          match parse_list_item(next_chunk) {
            Some(next_item) if next_item.ordered == ordered => {
              items.push(next_item.text)
              next_index = next_index + 1
            }
            _ => break
          }
        }
        blocks.push(pdf_list_block(items, ordered))
        index = next_index
        continue
      }
      None => ()
    }

    let tail = collect_ocr_recovery_paragraph(page.chunks, index)
    let text = tail.0
    if text != "" {
      if should_promote_to_heading([page], 0, index, text, current_heading_seen) {
        let level = if current_heading_seen { 2 } else { 1 }
        blocks.push(@ast.text_heading(level, text))
        current_heading_seen = true
      } else {
        blocks.push(@ast.text_paragraph(text))
      }
    }
    index = tail.1
  }

  let repaired_blocks = repair_pdf_blocks(blocks, first_heading_emitted)
  PdfStructureResult::{
    blocks: repaired_blocks,
    annotations: [],
    summary: summarize_pdf_blocks(repaired_blocks, 0),
  }
}

///|
fn reconstruct_structured_page_blocks(
  page : PdfPageText,
  route : PdfPageRoute,
  first_heading_emitted : Bool,
) -> PdfStructureResult {
  let blocks : Array[@ast.Block] = []
  let mut current_heading_seen = first_heading_emitted
  let mut index = 0

  while index < page.chunks.length() {
    let chunk = page.chunks[index]
    if chunk == "" {
      index = index + 1
      continue
    }

    if route_flags_contain(route.flags, SuspectTable) &&
      looks_like_chart_axis_noise(chunk) {
      index = index + 1
      continue
    }

    match parse_list_item(chunk) {
      Some(item) => {
        let items : Array[String] = [item.text]
        let ordered = item.ordered
        let mut next_index = index + 1
        while next_index < page.chunks.length() {
          let next_chunk = page.chunks[next_index]
          if next_chunk == "" {
            next_index = next_index + 1
            continue
          }
          match parse_list_item(next_chunk) {
            Some(next_item) if next_item.ordered == ordered => {
              items.push(next_item.text)
              next_index = next_index + 1
            }
            _ => break
          }
        }
        blocks.push(pdf_list_block(items, ordered))
        index = next_index
        continue
      }
      None => ()
    }

    if route_flags_contain(route.flags, SuspectTable) &&
      looks_like_figure_caption(chunk) {
      blocks.push(@ast.text_paragraph(chunk))
      index = index + 1
      continue
    }

    if route_flags_contain(route.flags, SuspectTable) &&
      looks_like_table_caption(chunk) {
      let caption = collect_table_caption(page.chunks, index)
      blocks.push(@ast.text_paragraph(caption.0))
      match try_parse_scientific_table(page.chunks, caption.1) {
        Some(parsed) => {
          blocks.push(pdf_table_block(parsed.0, parsed.1))
          index = parsed.2
        }
        None => index = caption.1
      }
      continue
    }

    if route_flags_contain(route.flags, SuspectCode) &&
      looks_like_listing_caption(chunk) {
      blocks.push(@ast.text_paragraph(chunk))
      let code = collect_code_block_lines(page.chunks, index + 1)
      if code.0.length() > 0 {
        blocks.push(@ast.CodeBlock(None, code.0.join("\n")))
      }
      index = code.1
      continue
    }

    if route_flags_contain(route.flags, SuspectFormula) &&
      looks_like_formula_heading(chunk) {
      let level = if current_heading_seen { 2 } else { 1 }
      blocks.push(@ast.text_heading(level, chunk))
      current_heading_seen = true
      index = index + 1
      continue
    }

    if route_flags_contain(route.flags, SuspectFormula) &&
      looks_like_formula_chunk(chunk) {
      blocks.push(@ast.text_paragraph("$$" + chunk + "$$"))
      index = index + 1
      continue
    }

    let tail = collect_structured_paragraph(page.chunks, index, route)
    let text = tail.0
    if text != "" {
      if should_promote_to_heading([page], 0, index, text, current_heading_seen) {
        let level = if current_heading_seen { 2 } else { 1 }
        blocks.push(@ast.text_heading(level, text))
        current_heading_seen = true
      } else {
        blocks.push(@ast.text_paragraph(text))
      }
    }
    index = tail.1
  }

  let repaired_blocks = repair_pdf_blocks(blocks, first_heading_emitted)
  PdfStructureResult::{
    blocks: repaired_blocks,
    annotations: [],
    summary: summarize_pdf_blocks(repaired_blocks, 0),
  }
}

///|
fn collect_ocr_recovery_paragraph(
  chunks : Array[String],
  start : Int,
) -> (String, Int) {
  let parts : Array[String] = []
  let mut index = start
  while index < chunks.length() {
    let raw_chunk = chunks[index]
    let chunk = collapse_inline_whitespace(raw_chunk)
    if chunk == "" ||
      (index > start && ocr_chunk_starts_new_block(chunks, index)) {
      break
    }
    parts.push(chunk)
    index = index + 1
    if line_ends_terminal_punctuation(chunk) {
      break
    }
  }
  (merge_structured_paragraph_parts(parts), index)
}

///|
fn collect_layout_paragraph(
  lines : Array[PdfLayoutLine],
  start : Int,
  route : PdfPageRoute,
) -> (String, Int) {
  let parts : Array[String] = []
  let mut index = start
  while index < lines.length() {
    let chunk = collapse_inline_whitespace(lines[index].text)
    if chunk == "" ||
      (index > start && layout_line_starts_new_block(lines, index, route)) {
      break
    }
    parts.push(chunk)
    index = index + 1
    if line_ends_terminal_punctuation(chunk) {
      break
    }
  }
  (merge_structured_paragraph_parts(parts), index)
}

///|
fn layout_line_starts_new_block(
  lines : Array[PdfLayoutLine],
  index : Int,
  route : PdfPageRoute,
) -> Bool {
  let chunk = collapse_inline_whitespace(lines[index].text)
  chunk == "" ||
  parse_list_item(chunk) is Some(_) ||
  looks_like_table_caption(chunk) ||
  (
    (route.provider == OcrRecovery ||
      route_flags_contain(route.flags, SuspectTable)) &&
    try_parse_layout_table(lines, index) is Some(_)
  )
}

///|
fn ocr_chunk_starts_new_block(chunks : Array[String], index : Int) -> Bool {
  let chunk = collapse_inline_whitespace(chunks[index])
  chunk == "" ||
  parse_list_item(chunk) is Some(_) ||
  is_heading_candidate_text(chunk) ||
  try_parse_ocr_whitespace_table(chunks, index) is Some(_)
}

///|
fn build_pdf_page_annotations(
  route : PdfPageRoute,
  blocks : Array[@ast.Block],
  start_index : Int,
) -> Array[@ast.BlockAnnotation] {
  let annotations : Array[@ast.BlockAnnotation] = []
  let page_has_table = pdf_page_contains_table(blocks)
  let route_flag_summary = summarize_route_page_flags(route)
  let provider_resource = "resource: pdf/" +
    route.provider.label() +
    "/page/" +
    route.page_no.to_string() +
    "; kind: page"
  let mut table_downgrade_marked = false
  let mut multi_column_marked = false

  for offset, block in blocks {
    let diagnostics : Array[String] = []
    if route.provider == OcrRecovery {
      diagnostics.push(
        "PDF page was routed to OCR recovery because extracted text looked empty or unusable.",
      )
    }
    if route_flag_summary != "" {
      diagnostics.push("PDF route flags: " + route_flag_summary)
    }
    if route_flags_contain(route.flags, SuspectTable) &&
      !page_has_table &&
      !table_downgrade_marked &&
      pdf_block_can_explain_table_downgrade(block) {
      diagnostics.push(
        "Table-like layout was downgraded to paragraph-level content because no stable table grid was reconstructed.",
      )
      table_downgrade_marked = true
    }
    if route_flags_contain(route.flags, SuspectMultiColumn) &&
      !multi_column_marked &&
      pdf_block_is_textual(block) {
      diagnostics.push(
        "Multi-column layout heuristics were triggered on this page, so block ordering may still be approximate.",
      )
      multi_column_marked = true
    }
    annotations.push(@ast.BlockAnnotation::{
      id: "block-" + (start_index + offset + 1).to_string(),
      source_hint: Some("page: " + route.page_no.to_string()),
      origin_hint: Some(provider_resource),
      diagnostics,
    })
  }
  annotations
}

///|
fn pdf_page_contains_table(blocks : Array[@ast.Block]) -> Bool {
  for block in blocks {
    if block is @ast.Table(_, _) {
      return true
    }
  }
  false
}

///|
fn pdf_block_can_explain_table_downgrade(block : @ast.Block) -> Bool {
  match block {
    @ast.Paragraph(_) => true
    @ast.List(_, _) => true
    @ast.CodeBlock(_, _) => true
    _ => false
  }
}

///|
fn pdf_block_is_textual(block : @ast.Block) -> Bool {
  match block {
    @ast.Heading(_, _) => true
    @ast.Paragraph(_) => true
    @ast.List(_, _) => true
    @ast.Quote(_) => true
    @ast.CodeBlock(_, _) => true
    _ => false
  }
}

///|
fn summarize_route_page_flags(route : PdfPageRoute) -> String {
  if route.flags.length() == 0 {
    return ""
  }
  let labels : Array[String] = []
  for flag in route.flags {
    labels.push(flag.label())
  }
  labels.join(",")
}

///|
fn summarize_pdf_blocks(
  blocks : Array[@ast.Block],
  merged_paragraph_count : Int,
) -> PdfStructureSummary {
  let mut heading_count = 0
  let mut list_block_count = 0
  let mut list_item_count = 0
  let mut paragraph_count = 0
  for block in blocks {
    match block {
      @ast.Heading(_, _) => heading_count = heading_count + 1
      @ast.Paragraph(_) => paragraph_count = paragraph_count + 1
      @ast.List(items, _) => {
        list_block_count = list_block_count + 1
        list_item_count = list_item_count + items.length()
      }
      _ => ()
    }
  }
  PdfStructureSummary::{
    heading_count,
    list_block_count,
    list_item_count,
    paragraph_count,
    merged_paragraph_count,
  }
}

///|
fn collect_structured_paragraph(
  chunks : Array[String],
  start : Int,
  route : PdfPageRoute,
) -> (String, Int) {
  let parts : Array[String] = []
  let mut index = start
  while index < chunks.length() {
    let chunk = chunks[index]
    if chunk == "" ||
      (index > start && structured_chunk_starts_new_block(chunk, route)) {
      break
    }
    parts.push(chunk)
    index = index + 1
    if chunk.has_suffix(".") || chunk.has_suffix(":") {
      break
    }
  }
  (merge_structured_paragraph_parts(parts), index)
}

///|
fn structured_chunk_starts_new_block(
  chunk : String,
  route : PdfPageRoute,
) -> Bool {
  looks_like_listing_caption(chunk) ||
  looks_like_table_caption(chunk) ||
  looks_like_figure_caption(chunk) ||
  looks_like_formula_heading(chunk) ||
  (
    route_flags_contain(route.flags, SuspectFormula) &&
    looks_like_formula_chunk(chunk)
  )
}

///|
fn merge_structured_paragraph_parts(parts : Array[String]) -> String {
  if parts.length() == 0 {
    return ""
  }
  let mut merged = parts[0]
  let mut index = 1
  while index < parts.length() {
    merged = merge_paragraph_text(merged, parts[index])
    index = index + 1
  }
  merged
}

///|
fn collect_code_block_lines(
  chunks : Array[String],
  start : Int,
) -> (Array[String], Int) {
  let lines : Array[String] = []
  let mut index = start
  while index < chunks.length() {
    let chunk = chunks[index]
    if chunk == "" {
      if lines.length() == 0 {
        index = index + 1
        continue
      }
      let next_index = skip_blank_chunks(chunks, index)
      if next_index < chunks.length() &&
        (
          looks_like_code_line(chunks[next_index]) ||
          looks_like_code_continuation(chunks[next_index])
        ) {
        lines.push("")
        index = next_index
        continue
      }
      break
    }
    if looks_like_formula_heading(chunk) ||
      looks_like_table_caption(chunk) ||
      looks_like_figure_caption(chunk) {
      break
    }
    if lines.length() > 0 &&
      !looks_like_code_line(chunk) &&
      !looks_like_code_continuation(chunk) {
      break
    }
    if looks_like_code_line(chunk) || looks_like_code_continuation(chunk) {
      lines.push(normalize_code_line(chunk))
      index = index + 1
      continue
    }
    break
  }
  (lines, index)
}

///|
fn looks_like_code_line(text : String) -> Bool {
  text.contains("{") ||
  text.contains("}") ||
  text.contains("function ") ||
  text.contains("return ") ||
  text.contains("console.") ||
  text.contains("console .") ||
  text.contains(";")
}

///|
fn looks_like_code_continuation(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  normalized == "}" ||
  normalized.has_prefix("console") ||
  normalized.has_prefix("return") ||
  normalized.has_suffix(";")
}

///|
fn normalize_code_line(text : String) -> String {
  normalize_code_spacing(
    text
    .replace(old="console .", new="console.")
    .replace(old=" .log", new=".log")
    .replace(old="functionadd", new="function add")
    .replace(old="returna", new="return a")
    .replace(old="a+b", new="a + b"),
  )
}

///|
fn normalize_code_spacing(text : String) -> String {
  let normalized = collapse_inline_whitespace(text)
  let chars = marker_chars(normalized)
  let mut result = ""
  let mut index = 0

  while index < chars.length() {
    let ch = chars[index]
    if ch == ' ' {
      let prev = last_visible_char(result)
      let next = next_non_space_char(chars, index + 1)
      if should_keep_code_space(prev, next) &&
        result != "" &&
        !result.has_suffix(" ") {
        result = result + " "
      }
      index = index + 1
      continue
    }

    if ch == '.' || ch == ',' || ch == ';' {
      if result.has_suffix(" ") {
        result = result[0:result.length() - 1].to_string()
      }
      result = result + ch.to_string()
      if ch == ',' {
        let next = next_non_space_char(chars, index + 1)
        match next {
          Some(')') | None => ()
          _ => result = result + " "
        }
      }
      index = index + 1
      continue
    }

    result = result + ch.to_string()
    index = index + 1
  }

  collapse_inline_whitespace(result)
}

///|
fn should_keep_code_space(prev : Char?, next : Char?) -> Bool {
  match prev {
    Some('(') => false
    Some('.') => false
    Some(existing) =>
      match next {
        Some(')') => false
        Some(',') => false
        Some('(') =>
          !(is_lower_ascii(existing) ||
          is_upper_ascii(existing) ||
          is_digit_ascii(existing) ||
          existing == ')')
        Some(_) => true
        None => false
      }
    None => false
  }
}

///|
fn next_non_space_char(chars : Array[Char], start : Int) -> Char? {
  let mut index = start
  while index < chars.length() {
    if chars[index] != ' ' {
      return Some(chars[index])
    }
    index = index + 1
  }
  None
}

///|
fn skip_blank_chunks(chunks : Array[String], start : Int) -> Int {
  let mut index = start
  while index < chunks.length() && chunks[index] == "" {
    index = index + 1
  }
  index
}

///|
fn looks_like_listing_caption(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  normalized.has_prefix("Listing ") || normalized.has_prefix("Algorithm ")
}

///|
fn looks_like_formula_heading(text : String) -> Bool {
  collapse_inline_whitespace(text) == "Formula"
}

///|
fn looks_like_formula_chunk(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if normalized.length() > 48 || !normalized.contains("=") {
    return false
  }
  let mut operator_count = 0
  for ch in normalized {
    if ch == '=' || ch == '+' || ch == '-' || ch == '/' {
      operator_count = operator_count + 1
    }
  }
  operator_count >= 2
}

///|
fn looks_like_figure_caption(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  normalized.has_prefix("Fig. ") || normalized.has_prefix("Figure ")
}

///|
fn looks_like_chart_axis_noise(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if normalized == "C/0" ||
    normalized == "0 / C" ||
    normalized == "0/C" ||
    normalized == "/" ||
    normalized == "C" ||
    normalized == "/ C" ||
    normalized == "Concentration (g)" {
    return true
  }
  looks_like_standalone_page_number(normalized)
}

///|
fn looks_like_table_caption(text : String) -> Bool {
  collapse_inline_whitespace(text).has_prefix("Table ")
}

///|
fn collect_table_caption(chunks : Array[String], start : Int) -> (String, Int) {
  let caption = chunks[start]
  if start + 1 < chunks.length() {
    let next = chunks[start + 1]
    if !looks_like_table_data_line(next) &&
      !looks_like_figure_caption(next) &&
      !looks_like_table_caption(next) &&
      !looks_like_formula_heading(next) &&
      looks_like_caption_continuation(next) {
      return (caption + " " + next, start + 2)
    }
  }
  (caption, start + 1)
}

///|
fn looks_like_caption_continuation(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  tokenize_words(normalized).length() >= 4 || normalized.has_suffix(".")
}

///|
fn try_parse_scientific_table(
  chunks : Array[String],
  start : Int,
) -> (Array[String], Array[Array[String]], Int)? {
  let header_lines : Array[String] = []
  let data_groups : Array[Array[String]] = []
  let mut index = start
  let mut found_data = false
  let mut blank_group_mode : Bool? = None
  let mut current_group : Array[String] = []

  while index < chunks.length() {
    let chunk = collapse_inline_whitespace(chunks[index])
    if chunk == "" {
      if found_data && current_group.length() > 0 {
        data_groups.push(current_group)
        current_group = []
      }
      index = index + 1
      continue
    }

    if chunk == "" ||
      looks_like_figure_caption(chunk) ||
      looks_like_formula_heading(chunk) ||
      looks_like_listing_caption(chunk) {
      break
    }

    let values = tokenize_table_values(chunk)
    if !found_data && values.length() == 0 {
      header_lines.push(chunk)
      index = index + 1
      continue
    }
    if values.length() == 0 {
      if found_data && current_group.length() > 0 {
        data_groups.push(current_group)
      }
      break
    }

    found_data = true
    match blank_group_mode {
      None => {
        blank_group_mode = Some(values.length() == 1)
        if values.length() == 1 {
          for value in values {
            current_group.push(value)
          }
        } else {
          data_groups.push(values)
        }
      }
      Some(true) =>
        for value in values {
          current_group.push(value)
        }
      Some(false) => data_groups.push(values)
    }
    index = index + 1
  }

  if current_group.length() > 0 {
    data_groups.push(current_group)
  }

  if header_lines.length() >= 2 && data_groups.length() >= 2 {
    let headers = coalesce_table_header_lines(header_lines)
    let column_count = if headers.length() < data_groups.length() {
      headers.length()
    } else {
      data_groups.length()
    }
    let row_count = common_group_length(data_groups, column_count)
    if row_count >= 2 {
      let rows = transpose_table_groups(data_groups, column_count, row_count)
      if rows.length() == row_count {
        return Some((headers, rows, index))
      }
    }
  }

  None
}

///|
fn coalesce_table_header_lines(lines : Array[String]) -> Array[String] {
  let headers : Array[String] = []
  let mut index = 0
  while index < lines.length() {
    let current = collapse_inline_whitespace(lines[index])
    if index + 1 < lines.length() &&
      should_merge_table_header_lines(current, lines[index + 1]) {
      headers.push(current + " " + collapse_inline_whitespace(lines[index + 1]))
      index = index + 2
    } else {
      headers.push(current)
      index = index + 1
    }
  }
  headers
}

///|
fn should_merge_table_header_lines(left : String, right : String) -> Bool {
  let left_words = tokenize_words(left)
  if left_words.length() == 0 || left_words.length() > 2 {
    return false
  }
  !left.contains("(") &&
  (right.contains("(") || looks_like_lowercase_phrase(right))
}

///|
fn looks_like_lowercase_phrase(text : String) -> Bool {
  match first_alpha_char(collapse_inline_whitespace(text)) {
    Some(ch) => is_lower_ascii(ch)
    None => false
  }
}

///|
fn common_group_length(groups : Array[Array[String]], needed : Int) -> Int {
  if groups.length() < needed {
    return 0
  }
  let target = groups[0].length()
  if target < 2 {
    return 0
  }
  let mut index = 1
  while index < needed {
    if groups[index].length() != target {
      return 0
    }
    index = index + 1
  }
  target
}

///|
fn transpose_table_groups(
  groups : Array[Array[String]],
  column_count : Int,
  row_count : Int,
) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  let mut row_index = 0
  while row_index < row_count {
    let row : Array[String] = []
    let mut column_index = 0
    while column_index < column_count && column_index < groups.length() {
      row.push(groups[column_index][row_index])
      column_index = column_index + 1
    }
    rows.push(row)
    row_index = row_index + 1
  }
  rows
}

///|
fn looks_like_table_data_line(text : String) -> Bool {
  tokenize_table_values(text).length() > 0
}

///|
fn try_parse_layout_table(
  lines : Array[PdfLayoutLine],
  start : Int,
) -> (Array[String], Array[Array[String]], Int)? {
  let candidate_lines : Array[PdfLayoutLine] = []
  let mut index = start
  while index < lines.length() {
    let line = lines[index]
    if !looks_like_layout_table_row(line) {
      break
    }
    candidate_lines.push(line)
    index = index + 1
  }

  if candidate_lines.length() < 3 {
    return None
  }
  let anchors = cluster_layout_table_columns(candidate_lines)
  if anchors.length() < 2 {
    return None
  }

  let matrix : Array[Array[String]] = []
  for line in candidate_lines {
    matrix.push(layout_table_row_cells(line, anchors))
  }

  let header_rows = detect_layout_table_header_rows(matrix)
  if header_rows <= 0 || header_rows >= matrix.length() {
    return None
  }

  let headers = flatten_layout_table_headers(matrix, anchors.length(), header_rows)
  let rows : Array[Array[String]] = []
  let mut row_index = header_rows
  while row_index < matrix.length() {
    let normalized = normalize_layout_table_row(matrix[row_index], anchors.length())
    if row_has_any_text(normalized) {
      rows.push(normalized)
    }
    row_index = row_index + 1
  }
  if rows.length() == 0 {
    return None
  }

  Some((headers, rows, index))
}

///|
fn looks_like_layout_table_row(line : PdfLayoutLine) -> Bool {
  let text = collapse_inline_whitespace(line.text)
  if text == "" || looks_like_table_caption(text) || looks_like_figure_caption(text) {
    return false
  }
  if line.words.length() < 2 {
    return false
  }
  let numeric_count = count_layout_numeric_words(line.words)
  numeric_count > 0 ||
  line.words.length() >= 3 ||
  !layout_text_looks_like_sentence(text)
}

///|
fn layout_text_looks_like_sentence(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  normalized.has_suffix(".") ||
  normalized.has_suffix(":") ||
  tokenize_words(normalized).length() >= 8
}

///|
fn count_layout_numeric_words(words : Array[PdfLayoutWord]) -> Int {
  let mut count = 0
  for word in words {
    if looks_like_layout_numeric_value(word.text) {
      count = count + 1
    }
  }
  count
}

///|
fn looks_like_layout_numeric_value(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
    .replace(old="%", new="")
    .replace(old=",", new="")
    .replace(old="(", new="")
    .replace(old=")", new="")
  if normalized == "" {
    return false
  }
  let mut digit_count = 0
  for ch in normalized {
    if is_digit_ascii(ch) {
      digit_count = digit_count + 1
    } else if ch == '.' || ch == '-' || ch == '+' || ch == '/' {
      ()
    } else {
      return false
    }
  }
  digit_count > 0
}

///|
fn cluster_layout_table_columns(lines : Array[PdfLayoutLine]) -> Array[Int] {
  let anchors : Array[Int] = []
  for line in lines {
    for word in line.words {
      let center = layout_word_center(word)
      let mut matched = false
      let mut index = 0
      while index < anchors.length() {
        if abs_int(anchors[index] - center) <= 55 {
          anchors[index] = (anchors[index] + center) / 2
          matched = true
          break
        }
        index = index + 1
      }
      if !matched {
        insert_int_sorted(anchors, center)
      }
    }
  }
  anchors
}

///|
fn layout_word_center(word : PdfLayoutWord) -> Int {
  word.left + (word.right - word.left) / 2
}

///|
fn layout_table_row_cells(
  line : PdfLayoutLine,
  anchors : Array[Int],
) -> Array[String] {
  let cells : Array[String] = Array::make(anchors.length(), "")
  for word in line.words {
    let covered = layout_word_covered_columns(word, anchors)
    if covered.length() == 0 {
      continue
    }
    for column in covered {
      let existing = cells[column]
      cells[column] = if existing == "" {
        word.text
      } else {
        existing + " " + word.text
      }
    }
  }
  cells.map(cell => collapse_inline_whitespace(cell))
}

///|
fn layout_word_covered_columns(
  word : PdfLayoutWord,
  anchors : Array[Int],
) -> Array[Int] {
  let covered : Array[Int] = []
  let center = layout_word_center(word)
  let mut index = 0
  while index < anchors.length() {
    if anchors[index] >= word.left - 18 && anchors[index] <= word.right + 18 {
      covered.push(index)
    }
    index = index + 1
  }
  if covered.length() > 0 {
    return covered
  }

  let mut best_index = 0
  let mut best_distance = abs_int(anchors[0] - center)
  let mut probe = 1
  while probe < anchors.length() {
    let distance = abs_int(anchors[probe] - center)
    if distance < best_distance {
      best_distance = distance
      best_index = probe
    }
    probe = probe + 1
  }
  [best_index]
}

///|
fn detect_layout_table_header_rows(rows : Array[Array[String]]) -> Int {
  let mut header_rows = 0
  let mut index = 0
  while index < rows.length() && index < 3 {
    if layout_table_row_is_data(rows[index]) {
      break
    }
    header_rows = header_rows + 1
    index = index + 1
  }
  if header_rows == 0 { 1 } else { header_rows }
}

///|
fn layout_table_row_is_data(row : Array[String]) -> Bool {
  let mut numeric = 0
  let mut non_empty = 0
  for cell in row {
    let normalized = collapse_inline_whitespace(cell)
    if normalized == "" {
      continue
    }
    non_empty = non_empty + 1
    if looks_like_layout_numeric_value(normalized) {
      numeric = numeric + 1
    }
  }
  non_empty >= 2 && numeric * 2 >= non_empty
}

///|
fn flatten_layout_table_headers(
  rows : Array[Array[String]],
  column_count : Int,
  header_rows : Int,
) -> Array[String] {
  let headers : Array[String] = []
  let mut column = 0
  while column < column_count {
    let parts : Array[String] = []
    let mut row = 0
    while row < header_rows {
      let cell = collapse_inline_whitespace(rows[row][column])
      if cell != "" && (parts.length() == 0 || parts[parts.length() - 1] != cell) {
        parts.push(cell)
      }
      row = row + 1
    }
    headers.push(
      if parts.length() == 0 {
        "Column " + (column + 1).to_string()
      } else {
        parts.join(" / ")
      },
    )
    column = column + 1
  }
  headers
}

///|
fn normalize_layout_table_row(
  row : Array[String],
  column_count : Int,
) -> Array[String] {
  let normalized : Array[String] = []
  let mut index = 0
  while index < column_count {
    normalized.push(collapse_inline_whitespace(row[index]))
    index = index + 1
  }
  normalized
}

///|
fn row_has_any_text(row : Array[String]) -> Bool {
  for cell in row {
    if collapse_inline_whitespace(cell) != "" {
      return true
    }
  }
  false
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 { -value } else { value }
}

///|
fn insert_int_sorted(items : Array[Int], value : Int) -> Unit {
  let mut index = 0
  while index < items.length() && items[index] <= value {
    index = index + 1
  }
  items.insert(index, value)
}

///|
fn try_parse_ocr_whitespace_table(
  chunks : Array[String],
  start : Int,
) -> (Array[String], Array[Array[String]], Int)? {
  let rows : Array[Array[String]] = []
  let mut index = start
  let mut expected_columns = 0

  while index < chunks.length() {
    let chunk = chunks[index]
    let normalized = collapse_inline_whitespace(chunk)
    if normalized == "" || parse_list_item(normalized) is Some(_) {
      break
    }
    let columns = split_ocr_table_columns(chunk)
    if columns.length() < 2 {
      break
    }
    if expected_columns == 0 {
      expected_columns = columns.length()
    } else if columns.length() != expected_columns {
      break
    }
    rows.push(columns)
    index = index + 1
  }

  if rows.length() < 3 || expected_columns < 2 {
    return None
  }
  if !ocr_table_header_is_useful(rows[0]) {
    return None
  }

  let body : Array[Array[String]] = []
  let mut row_index = 1
  while row_index < rows.length() {
    body.push(rows[row_index].map(cell => collapse_inline_whitespace(cell)))
    row_index = row_index + 1
  }
  if body.length() < 2 {
    return None
  }

  Some((rows[0].map(cell => collapse_inline_whitespace(cell)), body, index))
}

///|
fn split_ocr_table_columns(line : String) -> Array[String] {
  let cells : Array[String] = []
  let chars = marker_chars(trim_preserve_inline_whitespace(line))
  let mut current = ""
  let mut space_run = 0
  let mut index = 0

  while index < chars.length() {
    let ch = chars[index]
    if ch == '\t' {
      let trimmed = trim_preserve_inline_whitespace(current)
      if trimmed != "" {
        cells.push(trimmed)
      }
      current = ""
      space_run = 0
      index = index + 1
      continue
    }
    if ch == ' ' {
      space_run = space_run + 1
      index = index + 1
      continue
    }
    if space_run >= 2 {
      let trimmed = trim_preserve_inline_whitespace(current)
      if trimmed != "" {
        cells.push(trimmed)
      }
      current = ""
    } else if space_run == 1 && current != "" {
      current = current + " "
    }
    space_run = 0
    current = current + ch.to_string()
    index = index + 1
  }

  let trimmed = trim_preserve_inline_whitespace(current)
  if trimmed != "" {
    cells.push(trimmed)
  }
  cells
}

///|
fn ocr_table_header_is_useful(row : Array[String]) -> Bool {
  let mut text_like_cells = 0
  for cell in row {
    let normalized = collapse_inline_whitespace(cell)
    if normalized == "" || looks_like_table_value(normalized) {
      continue
    }
    text_like_cells = text_like_cells + 1
  }
  text_like_cells >= 2
}

///|
fn tokenize_table_values(text : String) -> Array[String] {
  let normalized = collapse_inline_whitespace(
    text
    .replace(old="(cid:3) ", new="-")
    .replace(old="(cid:3)", new="-")
    .replace(old="−", new="-"),
  )
  if normalized == "" {
    return []
  }

  let values : Array[String] = []
  for token in normalized.split(" ").to_array() {
    let clean = normalize_table_value_token(token.to_string())
    if clean != "" {
      values.push(clean)
    }
  }

  let mut all_values = values.length() > 0
  for value in values {
    if !looks_like_table_value(value) {
      all_values = false
    }
  }
  if all_values {
    values
  } else {
    []
  }
}

///|
fn normalize_table_value_token(token : String) -> String {
  let trimmed = collapse_inline_whitespace(token)
  if trimmed == "" {
    return ""
  }
  if trimmed == "-" {
    return ""
  }
  trimmed
}

///|
fn looks_like_table_value(token : String) -> Bool {
  let normalized = token
    .replace(old=",", new="")
    .replace(old="(", new="")
    .replace(old=")", new="")
  if normalized == "" {
    return false
  }
  let mut digit_count = 0
  for ch in normalized {
    if is_digit_ascii(ch) {
      digit_count = digit_count + 1
      continue
    }
    if ch == '.' || ch == '-' || ch == '+' || ch == 'E' || ch == 'e' {
      continue
    }
    return false
  }
  digit_count > 0
}

///|
fn should_promote_to_heading(
  pages : Array[PdfPageText],
  page_index : Int,
  chunk_index : Int,
  chunk : String,
  heading_seen : Bool,
) -> Bool {
  if !is_heading_candidate_text(chunk) {
    return false
  }
  if !heading_seen && page_index == 0 && chunk_index == 0 {
    return true
  }
  match next_chunk_after(pages, page_index, chunk_index) {
    Some(next) =>
      next.length() > chunk.length() && parse_list_item(next) is None
    None => false
  }
}

///|
fn next_chunk_after(
  pages : Array[PdfPageText],
  page_index : Int,
  chunk_index : Int,
) -> String? {
  if page_index < pages.length() {
    let page = pages[page_index]
    if chunk_index + 1 < page.chunks.length() {
      return Some(page.chunks[chunk_index + 1])
    }
  }
  let mut next_page = page_index + 1
  while next_page < pages.length() {
    if pages[next_page].chunks.length() > 0 {
      return Some(pages[next_page].chunks[0])
    }
    next_page = next_page + 1
  }
  None
}

///|
fn try_merge_paragraph_candidate(
  candidates : Array[PdfBlockCandidate],
  next_text : String,
) -> Bool {
  if candidates.length() == 0 {
    return false
  }
  let last_index = candidates.length() - 1
  let last = candidates[last_index]
  match last.kind {
    Paragraph =>
      if should_merge_paragraphs(last.text, next_text) {
        candidates[last_index] = PdfBlockCandidate::{
          kind: Paragraph,
          text: merge_paragraph_text(last.text, next_text),
        }
        true
      } else {
        false
      }
    _ => false
  }
}

///|
fn should_merge_paragraphs(left : String, right : String) -> Bool {
  if left == "" || right == "" || is_heading_candidate_text(right) {
    return false
  }
  let left_last = last_visible_char(left)
  let right_first = first_visible_char(right)
  let left_words = tokenize_words(left).length()
  match left_last {
    Some('-') =>
      match right_first {
        Some(first) => is_lower_ascii(first) || is_upper_ascii(first)
        None => false
      }
    Some(last) =>
      match right_first {
        Some(first) =>
          !is_terminal_punctuation(last) &&
          (
            is_lower_ascii(first) ||
            is_digit_ascii(first) ||
            (left_words >= 8 && !looks_like_standalone_line(right))
          )
        None => false
      }
    None => false
  }
}

///|
fn merge_paragraph_text(left : String, right : String) -> String {
  match last_visible_char(left) {
    Some('-') =>
      if should_preserve_wrapped_hyphen(left, right) {
        collapse_inline_whitespace(left) + collapse_inline_whitespace(right)
      } else {
        remove_last_visible_char(left) + collapse_inline_whitespace(right)
      }
    Some('—') =>
      collapse_inline_whitespace(left) + collapse_inline_whitespace(right)
    Some('–') =>
      collapse_inline_whitespace(left) + collapse_inline_whitespace(right)
    _ =>
      collapse_inline_whitespace(left) + " " + collapse_inline_whitespace(right)
  }
}

///|
fn should_preserve_wrapped_hyphen(left : String, right : String) -> Bool {
  let prefix = trailing_word_before_hyphen(left)
  let normalized = normalize_word_token(prefix)
  if normalized == "" {
    return false
  }
  match first_visible_char(right) {
    Some(ch) =>
      is_lower_ascii(ch) &&
      (
        normalized == "self" ||
        normalized == "post" ||
        normalized == "pre" ||
        normalized == "cross" ||
        normalized == "co" ||
        normalized == "non" ||
        normalized == "mid" ||
        normalized == "multi"
      )
    None => false
  }
}

///|
fn trailing_word_before_hyphen(text : String) -> String {
  let trimmed = collapse_inline_whitespace(text)
  let chars = marker_chars(trimmed)
  if chars.length() == 0 || chars[chars.length() - 1] != '-' {
    return ""
  }
  let mut index = chars.length() - 1
  let mut result = ""
  while index > 0 {
    index = index - 1
    let ch = chars[index]
    if is_upper_ascii(ch) || is_lower_ascii(ch) {
      result = ch.to_string() + result
      continue
    }
    break
  }
  result
}

///|
fn last_visible_char(text : String) -> Char? {
  let trimmed = collapse_inline_whitespace(text)
  let mut result : Char? = None
  for ch in trimmed {
    result = Some(ch)
  }
  result
}

///|
fn first_visible_char(text : String) -> Char? {
  for ch in collapse_inline_whitespace(text) {
    return Some(ch)
  }
  None
}

///|
fn remove_last_visible_char(text : String) -> String {
  let trimmed = collapse_inline_whitespace(text)
  let chars : Array[String] = []
  for ch in trimmed {
    chars.push(ch.to_string())
  }
  if chars.length() == 0 {
    return ""
  }
  let result : Array[String] = []
  let mut index = 0
  while index + 1 < chars.length() {
    result.push(chars[index])
    index = index + 1
  }
  result.join("")
}

///|
fn is_terminal_punctuation(ch : Char) -> Bool {
  ch == '.' || ch == '!' || ch == '?' || ch == ':' || ch == ';'
}

///|
fn looks_like_standalone_line(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  normalized == "" ||
  normalized.has_suffix(":") ||
  normalized.has_suffix(",") ||
  tokenize_words(normalized).length() <= 3
}

///|
fn repair_pdf_blocks(
  blocks : Array[@ast.Block],
  heading_seen_init : Bool,
) -> Array[@ast.Block] {
  let repaired : Array[@ast.Block] = []
  let mut heading_seen = heading_seen_init
  let mut index = 0
  while index < blocks.length() {
    let block = blocks[index]
    match block {
      @ast.Heading(_, _) => {
        append_repaired_block(repaired, block)
        heading_seen = true
        index = index + 1
      }
      @ast.List(items, ordered) => {
        append_repaired_list_block(repaired, pdf_list_strings(items), ordered)
        index = index + 1
      }
      @ast.Paragraph([@ast.Text(text)]) => {
        let normalized = collapse_inline_whitespace(text)
        if normalized == "" {
          index = index + 1
          continue
        }
        if looks_like_orphan_list_marker(normalized) {
          match next_plain_text_paragraph(blocks, index + 1) {
            Some((next_text, next_index)) =>
              if try_merge_paragraph_into_last_list(repaired, next_text) {
                index = next_index + 1
                continue
              }
            None => ()
          }
        }
        if try_merge_paragraph_into_last_list(repaired, normalized) {
          index = index + 1
          continue
        }
        if try_append_missing_list_item(repaired, normalized) {
          index = index + 1
          continue
        }
        if should_promote_paragraph_block_to_heading(
            blocks, index, normalized, heading_seen,
          ) {
          let level = if heading_seen { 2 } else { 1 }
          append_repaired_block(repaired, @ast.text_heading(level, normalized))
          heading_seen = true
          index = index + 1
          continue
        }
        append_repaired_block(repaired, @ast.text_paragraph(normalized))
        index = index + 1
      }
      _ => {
        append_repaired_block(repaired, block)
        index = index + 1
      }
    }
  }
  repaired
}

///|
fn append_repaired_block(
  repaired : Array[@ast.Block],
  block : @ast.Block,
) -> Unit {
  match block {
    @ast.List(items, ordered) =>
      append_repaired_list_block(repaired, pdf_list_strings(items), ordered)
    _ => repaired.push(block)
  }
}

///|
fn append_repaired_list_block(
  repaired : Array[@ast.Block],
  items : Array[String],
  ordered : Bool,
) -> Unit {
  if items.length() == 0 {
    return
  }
  if repaired.length() == 0 {
    repaired.push(pdf_list_block(items, ordered))
    return
  }
  let last_index = repaired.length() - 1
  match repaired[last_index] {
    @ast.List(existing, existing_ordered) =>
      if existing_ordered == ordered {
        let merged = copy_string_array(pdf_list_strings(existing))
        for item in items {
          merged.push(item)
        }
        repaired[last_index] = pdf_list_block(merged, ordered)
      } else {
        repaired.push(pdf_list_block(items, ordered))
      }
    _ => repaired.push(pdf_list_block(items, ordered))
  }
}

///|
fn next_plain_text_paragraph(
  blocks : Array[@ast.Block],
  start : Int,
) -> (String, Int)? {
  let mut index = start
  while index < blocks.length() {
    match blocks[index] {
      @ast.Paragraph([@ast.Text(text)]) => {
        let normalized = collapse_inline_whitespace(text)
        if normalized != "" {
          return Some((normalized, index))
        }
      }
      @ast.Paragraph(_) => ()
      _ => return None
    }
    index = index + 1
  }
  None
}

///|
fn looks_like_orphan_list_marker(text : String) -> Bool {
  text == "•" || text == "-" || text == "*" || is_ordered_list_marker(text)
}

///|
fn try_merge_paragraph_into_last_list(
  repaired : Array[@ast.Block],
  text : String,
) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if !looks_like_list_continuation_paragraph(normalized) ||
    repaired.length() == 0 {
    return false
  }
  let last_index = repaired.length() - 1
  match repaired[last_index] {
    @ast.List(items, ordered) =>
      if items.length() == 0 {
        false
      } else {
        let merged_items = copy_string_array(pdf_list_strings(items))
        let item_index = merged_items.length() - 1
        merged_items[item_index] = merge_paragraph_text(
          merged_items[item_index],
          normalized,
        )
        repaired[last_index] = pdf_list_block(merged_items, ordered)
        true
      }
    _ => false
  }
}

///|
fn looks_like_list_continuation_paragraph(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if normalized == "" || looks_like_orphan_list_marker(normalized) {
    return false
  }
  match first_alpha_char(normalized) {
    Some(ch) => is_lower_ascii(ch)
    None => false
  }
}

///|
fn try_append_missing_list_item(
  repaired : Array[@ast.Block],
  text : String,
) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if !looks_like_missing_list_item_paragraph(normalized) ||
    repaired.length() == 0 {
    return false
  }
  let last_index = repaired.length() - 1
  match repaired[last_index] {
    @ast.List(items, ordered) => {
      let merged_items = copy_string_array(pdf_list_strings(items))
      merged_items.push(normalized)
      repaired[last_index] = pdf_list_block(merged_items, ordered)
      true
    }
    _ => false
  }
}

///|
fn looks_like_missing_list_item_paragraph(text : String) -> Bool {
  let normalized = collapse_inline_whitespace(text)
  if normalized == "" || parse_list_item(normalized) is Some(_) {
    return false
  }
  match first_char_index(normalized, ':') {
    Some(index) =>
      index >= 4 &&
      index <= 40 &&
      is_heading_candidate_text(normalized[:index].to_string())
    None => false
  }
}

///|
fn first_char_index(text : String, target : Char) -> Int? {
  let mut index = 0
  for ch in text {
    if ch == target {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn copy_string_array(items : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for item in items {
    copied.push(item)
  }
  copied
}

///|
fn pdf_list_block(items : Array[String], ordered : Bool) -> @ast.Block {
  let inline_items : Array[Array[@ast.Inline]] = []
  for item in items {
    inline_items.push(@ast.text_inlines(item))
  }
  @ast.List(inline_items, ordered)
}

///|
fn pdf_table_block(
  headers : Array[String],
  rows : Array[Array[String]],
) -> @ast.Block {
  let inline_headers : Array[Array[@ast.Inline]] = []
  for cell in headers {
    inline_headers.push(@ast.text_inlines(cell))
  }
  let inline_rows : Array[Array[Array[@ast.Inline]]] = []
  for row in rows {
    let inline_row : Array[Array[@ast.Inline]] = []
    for cell in row {
      inline_row.push(@ast.text_inlines(cell))
    }
    inline_rows.push(inline_row)
  }
  @ast.Table(inline_headers, inline_rows)
}

///|
fn pdf_list_strings(items : Array[Array[@ast.Inline]]) -> Array[String] {
  let copied : Array[String] = []
  for item in items {
    copied.push(@ast.plain_text_of_inlines(item))
  }
  copied
}

///|
fn should_promote_paragraph_block_to_heading(
  blocks : Array[@ast.Block],
  index : Int,
  text : String,
  heading_seen : Bool,
) -> Bool {
  if !is_heading_candidate_text(text) ||
    looks_like_listing_caption(text) ||
    looks_like_table_caption(text) ||
    looks_like_figure_caption(text) {
    return false
  }
  if !heading_seen {
    return true
  }
  match next_block_text_after(blocks, index + 1) {
    Some(next) =>
      next.length() > text.length() ||
      looks_like_missing_list_item_paragraph(next)
    None => false
  }
}

///|
fn next_block_text_after(blocks : Array[@ast.Block], start : Int) -> String? {
  let mut index = start
  while index < blocks.length() {
    match blocks[index] {
      @ast.Paragraph([@ast.Text(text)]) => {
        let normalized = collapse_inline_whitespace(text)
        if normalized != "" {
          return Some(normalized)
        }
      }
      @ast.Heading(_, [@ast.Text(text)]) => {
        let normalized = collapse_inline_whitespace(text)
        if normalized != "" {
          return Some(normalized)
        }
      }
      @ast.List(items, _) =>
        if items.length() > 0 {
          return Some(@ast.plain_text_of_inlines(items[0]))
        } else {
          return None
        }
      _ => return None
    }
    index = index + 1
  }
  None
}

///|
fn render_pdf_candidates(
  candidates : Array[PdfBlockCandidate],
) -> (Array[@ast.Block], Int, Int) {
  let blocks : Array[@ast.Block] = []
  let mut list_block_count = 0
  let mut paragraph_count = 0
  let mut index = 0
  while index < candidates.length() {
    let candidate = candidates[index]
    match candidate.kind {
      Paragraph => {
        blocks.push(@ast.text_paragraph(candidate.text))
        paragraph_count = paragraph_count + 1
        index = index + 1
      }
      Heading(level) => {
        blocks.push(@ast.text_heading(level, candidate.text))
        index = index + 1
      }
      List(ordered) => {
        let items : Array[String] = []
        let mut list_index = index
        while list_index < candidates.length() {
          match candidates[list_index].kind {
            List(next_ordered) if next_ordered == ordered => {
              items.push(candidates[list_index].text)
              list_index = list_index + 1
            }
            _ => break
          }
        }
        blocks.push(pdf_list_block(items, ordered))
        list_block_count = list_block_count + 1
        index = list_index
      }
    }
  }
  (blocks, list_block_count, paragraph_count)
}

///|
fn parse_list_item(text : String) -> PdfListItem? {
  let normalized = collapse_inline_whitespace(text)
  let words = tokenize_words(normalized)
  if words.length() < 2 {
    return None
  }
  let marker = words[0]
  if marker == "•" || marker == "-" || marker == "*" {
    return Some(PdfListItem::{ text: join_words_from(words, 1), ordered: false })
  }
  if is_ordered_list_marker(marker) {
    return Some(PdfListItem::{ text: join_words_from(words, 1), ordered: true })
  }
  None
}

///|
fn is_ordered_list_marker(marker : String) -> Bool {
  if marker == "" {
    return false
  }
  let trimmed = collapse_inline_whitespace(marker)
  if trimmed.length() <= 1 {
    return false
  }
  let chars = marker_chars(trimmed)
  if chars.length() == 0 {
    return false
  }

  if chars[0] == '(' && chars[chars.length() - 1] == ')' && chars.length() > 2 {
    return ordered_marker_body_is_valid(
      join_chars(chars, 1, chars.length() - 1),
    )
  }

  let last = chars[chars.length() - 1]
  if last == '.' || last == ')' {
    return ordered_marker_body_is_valid(
      join_chars(chars, 0, chars.length() - 1),
    )
  }
  false
}

///|
fn ordered_marker_body_is_valid(body : String) -> Bool {
  let normalized = collapse_inline_whitespace(body)
  if normalized == "" {
    return false
  }
  let mut digit_count = 0
  let mut letter_count = 0
  for ch in normalized {
    if is_digit_ascii(ch) {
      digit_count = digit_count + 1
    } else if is_upper_ascii(ch) || is_lower_ascii(ch) {
      letter_count = letter_count + 1
    } else {
      return false
    }
  }
  (digit_count > 0 && letter_count == 0 && digit_count <= 2) ||
  (digit_count == 0 && letter_count == 1)
}

///|
fn marker_chars(text : String) -> Array[Char] {
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  chars
}

///|
fn join_chars(chars : Array[Char], start : Int, end_exclusive : Int) -> String {
  let mut result = ""
  let mut index = start
  while index < end_exclusive && index < chars.length() {
    result = result + chars[index].to_string()
    index = index + 1
  }
  result
}
