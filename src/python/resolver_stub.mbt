// Fallback for targets without a filesystem/process capability (wasm, js):
// no interpreter can be resolved there, so bridge-backed features report
// themselves unavailable via the shared diagnostic.

///|
pub async fn resolve_python() -> (String, Array[String])? {
  @async.pause()
  None
}
