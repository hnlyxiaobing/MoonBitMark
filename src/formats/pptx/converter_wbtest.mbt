///|
test "pptx warning collection" {
  inspect(
    collect_pptx_warnings("<!-- Slide 1: Parse error -->").length(),
    content="1",
  )
}
