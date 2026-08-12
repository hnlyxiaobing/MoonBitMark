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
  // binary is invoked via a path but may be a bare name when it is resolved
  // through PATH (in that case this tier yields no candidates). The cap of
  // 10 levels covers this repo's own build layout: the CLI exe lives at
  // `_build/native/release/build/moonbitlang/moonbitmark/cmd/main/main.exe`,
  // 9 directories below the repository root.
  let argv = @env.args()
  if argv.length() > 0 {
    for candidate in exe_probe_candidates(argv[0], relative_path, 10) {
      if file_exists(candidate) {
        return Found(path=candidate, source=ExeLocation)
      }
    }
  }
  // 3. Current working directory (previous behavior).
  if file_exists(relative_path) {
    Found(path=relative_path, source=WorkingDirectory)
  } else {
    NotFound(relative_path~, env_var~)
  }
}
