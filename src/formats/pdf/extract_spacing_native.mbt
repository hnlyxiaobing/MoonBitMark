///|
/// Word-spacing-aware PDF text extractor.
///
/// The per-page extraction loop below is a behavioral copy of mbtpdf's
/// private functions `extract_text_from_page`, `append_text_from_streams`
/// and `lookup_text_extractor` (upstream `bobzhang/mbtpdf@0.2.0`,
/// `text/pdftext/extract.mbt`). They are copied because
/// `PdfText.pdf` is a private field, so the loop cannot be reused through
/// the public API. The copy is extended locally to materialize inter-word
/// spacing from TJ displacement numbers and Td horizontal moves, which the
/// upstream implementation silently drops.

///|
/// Sentinel used to split mbtpdf's joined per-page text back into pages when
/// a page has to fall back to the upstream extractor. Uses an ASCII
/// record-separator control character that cannot appear in extracted text.
let pdf_fallback_page_break : String = "\u{1e}"

///|
/// Displacement at or above which a space character is materialized between
/// text pieces, expressed as a fraction of the em (for TJ numbers) or of the
/// current font size (for Td horizontal moves). Calibrated on the conversion
/// eval fixtures: word gaps cluster at 0.22em and above, while kerning and
/// code letterspacing stay at or below 0.15em and the tightest glued unit
/// ("0.5M") sits at 0.2em, so 0.21 sits inside the gap between the two
/// clusters.
let space_ratio : Double = 0.21

///|
/// Font size assumed when no `Tf` operator has been seen yet, so the
/// displacement-to-space conversion is defined on every branch.
let default_font_size : Double = 12.0

///|
/// ASCII letters and digits, used to decide whether a typographic gap is a
/// word boundary in a space-separated script.
fn is_ascii_word_char(ch : Char) -> Bool {
  is_lower_ascii(ch) || is_upper_ascii(ch) || is_digit_ascii(ch)
}

///|
priv struct PdfSpacingExtractor {
  pdf : @mbtpdf.Pdf
  text : @pdftextlib.PdfText
}

///|
fn PdfSpacingExtractor::new(pdf : @mbtpdf.Pdf) -> PdfSpacingExtractor {
  { pdf, text: @pdftextlib.PdfText::new(pdf), }
}

///|
/// Extract text from every page, one entry per page. A page whose content
/// stream fails to parse falls back to the upstream mbtpdf extraction for
/// that page and records a warning, instead of failing the whole document.
fn extract_spacing_pages(
  pdf : @mbtpdf.Pdf,
  warnings : Array[String],
) -> Array[String] raise {
  let extractor = PdfSpacingExtractor::new(pdf)
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let mut fallback_pages : Array[String]? = None
  let out : Array[String] = []
  for i, page in pages {
    let text = extractor.extract_text_from_page(page) catch {
      _ => {
        warnings.push(
          "page \{i + 1}: spacing-aware extraction failed, fell back to mbtpdf extract_text",
        )
        let all_pages = match fallback_pages {
          Some(cached) => cached
          None => {
            let extracted = @pdftextlib.PdfText::new(pdf)
              .extract_text(page_break=pdf_fallback_page_break)
              .split(pdf_fallback_page_break)
              .to_array()
              .map(chunk => chunk.to_owned())
            fallback_pages = Some(extracted)
            extracted
          }
        }
        if i < all_pages.length() {
          all_pages[i]
        } else {
          ""
        }
      }
    }
    out.push(text)
  }
  out
}

///|
fn PdfSpacingExtractor::extract_text_from_page(
  self : PdfSpacingExtractor,
  page : @pdfpage.Page,
) -> String raise {
  let builder = StringBuilder()
  let visited : Map[Int32, Bool] = Map([], capacity=8)
  self.append_text_from_streams(builder, page.resources, page.content, visited)
  builder.to_string()
}

