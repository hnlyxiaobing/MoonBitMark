// HTML Converter - Converts HTML files to Markdown (with URL support)

///|
/// Converter for HTML files
pub(all) struct HtmlConverter {
  dummy : Int
}

///|
/// Create a new HTML converter
pub fn HtmlConverter::new() -> HtmlConverter {
  HtmlConverter::{ dummy: 0 }
}

///|
/// Accepts function - checks if file is HTML
pub fn HtmlConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => {
      let mt_lower = mt.to_lower().to_string()
      mt_lower.has_prefix("text/html") ||
      mt_lower.has_prefix("application/xhtml")
    }
    None =>
      match info.extension {
        Some(ext) => {
          let ext_lower = ext.to_lower().to_string()
          ext_lower == ".html" || ext_lower == ".htm" || ext_lower == ".xhtml"
        }
        _ => false
      }
  }
}

///|
/// Convert function - converts HTML to Markdown (supports files and URLs)
pub async fn HtmlConverter::convert(
  input : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  ignore(ctx)
  let (html, source_label) = if input.has_prefix("http://") ||
    input.has_prefix("https://") {
    (
      convert_from_url(input) catch {
        err =>
          fail(
            render_html_failure(
              @core.InputError(
                "Failed to fetch HTML URL",
                Some(err.to_string()),
              ),
              Some(@core.Load(Some("url"))),
              Some(@core.Url(input)),
              Some(
                @core.Custom(
                  "Check the URL, network reachability, and remote response status.",
                ),
              ),
            ),
          )
      },
      "url",
    )
  } else {
    (
      convert_from_file(input) catch {
        err =>
          fail(
            render_html_failure(
              @core.InputError(
                "Failed to read HTML file",
                Some(err.to_string()),
              ),
              Some(@core.Load(Some("file"))),
              Some(@core.File(input)),
              Some(@core.InspectSourceDocument),
            ),
          )
      },
      "file",
    )
  }
  let title = extract_title(html)
  let doc = html_to_document(html, title)
  let rendered_markdown = @ast.render_markdown(doc)
  let metadata = Map::new()
  metadata["format"] = "html"
  metadata["html_source"] = source_label
  let warnings = collect_html_warnings(html)
  let diagnostics = html_warning_diagnostics(input, html)
  @core.ConvertResult::markdown_only(rendered_markdown, "html")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_stats(Some(@core.stats_for_markdown(rendered_markdown)))
  .with_document(Some(doc))
}

///|
fn preprocess_html(html : String) -> String {
  let mut result = html
  result = remove_tag_block(result, "script")
  result = remove_tag_block(result, "style")
  result = remove_tag_block(result, "nav")
  result = remove_tag_block(result, "aside")
  result = remove_tag_block(result, "footer")
  remove_comments(result)
}

///|
pub fn html_to_document(html : String, title : String?) -> @ast.Document {
  let blocks = prepend_html_title_block(html_to_blocks(html), title)
  @ast.Document::{ title, metadata: {}, blocks }
}

///|
pub fn html_to_blocks(html : String) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  let body = extract_body_html(preprocess_html(html))
  let mut remaining = body
  while remaining.trim() != "" {
    let trimmed = remaining.trim_start().to_string()
    remaining = trimmed
    match unwrap_container_html(remaining) {
      Some(unwrapped) => {
        remaining = unwrapped
        continue
      }
      None => ()
    }
    match parse_next_html_block(remaining) {
      Some((block, rest)) => {
        blocks.push(block)
        remaining = rest
      }
      None => {
        let paragraph = plain_text_fragment(remaining)
        if paragraph != "" {
          blocks.push(@ast.text_paragraph(paragraph))
        }
        remaining = ""
      }
    }
  }
  blocks
}

///|
fn extract_body_html(html : String) -> String {
  let lower = html.to_lower()
  match lower.find("<body") {
    Some(start) =>
      match find_from(html, ">", start) {
        Some(open_end) =>
          match find_from(lower, "</body>", open_end + 1) {
            Some(close_start) => html[open_end + 1:close_start].to_string()
            None => html
          }
        None => html
      }
    None => html
  }
}

