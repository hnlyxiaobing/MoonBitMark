///|
async fn main {
  let result = @engine.MarkItDown::new().convert("moon.mod.json")
  println("# Markdown")
  println(result.markdown)
  println("")
  println("# Debug")
  println(result.debug_report())
}
