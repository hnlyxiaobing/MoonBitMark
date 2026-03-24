///|
test "pdf helper file stem" {
  inspect(@core.file_stem("reports/spec.pdf"), content="Some(\"spec\")")
}

///|
test "pdf normalization splits headings and removes repeated edges" {
  let normalized = normalize_pdf_pages([
    "Monthly Report  Overview of Sales  • Q1  • Q2  Page 1", "Monthly Report  Overview of Costs  • Q3  • Q4  Page 1",
  ])
  inspect(
    normalized.pages[0].chunks,
    content="[\"Overview of Sales\", \"• Q1\", \"• Q2\"]",
  )
  inspect(
    normalized.pages[1].chunks,
    content="[\"Overview of Costs\", \"• Q3\", \"• Q4\"]",
  )
  inspect(normalized.removed_header_count, content="2")
  inspect(normalized.removed_footer_count, content="2")
}

///|
test "pdf normalization keeps single-line memo boundaries" {
  let chunks = split_page_chunks(
    "May 5, 2023\nTo Whom it May Concern:\n\nThere were 20,000 bottles of water.\nBest Regards,\nMallori",
  )
  inspect(
    chunks,
    content="[\"May 5, 2023\", \"To Whom it May Concern:\", \"There were 20,000 bottles of water.\", \"Best Regards,\", \"Mallori\"]",
  )
}

///|
test "pdf normalization recovers inline memo boundaries" {
  inspect(
    split_page_chunks(
      "May 5, 2023 To Whom it May Concern: There were 20,000 bottles of water. Best Regards, Mallori",
    ),
    content="[\"May 5, 2023\", \"To Whom it May Concern:\", \"There were 20,000 bottles of water.\", \"Best Regards,\", \"Mallori\"]",
  )
}

///|
test "pdf normalization restores obvious code spacing" {
  inspect(
    split_page_chunks(
      "JavaScriptCodeExample\nListing1:SimpleJavaScriptProgram functionadd(a,b){ returna+b; }",
    ),
    content="[\"JavaScript Code Example\", \"Listing 1: Simple JavaScript Program function add(a,b) { return a+b; }\"]",
  )
}

///|
test "pdf structure reconstruction emits headings and lists" {
  let normalized = normalize_pdf_pages([
    "The Evolution of the Word Processor The concept of the word processor predates modern computers.  • IBM MT/ST: Introduced in 1964.  • Wang Laboratories: Built dedicated machines.",
    "Future of Word Processing Today, word processors include AI assistance.  1. Undo/Redo: Easy recovery.  2. Track Changes: Better collaboration.",
  ])
  let structure = reconstruct_pdf_blocks(normalized.pages)
  inspect(
    @ast.render_markdown(@ast.Document::{
      title: None,
      metadata: {},
      blocks: structure.blocks,
    }),
    content="# The Evolution of the Word Processor\n\nThe concept of the word processor predates modern computers.\n\n- IBM MT/ST: Introduced in 1964.\n- Wang Laboratories: Built dedicated machines.\n\n## Future of Word Processing\n\nToday, word processors include AI assistance.\n\n1. Undo/Redo: Easy recovery.\n2. Track Changes: Better collaboration.",
  )
}

///|
test "pdf structure keeps short standalone lines as separate paragraphs" {
  let structure = reconstruct_pdf_blocks([
    PdfPageText::{
      number: 1,
      raw_text: "",
      chunks: [
        "May 5, 2023", "To Whom it May Concern:", "There were 20,000 bottles of water, 10,000 blankets, and 200 laptops delivered on January 23, 2023.",
        "A total of 3 trucks were used for 15 hours.", "Best Regards,", "Mallori",
      ],
    },
  ])
  inspect(
    @ast.render_markdown(@ast.Document::{
      title: None,
      metadata: {},
      blocks: structure.blocks,
    }),
    content="May 5, 2023\n\nTo Whom it May Concern:\n\nThere were 20,000 bottles of water, 10,000 blankets, and 200 laptops delivered on January 23, 2023.\n\nA total of 3 trucks were used for 15 hours.\n\nBest Regards,\n\nMallori",
  )
}

