///|
async fn read_input_bytes(path : String) -> Bytes? {
  let file = @fs.open(path, mode=ReadOnly) catch { _ => return None }
  let all_bytes : Array[Byte] = []
  while true {
    let buffer : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let bytes_read = file.read(buffer) catch {
      _ => {
        ignore(file.close())
        return None
      }
    }
    if bytes_read == 0 {
      break
    }
    for i in 0..<bytes_read {
      all_bytes.push(buffer[i])
    }
  }
  ignore(file.close())
  Some(bytes_from_array(all_bytes))
}

///|
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = Buffer()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}
