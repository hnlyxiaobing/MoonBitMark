///|
test "pdf assembly metadata records route summary" {
  let raw_pages = [
    "Monthly Report\nRevenue increased across the quarter.\nCustomer retention remained strong.",
    " ",
  ]
  let route = plan_pdf_route(raw_pages)
  let extraction = bind_route_to_native_extraction(
    PdfNativeExtraction::{
      raw_pages,
      pages: [
        PdfPageExtraction::{
          page_no: 1,
          source_kind: NativeTextFast,
          raw_text: Some(raw_pages[0]),
          lines: [PdfRawLine::{ text: "Monthly Report" }],
          layout: None,
        },
        PdfPageExtraction::{
          page_no: 2,
          source_kind: NativeTextFast,
          raw_text: Some(raw_pages[1]),
          lines: [],
          layout: None,
        },
      ],
      provider: Some("mbtpdf"),
      warnings: [],
      used_text_fallback: false,
    },
    route,
  )
  let assembled = assemble_pdf_document(Some("report"), extraction, route)

  inspect(
    assembled.metadata.get("pdf_text_provider"),
    content="Some(\"mbtpdf\")",
  )
  inspect(
    assembled.metadata.get("pdf_text_fallback_used"),
    content="Some(\"false\")",
  )
  inspect(
    assembled.metadata.get("route_document_mode"),
    content="Some(\"mixed\")",
  )
  inspect(assembled.metadata.get("route_recovery_pages"), content="Some(\"1\")")
  inspect(
    assembled.metadata.get("route_recovery_page_numbers"),
    content="Some(\"2\")",
  )
  inspect(
    assembled.metadata.get("route_recovery_reasons"),
    content="Some(\"page 2: scanned\")",
  )
  inspect(
    assembled.metadata.get("route_native_fast_pages"),
    content="Some(\"1\")",
  )
  inspect(
    assembled.metadata.get("route_text_quality"),
    content="Some(\"empty:1,weak:1\")",
  )
  inspect(
    assembled.metadata.get("route_layout_complexity"),
    content="Some(\"simple:2\")",
  )
  inspect(assembled.document.annotations.length(), content="3")
  inspect(
    assembled.document.annotations[0].source_hint,
    content="Some(\"page: 1\")",
  )
  inspect(
    assembled.document.annotations[0].origin_hint,
    content="Some(\"resource: pdf/native_text_fast/page/1; kind: page\")",
  )
}

///|
test "pdf assembly metadata records fallback extraction details" {
  let raw_pages = ["Formula\n\na2 + 8 = 12"]
  let route = plan_pdf_route(raw_pages)
  let extraction = bind_route_to_native_extraction(
    PdfNativeExtraction::{
      raw_pages,
      pages: [
        PdfPageExtraction::{
          page_no: 1,
          source_kind: NativeTextStructured,
          raw_text: Some(raw_pages[0]),
          lines: [
            PdfRawLine::{ text: "Formula" },
            PdfRawLine::{ text: "a2 + 8 = 12" },
          ],
          layout: None,
        },
      ],
      provider: Some("pdfminer"),
      warnings: ["page order differs from native extractor"],
      used_text_fallback: true,
    },
    route,
  )
  let assembled = assemble_pdf_document(Some("formula"), extraction, route)

  inspect(
    assembled.metadata.get("pdf_text_provider"),
    content="Some(\"pdfminer\")",
  )
  inspect(
    assembled.metadata.get("pdf_text_fallback_used"),
    content="Some(\"true\")",
  )
  inspect(
    assembled.metadata.get("pdf_text_warning_count"),
    content="Some(\"1\")",
  )
  inspect(
    assembled.metadata.get("route_text_quality"),
    content="Some(\"very_poor:1\")",
  )
  inspect(
    assembled.metadata.get("route_layout_complexity"),
    content="Some(\"simple:1\")",
  )
  inspect(assembled.document.annotations.length(), content="2")
  inspect(
    assembled.document.annotations[0].source_hint,
    content="Some(\"page: 1\")",
  )
}
