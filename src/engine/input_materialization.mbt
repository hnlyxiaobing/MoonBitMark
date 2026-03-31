///|
priv struct MaterializedInput {
  file_path : String
  cleanup_path : String?
}

///|
async fn convert_with_materialized_path(
  input : @core.InputSource,
  converter_name : String,
  hint : @core.DiagnosticHint,
  convert : async (String) -> @core.ConvertResult,
) -> @core.ConvertResult {
  let materialized = materialize_input_path(input, converter_name, hint) catch {
    err =>
      fail(
        render_engine_failure(
          @core.InputError("Failed to materialize input", Some(err.to_string())),
          Some(@core.Load(Some("materialize-input"))),
          Some(diagnostic_source_of_input(input)),
          Some(hint),
        ),
      )
  }
  try convert(materialized.file_path) catch {
    err => {
      cleanup_materialized_input(materialized)
      fail(err.to_string())
    }
  } noraise {
    result => {
      cleanup_materialized_input(materialized)
      result
    }
  }
}

///|
async fn materialize_input_path(
  input : @core.InputSource,
  converter_name : String,
  hint : @core.DiagnosticHint,
) -> MaterializedInput {
  match input {
    @core.FileInput(path, _) =>
      MaterializedInput::{ file_path: path, cleanup_path: None }
    @core.UrlInput(url, _) =>
      MaterializedInput::{ file_path: url, cleanup_path: None }
    @core.BytesInput(name, bytes, mime_type) => {
      let source_name = match name {
        Some(value) => value
        None =>
          fail(
            render_engine_failure(
              @core.InputError(
                "Bytes input is not supported without a source name",
                None,
              ),
              Some(@core.Load(Some("materialize-input"))),
              Some(@core.Bytes(None)),
              Some(@core.ProvideBytesSourceName),
            ),
          )
      }
      ensure_engine_materialized_dir()
      let file_path = engine_materialized_path(
        converter_name,
        source_name,
        materialized_extension(source_name, mime_type),
      )
      write_engine_materialized_bytes(file_path, bytes) catch {
        err =>
          fail(
            render_engine_failure(
              @core.InputError(
                "Failed to persist bytes input",
                Some(err.to_string()),
              ),
              Some(@core.Load(Some("materialize-input"))),
              Some(@core.Bytes(Some(source_name))),
              Some(hint),
            ),
          )
      }
      MaterializedInput::{ file_path, cleanup_path: Some(file_path) }
    }
  }
}

///|
async fn cleanup_materialized_input(materialized : MaterializedInput) -> Unit {
  match materialized.cleanup_path {
    Some(path) => ignore(@fs.remove(path) catch { _ => () })
    None => ()
  }
}

///|
fn engine_materialized_dir() -> String {
  "_build/engine-materialized-inputs"
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
fn engine_materialized_path(
  converter_name : String,
  source_name : String,
  extension : String,
) -> String {
  let suffix = @async.now().to_string()
  let stem = sanitize_materialized_stem(source_name)
  engine_materialized_dir() +
  "/" +
  converter_name +
  "-" +
  suffix +
  "-" +
  stem +
  "." +
  extension
}

///|
fn materialized_extension(source_name : String, mime_type : String?) -> String {
  let from_name = @core.path_extension(source_name)
  if from_name != "bin" || @core.normalize_path(source_name).contains(".") {
    return from_name
  }
  match mime_type {
    Some(value) => @core.image_extension_for_media_type(value)
    None => "bin"
  }
}

///|
fn sanitize_materialized_stem(source_name : String) -> String {
  let mut result = ""
  for ch in @core.file_name_only(source_name) {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') {
      result = result + ch.to_string()
    } else {
      result = result + "-"
    }
  }
  let trimmed = result.trim().to_string()
  if trimmed == "" {
    "document"
  } else {
    trimmed
  }
}

///|
async fn write_engine_materialized_bytes(path : String, bytes : Bytes) -> Unit {
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  file.write(bytes)
  file.close()
}
