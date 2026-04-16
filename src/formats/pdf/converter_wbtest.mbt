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
  let structure = reconstruct_pdf_blocks_with_heading_state(
    normalized.pages,
    false,
  )
  inspect(
    @ast.render_markdown(@ast.document(None, {}, structure.blocks)),
    content="# The Evolution of the Word Processor\n\nThe concept of the word processor predates modern computers.\n\n- IBM MT/ST: Introduced in 1964.\n- Wang Laboratories: Built dedicated machines.\n\n## Future of Word Processing\n\nToday, word processors include AI assistance.\n\n1. Undo/Redo: Easy recovery.\n2. Track Changes: Better collaboration.",
  )
}

///|
test "pdf structure keeps short standalone lines as separate paragraphs" {
  let structure = reconstruct_pdf_blocks_with_heading_state(
    [
      PdfPageText::{
        number: 1,
        raw_text: "",
        chunks: [
          "May 5, 2023", "To Whom it May Concern:", "There were 20,000 bottles of water, 10,000 blankets, and 200 laptops delivered on January 23, 2023.",
          "A total of 3 trucks were used for 15 hours.", "Best Regards,", "Mallori",
        ],
        layout: None,
      },
    ],
    false,
  )
  inspect(
    @ast.render_markdown(@ast.document(None, {}, structure.blocks)),
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
    used_text_fallback: true,
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
    content="Some(\"PDF OCR recovery was enabled but no usable PDF OCR backend was available.\")",
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
      used_text_fallback: false,
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
    content="[\"PDF route marked 1/3 page(s) for OCR recovery, but OCR recovery did not supply usable page text; native extraction remains for those pages.\"]",
  )
}

///|
test "pdf ocr recovery attempts mixed documents with recovery pages" {
  let route_plan = PdfRoutePlan::{
    document_mode: Mixed,
    pages: [
      PdfPageRoute::{
        page_no: 1,
        provider: NativeTextFast,
        text_quality: Strong,
        layout_complexity: Simple,
        flags: [],
      },
      PdfPageRoute::{
        page_no: 2,
        provider: OcrRecovery,
        text_quality: Empty,
        layout_complexity: Simple,
        flags: [SuspectScanned],
      },
    ],
    summary: PdfRouteSummary::{
      total_pages: 2,
      native_fast_pages: 1,
      structured_pages: 0,
      recovery_pages: 1,
      flagged_pages: 1,
    },
  }
  inspect(
    should_attempt_pdf_ocr_recovery(route_plan, @ocr.OcrConfig::{
      ..@ocr.OcrConfig::default(),
      mode: @ocr.Auto,
    }),
    content="true",
  )
}

///|
test "pdf ocr page injection replaces only recovery pages" {
  let route_plan = PdfRoutePlan::{
    document_mode: Mixed,
    pages: [
      PdfPageRoute::{
        page_no: 1,
        provider: NativeTextFast,
        text_quality: Strong,
        layout_complexity: Simple,
        flags: [],
      },
      PdfPageRoute::{
        page_no: 2,
        provider: OcrRecovery,
        text_quality: Empty,
        layout_complexity: Simple,
        flags: [SuspectScanned],
      },
      PdfPageRoute::{
        page_no: 3,
        provider: OcrRecovery,
        text_quality: Empty,
        layout_complexity: Simple,
        flags: [SuspectScanned],
      },
    ],
    summary: PdfRouteSummary::{
      total_pages: 3,
      native_fast_pages: 1,
      structured_pages: 0,
      recovery_pages: 2,
      flagged_pages: 2,
    },
  }
  inspect(
    inject_pdf_ocr_pages(
      ["native page one", "", ""],
      route_plan,
      "Recovered page two\n" +
      pdf_ocr_page_break_marker() +
      "\nRecovered page three",
    ),
    content="[\"native page one\", \"Recovered page two\", \"Recovered page three\"]",
  )
}

///|
test "pdf ocr page injection respects page-aligned OCR output" {
  let route_plan = PdfRoutePlan::{
    document_mode: Mixed,
    pages: [
      PdfPageRoute::{
        page_no: 1,
        provider: NativeTextFast,
        text_quality: Strong,
        layout_complexity: Simple,
        flags: [],
      },
      PdfPageRoute::{
        page_no: 2,
        provider: OcrRecovery,
        text_quality: Empty,
        layout_complexity: Simple,
        flags: [SuspectScanned],
      },
      PdfPageRoute::{
        page_no: 3,
        provider: NativeTextFast,
        text_quality: Good,
        layout_complexity: Simple,
        flags: [],
      },
    ],
    summary: PdfRouteSummary::{
      total_pages: 3,
      native_fast_pages: 2,
      structured_pages: 0,
      recovery_pages: 1,
      flagged_pages: 1,
    },
  }
  inspect(
    inject_pdf_ocr_pages(
      ["native page one", "", "native page three"],
      route_plan,
      "page one text\n" +
      pdf_ocr_page_break_marker() +
      "\nRecovered page two\n" +
      pdf_ocr_page_break_marker() +
      "\npage three text",
    ),
    content="[\"native page one\", \"Recovered page two\", \"native page three\"]",
  )
}
