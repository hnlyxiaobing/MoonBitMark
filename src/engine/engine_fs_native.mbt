///|
async fn write_asset_file(path : String, bytes : Bytes) -> Bool {
  let file = @fs.open(path, mode=WriteOnly, create_mode=@fs.CreateOrTruncate)
  file.write(bytes)
  file.close()
  true
}

///|
/// Create the parent directory chain for a file path so the file can be
/// written even when intermediate directories do not exist yet.
pub async fn ensure_parent_directory(path : String) -> Unit {
  match parent_directory_of(path) {
    Some(dir) => ensure_directory_chain(dir)
    None => ()
  }
}

///|
/// Strip the last path component. Both `/` and `\` are treated as separators;
/// returns `None` when the path has no parent (e.g. a bare file name).
fn parent_directory_of(path : String) -> String? {
  let normalized = path.replace_all(old="\\", new="/")
  let mut end = normalized.length()
  while end > 0 && normalized[end - 1] == '/' {
    end = end - 1
  }
  if end == 0 {
    return None
  }
  let mut separator = -1
  for i in 0..<end {
    if normalized[i] == '/' {
      separator = i
    }
  }
  if separator < 0 {
    return None
  }
  if separator == 0 {
    return Some("/")
  }
  Some(normalized[0:separator].to_owned())
}

///|
async fn ensure_directory_chain(path : String) -> Unit {
  let normalized = normalize_asset_path(path)
  let mut current = directory_prefix(normalized)
  for segment in split_path_segments(normalized) {
    current = join_segment(current, segment)
    ignore(
      @fs.mkdir(current, permission=0o755, recursive=true) catch {
        _ => ()
      },
    )
  }
}

///|
fn directory_prefix(path : String) -> String {
  if path.length() >= 2 && path[1] == ':' {
    path[0:2].to_owned()
  } else if path.has_prefix("/") {
    "/"
  } else {
    ""
  }
}

///|
fn split_path_segments(path : String) -> Array[String] {
  let normalized = normalize_asset_path(path)
  let segments : Array[String] = []
  let mut current = ""
  let mut start = 0
  if normalized.length() >= 2 && normalized[1] == ':' {
    start = 2
  } else if normalized.has_prefix("/") {
    start = 1
  }
  let mut i = start
  while i < normalized.length() {
    let ch = normalized[i]
    if ch == '/' {
      if current != "" {
        segments.push(current)
        current = ""
      }
    } else {
      current = current + normalized[i:i + 1].to_owned()
    }
    i = i + 1
  }
  if current != "" {
    segments.push(current)
  }
  segments
}

///|
fn join_segment(current : String, segment : String) -> String {
  if current == "" || current == "/" {
    current + segment
  } else {
    current + "/" + segment
  }
}
