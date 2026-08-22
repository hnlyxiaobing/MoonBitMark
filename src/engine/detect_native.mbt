///|
/// 读取输入文件字节用于格式检测。
///
/// 非 Windows：自研 C FFI（绕开 async `@fs` 的 statx ENOSYS）；
/// 失败返回 None（格式检测失败不阻断转换，保持原有容错语义）。
#cfg(not(platform="windows"))
async fn read_input_bytes(path : String) -> Bytes? {
  Some(@core.read_file_bytes_ffi(path)) catch {
    _ => None
  }
}

///|
/// Windows：async `@fs` 路径。
#cfg(platform="windows")
async fn read_input_bytes(path : String) -> Bytes? {
  Some(@core.read_file_bytes(path)) catch {
    _ => None
  }
}
