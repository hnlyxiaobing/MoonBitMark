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
  let base_url = html_document_base(input, html)
  let doc = html_to_document_with_base(html, title, base_url)
  let rendered_markdown = @ast.render_markdown(doc)
  let metadata = Map::new()
  metadata["format"] = "html"
  metadata["html_source"] = source_label
  match base_url {
    Some(value) => metadata["html_base"] = value
    None => ()
  }
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
  result = remove_tag_block(result, "template")
  result = remove_comments(result)
  result = select_primary_html(result)
  result = remove_tag_block(result, "nav")
  result = remove_tag_block(result, "aside")
  result = remove_tag_block(result, "footer")
  result = remove_tag_block(result, "form")
  result = remove_tag_block(result, "iframe")
  remove_tag_block(result, "button")
}

///|
fn select_primary_html(html : String) -> String {
  let body = extract_body_html(html)
  match largest_tag_inner_html(body, "article") {
    Some(article) => article
    None =>
      match largest_tag_inner_html(body, "main") {
        Some(main_content) => main_content
        None => body
      }
  }
}

///|
fn largest_tag_inner_html(html : String, tag : String) -> String? {
  let mut best : String? = None
  let mut remaining = html
  while remaining.trim() != "" {
    match find_from(remaining.to_lower(), "<" + tag, 0) {
      Some(start) => {
        remaining = remaining[start:].to_string()
        match take_tag_parts(remaining, tag) {
          Some((_, inner, rest)) => {
            match best {
              Some(current) =>
                if inner.length() > current.length() {
                  best = Some(inner)
                }
              None => best = Some(inner)
            }
            remaining = rest
          }
          None => break
        }
      }
      None => break
    }
  }
  best
}

///|
pub fn html_to_document(html : String, title : String?) -> @ast.Document {
  html_to_document_with_base(html, title, None)
}

///|
fn html_to_document_with_base(
  html : String,
  title : String?,
  base_url : String?,
) -> @ast.Document {
  let blocks = prepend_html_title_block(
    html_to_blocks_with_base(html, base_url),
    title,
  )
  @ast.Document::{ title, metadata: {}, blocks }
}

///|
pub fn html_to_blocks(html : String) -> Array[@ast.Block] {
  html_to_blocks_with_base(html, None)
}

///|
fn html_to_blocks_with_base(
  html : String,
  base_url : String?,
) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  let body = preprocess_html(html)
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
    match parse_next_html_block(remaining, base_url) {
      Some((block, rest)) => {
        blocks.push(block)
        remaining = rest
      }
      None => {
        let paragraph = plain_text_fragment(remaining, base_url)
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
fn parse_next_html_block(
  html : String,
  base_url : String?,
) -> (@ast.Block, String)? {
  if html == "" {
    return None
  }
  if html.has_prefix("<h1") {
    return parse_heading_html_block(html, 1, base_url)
  }
  if html.has_prefix("<h2") {
    return parse_heading_html_block(html, 2, base_url)
  }
  if html.has_prefix("<h3") {
    return parse_heading_html_block(html, 3, base_url)
  }
  if html.has_prefix("<h4") {
    return parse_heading_html_block(html, 4, base_url)
  }
  if html.has_prefix("<h5") {
    return parse_heading_html_block(html, 5, base_url)
  }
  if html.has_prefix("<h6") {
    return parse_heading_html_block(html, 6, base_url)
  }
  if html.has_prefix("<pre") {
    return parse_pre_html_block(html)
  }
  if html.has_prefix("<p") {
    return parse_paragraph_html_block(html, "p", base_url)
  }
  if html.has_prefix("<figcaption") {
    return parse_paragraph_html_block(html, "figcaption", base_url)
  }
  if html.has_prefix("<img") {
    return parse_image_html_block(html, base_url)
  }
  if html.has_prefix("<blockquote") {
    return parse_blockquote_html_block(html, base_url)
  }
  if html.has_prefix("<ul") {
    return parse_list_html_block(html, false, base_url)
  }
  if html.has_prefix("<ol") {
    return parse_list_html_block(html, true, base_url)
  }
  if html.has_prefix("<table") {
    return parse_table_html_block(html, base_url)
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
  base_url : String?,
) -> (@ast.Block, String)? {
  let tag = "h" + level.to_string()
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) =>
      Some((@ast.Heading(level, inline_html_to_inlines(inner, base_url)), rest))
    None => None
  }
}

///|
fn parse_paragraph_html_block(
  html : String,
  tag : String,
  base_url : String?,
) -> (@ast.Block, String)? {
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) =>
      Some((@ast.Paragraph(inline_html_to_inlines(inner, base_url)), rest))
    None => None
  }
}

