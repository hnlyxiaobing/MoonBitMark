///|
/// Targets without a filesystem (wasm, js) cannot read from disk; inputs
/// must be supplied as in-memory bytes instead.
pub async fn read_file_bytes(path : String) -> Bytes {
  ignore(path)
  @async.pause()
  abort("File system access is only supported on the native target")
}

///|
pub async fn read_utf8_file(path : String) -> String {
  ignore(path)
  @async.pause()
  abort("File system access is only supported on the native target")
}