///|
fn parse_next_html_block(html : String) -> (@ast.Block, String)? {
  if html == "" {
    return None
  }
  if html.has_prefix("<h1") {
    return parse_heading_html_block(html, 1)
  }
  if html.has_prefix("<h2") {
    return parse_heading_html_block(html, 2)
  }
  if html.has_prefix("<h3") {
    return parse_heading_html_block(html, 3)
  }
  if html.has_prefix("<h4") {
    return parse_heading_html_block(html, 4)
  }
  if html.has_prefix("<h5") {
    return parse_heading_html_block(html, 5)
  }
  if html.has_prefix("<h6") {
    return parse_heading_html_block(html, 6)
  }
  if html.has_prefix("<p") {
    return parse_paragraph_html_block(html, "p")
  }
  if html.has_prefix("<blockquote") {
    return parse_blockquote_html_block(html)
  }
  if html.has_prefix("<pre") {
    return parse_pre_html_block(html)
  }
  if html.has_prefix("<ul") {
    return parse_list_html_block(html, false)
  }
  if html.has_prefix("<ol") {
    return parse_list_html_block(html, true)
  }
  if html.has_prefix("<table") {
    return parse_table_html_block(html)
  }
  if html.has_prefix("<hr") {
    let rest = match find_from(html, ">", 0) {
      Some(end) => html[end + 1:].to_string()
      None => ""
    }
    return Some((@ast.HorizontalRule, rest))
  }
  None
}

///|
fn prepend_html_title_block(
  blocks : Array[@ast.Block],
  title : String?,
) -> Array[@ast.Block] {
  let result : Array[@ast.Block] = []
  match title {
    Some(value) if !leading_html_block_matches_title(blocks, value) =>
      result.push(@ast.text_paragraph(value))
    _ => ()
  }
  for block in blocks {
    result.push(block)
  }
  result
}

///|
fn leading_html_block_matches_title(
  blocks : Array[@ast.Block],
  title : String,
) -> Bool {
  match blocks {
    [first, ..] =>
      normalize_html_block_text(html_block_text(first)) ==
      normalize_html_block_text(title)
    [] => false
  }
}

///|
fn html_block_text(block : @ast.Block) -> String {
  match block {
    @ast.Heading(_, inlines) =>
      render_inline_markdown(inlines).trim().to_string()
    @ast.Paragraph(inlines) =>
      render_inline_markdown(inlines).trim().to_string()
    _ => ""
  }
}

///|
fn normalize_html_block_text(text : String) -> String {
  text.trim().to_lower().to_string()
}

///|
fn parse_heading_html_block(
  html : String,
  level : Int,
) -> (@ast.Block, String)? {
  let tag = "h" + level.to_string()
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) =>
      Some((@ast.Heading(level, inline_html_to_inlines(inner)), rest))
    None => None
  }
}

///|
fn parse_paragraph_html_block(
  html : String,
  tag : String,
) -> (@ast.Block, String)? {
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) =>
      Some((@ast.Paragraph(inline_html_to_inlines(inner)), rest))
    None => None
  }
}

///|
fn parse_blockquote_html_block(html : String) -> (@ast.Block, String)? {
  match take_tag_inner_html(html, "blockquote") {
    Some((inner, rest)) => {
      let content = render_inline_markdown(inline_html_to_inlines(inner))
      Some(
        (
          @ast.Quote(
            content.split("\n").to_array().map(line => line.to_string()),
          ),
          rest,
        ),
      )
    }
    None => None
  }
}

///|
fn parse_pre_html_block(html : String) -> (@ast.Block, String)? {
  match take_tag_inner_html(html, "pre") {
    Some((inner, rest)) => {
      let trimmed = inner.trim().to_string()
      match take_tag_parts(trimmed, "code") {
        Some((open_tag, code_inner, _)) => {
          let lang = code_language_from_tag(open_tag)
          let content = decode_html_entities(strip_remaining_tags(code_inner))
            .trim()
            .to_string()
          Some((@ast.CodeBlock(lang, content), rest))
        }
        None => {
          let content = decode_html_entities(strip_remaining_tags(inner))
            .trim()
            .to_string()
          Some((@ast.CodeBlock(None, content), rest))
        }
      }
    }
    None => None
  }
}

