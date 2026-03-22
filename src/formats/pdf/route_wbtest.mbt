///|
test "pdf route keeps plain narrative pages on fast path" {
  let route = plan_pdf_route([
    "Monthly Report\nRevenue increased across the quarter.\nCustomer retention remained strong.",
  ])
  inspect(route.document_mode.label(), content="fast_text_only")
  inspect(route.pages[0].provider.label(), content="native_text_fast")
  inspect(route.pages[0].flags.length(), content="0")
}

///|
test "pdf route upgrades code and formula pages to structured path" {
  let route = plan_pdf_route([
    "Formula 1\nListing1:SimpleJavaScriptProgram functionadd(a,b){ return a+b; }\na = b + c / d",
  ])
  inspect(route.document_mode.label(), content="mixed")
  inspect(route.pages[0].provider.label(), content="native_text_structured")
  inspect(
    summarize_route_flags(route),
    content="code:1,formula:1,broken_spacing:1",
  )
}

///|
test "pdf route sends empty pages to recovery path" {
  let route = plan_pdf_route(["  \n\t\r  "])
  inspect(route.document_mode.label(), content="recovery_only")
  inspect(route.pages[0].provider.label(), content="ocr_recovery")
  inspect(summarize_route_flags(route), content="scanned:1")
}

///|
test "pdf bridge heuristic skips large structured docs without broken spacing" {
  let page = "Table 1\nModel accuracy values\n0.91 0.92 0.93 0.94\nDiscussion paragraph continues here."
  let pages = Array::make(12, page)
  let route = plan_pdf_route(pages)
  inspect(should_attempt_pdf_bridge(pages, route, 12), content="false")
}

///|
test "pdf bridge heuristic still recovers missing pages" {
  let pages = ["Page one text only"]
  let route = plan_pdf_route(pages)
  inspect(should_attempt_pdf_bridge(pages, route, 2), content="true")
}

///|
test "pdf bridge heuristic skips large broken-spacing docs" {
  let page = "Potentiodynamicpolarizationdata neuralnetworkclassificationmodel results summary continues here."
  let pages = Array::make(12, page)
  let route = plan_pdf_route(pages)
  inspect(should_attempt_pdf_bridge(pages, route, 12), content="false")
}

///|
test "pdf bridge heuristic upgrades small multi-column docs" {
  let page = "Column heading\nShort line one\nShort line two\nShort line three\nShort line four\nShort line five\nShort line six\nShort line seven\nShort line eight\nShort line nine\nShort line ten\nShort line eleven"
  let pages = [page, page]
  let route = plan_pdf_route(pages)
  inspect(should_attempt_pdf_bridge(pages, route, 2), content="true")
}
