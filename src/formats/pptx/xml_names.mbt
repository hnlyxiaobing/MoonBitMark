///|
fn pptx_local_name(name : String) -> String {
  match name.find(":") {
    Some(pos) => {
      let start = pos + 1
      let mut result = ""
      let mut index = 0
      for ch in name {
        if index >= start {
          result = result + ch.to_string()
        }
        index = index + 1
      }
      result
    }
    None => name
  }
}
