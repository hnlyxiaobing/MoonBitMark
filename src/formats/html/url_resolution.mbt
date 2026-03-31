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
