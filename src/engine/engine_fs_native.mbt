///|
async fn write_asset_file(path : String, bytes : Bytes) -> Bool {
  let file = @fs.open(path, mode=WriteOnly, create_mode=@fs.CreateOrTruncate)
  file.write(bytes)
  file.close()
  true
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