///|
test "pdf warning diagnostics render postprocess and normalize phases" {
  let route_plan = PdfRoutePlan::{
    document_mode: FastTextOnly,
    pages: [],
    summary: PdfRouteSummary::{
      total_pages: 0,
      native_fast_pages: 0,
      structured_pages: 0,
      recovery_pages: 0,
      flagged_pages: 0,
    },
  }
  let extraction = PdfNativeExtraction::{
    raw_pages: [],
    pages: [],
    provider: Some("pdfminer"),
    warnings: ["bridge page count differs"],
    used_fallback: true,
  }
  let normalization = PdfNormalizationResult::{
    pages: [],
    removed_header_count: 1,
    removed_footer_count: 0,
    merged_partial_numbering_count: 1,
  }
  let diagnostics = pdf_warning_diagnostics(
    "spec.pdf",
    route_plan,
    extraction,
    normalization,
    None,
  )
  inspect(diagnostics.length(), content="4")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: parse/pdf-bridge\n  Source: spec.pdf\n  Message: PDF text extraction used fallback provider: pdfminer.\n  Hint: Review fallback output if page layout, formulas, or tables still look degraded.",
  )
  inspect(
    diagnostics[1].render(),
    content="Warning: ConverterWarning\n  Phase: parse/pdf-bridge\n  Source: spec.pdf\n  Message: PDF bridge warning: bridge page count differs\n  Hint: Inspect the fallback extraction output if important pages are still missing or truncated.",
  )
  inspect(
    diagnostics[2].render(),
    content="Warning: ConverterWarning\n  Phase: postprocess/numbering-merge\n  Source: spec.pdf\n  Message: Merged partial numbering lines during PDF post-processing.\n  Hint: Review merged numbering if the PDF relies on strict line boundaries.",
  )
  inspect(
    diagnostics[3].render(),
    content="Warning: ConverterWarning\n  Phase: normalize/headers-footers\n  Source: spec.pdf\n  Message: Removed repeated page header/footer lines during PDF normalization.\n  Hint: Review the output if the PDF uses repeated running headers as semantic content.",
  )
}

///|
test "pdf ocr warning when auto mode sees empty native text" {
  let route_plan = PdfRoutePlan::{
    document_mode: RecoveryOnly,
    pages: [
      PdfPageRoute::{
        page_no: 1,
        provider: OcrRecovery,
        text_quality: Empty,
        layout_complexity: Simple,
        flags: [SuspectScanned],
      },
    ],
    summary: PdfRouteSummary::{
      total_pages: 1,
      native_fast_pages: 0,
      structured_pages: 0,
      recovery_pages: 1,
      flagged_pages: 1,
    },
  }
  inspect(
    pdf_ocr_warning(
      @ocr.OcrConfig::{ ..@ocr.OcrConfig::default(), mode: @ocr.Auto },
      route_plan,
      "",
      @ocr.OcrResult::not_attempted(),
      false,
    ),
    content="Some(\"OCR skipped for PDF because no page-rendering backend is configured.\")",
  )
}

///|
test "pdf warning message reports recovery page counts" {
  let route_plan = PdfRoutePlan::{
    document_mode: Mixed,
    pages: [],
    summary: PdfRouteSummary::{
      total_pages: 3,
      native_fast_pages: 1,
      structured_pages: 1,
      recovery_pages: 1,
      flagged_pages: 1,
    },
  }
  let warnings = pdf_warning_messages(
    route_plan,
    PdfNativeExtraction::{
      raw_pages: [],
      pages: [],
      provider: Some("pdfium"),
      warnings: [],
      used_fallback: false,
    },
    PdfNormalizationResult::{
      pages: [],
      removed_header_count: 0,
      removed_footer_count: 0,
      merged_partial_numbering_count: 0,
    },
    None,
  )
  inspect(
    warnings,
    content="[\"PDF route marked 1/3 page(s) for OCR recovery, but only native text extraction is currently active.\"]",
  )
}