///|
fn parse_list_html_block(
  html : String,
  ordered : Bool,
) -> (@ast.Block, String)? {
  let tag = if ordered { "ol" } else { "ul" }
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) => {
      let items = extract_list_items(inner)
      Some((@ast.List(items, ordered), rest))
    }
    None => None
  }
}

///|
fn parse_table_html_block(html : String) -> (@ast.Block, String)? {
  match take_tag_inner_html(html, "table") {
    Some((inner, rest)) => {
      let rows = extract_table_rows(inner)
      match rows {
        [header, .. tail] => Some((@ast.Table(header, tail.to_array()), rest))
        [] => Some((@ast.Table([], []), rest))
      }
    }
    None => None
  }
}

///|
fn take_tag_inner_html(html : String, tag : String) -> (String, String)? {
  match take_tag_parts(html, tag) {
    Some((_, inner, rest)) => Some((inner, rest))
    None => None
  }
}

///|
fn take_tag_parts(html : String, tag : String) -> (String, String, String)? {
  let open = "<" + tag
  let close = "</" + tag + ">"
  match find_from(html.to_lower(), open, 0) {
    Some(start) if start == 0 =>
      match find_from(html, ">", start) {
        Some(open_end) =>
          match find_from(html.to_lower(), close, open_end + 1) {
            Some(close_start) => {
              let open_tag = html[start:open_end + 1].to_string()
              let inner = html[open_end + 1:close_start].to_string()
              let rest = html[close_start + close.length():].to_string()
              Some((open_tag, inner, rest))
            }
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn extract_list_items(inner : String) -> Array[String] {
  let items : Array[String] = []
  let mut remaining = inner
  while remaining.trim() != "" {
    let lower = remaining.to_lower()
    match lower.find("<li") {
      Some(start) =>
        match find_from(remaining, ">", start) {
          Some(open_end) =>
            match find_from(lower, "</li>", open_end + 1) {
              Some(close_start) => {
                let item = remaining[open_end + 1:close_start].to_string()
                items.push(render_inline_markdown(inline_html_to_inlines(item)))
                remaining = remaining[close_start + 5:].to_string()
              }
              None => break
            }
          None => break
        }
      None => break
    }
  }
  items
}

///|
fn extract_table_rows(inner : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  let mut remaining = inner
  while remaining.trim() != "" {
    let lower = remaining.to_lower()
    match lower.find("<tr") {
      Some(start) =>
        match find_from(remaining, ">", start) {
          Some(open_end) =>
            match find_from(lower, "</tr>", open_end + 1) {
              Some(close_start) => {
                let row_html = remaining[open_end + 1:close_start].to_string()
                rows.push(extract_table_cells(row_html))
                remaining = remaining[close_start + 5:].to_string()
              }
              None => break
            }
          None => break
        }
      None => break
    }
  }
  rows
}

///|
fn inline_html_to_inlines(fragment : String) -> Array[@ast.Inline] {
  let inlines : Array[@ast.Inline] = []
  let mut cursor = 0
  while cursor < fragment.length() {
    if fragment[cursor] == '<' {
      match parse_known_inline(fragment, cursor) {
        Some((parsed, next_cursor)) => {
          for inline in parsed {
            inlines.push(inline)
          }
          cursor = next_cursor
        }
        None =>
          match find_from(fragment, ">", cursor) {
            Some(end) => cursor = end + 1
            None => {
              push_text_inline(inlines, fragment[cursor:].to_string())
              break
            }
          }
      }
    } else {
      let next_tag = match find_from(fragment, "<", cursor) {
        Some(pos) => pos
        None => fragment.length()
      }
      push_text_inline(inlines, fragment[cursor:next_tag].to_string())
      cursor = next_tag
    }
  }
  inlines
}

///|
fn parse_known_inline(
  fragment : String,
  cursor : Int,
) -> (Array[@ast.Inline], Int)? {
  let remaining = fragment[cursor:].to_string()
  let lower = remaining.to_lower()
  if lower.has_prefix("<br") {
    return match find_from(remaining, ">", 0) {
      Some(end) => Some(([@ast.LineBreak], cursor + end + 1))
      None => None
    }
  }
  if lower.has_prefix("<img") {
    return match find_from(remaining, ">", 0) {
      Some(end) => {
        let open_tag = remaining[0:end + 1].to_string()
        let src = extract_attribute(open_tag, "src")
        let alt = extract_attribute(open_tag, "alt")
        Some(([@ast.Image(alt, src)], cursor + end + 1))
      }
      None => None
    }
  }
  if lower.has_prefix("<strong") {
    return wrap_inline_children(remaining, cursor, "strong", children => {
      @ast.Strong(children)
    })
  }
  if lower.has_prefix("<b") {
    return wrap_inline_children(remaining, cursor, "b", children => {
      @ast.Strong(children)
    })
  }
  if lower.has_prefix("<em") {
    return wrap_inline_children(remaining, cursor, "em", children => {
      @ast.Emphasis(children)
    })
  }
  if lower.has_prefix("<i") {
    return wrap_inline_children(remaining, cursor, "i", children => {
      @ast.Emphasis(children)
    })
  }
  if lower.has_prefix("<a") {
    return match take_tag_parts(remaining, "a") {
      Some((open_tag, inner, rest)) => {
        let href = extract_attribute(open_tag, "href")
        let children = inline_html_to_inlines(inner)
        let parsed = if href == "" {
          children
        } else {
          [@ast.Link(children, href)]
        }
        Some((parsed, cursor + remaining.length() - rest.length()))
      }
      None => None
    }
  }
  if lower.has_prefix("<code") {
    return match take_tag_parts(remaining, "code") {
      Some((_, inner, rest)) => {
        let content = decode_html_entities(strip_remaining_tags(inner))
        Some(
          ([@ast.Code(content)], cursor + remaining.length() - rest.length()),
        )
      }
      None => None
    }
  }
  None
}

///|
fn wrap_inline_children(
  remaining : String,
  cursor : Int,
  tag : String,
  wrap : (Array[@ast.Inline]) -> @ast.Inline,
) -> (Array[@ast.Inline], Int)? {
  match take_tag_parts(remaining, tag) {
    Some((_, inner, rest)) => {
      let children = inline_html_to_inlines(inner)
      Some(([wrap(children)], cursor + remaining.length() - rest.length()))
    }
    None => None
  }
}

///|
fn push_text_inline(inlines : Array[@ast.Inline], text : String) -> Unit {
  let decoded = decode_html_entities(text)
  if decoded == "" {
    return
  }
  match inlines {
    [.., @ast.Text(last)] => {
      ignore(inlines.pop())
      inlines.push(@ast.Text(last + decoded))
    }
    _ => inlines.push(@ast.Text(decoded))
  }
}

///|
fn render_inline_markdown(inlines : Array[@ast.Inline]) -> String {
  @ast.render_inlines(inlines).replace(old="  \n", new="\n")
}

///|
fn unwrap_container_html(html : String) -> String? {
  match unwrap_html_tag(html, "div") {
    Some(unwrapped) => Some(unwrapped)
    None =>
      match unwrap_html_tag(html, "section") {
        Some(unwrapped) => Some(unwrapped)
        None =>
          match unwrap_html_tag(html, "article") {
            Some(unwrapped) => Some(unwrapped)
            None => unwrap_html_tag(html, "main")
          }
      }
  }
}

///|
fn unwrap_html_tag(html : String, tag : String) -> String? {
  if !html.has_prefix("<" + tag) {
    return None
  }
  match take_tag_parts(html, tag) {
    Some((_, inner, rest)) => {
      let trimmed_inner = inner.trim().to_string()
      if trimmed_inner == "" {
        Some(rest)
      } else if rest.trim() == "" {
        Some(trimmed_inner)
      } else {
        Some(trimmed_inner + "\n" + rest)
      }
    }
    None => None
  }
}

///|
fn plain_text_fragment(fragment : String) -> String {
  render_inline_markdown(inline_html_to_inlines(fragment)).trim().to_string()
}

///|
/// Convert from URL
pub async fn convert_from_url(url : String) -> String {
  let (response, data) = @http.get(url)
  if response.code != 200 {
    fail("HTTP request failed with status code: " + response.code.to_string())
  }
  data.text()
}

///|
/// Convert from local file
pub async fn convert_from_file(file_path : String) -> String {
  @core.strip_utf8_bom(@core.read_utf8_file(file_path))
}

///|
fn extract_title(html : String) -> String? {
  let lower = html.to_lower()
  match lower.find("<title") {
    Some(start) =>
      match find_from(html, ">", start) {
        Some(tag_end) =>
          match find_from(lower, "</title>", tag_end + 1) {
            Some(close_start) => {
              let title = html[tag_end + 1:close_start]
                .to_string()
                .trim()
                .to_string()
              if title == "" {
                None
              } else {
                Some(title)
              }
            }
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn collect_html_warnings(html : String) -> Array[String] {
  let warnings : Array[String] = []
  let lower = html.to_lower()
  if lower.contains("<script") {
    warnings.push("Dropped <script> blocks during HTML conversion.")
  }
  if lower.contains("<style") {
    warnings.push("Dropped <style> blocks during HTML conversion.")
  }
  if lower.contains("<nav") {
    warnings.push("Dropped <nav> blocks during HTML conversion.")
  }
  if lower.contains("<aside") {
    warnings.push("Dropped <aside> blocks during HTML conversion.")
  }
  if lower.contains("<footer") {
    warnings.push("Dropped <footer> blocks during HTML conversion.")
  }
  warnings
}

///|
fn html_warning_diagnostics(
  input : String,
  html : String,
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  let lower = html.to_lower()
  let source = if input.has_prefix("http://") || input.has_prefix("https://") {
    @core.Url(input)
  } else {
    @core.File(input)
  }
  if lower.contains("<script") {
    diagnostics.push(
      @core.warning_diagnostic(
        "Dropped <script> blocks during HTML conversion.",
        Some(@core.Normalize(Some("preprocess"))),
        Some(source),
        Some(
          @core.Custom(
            "Scripts are intentionally removed before Markdown rendering.",
          ),
        ),
      ),
    )
  }
  if lower.contains("<style") {
    diagnostics.push(
      @core.warning_diagnostic(
        "Dropped <style> blocks during HTML conversion.",
        Some(@core.Normalize(Some("preprocess"))),
        Some(source),
        Some(@core.Custom("CSS is not preserved in Markdown output.")),
      ),
    )
  }
  if lower.contains("<nav") {
    diagnostics.push(
      @core.warning_diagnostic(
        "Dropped <nav> blocks during HTML conversion.",
        Some(@core.Normalize(Some("preprocess"))),
        Some(source),
        Some(
          @core.Custom(
            "Navigation chrome is removed so the Markdown stays focused on body content.",
          ),
        ),
      ),
    )
  }
  if lower.contains("<aside") {
    diagnostics.push(
      @core.warning_diagnostic(
        "Dropped <aside> blocks during HTML conversion.",
        Some(@core.Normalize(Some("preprocess"))),
        Some(source),
        Some(
          @core.Custom(
            "Sidebar content is removed when extracting the main readable body.",
          ),
        ),
      ),
    )
  }
  if lower.contains("<footer") {
    diagnostics.push(
      @core.warning_diagnostic(
        "Dropped <footer> blocks during HTML conversion.",
        Some(@core.Normalize(Some("preprocess"))),
        Some(source),
        Some(
          @core.Custom(
            "Repeated footer content is removed during HTML body cleanup.",
          ),
        ),
      ),
    )
  }
  diagnostics
}

///|
fn find_from(haystack : String, needle : String, start : Int) -> Int? {
  if start >= haystack.length() {
    None
  } else {
    let substring = haystack[start:].to_string()
    match substring.find(needle[:]) {
      Some(pos) => Some(start + pos)
      None => None
    }
  }
}

///|
fn remove_tag_block(html : String, tag_name : String) -> String {
  let open_tag = "<" + tag_name
  let close_tag = "</" + tag_name
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find(open_tag[:]) {
      Some(start) =>
        match find_from(lower_result, close_tag, start) {
          Some(end_idx) => {
            let close_end = end_idx + close_tag.length()
            let before = result[:start].to_string()
            let after = result[close_end:].to_string()
            result = before + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
fn remove_comments(html : String) -> String {
  let mut result = html
  let mut found = true

  while found {
    match result.find("<!--") {
      Some(idx) =>
        match find_from(result, "-->", idx) {
          Some(end_idx) => {
            let close_end = end_idx + 3
            let before = result[:idx].to_string()
            let after = result[close_end:].to_string()
            result = before + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
fn extract_table_cells(row_html : String) -> Array[String] {
  let th_cells = extract_cells_by_tag(row_html, "th")
  if th_cells.length() > 0 {
    th_cells
  } else {
    extract_cells_by_tag(row_html, "td")
  }
}

///|
fn extract_cells_by_tag(html : String, tag : String) -> Array[String] {
  let cells : Array[String] = Array::new()
  let open_tag = "<" + tag
  let close_tag = "</" + tag
  let mut remaining = html
  let mut found = true

  while found {
    let lower_remaining = remaining.to_lower()
    match lower_remaining.find(open_tag[:]) {
      Some(idx) =>
        match find_from(remaining, ">", idx) {
          Some(tag_end_idx) => {
            let content_start = tag_end_idx + 1
            match find_from(lower_remaining, close_tag, content_start) {
              Some(end_idx) => {
                let content = remaining[content_start:end_idx].to_string()
                cells.push(
                  render_inline_markdown(inline_html_to_inlines(content))
                  .trim()
                  .to_string(),
                )
                remaining = remaining[end_idx + close_tag.length():].to_string()
              }
              None => found = false
            }
          }
          None => found = false
        }
      None => found = false
    }
  }

  cells
}

///|
fn strip_remaining_tags(html : String) -> String {
  let mut result = html
  let mut found = true

  while found {
    match result.find("<") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(end_idx) => {
            let before = result[:idx].to_string()
            let after = result[end_idx + 1:].to_string()
            result = before + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
fn extract_attribute(tag : String, attr_name : String) -> String {
  let attr_pattern = attr_name + "=\""
  let attr_pattern_single = attr_name + "='"

  match tag.find(attr_pattern[:]) {
    Some(idx) => {
      let start = idx + attr_pattern.length()
      let remaining = tag[start:].to_string()
      match remaining.find("\"") {
        Some(end) => remaining[:end].to_string()
        None => ""
      }
    }
    None =>
      match tag.find(attr_pattern_single[:]) {
        Some(idx) => {
          let start = idx + attr_pattern_single.length()
          let remaining = tag[start:].to_string()
          match remaining.find("'") {
            Some(end) => remaining[:end].to_string()
            None => ""
          }
        }
        None => ""
      }
  }
}

///|
fn decode_html_entities(text : String) -> String {
  let mut result = text
  result = result.replace(old="&nbsp;", new=" ")
  result = result.replace(old="&amp;", new="&")
  result = result.replace(old="&lt;", new="<")
  result = result.replace(old="&gt;", new=">")
  result = result.replace(old="&quot;", new="\"")
  result = result.replace(old="&#39;", new="'")
  result
}

///|
fn code_language_from_tag(tag : String) -> String? {
  let class_name = extract_attribute(tag, "class")
  if class_name.has_prefix("language-") {
    Some(class_name[9:].to_string())
  } else {
    None
  }
}

///|
fn render_html_failure(
  error : @core.ConversionError,
  phase : @core.ConversionPhase?,
  source : @core.DiagnosticSource?,
  hint : @core.DiagnosticHint?,
) -> String {
  @core.error_diagnostic(error, phase, source, hint).render()
}
