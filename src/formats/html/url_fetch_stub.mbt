///|
/// Convert from URL
///
/// Targets without socket access (wasm, js) cannot perform HTTP requests.
pub async fn convert_from_url(url : String) -> String {
  ignore(url)
  @async.pause()
  abort("URL fetching is only supported on the native target")
}
