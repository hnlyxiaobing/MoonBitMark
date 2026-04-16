///|
test "pdf scientific table parser rebuilds column-major table" {
  let parsed = try_parse_scientific_table(
    [
      "Inhibitor", "concentration (g)", "bc (V/dec)", "ba (V/dec)", "Ecorr (V)",
      "icorr (A/cm2)", "Polarization", "resistance (Ω)", "Corrosion", "rate (mm/year)",
      "0 2 4 6 8 10", "0.0335 1.9460 0.0163 0.3233 0.1240 0.0382", "0.0409 0.0596 0.2369 0.0540 0.0556 0.0086",
      "-0.9393 -0.8276 -0.8825 -0.8027 -0.5896 -0.5356", "0.0003 0.0002 0.0001 5.39E-05 5.46E-05 1.24E-05",
      "24.0910 121.440 42.121 373.180 305.650 246.080", "2.8163 1.5054 0.9476 0.4318 0.3772 0.0919",
      "The plot of inhibitor concentration over degree of surface coverage versus inhibitor concentration",
    ],
    0,
  )

  inspect(parsed is Some(_), content="true")
  match parsed {
    Some((headers, rows, next_index)) => {
      inspect(
        headers,
        content="[\"Inhibitor concentration (g)\", \"bc (V/dec)\", \"ba (V/dec)\", \"Ecorr (V)\", \"icorr (A/cm2)\", \"Polarization resistance (Ω)\", \"Corrosion rate (mm/year)\"]",
      )
      inspect(rows.length(), content="6")
      inspect(
        rows[0],
        content="[\"0\", \"0.0335\", \"0.0409\", \"-0.9393\", \"0.0003\", \"24.0910\", \"2.8163\"]",
      )
      inspect(next_index, content="17")
    }
    None => fail("expected parsed table")
  }
}

///|
test "pdf structured page reconstruction emits markdown table block" {
  let page = PdfPageText::{
    number: 1,
    raw_text: "",
    chunks: [
      "Fig. 4. Anodic and cathodic polarization curve of stainless steel in 0.5 M H2SO4 solution in the presence and absence of ES.",
      "Table 1 Potentiodynamic polarization data for stainless steel in the absence and presence of ES in 0.5 M H2SO4 solution.",
      "Inhibitor", "concentration (g)", "bc (V/dec)", "ba (V/dec)", "Ecorr (V)",
      "icorr (A/cm2)", "Polarization", "resistance (Ω)", "Corrosion", "rate (mm/year)",
      "0 2 4 6 8 10", "0.0335 1.9460 0.0163 0.3233 0.1240 0.0382", "0.0409 0.0596 0.2369 0.0540 0.0556 0.0086",
      "-0.9393 -0.8276 -0.8825 -0.8027 -0.5896 -0.5356", "0.0003 0.0002 0.0001 5.39E-05 5.46E-05 1.24E-05",
      "24.0910 121.440 42.121 373.180 305.650 246.080", "2.8163 1.5054 0.9476 0.4318 0.3772 0.0919",
      "The plot of inhibitor concentration over degree of surface coverage versus inhibitor concentration gives a straight line as shown in Fig. 5.",
    ],
    layout: None,
  }
  let route = PdfPageRoute::{
    page_no: 1,
    provider: NativeTextStructured,
    text_quality: Good,
    layout_complexity: Complex,
    flags: [SuspectTable],
  }
  let result = reconstruct_structured_page_blocks(page, route, false)
  inspect(
    @ast.render_markdown(@ast.document(None, {}, result.blocks)),
    content="Fig. 4. Anodic and cathodic polarization curve of stainless steel in 0.5 M H2SO4 solution in the presence and absence of ES.\n\nTable 1 Potentiodynamic polarization data for stainless steel in the absence and presence of ES in 0.5 M H2SO4 solution.\n\n| Inhibitor concentration (g) | bc (V/dec) | ba (V/dec) | Ecorr (V) | icorr (A/cm2) | Polarization resistance (Ω) | Corrosion rate (mm/year) |\n| --- | --- | --- | --- | --- | --- | --- |\n| 0 | 0.0335 | 0.0409 | -0.9393 | 0.0003 | 24.0910 | 2.8163 |\n| 2 | 1.9460 | 0.0596 | -0.8276 | 0.0002 | 121.440 | 1.5054 |\n| 4 | 0.0163 | 0.2369 | -0.8825 | 0.0001 | 42.121 | 0.9476 |\n| 6 | 0.3233 | 0.0540 | -0.8027 | 5.39E-05 | 373.180 | 0.4318 |\n| 8 | 0.1240 | 0.0556 | -0.5896 | 5.46E-05 | 305.650 | 0.3772 |\n| 10 | 0.0382 | 0.0086 | -0.5356 | 1.24E-05 | 246.080 | 0.0919 |\n\nThe plot of inhibitor concentration over degree of surface coverage versus inhibitor concentration gives a straight line as shown in Fig. 5.",
  )
}

