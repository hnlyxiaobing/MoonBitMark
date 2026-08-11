///|
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
