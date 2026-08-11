///|
/// Targets without a filesystem (wasm, js) cannot persist extracted assets;
/// reporting the write as failed keeps the original data URI in place.
async fn write_asset_file(path : String, bytes : Bytes) -> Bool {
  ignore(path)
  ignore(bytes)
  @async.pause()
  false
}

///|
async fn ensure_directory_chain(path : String) -> Unit {
  ignore(path)
  @async.pause()
}
