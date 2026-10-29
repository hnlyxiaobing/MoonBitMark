///|
/// Targets without a filesystem (wasm, js) cannot materialize temporary files.
pub async fn create_unique_file(
  base : String,
  extension : String,
  payload : Bytes,
) -> String {
  ignore((base, extension, payload))
  @async.pause()
  fail("Temporary files are only supported on the native target")
}

///|
pub async fn reserve_unique_path(base : String, extension : String) -> String {
  ignore((base, extension))
  @async.pause()
  fail("Temporary files are only supported on the native target")
}