///|
test "pdf structured page reconstruction keeps fenced code after listing gap" {
  let page = PdfPageText::{
    number: 1,
    raw_text: "",
    chunks: [
      "Listing 1: Simple JavaScript Program", "", "function add (a , b ) {", "return a + b ;",
      "", "}", "console . log ( add (3 , 5) ) ;",
    ],
    layout: None,
  }
  let route = PdfPageRoute::{
    page_no: 1,
    provider: NativeTextStructured,
    text_quality: Good,
    layout_complexity: Medium,
    flags: [SuspectCode],
  }
  let structure = reconstruct_structured_page_blocks(page, route, false)
  inspect(
    @ast.render_markdown(@ast.document(None, {}, structure.blocks)),
    content="Listing 1: Simple JavaScript Program\n\n```\nfunction add(a, b) {\nreturn a + b;\n\n}\nconsole.log(add(3, 5));\n```",
  )
}

///|
test "pdf normalization drops standalone page furniture" {
  let normalized = normalize_pdf_pages([
    "454\nJournal Header / Data in Brief 22 (2019) 451-457\nBody paragraph.\n1",
  ])
  inspect(normalized.pages[0].chunks, content="[\"Body paragraph.\"]")
}

///|
test "pdf scientific caption splitter keeps inline figure references" {
  inspect(
    split_scientific_caption_boundary(
      "The plot gives a straight line as shown in Fig. 5. The strong correlation reveals adsorption.",
    ),
    content="[\"The plot gives a straight line as shown in Fig. 5. The strong correlation reveals adsorption.\"]",
  )
}

///|
test "pdf structured page reconstruction drops chart axis noise" {
  let page = PdfPageText::{
    number: 1,
    raw_text: "",
    chunks: ["/", "C", "Fig. 5. Langmuir adsorption isotherm of ES."],
    layout: None,
  }
  let route = PdfPageRoute::{
    page_no: 1,
    provider: NativeTextStructured,
    text_quality: Good,
    layout_complexity: Complex,
    flags: [SuspectTable],
  }
  let structure = reconstruct_structured_page_blocks(page, route, false)
  inspect(
    @ast.render_markdown(@ast.document(None, {}, structure.blocks)),
    content="Fig. 5. Langmuir adsorption isotherm of ES.",
  )
}

///|
test "pdf fallback linewise normalization rebuilds headings and bullet lines" {
  let chunks = normalize_fallback_page_chunks([
    PdfRawLine::{ text: "The Evolution of the Word Processor" },
    PdfRawLine::{ text: "" },
    PdfRawLine::{ text: "Pre-Digital Era (19th - Early 20th Century)" },
    PdfRawLine::{ text: "" },
    PdfRawLine::{
      text: "The origins of word processing can be traced back to the invention of the typewriter in the",
    },
    PdfRawLine::{
      text: "mid-19th century. Patented in 1868 by Christopher Latham Sholes, the typewriter",
    },
    PdfRawLine::{
      text: "revolutionized written communication by enabling people to produce legible documents.",
    },
    PdfRawLine::{ text: "" },
    PdfRawLine::{ text: "•" },
    PdfRawLine::{
      text: "IBM MT/ST (Magnetic Tape/Selectric Typewriter): Introduced in 1964.",
    },
  ])
  inspect(
    chunks,
    content="[\"The Evolution of the Word Processor\", \"Pre-Digital Era (19th - Early 20th Century)\", \"The origins of word processing can be traced back to the invention of the typewriter in the mid-19th century. Patented in 1868 by Christopher Latham Sholes, the typewriter revolutionized written communication by enabling people to produce legible documents.\", \"• IBM MT/ST (Magnetic Tape/Selectric Typewriter): Introduced in 1964.\"]",
  )
}

