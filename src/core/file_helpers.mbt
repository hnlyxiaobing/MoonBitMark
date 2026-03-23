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
fn normalize_path(path : String) -> String {
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
pub fn path_extension(path : String) -> String {
  match find_last_char(path, '.') {
    Some(index) =>
      if index + 1 < path.length() {
        path[index + 1:].to_lower().to_string()
      } else {
        "bin"
      }
    None => "bin"
  }
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
