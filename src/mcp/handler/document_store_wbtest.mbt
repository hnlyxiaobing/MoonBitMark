// White-box tests for the document store.
//
// The resource id doubles as the blob/meta path stem, so two documents that
// land on the same id also land on the same files. These cases pin the id
// allocation contract: every stored document gets its own id, and the
// `<millis>-<stem>[-<n>]` shape the staleness sweep relies on is preserved.

///|
/// Drop a stored document, ignoring the case where it never got written.
async fn drop_stored_document(uri : String) -> Unit {
  ignore(delete_document_resource(uri))
}

///|
/// Remove leftovers from an earlier run so the id sequence a test observes is
/// deterministic: `<base>` for the first write, `<base>-1` for the second.
async fn clear_document_ids(base_id : String) -> Unit {
  for suffix in ["", "-1", "-2"] {
    ignore(@fs.remove(document_blob_path(base_id + suffix)) catch { _ => () })
    ignore(@fs.remove(document_meta_path(base_id + suffix)) catch { _ => () })
  }
}

///|
test "document resource id keeps its timestamp-stem shape" {
  let id = new_document_resource_id("report.doc")
  // "<millis>-report-doc"
  assert_true(id.has_suffix("-report-doc"))
  let digits = id[:id.length() - 11].to_owned()
  assert_true(digits.length() >= 13)
  for ch in digits {
    assert_true(ch >= '0' && ch <= '9')
  }
  // The sweep compares `document_timestamp_prefix` against a millisecond
  // cutoff, so the timestamp has to stay the leading segment of the id.
  assert_true(document_timestamp_prefix(id).has_prefix(digits))
  // The id also has to stay a single path-safe segment, otherwise the
  // resource_uri whitelist added for the traversal fix would reject it.
  assert_true(is_safe_document_resource_id(id))
  assert_true(is_safe_document_resource_id(id + "-1"))
  assert_true(document_timestamp_prefix(id + "-1").has_prefix(digits))
}

///|
async test "document store suffixes colliding ids instead of overwriting" {
  let base_id = new_document_resource_id("wbtest-id-collision.txt")
  clear_document_ids(base_id)
  let first = store_document_resource_at_base_id(
    "wbtest-id-collision.txt",
    base_id,
    @utf8.encode("first payload"),
    Some("text/plain"),
  )
  // Same base id again. `base_id` is already claimed, so the allocator has to
  // fall back to `<base_id>-1` instead of truncating the first document.
  let second = store_document_resource_at_base_id(
    "wbtest-id-collision.txt",
    base_id,
    @utf8.encode("second payload"),
    Some("text/plain"),
  )
  assert_true(first.resource_uri != second.resource_uri)
  assert_true(first.resource_uri.has_suffix(base_id))
  assert_true(second.resource_uri.has_suffix(base_id + "-1"))
  // This is the regression the patch is about: before the exclusive create the
  // second write truncated the first blob, so `first.resource_uri` resolved to
  // the second payload. Each uri must keep its own bytes.
  let first_bytes = match read_document_resource_bytes(first.resource_uri) {
    Ok(value) => value
    Err(message) => fail("first document must stay readable: " + message)
  }
  let second_bytes = match read_document_resource_bytes(second.resource_uri) {
    Ok(value) => value
    Err(message) => fail("second document must stay readable: " + message)
  }
  assert_eq(@utf8.decode(first_bytes), "first payload")
  assert_eq(@utf8.decode(second_bytes), "second payload")
  drop_stored_document(first.resource_uri)
  drop_stored_document(second.resource_uri)
}

///|
async test "stored document round-trips bytes, filename and mime type" {
  let stored = store_document_resource(
    "wbtest-roundtrip.txt",
    @utf8.encode("round trip payload"),
    Some("text/plain"),
  )
  let id = match parse_document_resource_id(stored.resource_uri) {
    Ok(value) => value
    Err(message) => fail("stored uri must parse: " + message)
  }
  assert_true(@fs.exists(stored.blob_path))
  assert_true(@fs.exists(document_meta_path(id)))
  let loaded = match load_document_resource(stored.resource_uri) {
    Ok(value) => value
    Err(message) => fail("stored document must load: " + message)
  }
  assert_eq(loaded.filename, "wbtest-roundtrip.txt")
  assert_eq(optional_string(loaded.mime_type), "text/plain")
  let data = match read_document_resource_bytes(stored.resource_uri) {
    Ok(value) => value
    Err(message) => fail("stored bytes must be readable: " + message)
  }
  assert_eq(@utf8.decode(data), "round trip payload")
  drop_stored_document(stored.resource_uri)
}