///|
fn parse_blockquote_html_block(
  html : String,
  base_url : String?,
) -> (@ast.Block, String)? {
  match take_tag_inner_html(html, "blockquote") {
    Some((inner, rest)) => {
      let nested_blocks = html_to_blocks_with_base(inner, base_url)
      let content = @ast.render_markdown(@ast.Document::{
          title: None,
          metadata: {},
          blocks: nested_blocks,
        })
        .trim()
        .to_string()
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
fn parse_image_html_block(
  html : String,
  base_url : String?,
) -> (@ast.Block, String)? {
  match find_from(html, ">", 0) {
    Some(end) => {
      let open_tag = html[:end + 1].to_string()
      let rest = html[end + 1:].to_string()
      let src = resolve_html_image_url(extract_image_source(open_tag), base_url)
      let alt = extract_attribute(open_tag, "alt")
      let inlines = if src == "" {
        if alt == "" {
          []
        } else {
          [@ast.Text(alt)]
        }
      } else {
        [@ast.Image(alt, src)]
      }
      Some((@ast.Paragraph(inlines), rest))
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
  base_url : String?,
) -> (@ast.Block, String)? {
  let tag = if ordered { "ol" } else { "ul" }
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) => {
      let items = extract_list_items(inner, base_url)
      Some((@ast.List(items, ordered), rest))
    }
    None => None
  }
}

///|
fn parse_table_html_block(
  html : String,
  base_url : String?,
) -> (@ast.Block, String)? {
  match take_tag_inner_html(html, "table") {
    Some((inner, rest)) => {
      let (header, rows) = normalize_table_rows(
        extract_table_rows(inner, base_url),
      )
      Some((@ast.Table(header, rows), rest))
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
  let lower = html.to_lower()
  match find_from(lower, "<" + tag, 0) {
    Some(start) if start == 0 =>
      match find_from(html, ">", start) {
        Some(open_end) => {
          let open_tag = html[start:open_end + 1].to_string()
          if open_tag.trim().to_string().has_suffix("/>") {
            let rest = html[open_end + 1:].to_string()
            return Some((open_tag, "", rest))
          }
          let mut depth = 0
          let mut cursor = open_end + 1
          while cursor < html.length() {
            match find_from(lower, "<", cursor) {
              Some(tag_start) =>
                if lower[tag_start:].has_prefix("<!--") {
                  match find_from(lower, "-->", tag_start + 4) {
                    Some(comment_end) => cursor = comment_end + 3
                    None => return None
                  }
                } else if html_matches_tag(lower, tag_start, tag, true) {
                  let close_end = match find_from(html, ">", tag_start) {
                    Some(value) => value
                    None => return None
                  }
                  if depth == 0 {
                    let inner = html[open_end + 1:tag_start].to_string()
                    let rest = html[close_end + 1:].to_string()
                    return Some((open_tag, inner, rest))
                  }
                  depth = depth - 1
                  cursor = close_end + 1
                } else if html_matches_tag(lower, tag_start, tag, false) {
                  let nested_end = match find_from(html, ">", tag_start) {
                    Some(value) => value
                    None => return None
                  }
                  let nested_open = html[tag_start:nested_end + 1].to_string()
                  if !nested_open.trim().to_string().has_suffix("/>") {
                    depth = depth + 1
                  }
                  cursor = nested_end + 1
                } else {
                  cursor = tag_start + 1
                }
              None => return None
            }
          }
          None
        }
        None => None
      }
    _ => None
  }
}

///|
priv struct HtmlTableCell {
  content : Array[@ast.Inline]
  colspan : Int
  rowspan : Int
  is_header : Bool
}

///|
priv struct HtmlPendingSpan {
  remaining : Int
  content : Array[@ast.Inline]
}

///|
priv struct HtmlTableRow {
  cells : Array[HtmlTableCell]
  is_header : Bool
}

///|
fn extract_list_items(
  inner : String,
  base_url : String?,
) -> Array[Array[@ast.Inline]] {
  let items : Array[Array[@ast.Inline]] = []
  let mut remaining = inner
  while remaining.trim() != "" {
    let lower = remaining.to_lower()
    match lower.find("<li") {
      Some(start) =>
        match take_tag_parts(remaining[start:].to_string(), "li") {
          Some((_, item, rest)) => {
            items.push(inline_html_to_inlines(item, base_url))
            remaining = rest
          }
          None => break
        }
      None => break
    }
  }
  items
}

///|
fn extract_table_rows(
  inner : String,
  base_url : String?,
) -> Array[HtmlTableRow] {
  let rows : Array[HtmlTableRow] = []
  let mut remaining = inner
  while remaining.trim() != "" {
    let lower = remaining.to_lower()
    match lower.find("<tr") {
      Some(start) =>
        match take_tag_parts(remaining[start:].to_string(), "tr") {
          Some((_, row_html, rest)) => {
            let cells = extract_html_table_cells(row_html, base_url)
            rows.push(HtmlTableRow::{
              cells,
              is_header: html_table_cells_all_header(cells),
            })
            remaining = rest
          }
          None => break
        }
      None => break
    }
  }
  rows
}

///|
fn inline_html_to_inlines(
  fragment : String,
  base_url : String?,
) -> Array[@ast.Inline] {
  let inlines : Array[@ast.Inline] = []
  let mut cursor = 0
  while cursor < fragment.length() {
    if fragment[cursor] == '<' {
      match parse_known_inline(fragment, cursor, base_url) {
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
  base_url : String?,
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
        let src = resolve_html_image_url(
          extract_image_source(open_tag),
          base_url,
        )
        let alt = extract_attribute(open_tag, "alt")
        let parsed = if src == "" {
          if alt == "" {
            []
          } else {
            [@ast.Text(alt)]
          }
        } else {
          [@ast.Image(alt, src)]
        }
        Some((parsed, cursor + end + 1))
      }
      None => None
    }
  }
  if lower.has_prefix("<strong") {
    return wrap_inline_children(remaining, cursor, base_url, "strong", children => {
      @ast.Strong(children)
    })
  }
  if lower.has_prefix("<b") {
    return wrap_inline_children(remaining, cursor, base_url, "b", children => {
      @ast.Strong(children)
    })
  }
  if lower.has_prefix("<em") {
    return wrap_inline_children(remaining, cursor, base_url, "em", children => {
      @ast.Emphasis(children)
    })
  }
  if lower.has_prefix("<i") {
    return wrap_inline_children(remaining, cursor, base_url, "i", children => {
      @ast.Emphasis(children)
    })
  }
  if lower.has_prefix("<span") ||
    lower.has_prefix("<small") ||
    lower.has_prefix("<mark") ||
    lower.has_prefix("<abbr") ||
    lower.has_prefix("<sup") ||
    lower.has_prefix("<sub") {
    let tag = detect_inline_wrapper_tag(lower)
    return match tag {
      Some(name) =>
        wrap_inline_children(remaining, cursor, base_url, name, children => {
          @ast.Text(render_inline_plain_text(children))
        })
      None => None
    }
  }
  if lower.has_prefix("<a") {
    return match take_tag_parts(remaining, "a") {
      Some((open_tag, inner, rest)) => {
        let href = resolve_html_link_url(
          extract_attribute(open_tag, "href"),
          base_url,
        )
        let children = inline_html_to_inlines(inner, base_url)
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
  base_url : String?,
  tag : String,
  wrap : (Array[@ast.Inline]) -> @ast.Inline,
) -> (Array[@ast.Inline], Int)? {
  match take_tag_parts(remaining, tag) {
    Some((_, inner, rest)) => {
      let children = inline_html_to_inlines(inner, base_url)
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
fn render_inline_plain_text(inlines : Array[@ast.Inline]) -> String {
  let parts : Array[String] = []
  for inline in inlines {
    parts.push(plain_html_inline_text(inline))
  }
  parts.join("").trim().to_string()
}

///|
fn plain_html_inline_text(inline : @ast.Inline) -> String {
  match inline {
    @ast.Text(text) => text
    @ast.Emphasis(children) => render_inline_plain_text(children)
    @ast.Strong(children) => render_inline_plain_text(children)
    @ast.Link(children, _) => render_inline_plain_text(children)
    @ast.Image(alt, _) => alt
    @ast.Code(text) => text
    @ast.LineBreak => "\n"
  }
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
            None =>
              match unwrap_html_tag(html, "main") {
                Some(unwrapped) => Some(unwrapped)
                None =>
                  match unwrap_html_tag(html, "header") {
                    Some(unwrapped) => Some(unwrapped)
                    None => unwrap_html_tag(html, "figure")
                  }
              }
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
fn plain_text_fragment(fragment : String, base_url : String?) -> String {
  render_inline_markdown(inline_html_to_inlines(fragment, base_url))
  .trim()
  .to_string()
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
              let title = decode_html_entities(
                html[tag_end + 1:close_start].to_string().trim().to_string(),
              )
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
  let mut result = html
  let mut found = true
  while found {
    let lower_result = result.to_lower()
    match find_from(lower_result, "<" + tag_name, 0) {
      Some(start) => {
        let before = result[:start].to_string()
        match take_tag_parts(result[start:].to_string(), tag_name) {
          Some((_, _, rest)) => result = before + rest
          None => found = false
        }
      }
      None => found = false
    }
  } nobreak {
    result
  }
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
fn extract_html_table_cells(
  row_html : String,
  base_url : String?,
) -> Array[HtmlTableCell] {
  let cells : Array[HtmlTableCell] = []
  let mut remaining = row_html
  while remaining.trim() != "" {
    let lower = remaining.to_lower()
    let td_pos = lower.find("<td")
    let th_pos = lower.find("<th")
    let start = earliest_option(td_pos, th_pos)
    match start {
      Some(index) =>
        if th_pos == Some(index) {
          match take_tag_parts(remaining[index:].to_string(), "th") {
            Some((open_tag, inner, rest)) => {
              cells.push(HtmlTableCell::{
                content: inline_html_to_inlines(inner, base_url),
                colspan: parse_span_attribute(
                  extract_attribute(open_tag, "colspan"),
                ),
                rowspan: parse_span_attribute(
                  extract_attribute(open_tag, "rowspan"),
                ),
                is_header: true,
              })
              remaining = rest
            }
            None => break
          }
        } else {
          match take_tag_parts(remaining[index:].to_string(), "td") {
            Some((open_tag, inner, rest)) => {
              cells.push(HtmlTableCell::{
                content: inline_html_to_inlines(inner, base_url),
                colspan: parse_span_attribute(
                  extract_attribute(open_tag, "colspan"),
                ),
                rowspan: parse_span_attribute(
                  extract_attribute(open_tag, "rowspan"),
                ),
                is_header: false,
              })
              remaining = rest
            }
            None => break
          }
        }
      None => break
    }
  }
  cells
}

///|
fn normalize_table_rows(
  rows : Array[HtmlTableRow],
) -> (Array[Array[@ast.Inline]], Array[Array[Array[@ast.Inline]]]) {
  if rows.length() == 0 {
    return ([], [])
  }
  let expanded : Array[Array[Array[@ast.Inline]]] = []
  let pending : Array[HtmlPendingSpan?] = []
  let mut width = 0

  for row in rows {
    let current : Array[Array[@ast.Inline]] = []
    let mut col = 0
    for cell in row.cells {
      while col < pending.length() {
        match pending[col] {
          Some(span) if span.remaining > 0 => {
            current.push(span.content)
            pending[col] = Some(HtmlPendingSpan::{
              remaining: span.remaining - 1,
              content: span.content,
            })
            col = col + 1
          }
          _ => break
        }
      }

      for offset in 0..<cell.colspan {
        let content = if offset == 0 || cell.is_header {
          cell.content
        } else {
          []
        }
        current.push(content)
        if cell.rowspan > 1 {
          if col >= pending.length() {
            pending.push(
              Some(HtmlPendingSpan::{ remaining: cell.rowspan - 1, content }),
            )
          } else {
            pending[col] = Some(HtmlPendingSpan::{
              remaining: cell.rowspan - 1,
              content,
            })
          }
        } else if col >= pending.length() {
          pending.push(None)
        } else {
          pending[col] = None
        }
        col = col + 1
      }
    }

    while col < pending.length() {
      match pending[col] {
        Some(span) if span.remaining > 0 => {
          current.push(span.content)
          pending[col] = Some(HtmlPendingSpan::{
            remaining: span.remaining - 1,
            content: span.content,
          })
        }
        _ => current.push([])
      }
      col = col + 1
    }

    if current.length() > width {
      width = current.length()
    }
    expanded.push(current)
  }

  let normalized : Array[Array[Array[@ast.Inline]]] = []
  for row in expanded {
    normalized.push(normalize_html_table_row(row, width))
  }

  let header_count = leading_header_row_count(rows)
  let headers : Array[Array[@ast.Inline]] = []
  for col in 0..<width {
    let parts : Array[String] = []
    for row in 0..<header_count {
      let text = render_inline_plain_text(normalized[row][col])
        .trim()
        .to_string()
      if text != "" && !parts.contains(text) {
        parts.push(text)
      }
    }
    headers.push(@ast.text_inlines(parts.join(" ")))
  }

  let body_rows : Array[Array[Array[@ast.Inline]]] = []
  for row in header_count..<normalized.length() {
    body_rows.push(normalized[row])
  }
  (headers, body_rows)
}

///|
fn normalize_html_table_row(
  row : Array[Array[@ast.Inline]],
  width : Int,
) -> Array[Array[@ast.Inline]] {
  let normalized : Array[Array[@ast.Inline]] = []
  let mut index = 0
  while index < width {
    normalized.push(if index < row.length() { row[index] } else { [] })
    index = index + 1
  } nobreak {
    normalized
  }
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
  match parse_tag_attributes(tag).get(attr_name.to_lower()) {
    Some(value) => decode_html_entities(value)
    None => ""
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
  result = result.replace(old="&apos;", new="'")
  result = result.replace(old="&#39;", new="'")
  result = result.replace(old="&#34;", new="\"")
  result = result.replace(old="&ldquo;", new="\"")
  result = result.replace(old="&rdquo;", new="\"")
  result = result.replace(old="&lsquo;", new="'")
  result = result.replace(old="&rsquo;", new="'")
  result = result.replace(old="&hellip;", new="...")
  result = result.replace(old="&mdash;", new="--")
  result = result.replace(old="&ndash;", new="-")
  result = result.replace(old="&bull;", new="*")
  result
}

///|
fn code_language_from_tag(tag : String) -> String? {
  for class_name in split_whitespace(extract_attribute(tag, "class")) {
    if class_name.has_prefix("language-") {
      return Some(class_name[9:].to_string())
    }
    if class_name.has_prefix("lang-") {
      return Some(class_name[5:].to_string())
    }
  }
  None
}

///|
fn html_document_base(input : String, html : String) -> String? {
  let source_base = if input.has_prefix("http://") ||
    input.has_prefix("https://") {
    Some(input)
  } else {
    None
  }
  match extract_base_href(html) {
    Some(base_href) if base_href != "" =>
      match source_base {
        Some(source) => Some(resolve_relative_url(source, base_href))
        None =>
          if is_absolute_reference(base_href) || base_href.has_prefix("//") {
            Some(base_href)
          } else {
            None
          }
      }
    _ => source_base
  }
}

///|
fn extract_base_href(html : String) -> String? {
  let lower = html.to_lower()
  match find_from(lower, "<base", 0) {
    Some(start) =>
      match find_from(html, ">", start) {
        Some(end_idx) => {
          let value = extract_attribute(
            html[start:end_idx + 1].to_string(),
            "href",
          )
          if value == "" {
            None
          } else {
            Some(value)
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn resolve_html_link_url(href : String, base_url : String?) -> String {
  let normalized = href.trim().to_string()
  if normalized == "" || is_unsafe_reference(normalized) {
    return ""
  }
  if is_absolute_reference(normalized) ||
    normalized.has_prefix("mailto:") ||
    normalized.has_prefix("tel:") ||
    normalized.has_prefix("data:") {
    return normalized
  }
  if normalized.has_prefix("//") {
    return match base_url {
      Some(base) => url_scheme(base) + ":" + normalized
      None => normalized
    }
  }
  match base_url {
    Some(base) => resolve_relative_url(base, normalized)
    None => normalized
  }
}

///|
fn resolve_html_image_url(src : String, base_url : String?) -> String {
  let normalized = src.trim().to_string()
  if normalized == "" || is_unsafe_reference(normalized) {
    return ""
  }
  if normalized.has_prefix("data:") ||
    normalized.has_prefix("http://") ||
    normalized.has_prefix("https://") ||
    normalized.has_prefix("file://") {
    return normalized
  }
  if normalized.has_prefix("//") {
    return match base_url {
      Some(base) => url_scheme(base) + ":" + normalized
      None => normalized
    }
  }
  match base_url {
    Some(base) => resolve_relative_url(base, normalized)
    None => normalized
  }
}

///|
fn extract_image_source(tag : String) -> String {
  let src = extract_attribute(tag, "src")
  if src != "" {
    return src
  }
  let data_src = extract_attribute(tag, "data-src")
  if data_src != "" {
    return data_src
  }
  match first_srcset_candidate(extract_attribute(tag, "srcset")) {
    Some(value) => value
    None => ""
  }
}

///|
fn first_srcset_candidate(srcset : String) -> String? {
  let trimmed = srcset.trim().to_string()
  if trimmed == "" {
    return None
  }
  let first = match trimmed.split(",").next() {
    Some(value) => value.trim().to_string()
    None => return None
  }
  if first == "" {
    return None
  }
  match first.split(" ").next() {
    Some(value) => {
      let candidate = value.trim().to_string()
      if candidate == "" {
        None
      } else {
        Some(candidate)
      }
    }
    None => None
  }
}

///|
fn resolve_relative_url(base : String, reference : String) -> String {
  if reference == "" ||
    is_absolute_reference(reference) ||
    reference.has_prefix("mailto:") ||
    reference.has_prefix("tel:") ||
    reference.has_prefix("data:") {
    return reference
  }
  if !base.has_prefix("http://") &&
    !base.has_prefix("https://") &&
    !base.has_prefix("file://") {
    return reference
  }
  if reference.has_prefix("//") {
    return url_scheme(base) + ":" + reference
  }
  if reference.has_prefix("#") {
    return strip_url_fragment(base) + reference
  }
  if reference.has_prefix("?") {
    return strip_url_query(base) + reference
  }
  let (path_part, suffix) = split_reference_suffix(reference)
  if path_part.has_prefix("/") {
    return url_origin(base) + normalize_url_path(path_part) + suffix
  }
  let directory = url_directory(base)
  url_origin(base) + normalize_url_path(directory + path_part) + suffix
}

///|
fn split_reference_suffix(reference : String) -> (String, String) {
  let mut split_index : Int? = None
  match reference.find("?") {
    Some(index) => split_index = Some(index)
    None => ()
  }
  match reference.find("#") {
    Some(index) =>
      match split_index {
        Some(existing) => if index < existing { split_index = Some(index) }
        None => split_index = Some(index)
      }
    None => ()
  }
  match split_index {
    Some(index) =>
      (reference[:index].to_string(), reference[index:].to_string())
    None => (reference, "")
  }
}

///|
fn strip_url_fragment(url : String) -> String {
  match url.find("#") {
    Some(index) => url[:index].to_string()
    None => url
  }
}

///|
fn strip_url_query(url : String) -> String {
  let without_fragment = strip_url_fragment(url)
  match without_fragment.find("?") {
    Some(index) => without_fragment[:index].to_string()
    None => without_fragment
  }
}

///|
fn url_scheme(url : String) -> String {
  match url.find("://") {
    Some(index) => url[:index].to_string()
    None => ""
  }
}

///|
fn url_origin(url : String) -> String {
  match url.find("://") {
    Some(index) => {
      let prefix_end = index + 3
      match find_first_of(url, ["/", "?", "#"], prefix_end) {
        Some(end) => url[:end].to_string()
        None => url
      }
    }
    None => ""
  }
}

///|
fn url_directory(url : String) -> String {
  let without_suffix = strip_url_query(url)
  let origin = url_origin(without_suffix)
  let path = without_suffix[origin.length():].to_string()
  if path == "" || path.has_suffix("/") {
    path
  } else {
    match find_last_char(path, '/') {
      Some(index) => path[:index + 1].to_string()
      None => "/"
    }
  }
}

///|
fn normalize_url_path(path : String) -> String {
  let leading_slash = path.has_prefix("/")
  let segments : Array[String] = []
  for segment in path.split("/") {
    let part = segment.to_string()
    if part == "" || part == "." {
      continue
    }
    if part == ".." {
      if segments.length() > 0 {
        ignore(segments.pop())
      }
      continue
    }
    segments.push(part)
  }
  let normalized = segments.join("/")
  if leading_slash {
    "/" + normalized
  } else {
    normalized
  }
}

///|
fn is_absolute_reference(reference : String) -> Bool {
  let lower = reference.to_lower()
  lower.has_prefix("http://") ||
  lower.has_prefix("https://") ||
  lower.has_prefix("file://")
}

///|
fn is_unsafe_reference(reference : String) -> Bool {
  let lower = reference.to_lower()
  lower.has_prefix("javascript:") || lower.has_prefix("vbscript:")
}

///|
fn find_first_of(text : String, needles : Array[String], start : Int) -> Int? {
  let mut best : Int? = None
  for needle in needles {
    match find_from(text, needle, start) {
      Some(index) =>
        match best {
          Some(current) => if index < current { best = Some(index) }
          None => best = Some(index)
        }
      None => ()
    }
  }
  best
}

///|
fn detect_inline_wrapper_tag(lower_remaining : String) -> String? {
  if lower_remaining.has_prefix("<span") {
    Some("span")
  } else if lower_remaining.has_prefix("<small") {
    Some("small")
  } else if lower_remaining.has_prefix("<mark") {
    Some("mark")
  } else if lower_remaining.has_prefix("<abbr") {
    Some("abbr")
  } else if lower_remaining.has_prefix("<sup") {
    Some("sup")
  } else if lower_remaining.has_prefix("<sub") {
    Some("sub")
  } else {
    None
  }
}

///|
fn parse_tag_attributes(tag : String) -> Map[String, String] {
  let attrs = Map::new()
  let mut cursor = 1
  if cursor < tag.length() && tag[cursor] == '/' {
    cursor = cursor + 1
  }
  while cursor < tag.length() &&
        !is_html_space(tag[cursor]) &&
        tag[cursor] != '>' &&
        tag[cursor] != '/' {
    cursor = cursor + 1
  }

  while cursor < tag.length() {
    while cursor < tag.length() &&
          (is_html_space(tag[cursor]) || tag[cursor] == '/') {
      cursor = cursor + 1
    }
    if cursor >= tag.length() || tag[cursor] == '>' {
      break
    }

    let name_start = cursor
    while cursor < tag.length() &&
          !is_html_space(tag[cursor]) &&
          tag[cursor] != '=' &&
          tag[cursor] != '>' {
      cursor = cursor + 1
    }
    let name = tag[name_start:cursor].to_lower().to_string()
    while cursor < tag.length() && is_html_space(tag[cursor]) {
      cursor = cursor + 1
    }

    let value = if cursor < tag.length() && tag[cursor] == '=' {
      cursor = cursor + 1
      while cursor < tag.length() && is_html_space(tag[cursor]) {
        cursor = cursor + 1
      }
      if cursor >= tag.length() {
        ""
      } else if tag[cursor] == '"' || tag[cursor] == '\'' {
        let quote = tag[cursor]
        cursor = cursor + 1
        let start = cursor
        while cursor < tag.length() && tag[cursor] != quote {
          cursor = cursor + 1
        }
        let parsed = tag[start:cursor].to_string()
        if cursor < tag.length() {
          cursor = cursor + 1
        }
        parsed
      } else {
        let start = cursor
        while cursor < tag.length() &&
              !is_html_space(tag[cursor]) &&
              tag[cursor] != '>' {
          cursor = cursor + 1
        }
        tag[start:cursor].to_string()
      }
    } else {
      "true"
    }

    if name != "" {
      attrs[name] = value
    }
  }
  attrs
}

///|
fn split_whitespace(text : String) -> Array[String] {
  let parts : Array[String] = []
  let mut current = ""
  for ch in text {
    if ch.is_whitespace() {
      if current != "" {
        parts.push(current)
        current = ""
      }
    } else {
      current = current + ch.to_string()
    }
  }
  if current != "" {
    parts.push(current)
  }
  parts
}

///|
fn parse_span_attribute(raw : String) -> Int {
  if raw == "" {
    return 1
  }
  let mut value = 0
  for ch in raw {
    if !ch.is_ascii_digit() {
      return 1
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  if value <= 0 {
    1
  } else {
    value
  }
}

///|
fn leading_header_row_count(rows : Array[HtmlTableRow]) -> Int {
  let mut count = 0
  for row in rows {
    if row.is_header {
      count = count + 1
    } else {
      break
    }
  }
  if count == 0 {
    1
  } else {
    count
  }
}

///|
fn html_table_cells_all_header(cells : Array[HtmlTableCell]) -> Bool {
  if cells.length() == 0 {
    return false
  }
  for cell in cells {
    if !cell.is_header {
      return false
    }
  }
  true
}

///|
fn earliest_option(left : Int?, right : Int?) -> Int? {
  match left {
    Some(l) =>
      match right {
        Some(r) => Some(if l < r { l } else { r })
        None => Some(l)
      }
    None => right
  }
}

///|
fn html_matches_tag(
  lower_html : String,
  start : Int,
  tag : String,
  closing : Bool,
) -> Bool {
  let prefix = if closing { "</" + tag } else { "<" + tag }
  if !lower_html[start:].has_prefix(prefix) {
    return false
  }
  let boundary = start + prefix.length()
  if boundary >= lower_html.length() {
    true
  } else {
    is_html_tag_boundary(lower_html[boundary])
  }
}

///|
fn is_html_tag_boundary(ch : UInt16) -> Bool {
  is_html_space(ch) || ch == '>' || ch == '/'
}

///|
fn is_html_space(ch : UInt16) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn find_last_char(s : String, target : Char) -> Int? {
  let mut found = -1
  let mut index = 0
  for ch in s {
    if ch == target {
      found = index
    }
    index = index + 1
  }
  if found >= 0 {
    Some(found)
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
