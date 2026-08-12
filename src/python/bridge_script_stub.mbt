// Fallback for targets without a filesystem capability (wasm, js): bridge
// scripts cannot be spawned there, so resolution always reports NotFound and
// the caller surfaces the shared diagnostic.

///|
pub async fn resolve_bridge_script(
  relative_path : String,
  env_var : String,
) -> BridgeScriptResolution {
  @async.pause()
  NotFound(relative_path~, env_var~)
}
