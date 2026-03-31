// MoonBitMark MCP Handler - Runtime Security Boundaries

///|
pub(all) struct McpSecurityConfig {
  allowed_roots : Array[String]
  allow_http : Bool
  enable_ocr : Bool
  max_output_chars : Int?
  max_upload_bytes : Int
}

///|
pub fn load_mcp_security_config() -> Result[McpSecurityConfig, String] {
  let allowed_roots = match parse_allowed_roots_env() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let allow_http = match parse_bool_env("MOONBITMARK_MCP_ALLOW_HTTP", false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let enable_ocr = match parse_bool_env("MOONBITMARK_MCP_ENABLE_OCR", false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let max_output_chars = match
    parse_positive_int_env("MOONBITMARK_MCP_MAX_OUTPUT_CHARS") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let max_upload_bytes = match
    parse_positive_int_env_with_default(
      "MOONBITMARK_MCP_MAX_UPLOAD_BYTES", 10485760,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }

  Ok(McpSecurityConfig::{
    allowed_roots,
    allow_http,
    enable_ocr,
    max_output_chars,
    max_upload_bytes,
  })
}

///|
pub fn enforce_mcp_input_boundary(
  uri : String,
  config : McpSecurityConfig,
) -> Result[String, String] {
  let input = normalize_file_uri(uri)
  if is_http_input(input) {
    if !config.allow_http {
      Err(
        "HTTP input is disabled by MOONBITMARK_MCP_ALLOW_HTTP; set it to 1 or true to allow http:// and https:// URIs.",
      )
    } else {
      Ok(input)
    }
  } else {
    let resolved = resolve_file_path(input)
    if path_within_allowed_roots(resolved, config.allowed_roots) {
      Ok(resolved)
    } else {
      Err("File input is outside MOONBITMARK_MCP_ALLOWED_ROOTS: " + resolved)
    }
  }
}

///|
pub fn build_mcp_convert_context(
  config : McpSecurityConfig,
) -> @core.ConvertContext {
  let mut ctx = @core.ConvertContext::default()
  if config.enable_ocr {
    ctx = {
      ..ctx,
      ocr: @ocr.OcrConfig::{
        ..@ocr.OcrConfig::default(),
        mode: @ocr.Auto,
        enable_embedded_images: true,
      },
    }
  }
  ctx
}

///|
pub fn clamp_mcp_output_chars(
  requested_limit : Int?,
  config : McpSecurityConfig,
) -> Int? {
  match (requested_limit, config.max_output_chars) {
    (Some(requested), Some(boundary)) => Some(min_int(requested, boundary))
    (Some(requested), None) => Some(requested)
    (None, Some(boundary)) => Some(boundary)
    (None, None) => None
  }
}

///|
fn parse_allowed_roots_env() -> Result[Array[String], String] {
  match @env.get_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS") {
    Some(raw) if raw.trim() != "" => {
      let roots : Array[String] = []
      for segment in split_root_segments(raw) {
        if segment.trim() != "" {
          roots.push(resolve_file_path(segment.trim().to_string()))
        }
      }
      if roots.length() == 0 {
        return Err(
          "MOONBITMARK_MCP_ALLOWED_ROOTS must contain at least one non-empty path.",
        )
      }
      Ok(roots)
    }
    _ => Ok([resolve_file_path(current_dir_or_dot())])
  }
}

///|
fn split_root_segments(raw : String) -> Array[String] {
  let items : Array[String] = []
  for line in raw.replace(old="\r", new="").split("\n").to_array() {
    for segment in line.split(";").to_array() {
      let value = segment.to_string()
      if value.trim() != "" {
        items.push(value)
      }
    }
  }
  items
}

///|
fn parse_bool_env(name : String, fallback : Bool) -> Result[Bool, String] {
  match @env.get_env_var(name) {
    Some(raw) if raw.trim() != "" => {
      let normalized = raw.trim().to_lower().to_string()
      match normalized {
        "1" => Ok(true)
        "true" => Ok(true)
        "yes" => Ok(true)
        "on" => Ok(true)
        "0" => Ok(false)
        "false" => Ok(false)
        "no" => Ok(false)
        "off" => Ok(false)
        _ => Err(name + " must be one of: 1, 0, true, false, yes, no, on, off.")
      }
    }
    _ => Ok(fallback)
  }
}

///|
fn parse_positive_int_env(name : String) -> Result[Int?, String] {
  match @env.get_env_var(name) {
    Some(raw) if raw.trim() != "" => {
      let value : Int = @strconv.from_str(raw.trim()) catch {
        _ => return Err(name + " must be a positive integer.")
      }
      if value > 0 {
        Ok(Some(value))
      } else {
        Err(name + " must be a positive integer.")
      }
    }
    _ => Ok(None)
  }
}

///|
fn parse_positive_int_env_with_default(
  name : String,
  fallback : Int,
) -> Result[Int, String] {
  match parse_positive_int_env(name) {
    Ok(Some(value)) => Ok(value)
    Ok(None) => Ok(fallback)
    Err(message) => Err(message)
  }
}

///|
fn current_dir_or_dot() -> String {
  match @env.current_dir() {
    Some(dir) if dir.trim() != "" => dir
    _ => "."
  }
}

///|
fn normalize_file_uri(uri : String) -> String {
  if uri.has_prefix("file://") {
    uri[7:].to_string()
  } else {
    uri
  }
}

///|
fn is_http_input(input : String) -> Bool {
  input.has_prefix("http://") || input.has_prefix("https://")
}

///|
fn resolve_file_path(path : String) -> String {
  let normalized = canonicalize_path(@core.normalize_path(path))
  if is_absolute_path(normalized) {
    normalize_compare_path(normalized)
  } else {
    normalize_compare_path(
      canonicalize_path(
        @core.normalize_path(current_dir_or_dot()) + "/" + normalized,
      ),
    )
  }
}

///|
fn path_within_allowed_roots(path : String, roots : Array[String]) -> Bool {
  for root in roots {
    if path == root || path.has_prefix(root + "/") {
      return true
    }
  }
  false
}

///|
fn canonicalize_path(path : String) -> String {
  let normalized = @core.normalize_path(path)
  let prefix = path_prefix(normalized)
  let start = prefix.length()
  let remainder = normalized[start:]
  let segments : Array[String] = []
  for raw_segment in remainder.split("/").to_array() {
    let segment = raw_segment.to_string()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      ignore(segments.pop())
    } else {
      segments.push(segment)
    }
  }

  match prefix {
    "/" => "/" + segments.join("/")
    "" => segments.join("/")
    _ =>
      if segments.length() == 0 {
        prefix + "/"
      } else {
        prefix + "/" + segments.join("/")
      }
  }
}

///|
fn path_prefix(path : String) -> String {
  if path.length() >= 2 &&
    is_ascii_letter(path[0]) &&
    path[1:2].to_string() == ":" {
    path[0:2].to_string()
  } else if path.has_prefix("/") {
    "/"
  } else {
    ""
  }
}

///|
fn is_absolute_path(path : String) -> Bool {
  path.has_prefix("/") ||
  (
    path.length() >= 2 &&
    is_ascii_letter(path[0]) &&
    path[1:2].to_string() == ":"
  )
}

///|
fn normalize_compare_path(path : String) -> String {
  path.to_lower().to_string()
}

///|
fn is_ascii_letter(ch : UInt16) -> Bool {
  (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122)
}

///|
fn min_int(left : Int, right : Int) -> Int {
  if left <= right {
    left
  } else {
    right
  }
}
