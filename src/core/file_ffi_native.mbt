///|
/// 同步文件读取 FFI（绕开 async `@fs` 的 statx(2) 依赖，见 file_ffi_native.c）。
#borrow(path)
extern "C" fn ffi_fopen(path : Bytes) -> Int64 = "moonbitmark_ffi_fopen"

///|
#borrow(buf)
extern "C" fn ffi_fread(
  fp : Int64,
  buf : Bytes,
  offset : Int64,
  len : Int64,
) -> Int64 = "moonbitmark_ffi_fread"

///|
extern "C" fn ffi_fclose(fp : Int64) -> Int64 = "moonbitmark_ffi_fclose"

///|
/// 读取整个文件为 Bytes（同步）。失败 raise。
pub fn read_file_bytes_ffi(path : String) -> Bytes raise {
  let fp = ffi_fopen(@utf8.encode(path))
  if fp == 0L {
    fail("Failed to open file: " + path)
  }
  let buffer = Buffer()
  let chunk_len = 65536L
  while true {
    let chunk : Bytes = Bytes::make(chunk_len.to_int(), b'\x00')
    let read = ffi_fread(fp, chunk, 0L, chunk_len)
    if read < 0L {
      ignore(ffi_fclose(fp))
      fail("Failed to read file: " + path)
    }
    if read == 0L {
      break
    }
    buffer.write_bytes(chunk.view(start=0, end=read.to_int()))
    if read < chunk_len {
      break
    }
  }
  ignore(ffi_fclose(fp))
  buffer.to_bytes()
}
