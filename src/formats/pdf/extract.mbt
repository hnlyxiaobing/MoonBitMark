///|
fn normalize_extracted_page_text(text : String) -> String {
  text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}