///|
fn PdfSpacingExtractor::append_text_from_streams(
  self : PdfSpacingExtractor,
  builder : StringBuilder,
  resources : @mbtpdf.PdfObject,
  streams : Array[@mbtpdf.PdfObject],
  visited : Map[Int32, Bool],
) -> Unit raise {
  let ops = @pdfops.Op::parse_operators(self.pdf, resources, streams)
  let mut in_text = false
  let mut current_extractor : @pdftextlib.TextExtractor? = None
  let mut last_newline = false
  let mut last_char : Char? = None
  let mut current_font_size = default_font_size
  let mut pending_space = false
  let mut current_tc : Double = 0.0
  let mut current_std_font : @pdffont.StandardFont? = None
  let mut expected_x : Double = 0.0
  let extractor_cache : Map[String, @pdftextlib.TextExtractor] = Map(
    [],
    capacity=8,
  )
  fn append_newline() -> Unit {
    if !builder.is_empty() && !last_newline {
      builder.write_char('\n')
      last_newline = true
      last_char = Some('\n')
    }
  }

  fn append_text_piece(value : String) -> Unit {
    if value.length() == 0 {
      return
    }
    builder.write_string(value)
    last_newline = false
    for ch in value {
      last_char = Some(ch)
    }
  }

  fn append_space() -> Unit {
    if builder.is_empty() {
      return
    }
    match last_char {
      Some(' ') | Some('\n') | None => ()
      _ => {
        builder.write_char(' ')
        last_char = Some(' ')
        last_newline = false
      }
    }
  }

  fn decode_pdfdoc(value : String) -> String {
    @pdftextlib.PdfTextUtil::new().utf8_of_pdfdocstring(value) catch {
      _ => value
    }
  }

  fn decode_text(value : String) -> String {
    if @pdftextlib.PdfTextUtil::new().is_unicode(value) {
      return @pdftextlib.PdfTextUtil::new().utf8_of_pdfdocstring(value) catch {
        _ => value
      }
    }
    if current_extractor is Some(extractor) {
      @pdftextlib.PdfTextUtil::new().utf8_of_codepoints(
        extractor.codepoints_of_text(value),
      ) catch {
        _ => decode_pdfdoc(value)
      }
    } else {
      decode_pdfdoc(value)
    }
  }

  fn resolve_standard_font(font_name : String) -> @pdffont.StandardFont? {
    let base_font = match self.pdf.lookup_direct("/Font", resources) {
      Some(fonts) =>
        match self.pdf.lookup_direct(font_name, fonts) {
          Some(font_obj) =>
            match self.pdf.lookup_direct("/BaseFont", font_obj) {
              Some(Name(bf)) => {
                let s = bf.to_string_bytes()
                let stripped = if s.has_prefix("/") {
                  s[1:].to_owned()
                } else {
                  s
                }
                match stripped.find("+") {
                  Some(pos) => stripped[pos + 1:].to_owned()
                  None => stripped
                }
              }
              _ => return None
            }
          None => return None
        }
      None => return None
    }
    match base_font {
      "Helvetica" => Some(@pdffont.StandardFont::Helvetica)
      "Helvetica-Bold" => Some(@pdffont.StandardFont::HelveticaBold)
      "Helvetica-Oblique" => Some(@pdffont.StandardFont::HelveticaOblique)
      "Helvetica-BoldOblique" =>
        Some(@pdffont.StandardFont::HelveticaBoldOblique)
      "Times-Roman" => Some(@pdffont.StandardFont::TimesRoman)
      "Times-Bold" => Some(@pdffont.StandardFont::TimesBold)
      "Times-Italic" => Some(@pdffont.StandardFont::TimesItalic)
      "Times-BoldItalic" => Some(@pdffont.StandardFont::TimesBoldItalic)
      "Courier" => Some(@pdffont.StandardFont::Courier)
      "Courier-Bold" => Some(@pdffont.StandardFont::CourierBold)
      "Courier-Oblique" => Some(@pdffont.StandardFont::CourierOblique)
      "Courier-BoldOblique" => Some(@pdffont.StandardFont::CourierBoldOblique)
      "Symbol" => Some(@pdffont.StandardFont::Symbol)
      "ZapfDingbats" => Some(@pdffont.StandardFont::ZapfDingbats)
      _ => None
    }
  }

  /// Advance width of `raw` in text-space units, used to track the pen
  /// position for the OpTm gap check. Metrics exist only for the standard 14
  /// fonts; any other font (embedded/CID subsets) returns 0.0, so
  /// `expected_x` stops at the last Tm origin rather than the true pen
  /// position. The OpTm gap is then the full inter-run distance instead of
  /// the whitespace between ink, which over-estimates and can insert a space
  /// between Tm runs that are only one glyph-width apart. Kept as-is because
  /// the alternative — skipping OpTm entirely without metrics — would lose
  /// real word gaps for producers that place one word per Tm. The test
  /// "Tm gap is over-estimated when the font has no metrics" pins this.
  fn compute_text_advance(raw : String) -> Double {
    match current_std_font {
      Some(std_font) => {
        let w = @pdfstandard14.PdfStandard14::new().textwidth(
          true,
          @pdffont.Encoding::WinAnsiEncoding,
          std_font,
          raw,
        ) catch {
          _ => return 0.0
        }
        w.to_double() * current_font_size / 1000.0
      }
      None => 0.0
    }
  }

  fn append_text_value(value : String) -> Unit {
    let decoded = decode_text(value)
    if pending_space {
      pending_space = false
      // Only materialize the gap as a space when a space-using script is
      // involved on at least one side. Cursive scripts (Arabic) and CJK
      // justification use wide inter-letter adjustments that are not word
      // boundaries, so both-sides-non-Latin gaps stay glued.
      let mut latin_boundary = match last_char {
        Some(ch) => is_ascii_word_char(ch)
        None => false
      }
      if !latin_boundary {
        for ch in decoded {
          latin_boundary = is_ascii_word_char(ch)
          break
        }
      }
      if latin_boundary {
        append_space()
      }
    }
    append_text_piece(decoded)
  }

  /// Materialize a space when a TJ displacement opens a word-sized gap.
  /// TJ numbers are in thousandths of an em; a negative number moves the
  /// next glyph apart, so `-adjustment / 1000` is the gap width in ems.
  /// The space is deferred until the next text piece so the script check in
  /// `append_text_value` can veto it.
  fn append_text_array(obj : @mbtpdf.PdfObject) -> Unit {
    match obj {
      PdfArray(values) =>
        for value in values {
          match value {
            PdfString(text) => append_text_value(text)
            Real(adjustment) =>
              if -adjustment / 1000.0 >= space_ratio {
                pending_space = true
              }
            Integer(adjustment) =>
              if -adjustment.to_double() / 1000.0 >= space_ratio {
                pending_space = true
              }
            _ => ()
          }
        }
      PdfString(text) => append_text_value(text)
      _ => ()
    }
  }

  fn maybe_update_font(name : String) -> Unit {
    current_extractor = self.lookup_text_extractor(
      resources, name, extractor_cache,
    )
  }

  fn mark_visited(obj_num : Int32?) -> Bool {
    match obj_num {
      Some(i) =>
        match visited.get(i) {
          Some(true) => false
          _ => {
            visited.set(i, true)
            true
          }
        }
      None => true
    }
  }

  fn append_text_from_xobject(name : String) -> Unit raise {
    match self.pdf.lookup_direct("/XObject", resources) {
      Some(Dictionary(entries)) =>
        if entries.search_by(pair => pair.0 == name) is Some(idx) {
          let obj_ref = entries[idx].1
          let obj_num : Int32? = if obj_ref is Indirect(i) {
            Some(i)
          } else {
            None
          }
          if mark_visited(obj_num) {
            let xobj = self.pdf.direct(obj_ref)
            if self.pdf.lookup_direct("/Subtype", xobj) is Some(Name(n)) &&
              n.equal_string_bytes("/Form") {
              let xresources = self.pdf
                .lookup_direct("/Resources", xobj)
                .unwrap_or(resources)
              self.append_text_from_streams(
                builder,
                xresources,
                [xobj],
                visited,
              )
            }
          }
        }
      _ => ()
    }
  }

  for op in ops {
    match (op : @pdfops.Op) {
      OpBT => {
        in_text = true
        current_extractor = None
        current_font_size = default_font_size
        current_tc = 0.0
        pending_space = false
        current_std_font = None
        expected_x = 0.0
      }
      OpET => {
        in_text = false
        current_extractor = None
      }
      OpTf(name, size) =>
        if in_text {
          maybe_update_font(name)
          current_font_size = if size > 0.0 { size } else { default_font_size }
          current_std_font = resolve_standard_font(name)
          // Abandon the pen estimate: it was measured in the previous font's
          // metrics. A mid-line font switch can therefore miss one OpTm gap
          // rather than invent one, which is the conservative direction.
          expected_x = 0.0
        }
      OpTw(_) => ()
      OpTc(c) => if in_text { current_tc = c }
      OpTj(text) =>
        if in_text {
          append_text_value(text)
          expected_x = expected_x + compute_text_advance(text)
          if current_tc.abs() / current_font_size >= space_ratio {
            pending_space = true
          }
        }
      OpTJ(obj) =>
        if in_text {
          append_text_array(obj)
          let items = match obj {
            PdfArray(vs) => vs
            PdfString(_) => [obj]
            _ => []
          }
          for value in items {
            match value {
              PdfString(t) => expected_x = expected_x + compute_text_advance(t)
              _ => ()
            }
          }
          if current_tc.abs() / current_font_size >= space_ratio {
            pending_space = true
          }
        }
      OpSingleQuote(text) =>
        if in_text {
          append_newline()
          append_text_value(text)
          expected_x = expected_x + compute_text_advance(text)
          if current_tc.abs() / current_font_size >= space_ratio {
            pending_space = true
          }
        }
      OpDoubleQuote(_, ac, text) =>
        if in_text {
          current_tc = ac
          append_newline()
          append_text_value(text)
          expected_x = expected_x + compute_text_advance(text)
          if current_tc.abs() / current_font_size >= space_ratio {
            pending_space = true
          }
        }
      OpTStar => if in_text { append_newline() }
      OpTd(tx, ty) =>
        if in_text {
          if ty != 0.0 {
            append_newline()
            expected_x = 0.0
          } else {
            expected_x = expected_x + tx
            if tx / current_font_size >= space_ratio {
              pending_space = true
            }
          }
        }
      OpTD(tx, ty) =>
        if in_text {
          if ty != 0.0 {
            append_newline()
            expected_x = 0.0
          } else {
            expected_x = expected_x + tx
            if tx / current_font_size >= space_ratio {
              pending_space = true
            }
          }
        }
      OpTm(tm) =>
        if in_text {
          // Only materialize a Tm-derived space when the current font has
          // metrics (`current_std_font`), because the gap needs the pen
          // position after the previous run. With an embedded/subset font
          // `compute_text_advance` returns 0.0, so `expected_x` stays at the
          // previous Tm origin and the "gap" becomes the whole inter-run
          // distance (glyph ink included). That over-estimate inserts spaces
          // inside runs the producer split only for positioning, e.g. the
          // subscripts of `H2SO4` in `pdf_embedded_images_tables` becoming
          // `H2 SO 4`. Without metrics we leave the decision to the exact
          // TJ/Td/Tc signals instead of guessing.
          // Approximation: the gap uses the raw `tm.e` translation and
          // ignores the horizontal scale `tm.a`, so scaled text matrices
          // shift the computed gap by that factor.
          if current_std_font is Some(_) && expected_x > 0.0 {
            let gap = tm.e - expected_x
            if gap / current_font_size >= space_ratio {
              pending_space = true
            }
          }
          expected_x = tm.e
        }
      OpDo(name) => append_text_from_xobject(name)
      _ => ()
    }
  }
}

///|
fn PdfSpacingExtractor::lookup_text_extractor(
  self : PdfSpacingExtractor,
  resources : @mbtpdf.PdfObject,
  font_name : String,
  cache : Map[String, @pdftextlib.TextExtractor],
) -> @pdftextlib.TextExtractor? {
  if cache.get(font_name) is Some(extractor) {
    return Some(extractor)
  }
  match self.pdf.lookup_direct("/Font", resources) {
    Some(fonts) =>
      match self.pdf.lookup_direct(font_name, fonts) {
        Some(obj) =>
          try {
            let extractor = self.text.text_extractor_of_font(obj)
            cache.set(font_name, extractor)
            Some(extractor)
          } catch {
            _ => None
          }
        None => None
      }
    None => None
  }
}
