///|
/// Convert from URL
pub async fn convert_from_url(url : String) -> String {
  let (response, data) = @http.get(url)
  if response.code != 200 {
    fail("HTTP request failed with status code: " + response.code.to_string())
  }
  data.text()
}
