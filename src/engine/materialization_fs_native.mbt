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
async fn write_engine_materialized_bytes(path : String, bytes : Bytes) -> Unit {
  let file = @fs.open(path, mode=WriteOnly, create_mode=@fs.CreateOrTruncate)
  file.write(bytes)
  file.close()
}
