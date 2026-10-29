// MoonBitMark MCP Handler - Dynamic Document Store

///|
priv struct StoredDocument {
  resource_uri : String
  filename : String
  mime_type : String?
  byte_size : Int32
  blob_path : String
}

///|
async fn store_document_resource(
  filename : String,
  bytes : Bytes,
  mime_type : String?,
) -> StoredDocument {
  store_document_resource_at_base_id(
    filename,
    new_document_resource_id(filename),
    bytes,
    mime_type,
  )
}

///|
/// Store `bytes` under `base_id`, or under `<base_id>-<n>` for the first free
/// `n` when that id is already taken.
///
/// The id doubles as the blob/meta path stem, so two uploads that land in the
/// same millisecond with equivalent sanitized stems (everything that is not
/// alphanumeric collapses to `-`, and the file name is caller supplied) would
/// otherwise map onto the same files. The shared temp-file helper claims the
/// blob through an atomic exclusive create, so the id is unique per stored
/// document; suffixing keeps the shape `<timestamp>-<stem>[-<n>]` so
/// `document_timestamp_prefix` (and therefore the staleness sweep) still reads
/// the leading timestamp.
async fn store_document_resource_at_base_id(
  filename : String,
  base_id : String,
  bytes : Bytes,
  mime_type : String?,
) -> StoredDocument {
  ensure_document_store_dirs()
  sweep_stale_document_resources()
  let blob_path = @tempfile.create_unique_file(
    document_blob_base(base_id),
    ".bin",
    bytes,
  ) catch {
    err =>
      fail(
        "Failed to create document blob for " +
        filename +
        ": " +
        err.to_string(),
      )
  }
  let id = match @core.file_stem(blob_path) {
    Some(value) => value
    None => fail("Failed to derive a document resource id from " + blob_path)
  }
  let meta_path = document_meta_path(id)
  write_document_meta(meta_path, id, filename, mime_type, bytes.length()) catch {
    err => {
      // Without metadata the document is unloadable, so the blob must not be
      // left behind either.
      ignore(@fs.remove(blob_path) catch { _ => () })
      fail(
        "Failed to write document metadata " +
        meta_path +
        ": " +
        err.to_string(),
      )
    }
  }
  StoredDocument::{
    resource_uri: document_resource_uri(id),
    filename,
    mime_type,
    byte_size: bytes.length(),
    blob_path,
  }
}