///|
test "pdf block repair merges list continuations and promotes rescued headings" {
  let blocks = repair_pdf_blocks(
    [
      @ast.List(
        [
          @ast.text_inlines(
            "Accessibility: Writers no longer needed expensive publishing equipment or training",
          ),
        ],
        false,
      ),
      @ast.text_paragraph(
        "in typesetting to create polished work. This accessibility paved the way for self-",
      ),
      @ast.text_paragraph(
        "publishing, blogging, and even fan fiction communities.",
      ),
      @ast.List(
        [
          @ast.text_inlines(
            "Education: Word processors became a cornerstone of education, teaching students",
          ),
        ],
        false,
      ),
      @ast.text_paragraph(
        "not only how to write essays but also how to use technology effectively.",
      ),
      @ast.text_paragraph("Word Processors in a Post-Digital Era"),
      @ast.text_paragraph(
        "As we move further into the 21st century, the role of the word processor continues to evolve:",
      ),
    ],
    true,
  )
  inspect(
    @ast.render_markdown(@ast.document(None, {}, blocks)),
    content="- Accessibility: Writers no longer needed expensive publishing equipment or training in typesetting to create polished work. This accessibility paved the way for self-publishing, blogging, and even fan fiction communities.\n- Education: Word processors became a cornerstone of education, teaching students not only how to write essays but also how to use technology effectively.\n\n## Word Processors in a Post-Digital Era\n\nAs we move further into the 21st century, the role of the word processor continues to evolve:",
  )
}

///|
test "pdf block repair absorbs orphan bullets into surrounding list" {
  let blocks = repair_pdf_blocks(
    [
      @ast.text_paragraph(
        "The word processor's future lies in adaptability and intelligence. Some exciting possibilities include:",
      ),
      @ast.List(
        [
          @ast.text_inlines(
            "Fully AI-Assisted Writing: Imagine a word processor that understands your writing",
          ),
        ],
        false,
      ),
      @ast.text_paragraph("•"),
      @ast.text_paragraph(
        "style, drafts emails, or creates entire essays based on minimal input.",
      ),
      @ast.text_paragraph(
        "Immersive Interfaces: As augmented reality (AR) and virtual reality (VR) technology advance, users may be able to write and edit in 3D spaces, collaborating in virtual environments.",
      ),
      @ast.List(
        [
          @ast.text_inlines(
            "Hyper-Personalization: Word processors could offer dynamic suggestions based on industry-specific needs, user habits, or even regional language variations.",
          ),
        ],
        false,
      ),
    ],
    true,
  )
  inspect(
    @ast.render_markdown(@ast.document(None, {}, blocks)),
    content="The word processor's future lies in adaptability and intelligence. Some exciting possibilities include:\n\n- Fully AI-Assisted Writing: Imagine a word processor that understands your writing style, drafts emails, or creates entire essays based on minimal input.\n- Immersive Interfaces: As augmented reality (AR) and virtual reality (VR) technology advance, users may be able to write and edit in 3D spaces, collaborating in virtual environments.\n- Hyper-Personalization: Word processors could offer dynamic suggestions based on industry-specific needs, user habits, or even regional language variations.",
  )
}

///|
test "pdf spacing restoration keeps camel case brand names intact" {
  inspect(
    restore_obvious_spacing(
      "Tools like Grammarly, ProWritingAid, and OneDrive stay connected.",
    ),
    content="Tools like Grammarly, ProWritingAid, and OneDrive stay connected.",
  )
}

///|
test "pdf paragraph merge keeps em dash tight across wrapped lines" {
  inspect(
    merge_paragraph_text(
      "The journey of the word processor—from clunky typewriters to AI-powered platforms—",
      "reflects humanity's broader technological progress.",
    ),
    content="The journey of the word processor—from clunky typewriters to AI-powered platforms—reflects humanity's broader technological progress.",
  )
}

///|
test "pdf ocr recovery normalization preserves linewise block candidates" {
  let chunks = normalize_ocr_recovery_page_chunks([
    PdfRawLine::{ text: "Project Status" },
    PdfRawLine::{ text: "" },
    PdfRawLine::{ text: "•" },
    PdfRawLine::{ text: "Recovered backlog item" },
    PdfRawLine::{ text: "" },
    PdfRawLine::{ text: "Quarter  Revenue  Margin" },
    PdfRawLine::{ text: "Q1  12.4  31%" },
    PdfRawLine::{ text: "Q2  14.1  34%" },
  ])
  inspect(
    chunks,
    content="[\"Project Status\", \"\", \"•\", \"Recovered backlog item\", \"\", \"Quarter  Revenue  Margin\", \"Q1  12.4  31%\", \"Q2  14.1  34%\"]",
  )
}

