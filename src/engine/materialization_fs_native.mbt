///|
async fn cleanup_materialized_input(materialized : MaterializedInput) -> Unit {
  match materialized.cleanup_path {
    Some(path) => ignore(@fs.remove(path) catch { _ => () })
    None => ()
  }
}

///|
async fn ensure_engine_materialized_dir() -> Unit {
  ignore(
    @fs.mkdir(engine_materialized_dir(), permission=0o755, recursive=true) catch {
      _ => ()
    },
  )
}

///|
async fn write_engine_materialized_bytes(
  base : String,
  extension : String,
  bytes : Bytes,
) -> String {
  @tempfile.create_unique_file(base, "." + extension, bytes)
}
