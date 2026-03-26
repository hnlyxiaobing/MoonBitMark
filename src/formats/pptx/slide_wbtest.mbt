///|
test "pptx content placeholder paragraphs become list items" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
    "<p:cSld><p:spTree>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Title 1\"/><p:nvPr><p:ph type=\"title\"/></p:nvPr></p:nvSpPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Agenda</a:t></a:r></a:p></p:txBody></p:sp>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Content Placeholder 2\"/><p:nvPr><p:ph idx=\"1\"/></p:nvPr></p:nvSpPr><p:txBody><a:bodyPr/><a:lstStyle/>" +
    "<a:p><a:r><a:t>Alpha</a:t></a:r></a:p>" +
    "<a:p><a:r><a:t>Beta</a:t></a:r></a:p>" +
    "</p:txBody></p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let (blocks, warning) = process_slide_xml(xml, 2, "ppt/slides/slide2.xml")
  inspect(warning, content="None")
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="## Slide 2\n\n### Agenda\n\n- Alpha\n- Beta",
  )
}

///|
test "pptx table graphic frame becomes markdown table" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
    "<p:cSld><p:spTree>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Title 1\"/><p:nvPr><p:ph type=\"title\"/></p:nvPr></p:nvSpPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Revenue</a:t></a:r></a:p></p:txBody></p:sp>" +
    "<p:graphicFrame><a:graphic><a:graphicData>" +
    "<a:tbl>" +
    "<a:tr><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>Quarter</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>Value</a:t></a:r></a:p></a:txBody></a:tc></a:tr>" +
    "<a:tr><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>Q1</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>10</a:t></a:r></a:p></a:txBody></a:tc></a:tr>" +
    "</a:tbl>" +
    "</a:graphicData></a:graphic></p:graphicFrame>" +
    "</p:spTree></p:cSld></p:sld>"
  let (blocks, warning) = process_slide_xml(xml, 1, "ppt/slides/slide1.xml")
  inspect(warning, content="None")
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="## Slide 1\n\n### Revenue\n\n| Quarter | Value |\n| --- | --- |\n| Q1 | 10 |",
  )
}

///|
test "pptx notes xml becomes speaker notes blocks" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
    "<p:notes xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
    "<p:cSld><p:spTree>" +
    "<p:sp><p:txBody><a:bodyPr/><a:p><a:r><a:t>Speaker note one</a:t></a:r></a:p><a:p><a:r><a:t>Speaker note two</a:t></a:r></a:p></p:txBody></p:sp>" +
    "</p:spTree></p:cSld></p:notes>"
  let (blocks, warning) = notes_blocks_from_xml(
    xml, "ppt/notesSlides/notesSlide1.xml",
  )
  inspect(warning, content="None")
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="#### Speaker Notes\n\nSpeaker note one\n\nSpeaker note two",
  )
}

///|
test "pptx chart xml becomes heading and table" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
    "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:chart><c:title><c:tx><c:rich><a:p><a:r><a:t>Revenue by Quarter</a:t></a:r></a:p></c:rich></c:tx></c:title><c:plotArea><c:barChart>" +
    "<c:ser><c:tx><c:v>FY25</c:v></c:tx><c:cat><c:strLit><c:pt idx=\"0\"><c:v>Q1</c:v></c:pt><c:pt idx=\"1\"><c:v>Q2</c:v></c:pt></c:strLit></c:cat><c:val><c:numLit><c:pt idx=\"0\"><c:v>10</c:v></c:pt><c:pt idx=\"1\"><c:v>12</c:v></c:pt></c:numLit></c:val></c:ser>" +
    "<c:ser><c:tx><c:v>FY24</c:v></c:tx><c:cat><c:strLit><c:pt idx=\"0\"><c:v>Q1</c:v></c:pt><c:pt idx=\"1\"><c:v>Q2</c:v></c:pt></c:strLit></c:cat><c:val><c:numLit><c:pt idx=\"0\"><c:v>8</c:v></c:pt><c:pt idx=\"1\"><c:v>11</c:v></c:pt></c:numLit></c:val></c:ser>" +
    "</c:barChart></c:plotArea></c:chart></c:chartSpace>"
  let (chart, warning) = parse_chart_xml(xml, "ppt/charts/chart1.xml")
  inspect(warning, content="None")
  guard chart is Some(value) else { fail("expected chart data") }
  let blocks = render_chart_blocks(value, 1)
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="#### Revenue by Quarter\n\n| Category | FY25 | FY24 |\n| --- | --- | --- |\n| Q1 | 10 | 8 |\n| Q2 | 12 | 11 |",
  )
}

///|
test "pptx explicit auto numbering becomes ordered list" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
    "<p:cSld><p:spTree>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Agenda\"/></p:nvSpPr><p:txBody><a:bodyPr/><a:lstStyle/>" +
    "<a:p><a:pPr><a:buAutoNum type=\"arabicPeriod\" startAt=\"1\"/></a:pPr><a:r><a:t>First item</a:t></a:r></a:p>" +
    "<a:p><a:pPr><a:buAutoNum type=\"arabicPeriod\" startAt=\"2\"/></a:pPr><a:r><a:t>Second item</a:t></a:r></a:p>" +
    "</p:txBody></p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let (blocks, warning) = process_slide_xml(xml, 3, "ppt/slides/slide3.xml")
  inspect(warning, content="None")
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="## Slide 3\n\n1. First item\n2. Second item",
  )
}

///|
test "pptx grouped shapes keep nested text order" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
    "<p:cSld><p:spTree>" +
    "<p:grpSp>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Title 1\"/><p:nvPr><p:ph type=\"title\"/></p:nvPr></p:nvSpPr><p:txBody><a:bodyPr/><a:p><a:r><a:t>Nested Title</a:t></a:r></a:p></p:txBody></p:sp>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Text Placeholder 2\"/><p:nvPr><p:ph type=\"body\"/></p:nvPr></p:nvSpPr><p:txBody><a:bodyPr/>" +
    "<a:p><a:r><a:t>Nested detail</a:t></a:r></a:p>" +
    "</p:txBody></p:sp>" +
    "</p:grpSp>" +
    "</p:spTree></p:cSld></p:sld>"
  let (blocks, warning) = process_slide_xml(xml, 4, "ppt/slides/slide4.xml")
  inspect(warning, content="None")
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="## Slide 4\n\n### Nested Title\n\nNested detail",
  )
}
