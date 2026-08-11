///|
/// Targets without a filesystem (wasm, js) never persist bytes inputs, so
/// there is nothing to clean up.
async fn cleanup_materialized_input(materialized : MaterializedInput) -> Unit {
  ignore(materialized.cleanup_path)
  @async.pause()
}

///|
async fn ensure_engine_materialized_dir() -> Unit {
  @async.pause()
}

///|
async fn write_engine_materialized_bytes(path : String, bytes : Bytes) -> Unit {
  ignore(path)
  ignore(bytes)
  @async.pause()
  fail("Bytes input persistence is only supported on the native target")
}
