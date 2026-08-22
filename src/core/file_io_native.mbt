///|
/// 非 Windows：自研 C FFI 读取，绕开 async `@fs` 的 statx(2) 依赖
/// （WSL1 / Linux < 4.11 返回 ENOSYS）。
#cfg(not(platform="windows"))
pub async fn read_file_bytes(path : String) -> Bytes {
  read_file_bytes_ffi(path)
}

///|
/// Windows：async `@fs` 路径（CreateFileW，无 statx 依赖，正确处理 UTF-8 路径）。
#cfg(platform="windows")
pub async fn read_file_bytes(path : String) -> Bytes {
  let file = @fs.open(path, mode=ReadOnly)
  let buffer = Buffer()
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