///|
async fn load_document_resource(
  resource_uri : String,
) -> Result[StoredDocument, String] {
  sweep_stale_document_resources()
  let id = match parse_document_resource_id(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let meta_path = document_meta_path(id)
  let blob_path = document_blob_path(id)
  if !@fs.exists(meta_path) || !@fs.exists(blob_path) {
    return Err("Resource not found")
  }
  let metadata = match read_document_meta(meta_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let filename = match metadata.get("filename") {
    Some(value) if value != "" => value
    _ => return Err("Stored document metadata is missing filename")
  }
  let byte_size = match metadata.get("byte_size") {
    Some(value) =>
      @string.from_str(value[:]) catch {
        _ => return Err("Stored document metadata has invalid byte_size")
      }
    None => return Err("Stored document metadata is missing byte_size")
  }
  let mime_type = match metadata.get("mime_type") {
    Some(value) if value != "" => Some(value)
    _ => None
  }
  Ok(StoredDocument::{
    resource_uri,
    filename,
    mime_type,
    byte_size,
    blob_path,
  })
}

///|
async fn read_document_resource_bytes(
  resource_uri : String,
) -> Result[Bytes, String] {
  let stored = match load_document_resource(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@core.read_file_bytes(stored.blob_path)) catch {
    err => Err("Failed to read stored document bytes: " + err.to_string())
  }
}

///|
async fn read_document_resource_contents(
  resource_uri : String,
) -> Result[@types.McpResourceContents, String] {
  let stored = match load_document_resource(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@types.McpResourceContents::{
    uri: resource_uri,
    mime_type: Some("text/markdown"),
    text: render_document_resource_text(stored),
  })
}

///|
fn render_document_resource_text(stored : StoredDocument) -> String {
  [
    "# Uploaded document resource",
    "",
    "- resource_uri: " + stored.resource_uri,
    "- source_filename: " + stored.filename,
    "- mime_type: " + optional_string(stored.mime_type),
    "- byte_size: " + stored.byte_size.to_string(),
    "- storage_kind: local_blob",
    "- next_step: call inspect_document or convert_to_markdown with resource_uri.",
  ].join("\n")
}

///|
async fn list_stored_documents() -> Array[StoredDocument] {
  let meta_dir = document_meta_dir()
  if !@fs.exists(meta_dir) {
    return []
  }
  let entries = @fs.readdir(
    meta_dir,
    include_hidden=true,
    include_special=false,
    sort=false,
  ) catch {
    _ => return []
  }
  let docs : Array[StoredDocument] = []
  for entry in entries {
    if !entry.has_suffix(".meta.txt") {
      continue
    }
    let id = entry[:entry.length() - 9].to_owned()
    let meta_path = document_meta_path(id)
    let blob_path = document_blob_path(id)
    if !@fs.exists(meta_path) || !@fs.exists(blob_path) {
      continue
    }
    let metadata = match read_document_meta(meta_path) {
      Ok(value) => value
      Err(_) => continue
    }
    let filename = match metadata.get("filename") {
      Some(value) if value != "" => value
      _ => continue
    }
    let byte_size = match metadata.get("byte_size") {
      Some(value) => @string.from_str(value[:]) catch { _ => continue }
      None => continue
    }
    let mime_type = match metadata.get("mime_type") {
      Some(value) if value != "" => Some(value)
      _ => None
    }
    docs.push(StoredDocument::{
      resource_uri: document_resource_uri(id),
      filename,
      mime_type,
      byte_size,
      blob_path,
    })
  }
  docs
}

///|
async fn delete_document_resource(
  resource_uri : String,
) -> Result[StoredDocument, String] {
  let id = match parse_document_resource_id(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let meta_path = document_meta_path(id)
  let blob_path = document_blob_path(id)
  if !@fs.exists(meta_path) && !@fs.exists(blob_path) {
    return Err("Resource not found")
  }
  let metadata = match read_document_meta(meta_path) {
    Ok(value) => value
    Err(_) => {
      ignore(@fs.remove(blob_path) catch { _ => () })
      ignore(@fs.remove(meta_path) catch { _ => () })
      return Err(
        "Stored document metadata is malformed; cleaned up orphaned files",
      )
    }
  }
  let filename = match metadata.get("filename") {
    Some(value) if value != "" => value
    _ => "unknown"
  }
  let byte_size = match metadata.get("byte_size") {
    Some(value) => @string.from_str(value[:]) catch { _ => 0 }
    None => 0
  }
  let mime_type = match metadata.get("mime_type") {
    Some(value) if value != "" => Some(value)
    _ => None
  }
  let stored = StoredDocument::{
    resource_uri,
    filename,
    mime_type,
    byte_size,
    blob_path,
  }
  ignore(@fs.remove(blob_path) catch { _ => () })
  ignore(@fs.remove(meta_path) catch { _ => () })
  Ok(stored)
}

///|
async fn sweep_stale_document_resources() -> Unit {
  let meta_dir = document_meta_dir()
  if !@fs.exists(meta_dir) {
    return
  }
  let cutoff = (@async.now() - 86400000).to_string()
  let entries = @fs.readdir(
    meta_dir,
    include_hidden=true,
    include_special=false,
    sort=false,
  ) catch {
    _ => return
  }
  for entry in entries {
    if !entry.has_suffix(".meta.txt") {
      continue
    }
    let id = entry[:entry.length() - 9].to_owned()
    if document_timestamp_prefix(id) < cutoff {
      ignore(@fs.remove(document_meta_path(id)) catch { _ => () })
      ignore(@fs.remove(document_blob_path(id)) catch { _ => () })
    }
  }
}

///|
async fn ensure_document_store_dirs() -> Unit {
  ignore(
    @fs.mkdir(document_store_root(), permission=0o755, recursive=true) catch {
      _ => ()
    },
  )
  ignore(
    @fs.mkdir(document_blob_dir(), permission=0o755, recursive=true) catch {
      _ => ()
    },
  )
  ignore(
    @fs.mkdir(document_meta_dir(), permission=0o755, recursive=true) catch {
      _ => ()
    },
  )
}

///|
fn document_store_root() -> String {
  "_build/mcp-document-store"
}

///|
fn document_blob_dir() -> String {
  document_store_root() + "/blobs"
}

///|
fn document_meta_dir() -> String {
  document_store_root() + "/meta"
}

///|
fn document_blob_base(id : String) -> String {
  document_blob_dir() + "/" + id
}

///|
fn document_blob_path(id : String) -> String {
  document_blob_base(id) + ".bin"
}

///|
fn document_meta_path(id : String) -> String {
  document_meta_dir() + "/" + id + ".meta.txt"
}

///|
fn document_resource_uri(id : String) -> String {
  "moonbitmark://document/" + id
}

///|
fn parse_document_resource_id(resource_uri : String) -> Result[String, String] {
  let prefix = "moonbitmark://document/"
  if !resource_uri.has_prefix(prefix) {
    return Err("Resource not found")
  }
  let id = resource_uri[prefix.length():].to_owned()
  if id.trim() == "" {
    Err("Resource not found")
  } else if !is_safe_document_resource_id(id) {
    // The id is appended to the store's blob/meta paths. Anything that could
    // escape the store root (path separators, drive prefixes, "..") has to be
    // rejected before it ever reaches the filesystem.
    Err("Resource not found")
  } else {
    Ok(id)
  }
}

///|
/// Document resource ids are generated as "<timestamp>-<sanitized filename>",
/// where the sanitized stem keeps only ASCII letters, digits and dashes.
/// Restricting the id to that alphabet keeps it a single path segment, so a
/// crafted `resource_uri` cannot traverse out of the document store.
fn is_safe_document_resource_id(id : String) -> Bool {
  for ch in id {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' {
      continue
    } else {
      return false
    }
  }
  true
}

///|
fn new_document_resource_id(filename : String) -> String {
  @async.now().to_string() + "-" + sanitize_document_stem(filename)
}

///|
fn sanitize_document_stem(name : String) -> String {
  let mut result = ""
  for ch in @core.file_name_only(name) {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') {
      result = result + ch.to_string()
    } else {
      result = result + "-"
    }
  }
  let trimmed = result.trim().to_owned()
  if trimmed == "" {
    "document"
  } else {
    trimmed
  }
}

///|
fn document_timestamp_prefix(id : String) -> String {
  match @core.find_last_char(id, '-') {
    Some(index) if index > 0 => id[:index].to_owned()
    _ => id
  }
}

///|
async fn write_document_meta(
  path : String,
  id : String,
  filename : String,
  mime_type : String?,
  byte_size : Int32,
) -> Unit {
  let lines : Array[String] = [
    "id: " + id,
    "filename: " + sanitize_meta_value(filename),
    "mime_type: " + sanitize_meta_value(optional_string(mime_type)),
    "byte_size: " + byte_size.to_string(),
  ]
  let file = @fs.open(path, mode=WriteOnly, create_mode=@fs.CreateOrTruncate)
  file.write(@utf8.encode(lines.join("\n") + "\n"))
  file.close()
}

///|
async fn read_document_meta(
  path : String,
) -> Result[Map[String, String], String] {
  let text = @core.read_utf8_file(path) catch {
    err =>
      return Err("Failed to read stored document metadata: " + err.to_string())
  }
  let values : Map[String, String] = Map([])
  for line in text.split("\n") {
    let rendered = line.trim().to_owned()
    if rendered == "" {
      continue
    }
    match rendered.find(": ") {
      Some(index) => {
        let key = rendered[:index].to_owned()
        let value = rendered[index + 2:].to_owned()
        values[key] = if value == "null" { "" } else { value }
      }
      None => return Err("Stored document metadata is malformed")
    }
  }
  Ok(values)
}

///|
fn sanitize_meta_value(value : String) -> String {
  value.replace(old="\r", new=" ").replace(old="\n", new=" ").trim().to_owned()
}
