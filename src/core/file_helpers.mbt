///|
pub fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buffer = @buffer.new()
  for byte in arr {
    buffer.write_byte(byte)
  }
  buffer.to_bytes()
}

///|
pub async fn read_file_bytes(path : String) -> Bytes {
  let file = @fs.open(path, mode=ReadOnly)
  let buffer = @buffer.new()
  while true {
    let chunk : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let read = file.read(chunk)
    if read == 0 {
      break
    }
    for i in 0..<read {
      buffer.write_byte(chunk[i])
    }
  }
  file.close()
  buffer.to_bytes()
}

///|
pub async fn read_utf8_file(path : String) -> String {
  @utf8.decode(read_file_bytes(path))
}

///|
pub async fn read_input_bytes(input : InputSource) -> Bytes {
  match input {
    FileInput(_, Some(bytes)) => bytes
    FileInput(path, None) => read_file_bytes(path)
    BytesInput(_, bytes, _) => bytes
    UrlInput(url, _) =>
      fail("URL input is not supported as direct bytes in this context: " + url)
  }
}

///|
pub async fn read_input_utf8(input : InputSource) -> String {
  @utf8.decode(read_input_bytes(input))
}

///|
pub fn strip_utf8_bom(text : String) -> String {
  let mut result = ""
  let mut is_first = true
  for ch in text {
    if is_first && ch == '\u{feff}' {
      is_first = false
      continue
    }
    result = result + ch.to_string()
    is_first = false
  }
  result
}

///|
pub fn normalize_path(path : String) -> String {
  path.replace(old="\\", new="/")
}

///|
pub fn file_name_only(path : String) -> String {
  let normalized = normalize_path(path)
  match find_last_char(normalized, '/') {
    Some(index) => normalized[index + 1:].to_string()
    None => normalized
  }
}

///|
pub fn path_dirname(path : String) -> String {
  let normalized = normalize_path(path)
  match find_last_char(normalized, '/') {
    Some(index) => if index > 0 { normalized[0:index].to_string() } else { "" }
    None => ""
  }
}

///|
pub fn file_stem(path : String) -> String? {
  let basename = file_name_only(path)
  match find_last_char(basename, '.') {
    Some(index) =>
      if index > 0 {
        Some(basename[0:index].to_string())
      } else {
        None
      }
    None => if basename != "" { Some(basename) } else { None }
  }
}

///|
pub fn split_path_segments(path : String) -> Array[String] {
  let segments : Array[String] = []
  for part in normalize_path(path).split("/").to_array() {
    if part != "" {
      segments.push(part.to_string())
    }
  }
  segments
}

///|
pub fn join_path(base_dir : String, target : String) -> String {
  if target == "" {
    return normalize_path(base_dir)
  }
  let normalized_target = normalize_path(target)
  if normalized_target.contains("://") || normalized_target.has_prefix("#") {
    return normalized_target
  }
  let segments = split_path_segments(base_dir)
  for part in split_path_segments(normalized_target) {
    if part == "." {
      continue
    }
    if part == ".." {
      ignore(segments.pop())
    } else {
      segments.push(part)
    }
  }
  segments.join("/")
}

///|
pub fn path_extension(path : String) -> String {
  let normalized = normalize_path(path)
  match find_last_char(normalized, '.') {
    Some(index) =>
      if index + 1 < normalized.length() {
        normalized[index + 1:].to_lower().to_string()
      } else {
        "bin"
      }
    None => "bin"
  }
}

///|
pub fn image_extension_for_media_type(media_type : String) -> String {
  match media_type {
    "image/jpeg" => "jpg"
    "image/jpg" => "jpg"
    "image/png" => "png"
    "image/gif" => "gif"
    "image/webp" => "webp"
    "image/svg+xml" => "svg"
    "image/x-icon" => "ico"
    "audio/mpeg" => "mp3"
    "audio/mp4" => "m4a"
    "video/mp4" => "mp4"
    "application/pdf" => "pdf"
    _ => "bin"
  }
}

///|
pub fn numbered_asset_filename(
  prefix : String,
  index : Int,
  source_path : String,
  fallback_extension? : String = "bin",
) -> String {
  prefix +
  index.to_string() +
  "." +
  effective_extension(source_path, fallback_extension)
}

///|
fn effective_extension(path : String, fallback_extension : String) -> String {
  let extension = path_extension(path)
  if extension == "bin" && !normalize_path(path).contains(".") {
    fallback_extension
  } else {
    extension
  }
}

///|
pub fn is_image_filename(filename : String) -> Bool {
  let lowered = file_name_only(filename).to_lower().to_string()
  lowered.has_suffix(".png") ||
  lowered.has_suffix(".jpg") ||
  lowered.has_suffix(".jpeg") ||
  lowered.has_suffix(".gif") ||
  lowered.has_suffix(".webp") ||
  lowered.has_suffix(".svg") ||
  lowered.has_suffix(".bmp") ||
  lowered.has_suffix(".tif") ||
  lowered.has_suffix(".tiff")
}

///|
pub fn find_last_char(s : String, target : Char) -> Int? {
  let mut found = -1
  let mut i = 0
  for ch in s {
    if ch == target {
      found = i
    }
    i = i + 1
  }
  if found >= 0 {
    Some(found)
  } else {
    None
  }
}
