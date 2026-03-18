///|
test "pptx warning collection" {
  inspect(
    collect_pptx_warnings(["Some slides could not be parsed as XML."], [], []).length(),
    content="1",
  )
}

///|
test "pptx warning diagnostics render parse phase" {
  let diagnostics = pptx_warning_diagnostics("slides.pptx", [
    "Some slides could not be parsed as XML.",
  ])
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Error: ConverterWarning\n  Phase: parse/slides\n  Source: slides.pptx\n  Message: Some slides could not be parsed as XML.\n  Hint: Inspect malformed slide XML inside the PPTX archive.",
  )
}

///|
test "pptx relation warning diagnostics target archive entry" {
  let diagnostics = pptx_warning_diagnostics("slides.pptx", [
    "Failed to parse ppt/_rels/presentation.xml.rels.",
  ])
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Error: ConverterWarning\n  Phase: parse/ppt/_rels/presentation.xml.rels\n  Source: ppt/_rels/presentation.xml.rels\n  Message: Failed to parse ppt/_rels/presentation.xml.rels.\n  Hint: Inspect malformed relationship XML inside the PPTX archive.",
  )
}

///|
test "pptx asset warning diagnostics target archive entry" {
  let diagnostics = pptx_warning_diagnostics("slides.pptx", [
    "Failed to extract PPTX asset: ppt/media/image1.png",
  ])
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Error: ConverterWarning\n  Phase: load/asset\n  Source: ppt/media/image1.png\n  Message: Failed to extract PPTX asset: ppt/media/image1.png\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}

///|
test "pptx parse failure render targets presentation xml" {
  let rendered = render_pptx_parse_failure(
    "Failed to parse presentation.xml", "deck.pptx",
  )
  inspect(
    rendered,
    content="Error: XmlParseError\n  Phase: parse/ppt/presentation.xml\n  Source: ppt/presentation.xml\n  Message: Failed to parse presentation.xml\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}
