// Bridge script path resolution, shared across targets.
//
// The OCR and PDF bridges spawn `scripts/<name>/bridge.py`. Hard-coding that
// relative path only works when the current working directory is the
// repository root, so the script is resolved by priority instead:
//
// 1. An explicit environment variable override (`MOONBITMARK_OCR_BRIDGE` /
//    `MOONBITMARK_PDF_BRIDGE`). Like `MOONBITMARK_PYTHON`, a set-but-invalid
//    override fails fast instead of silently falling back, so configuration
//    errors surface immediately.
// 2. Probing upward from the executable's location (best effort, based on
//    `argv[0]`; see `bridge_script_native.mbt`).
// 3. The current working directory (previous behavior).
//
// This file holds the target-independent logic (path helpers, candidate
// enumeration, diagnostics); the filesystem probing lives in
// `bridge_script_native.mbt` / `bridge_script_stub.mbt`.

///|
/// Where a resolved bridge script path came from.
pub(all) enum BridgeScriptSource {
  /// Explicit environment variable override.
  EnvOverride
  /// Found by probing upward from the executable's directory.
  ExeLocation
  /// The current-working-directory relative path (fallback).
  WorkingDirectory
} derive(Debug, Eq)

///|
pub extend BridgeScriptSource with @debug.Debug::{to_repr}

///|
pub extend BridgeScriptSource with Eq::{not_equal, equal}

///|
/// Outcome of resolving a bridge script path.
pub(all) enum BridgeScriptResolution {
  /// The script exists at `path`, discovered via `source`.
  Found(path~ : String, source~ : BridgeScriptSource)
  /// The override environment variable is set but points at a file that
  /// does not exist (fail fast, no fallback).
  EnvOverrideMissing(path~ : String, env_var~ : String)
  /// No candidate exists: the script was not found relative to the
  /// executable or the current working directory, and no override is set.
  NotFound(relative_path~ : String, env_var~ : String)
} derive(Debug, Eq)

///|
pub extend BridgeScriptResolution with @debug.Debug::{to_repr}

///|
pub extend BridgeScriptResolution with Eq::{not_equal, equal}

///|
/// Strip the last path component. Both `/` and `\` are treated as separators;
/// returns `None` when the path has no parent (e.g. a bare file name).
pub fn parent_dir(path : String) -> String? {
  let normalized = path.replace_all(old="\\", new="/")
  let chars = normalized.to_array()
  let mut end = chars.length()
  // Ignore trailing separators so "a/b/" has parent "a".
  while end > 0 && chars[end - 1] == '/' {
    end = end - 1
  }
  let mut separator = -1
  for i in 0..<end {
    if chars[i] == '/' {
      separator = i
    }
  }
  if separator < 0 {
    return None
  }
  if separator == 0 {
    // A Unix root ("/") has no parent for probing purposes.
    return None
  }
  let parent_chars : Array[Char] = []
  for i in 0..<separator {
    parent_chars.push(chars[i])
  }
  Some(String::from_array(parent_chars))
}

///|
/// Enumerate `<dir>/<relative_path>` for the executable's directory and up to
/// `max_levels` of its parents. A bare `argv[0]` (no directory component)
/// yields no candidates.
pub fn exe_probe_candidates(
  exe_path : String,
  relative_path : String,
  max_levels : Int,
) -> Array[String] {
  let candidates : Array[String] = []
  let mut dir = parent_dir(exe_path)
  let mut level = 0
  while level < max_levels {
    match dir {
      Some(current) => {
        candidates.push(current + "/" + relative_path)
        dir = parent_dir(current)
        level = level + 1
      }
      None => break
    }
  }
  candidates
}

///|
/// Diagnostic for a failed bridge script resolution. The caller prefixes the
/// feature name (e.g. "OCR bridge unavailable: ").
pub fn bridge_script_diagnostic(resolution : BridgeScriptResolution) -> String {
  match resolution {
    Found(..) => ""
    EnvOverrideMissing(path~, env_var~) =>
      "bridge script not found: " +
      path +
      " (set via " +
      env_var +
      "). Fix " +
      env_var +
      " to point at an existing bridge script, or unset it to use the default lookup."
    NotFound(relative_path~, env_var~) =>
      "bridge script not found: " +
      relative_path +
      " (looked relative to the executable and the current working directory). Set " +
      env_var +
      " to the bridge script's absolute path."
  }
}
