// Native implementation of bridge script path resolution (see
// `bridge_script.mbt` for the resolution contract).

///|
/// Resolve the path of a bridge script such as `scripts/ocr/bridge.py`.
/// `env_var` names the explicit override variable (e.g.
/// `MOONBITMARK_OCR_BRIDGE`). See `bridge_script.mbt` for the priority order.
pub async fn resolve_bridge_script(
  relative_path : String,
  env_var : String,
) -> BridgeScriptResolution {
  // 1. Explicit override: fail fast when set but missing, no fallback.
  match @env.get_env_var(env_var) {
    Some(configured) => {
      let path = configured.trim().to_owned()
      if path != "" {
        return if file_exists(path) {
          Found(path~, source=EnvOverride)
        } else {
          EnvOverrideMissing(path~, env_var~)
        }
      }
    }
    None => ()
  }
  // 2. Probe upward from the executable's location. This is best effort:
  // `argv[0]` is used as the executable path, which is a full path when the
  // binary is invoked via a path. When the binary is resolved through PATH,
  // `argv[0]` may be a bare name; in that case the bare name is looked up
  // against the PATH environment variable first so installed binaries keep
  // working. The cap of 10 levels covers this repo's own build layout: the
  // CLI exe lives at
  // `_build/native/release/build/hnlyxiaobing/moonbitmark/cmd/main/main.exe`,
  // 9 directories below the repository root.
  let argv = @env.args()
  if argv.length() > 0 {
    match resolve_probe_base(argv[0]) {
      Some(base) =>
        for candidate in exe_probe_candidates(base, relative_path, 10) {
          if file_exists(candidate) {
            return Found(path=candidate, source=ExeLocation)
          }
        }
      None => ()
    }
  }
  // 3. Current working directory (previous behavior).
  if file_exists(relative_path) {
    Found(path=relative_path, source=WorkingDirectory)
  } else {
    NotFound(relative_path~, env_var~)
  }
}

///|
/// Turn `argv[0]` into a path usable for upward probing. A value that already
/// carries a directory component is returned as-is. A bare name (the binary
/// was resolved through PATH) is looked up against the PATH environment
/// variable; returns `None` when the executable cannot be located.
async fn resolve_probe_base(argv0 : String) -> String? {
  if has_path_separator(argv0) {
    return Some(argv0)
  }
  match @env.get_env_var("PATH") {
    Some(path_var) =>
      for dir in split_search_path(path_var) {
        for candidate in exe_name_candidates(dir, argv0) {
          if file_exists(candidate) {
            return Some(candidate)
          }
        }
      }
    None => ()
  }
  None
}

///|
fn has_path_separator(path : String) -> Bool {
  for ch in path {
    if ch == '/' || ch == '\\' {
      return true
    }
  }
  false
}

///|
/// File names to try inside a PATH directory for a bare executable name.
/// Mirrors Windows CreateProcess resolution by also trying a `.exe` suffix
/// when the name has none.
fn exe_name_candidates(dir : String, name : String) -> Array[String] {
  let base = dir + "/" + name
  let candidates : Array[String] = [base]
  let lower = name.to_lower().to_string()
  if !lower.has_suffix(".exe") {
    candidates.push(base + ".exe")
  }
  candidates
}