///|
test "pdf ocr recovery reconstruction rebuilds lists and whitespace tables" {
  let page = PdfPageText::{
    number: 2,
    raw_text: "",
    chunks: [
      "Recovered Summary", "", "• Implementation status is stable", "• Validation coverage increased",
      "", "Quarter  Revenue  Margin", "Q1  12.4  31%", "Q2  14.1  34%", "Q3  13.8  33%",
    ],
    layout: None,
  }
  let result = reconstruct_ocr_recovery_page_blocks(page, false)
  inspect(
    @ast.render_markdown(@ast.document(None, {}, result.blocks)),
    content="# Recovered Summary\n\n- Implementation status is stable\n- Validation coverage increased\n\n| Quarter | Revenue | Margin |\n| --- | --- | --- |\n| Q1 | 12.4 | 31% |\n| Q2 | 14.1 | 34% |\n| Q3 | 13.8 | 33% |",
  )
}

///|
test "pdf layout chunks reorder two-column reading order" {
  let chunks = layout_page_to_chunks(PdfLayoutPage::{
    page_no: 1,
    width: 1000,
    height: 1000,
    lines: [
      PdfLayoutLine::{
        text: "Neural Networks Overview",
        left: 80,
        top: 40,
        right: 920,
        bottom: 90,
        words: [],
      },
      PdfLayoutLine::{
        text: "Left column begins here.",
        left: 90,
        top: 180,
        right: 420,
        bottom: 220,
        words: [],
      },
      PdfLayoutLine::{
        text: "Left column continues here.",
        left: 90,
        top: 240,
        right: 430,
        bottom: 280,
        words: [],
      },
      PdfLayoutLine::{
        text: "Right column begins here.",
        left: 580,
        top: 185,
        right: 910,
        bottom: 225,
        words: [],
      },
      PdfLayoutLine::{
        text: "Right column continues here.",
        left: 580,
        top: 245,
        right: 920,
        bottom: 285,
        words: [],
      },
    ],
  })
  inspect(
    chunks,
    content="[\"Neural Networks Overview\", \"\", \"Left column begins here.\", \"Left column continues here.\", \"\", \"Right column begins here.\", \"Right column continues here.\"]",
  )
}

///|
test "pdf layout reconstruction flattens merged table headers from bbox words" {
  let layout = PdfLayoutPage::{
    page_no: 1,
    width: 1000,
    height: 1000,
    lines: [
      PdfLayoutLine::{
        text: "Quarter Metrics",
        left: 90,
        top: 120,
        right: 760,
        bottom: 160,
        words: [
          PdfLayoutWord::{ text: "Quarter", left: 90, top: 120, right: 240, bottom: 160 },
          PdfLayoutWord::{ text: "Metrics", left: 360, top: 120, right: 760, bottom: 160 },
        ],
      },
      PdfLayoutLine::{
        text: "Revenue Margin",
        left: 420,
        top: 170,
        right: 760,
        bottom: 210,
        words: [
          PdfLayoutWord::{ text: "Revenue", left: 420, top: 170, right: 540, bottom: 210 },
          PdfLayoutWord::{ text: "Margin", left: 620, top: 170, right: 760, bottom: 210 },
        ],
      },
      PdfLayoutLine::{
        text: "Q1 12.4 31%",
        left: 100,
        top: 235,
        right: 720,
        bottom: 275,
        words: [
          PdfLayoutWord::{ text: "Q1", left: 100, top: 235, right: 170, bottom: 275 },
          PdfLayoutWord::{ text: "12.4", left: 450, top: 235, right: 520, bottom: 275 },
          PdfLayoutWord::{ text: "31%", left: 650, top: 235, right: 720, bottom: 275 },
        ],
      },
      PdfLayoutLine::{
        text: "Q2 14.1 34%",
        left: 100,
        top: 290,
        right: 720,
        bottom: 330,
        words: [
          PdfLayoutWord::{ text: "Q2", left: 100, top: 290, right: 170, bottom: 330 },
          PdfLayoutWord::{ text: "14.1", left: 450, top: 290, right: 520, bottom: 330 },
          PdfLayoutWord::{ text: "34%", left: 650, top: 290, right: 720, bottom: 330 },
        ],
      },
    ],
  }
  let page = PdfPageText::{
    number: 1,
    raw_text: "",
    chunks: [],
    layout: Some(layout),
  }
  let route = PdfPageRoute::{
    page_no: 1,
    provider: OcrRecovery,
    text_quality: Weak,
    layout_complexity: Complex,
    flags: [SuspectTable],
  }
  let result = reconstruct_layout_page_blocks(page, route, false)
  inspect(
    @ast.render_markdown(@ast.document(None, {}, result.blocks)),
    content="| Quarter | Metrics / Revenue | Metrics / Margin |\n| --- | --- | --- |\n| Q1 | 12.4 | 31% |\n| Q2 | 14.1 | 34% |",
  )
}
