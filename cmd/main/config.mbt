// Default output directory resolution for the CLI.
//
// Priority (highest first):
// 1. `MOONBITMARK_OUT_DIR` — an empty value is ignored (falls through).
// 2. `<home>/.moonbitmark/config.json` field `out_dir` — a missing or empty
//    value disables the default.
// `None` keeps the historical behavior: markdown goes to stdout.

///|
fn config_home_candidates() -> Array[String] {
  let homes : Array[String] = []
  for name in ["USERPROFILE", "HOME"] {
    match @env.get_env_var(name) {
      Some(value) => {
        let home = value.trim().to_owned()
        if home != "" && !homes.contains(home) {
          homes.push(home)
        }
      }
      None => ()
    }
  }
  homes
}

///|
fn default_config_path(home : String) -> String {
  home.replace_all(old="\\", new="/").trim().to_owned() +
  "/.moonbitmark/config.json"
}

///|
async fn read_config_text(path : String) -> String? {
  let content = @core.read_utf8_file(path) catch { _ => return None }
  Some(content)
}

///|
/// Parse the `out_dir` field of a config file body. Raises on malformed JSON
/// or a non-string `out_dir` so configuration errors surface immediately.
/// A leading UTF-8 BOM (common in Windows-edited files) is tolerated.
fn out_dir_from_config(content : String, path : String) -> String? raise {
  let body = strip_leading_bom(content)
  match @types.parse_json(body) {
    Ok(value) =>
      match value.get("out_dir") {
        Some(@types.String(dir)) => {
          let dir = dir.trim().to_owned()
          if dir == "" {
            None
          } else {
            Some(dir)
          }
        }
        Some(_) =>
          fail("invalid config file " + path + ": out_dir must be a string")
        None => None
      }
    Err(error) => fail("invalid config file " + path + ": " + error.to_string())
  }
}

///|
fn strip_leading_bom(text : String) -> String {
  if text.has_prefix("\u{FEFF}") {
    text[1:].to_owned()
  } else {
    text
  }
}

///|
/// Resolve the default output directory for this run. Raises when a config
/// file exists but cannot be parsed.
async fn load_default_out_dir() -> String? {
  match @env.get_env_var("MOONBITMARK_OUT_DIR") {
    Some(value) => {
      let dir = value.trim().to_owned()
      if dir != "" {
        return Some(dir)
      }
    }
    None => ()
  }
  for home in config_home_candidates() {
    let path = default_config_path(home)
    match read_config_text(path) {
      Some(content) => return out_dir_from_config(content, path)
      None => continue
    }
  }
  None
}

///|
/// Derive the default output path `<out_dir>/<basename>.md` for `input`.
fn derive_output_path(input : String, out_dir : String) -> String {
  let dir = strip_trailing_slashes(
    out_dir.trim().replace_all(old="\\", new="/").to_owned(),
  )
  let name = derive_output_basename(input) + ".md"
  if dir == "" {
    name
  } else {
    dir + "/" + name
  }
}

///|
fn derive_output_basename(input : String) -> String {
  let trimmed = input.trim().to_owned()
  let url = is_url_input(trimmed)
  let work = if url { strip_url_suffix(trimmed) } else { trimmed }
  let stem = strip_extension(last_path_segment(work))
  let sanitized = strip_trailing_dots_and_spaces(sanitize_filename(stem))
  if sanitized == "" {
    if url {
      "index"
    } else {
      "output"
    }
  } else {
    sanitized
  }
}

///|
fn is_url_input(input : String) -> Bool {
  let lowered = input.to_lower().to_string()
  lowered.has_prefix("http://") || lowered.has_prefix("https://")
}

///|
/// Drop a URL query string and fragment so only the path remains.
fn strip_url_suffix(url : String) -> String {
  let mut end = url.length()
  for marker in ["?", "#"] {
    match url.find(marker) {
      Some(index) => if index < end { end = index }
      None => ()
    }
  }
  url[0:end].to_owned()
}

///|
fn last_path_segment(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  let mut separator = -1
  for i in 0..<normalized.length() {
    if normalized[i] == '/' {
      separator = i
    }
  }
  if separator < 0 {
    normalized
  } else {
    normalized[separator + 1:].to_owned()
  }
}

///|
/// Remove the final `.ext` suffix. A leading dot (".env") is kept so hidden
/// file names are not destroyed.
fn strip_extension(name : String) -> String {
  let mut dot = -1
  for i in 0..<name.length() {
    if name[i] == '.' {
      dot = i
    }
  }
  if dot <= 0 {
    name
  } else {
    name[0:dot].to_owned()
  }
}

///|
/// Replace characters that are illegal in file names on common platforms.
fn sanitize_filename(name : String) -> String {
  let mut result = ""
  for ch in name {
    let bad = ch == '<' ||
      ch == '>' ||
      ch == ':' ||
      ch == '"' ||
      ch == '/' ||
      ch == '\\' ||
      ch == '|' ||
      ch == '?' ||
      ch == '*' ||
      ch.to_int() < 0x20
    let piece = if bad { "_" } else { ch.to_string() }
    result = result + piece
  }
  result
}

///|
/// Windows rejects trailing dots and spaces in file names; strip them for
/// cross-platform safety.
fn strip_trailing_dots_and_spaces(name : String) -> String {
  let chars = name.to_array()
  let mut end = chars.length()
  while end > 0 && (chars[end - 1] == '.' || chars[end - 1] == ' ') {
    end = end - 1
  }
  name[0:end].to_owned()
}

///|
fn strip_trailing_slashes(path : String) -> String {
  let chars = path.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == '/' {
    end = end - 1
  }
  path[0:end].to_owned()
}
