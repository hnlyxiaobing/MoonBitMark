///|
/// Claim a name no concurrent caller can also be writing: create
/// `base + extension` exclusively, or `base-<n> + extension` for the first
/// free `n`.
///
/// A timestamp folded into `base` is not an identity: two calls that land in
/// the same millisecond produce the same path. `allow_existing=false` makes the
/// create atomic, and the counter stays *before* the extension so callers that
/// dispatch on the extension still see it last.
async fn claim_unique_file(
  base : String,
  extension : String,
) -> (String, @fs.File) {
  let mut attempt = 0
  while attempt < 128 {
    let path = if attempt == 0 {
      base + extension
    } else {
      base + "-" + attempt.to_string() + extension
    }
    if @fs.exists(path) {
      attempt = attempt + 1
      continue
    }
    let mut create_error = ""
    let opened : @fs.File? = Some(@fs.create(path, allow_existing=false)) catch {
      err => {
        create_error = err.to_string()
        None
      }
    }
    match opened {
      Some(file) => return (path, file)
      None =>
        // Distinguish "lost the race for this name" from "the directory is
        // gone / not writable": retrying only the former can ever succeed.
        if @fs.exists(path) {
          attempt = attempt + 1
        } else {
          fail("Failed to create temporary file " + path + ": " + create_error)
        }
    }
  }
  fail(
    "Failed to prepare a temporary file: no free name for " +
    base +
    " after 128 attempts",
  )
}

///|
/// Create a uniquely named file and write `payload` into it.
///
/// Concurrent conversions must never share a temporary path, otherwise one
/// caller reads another caller's bytes. The returned path is the one the
/// payload was actually written to.
pub async fn create_unique_file(
  base : String,
  extension : String,
  payload : Bytes,
) -> String {
  let (path, file) = claim_unique_file(base, extension)
  try {
    file.write(payload)
    file.close()
    path
  } catch {
    err => {
      // Drop the half-written candidate so a later attempt does not inherit it.
      // Close first: Windows refuses to unlink an open file.
      file.close()
      ignore(@fs.remove(path) catch { _ => () })
      fail("Failed to write temporary file " + path + ": " + err.to_string())
    }
  }
}

///|
/// Reserve a uniquely named empty file for a helper process to fill in.
///
/// Used for bridge output/stderr paths, which the child process opens itself:
/// the empty file only exists to claim the name atomically.
pub async fn reserve_unique_path(base : String, extension : String) -> String {
  let (path, file) = claim_unique_file(base, extension)
  file.close()
  path
}
