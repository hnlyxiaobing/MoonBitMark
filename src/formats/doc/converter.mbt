// Word Binary Converter - Pure MoonBit Implementation
// Converts legacy Word documents (.doc / .wps) to Markdown.
//
// Both formats are OLE2 compound files containing a "WordDocument" stream with
// a FIB header, plus a 0Table/1Table stream with the piece table (CLX) and the
// paragraph property table (PlcFkp). The extraction path follows [MS-DOC]:
// FIB -> CLX -> PlcPcd -> piece text, and PlcfBtePapx -> FKP -> Papx -> istd
// for heading recovery (wps2md uses the same route).

///|
pub(all) struct DocConverter {
  dummy : Int
}

///|
/// Create a new DOC converter.
pub fn DocConverter::new() -> DocConverter {
  DocConverter::{ dummy: 0 }
}

///|
/// Check if this converter accepts the given file (.doc / .wps).
pub fn DocConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      ext_lower == ".doc" || ext_lower == ".wps"
    }
    None => false
  }
}

///|
/// Convert a Word binary file to Markdown.
pub async fn DocConverter::convert(
  file_path : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  let bytes = @core.read_file_bytes(file_path)
  convert_bytes(bytes, file_path, ctx=ctx) catch {
    err => fail(err.to_string())
  }
}

///|
/// Convert an in-memory Word binary document (pure, no filesystem IO).
/// Exposed for white-box tests; `convert` is the filesystem entry point.
pub fn convert_bytes(
  bytes : Bytes,
  source_name : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult raise {
  ignore(ctx)

  let archive = match @ole2.CfbArchive::open_explained(bytes) {
    Ok(archive) => archive
    Err(message) =>
      fail(
        render_doc_failure(
          @core.InputError(message, Some("OLE2 container")),
          Some(@core.Load(Some("WordDocument"))),
          Some(@core.Input(source_name)),
          Some(@core.CheckArchiveIntegrity),
        ),
      )
  }

  let word_document = match archive.read_stream("WordDocument") {
    Some(stream) => stream
    None =>
      fail(
        render_doc_failure(
          @core.UnsupportedFeatureError(
            "Word binary document requires a WordDocument stream",
            ".doc/.wps",
          ),
          Some(@core.Parse(Some("WordDocument"))),
          Some(@core.ArchiveEntry("WordDocument")),
          Some(@core.InspectSourceDocument),
        ),
      )
  }

  let fib = match parse_fib(word_document) {
    Ok(fib) => fib
    Err(message) =>
      fail(
        render_doc_failure(
          @core.InputError(message, Some("WordDocument FIB")),
          Some(@core.Parse(Some("WordDocument"))),
          Some(@core.ArchiveEntry("WordDocument")),
          Some(@core.InspectSourceDocument),
        ),
      )
  }

  if fib.encrypted {
    fail(
      render_doc_failure(
        @core.UnsupportedFeatureError(
          "This Word document is encrypted (fEncrypted set); decryption is not supported",
          ".doc/.wps",
        ),
        Some(@core.Parse(Some("WordDocument"))),
        Some(@core.ArchiveEntry("WordDocument")),
        Some(@core.InspectSourceDocument),
      ),
    )
  }

  let table_name = if fib.which_tbl_stm { "1Table" } else { "0Table" }
  let table_stream = archive.read_stream(table_name)
  let pieces = parse_piece_table(
    word_document,
    table_stream,
    fib.fc_clx,
    fib.lcb_clx,
  )
  let warnings : Array[String] = []
  let main_text = match pieces {
    Some(piece_list) if piece_list.length() > 0 =>
      join_piece_text(word_document, piece_list, fib.ccp_text)
    _ =>
      match contiguous_text(word_document, fib) {
        Some(text) => text
        None => ""
      }
  }

  if main_text.length() == 0 {
    warnings.push(
      "No text content extracted from the Word document (no valid piece table or contiguous text).",
    )
  }

  let paragraphs = parse_paragraph_table(
    word_document,
    table_stream,
    fib.fc_plcf_bte_papx,
    fib.lcb_plcf_bte_papx,
    pieces,
  )

  let blocks = build_doc_blocks(main_text, paragraphs)
  let metadata = Map([])
  metadata["format"] = "doc"
  metadata["container"] = "ole2"
  let summary = parse_summary_information(archive)
  for key, value in summary {
    metadata[key] = value
  }
  let title = match metadata.get("title") {
    Some(value) => Some(value)
    None => @core.file_stem(source_name)
  }
  let doc = @ast.document(title, metadata, blocks)
  let rendered_markdown = @ast.render_markdown(doc)
  let diagnostics = doc_warning_diagnostics(source_name, warnings)
  @core.ConvertResult::markdown_only(rendered_markdown, "doc")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_diagnostics(diagnostics)
  .with_stats(Some(@core.stats_for_markdown(rendered_markdown)))
  .with_document(Some(doc))
}

///|
/// Minimal FIB fields needed to locate text and paragraph properties.
priv struct DocFib {
  encrypted : Bool
  which_tbl_stm : Bool
  fc_min : Int
  fc_mac : Int
  ccp_text : Int
  fc_clx : Int
  lcb_clx : Int
  fc_plcf_bte_papx : Int
  lcb_plcf_bte_papx : Int
}

///|
fn parse_fib(word_document : Bytes) -> Result[DocFib, String] {
  if word_document.length() < 0x200 {
    return Err(
      "truncated WordDocument stream: \\{word_document.length()} bytes (FIB requires 512)",
    )
  }
  let magic = doc_u16le(word_document, 0x00)
  if magic != 0xA5EC && magic != 0xA5DC {
    return Err(
      "not a Word binary document: FIB signature 0x" +
      magic.to_string() +
      " (expected 0xA5EC or 0xA5DC)",
    )
  }
  let flags = doc_u16le(word_document, 0x0A)
  let fib = DocFib::{
    encrypted: (flags & 0x0100) != 0,
    which_tbl_stm: (flags & 0x0200) != 0,
    fc_min: doc_u32le(word_document, 0x18),
    fc_mac: doc_u32le(word_document, 0x1C),
    ccp_text: doc_u32le(word_document, 0x4C),
    fc_clx: doc_u32le(word_document, 0x1A2),
    lcb_clx: doc_u32le(word_document, 0x1A6),
    fc_plcf_bte_papx: doc_u32le(word_document, 0x102),
    lcb_plcf_bte_papx: doc_u32le(word_document, 0x106),
  }
  Ok(fib)
}

///|
/// One entry of the piece table (PlcPcd).
priv struct DocPiece {
  cp0 : Int
  cp1 : Int
  compressed : Bool
  byte_offset : Int
  fc_space_start : Int
}

///|
/// Parse the CLX -> Pcdt -> PlcPcd structure, returning the piece list.
fn parse_piece_table(
  _word_document : Bytes,
  table : Bytes?,
  fc_clx : Int,
  lcb_clx : Int,
) -> Array[DocPiece]? {
  match table {
    None => None
    Some(tbl) => {
      if lcb_clx <= 0 || fc_clx < 0 || fc_clx + lcb_clx > tbl.length() {
        return None
      }
      let clx = tbl[fc_clx:fc_clx + lcb_clx].to_owned()
      let mut index = 0
      while index < clx.length() {
        let tag = clx[index].to_int()
        if tag == 0x01 {
          // Prc: skip grpprl
          if index + 3 > clx.length() {
            break
          }
          let cb_grpprl = doc_u16le(clx, index + 1)
          index = index + 3 + cb_grpprl
        } else if tag == 0x02 {
          // Pcdt: PlcPcd follows
          if index + 5 > clx.length() {
            break
          }
          let lcb = doc_u32le(clx, index + 1)
          if lcb < 4 || index + 5 + lcb > clx.length() {
            break
          }
          let plc = clx[index + 5:index + 5 + lcb].to_owned()
          let count = (lcb - 4) / 12
          let pieces : Array[DocPiece] = []
          let mut j = 0
          while j < count {
            let c0 = doc_u32le(plc, j * 4)
            let c1 = doc_u32le(plc, (j + 1) * 4)
            // PCD is 8 bytes; the fc field starts at +2 within each PCD.
            let fc_raw = doc_u32le_uint(plc, (count + 1) * 4 + j * 8 + 2)
            let compressed = (fc_raw & 0x40000000) != 0
            let fc_value = (fc_raw & 0x3FFFFFFF).reinterpret_as_int()
            let byte_offset = if compressed { fc_value / 2 } else { fc_value }
            pieces.push(
              DocPiece::{
                cp0: c0,
                cp1: c1,
                compressed,
                byte_offset,
                fc_space_start: fc_value,
              },
            )
            j = j + 1
          }
          return Some(pieces)
        } else {
          break
        }
      }
      None
    }
  }
}

///|
/// Concatenate the text of all pieces (used when no paragraph table is found).
fn join_piece_text(
  word_document : Bytes,
  pieces : Array[DocPiece],
  _ccp_text : Int,
) -> String {
  let sb = StringBuilder::new()
  for piece in pieces {
    let chars = piece.cp1 - piece.cp0
    if chars > 0 {
      sb.write_string(
        decode_piece_range(word_document, piece, 0, chars),
      )
    }
  }
  sb.to_string()
}

///|
/// Decode `chars` characters starting at character offset `start` within a piece.
fn decode_piece_range(
  word_document : Bytes,
  piece : DocPiece,
  start : Int,
  chars : Int,
) -> String {
  if chars <= 0 {
    return ""
  }
  if piece.compressed {
    let byte_off = piece.byte_offset + start
    if byte_off + chars > word_document.length() {
      return ""
    }
    decode_cp1252(word_document, byte_off, chars)
  } else {
    let byte_off = piece.byte_offset + start * 2
    if byte_off + chars * 2 > word_document.length() {
      return ""
    }
    decode_utf16le(word_document, byte_off, chars)
  }
}

///|
/// Extract text for a fc-space range [start_fc, end_fc), crossing piece
/// boundaries. In fc space every character occupies exactly 2 units; an
/// 8-bit piece maps fc-space offset `x` to byte offset `x / 2`, a 16-bit
/// piece maps it directly to byte offset `x`.
fn extract_fc_range(
  word_document : Bytes,
  pieces : Array[DocPiece],
  start_fc : Int,
  end_fc : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut pos = start_fc
  while pos < end_fc {
    let found = find_piece_at(pieces, pos)
    match found {
      None => {
        // fc space is not contiguous across pieces: a piece boundary can
        // jump forward (e.g. 16-bit piece ends at fc=60, next 8-bit piece
        // starts at fc=2168). Skip to the next piece start instead of
        // stopping, otherwise cross-piece paragraphs get truncated.
        match next_piece_start(pieces, pos) {
          None => break
          Some(ns) => pos = ns
        }
      }
      Some(piece) => {
        let piece_end_space = piece.fc_space_start + 2 * (piece.cp1 - piece.cp0)
        let seg_end = doc_min(end_fc, piece_end_space)
        let chars = (seg_end - pos) / 2
        if chars > 0 {
          if piece.compressed {
            let byte_off = piece.byte_offset + (pos - piece.fc_space_start) / 2
            if byte_off + chars <= word_document.length() {
              sb.write_string(decode_cp1252(word_document, byte_off, chars))
            }
          } else {
            let byte_off = piece.byte_offset + (pos - piece.fc_space_start)
            if byte_off + chars * 2 <= word_document.length() {
              sb.write_string(decode_utf16le(word_document, byte_off, chars))
            }
          }
        }
        let next = seg_end
        if next > pos {
          pos = next
        } else {
          // No progress: force move past this piece to avoid an infinite loop.
          pos = piece_end_space + 2
        }
      }
    }
  }
  sb.to_string()
}

///|
fn find_piece_at(pieces : Array[DocPiece], fc_space : Int) -> DocPiece? {
  for piece in pieces {
    let start = piece.fc_space_start
    let end = start + 2 * (piece.cp1 - piece.cp0)
    if fc_space >= start && fc_space < end {
      return Some(piece)
    }
  }
  None
}

///|
/// Smallest piece start strictly greater than `after_fc`, used to hop over
/// gaps in fc space at piece boundaries.
fn next_piece_start(pieces : Array[DocPiece], after_fc : Int) -> Int? {
  let mut best : Int? = None
  for piece in pieces {
    if piece.fc_space_start > after_fc {
      match best {
        None => best = Some(piece.fc_space_start)
        Some(b) => if piece.fc_space_start < b {
          best = Some(piece.fc_space_start)
        }
      }
    }
  }
  best
}

///|
/// 0xA5DC (Word 6/95) fallback: contiguous text between fcMin and fcMac.
fn contiguous_text(word_document : Bytes, fib : DocFib) -> String? {
  if fib.ccp_text <= 0 {
    return None
  }
  let text_bytes = fib.fc_mac - fib.fc_min
  if fib.fc_min < 0 || fib.fc_min + text_bytes > word_document.length() {
    return None
  }
  if text_bytes == fib.ccp_text * 2 {
    Some(decode_utf16le(word_document, fib.fc_min, fib.ccp_text))
  } else if text_bytes == fib.ccp_text {
    Some(decode_cp1252(word_document, fib.fc_min, fib.ccp_text))
  } else {
    None
  }
}

///|
/// A paragraph recovered from the PlcfBtePapx table.
priv struct DocParagraph {
  istd : Int
  ilfo : Int
  in_table : Bool
  row_end : Bool
  text : String
}

///|
/// Parse PlcfBtePapx -> FKP -> Papx to recover paragraph properties
/// (style id for headings, table/list membership) and the paragraph text.
fn parse_paragraph_table(
  word_document : Bytes,
  table : Bytes?,
  fc_plcf : Int,
  lcb_plcf : Int,
  pieces : Array[DocPiece]?,
) -> Array[DocParagraph] {
  let result : Array[DocParagraph] = []
  match table {
    None => result
    Some(tbl) => {
      if lcb_plcf < 12 || fc_plcf < 0 || fc_plcf + lcb_plcf > tbl.length() {
        return result
      }
      let plcf = tbl[fc_plcf:fc_plcf + lcb_plcf].to_owned()
      let count = (lcb_plcf - 4) / 8
      if count <= 0 {
        return result
      }
      for i in 0..<count {
        let pn = doc_u32le(plcf, (count + 1) * 4 + i * 4)
        let fkp_offset = pn * 512
        if fkp_offset + 512 > word_document.length() {
          continue
        }
        let fkp = word_document[fkp_offset:fkp_offset + 512].to_owned()
        let cpara = fkp[511].to_int()
        if cpara <= 0 {
          continue
        }
        let rgbx_off = (cpara + 1) * 4
        for j in 0..<cpara {
          let start_fc = doc_u32le(fkp, j * 4)
          let end_fc = doc_u32le(fkp, (j + 1) * 4)
          let b_off = fkp[rgbx_off + j * 13].to_int()
          let mut istd = 0
          let mut ilfo = 0
          let mut in_table = false
          let mut row_end = false
          if b_off != 0 {
            let po = b_off * 2
            if po + 1 < 512 {
              let cb = fkp[po].to_int()
              let istd_pos = if cb != 0 { po + 1 } else { po + 2 }
              if istd_pos + 2 <= 512 {
                istd = doc_u16le(fkp, istd_pos) & 0x0FFF
              }
              let grp_len = if cb != 0 {
                cb * 2 - 2
              } else {
                if po + 1 < 512 {
                  fkp[po + 1].to_int() * 2 - 2
                } else {
                  0
                }
              }
              let grp_start = if cb != 0 { po + 3 } else { po + 4 }
              if grp_len > 0 && grp_start + grp_len <= 512 {
                let sprm = parse_sprms(fkp, grp_start, grp_len)
                ilfo = sprm.ilfo
                in_table = sprm.in_table
                row_end = sprm.row_end
              }
            }
          }
          let raw_text = match pieces {
            Some(piece_list) =>
              extract_fc_range(word_document, piece_list, start_fc, end_fc)
            None => ""
          }
          result.push(
            DocParagraph::{
              istd,
              ilfo,
              in_table,
              row_end,
              text: clean_doc_text(raw_text),
            },
          )
        }
      }
      result
    }
  }
}

///|
priv struct DocSprms {
  ilfo : Int
  in_table : Bool
  row_end : Bool
}

///|
/// Walk a grpprl, decoding sprm opcodes per [MS-DOC] operand sizes:
/// spra {0,1} -> 1 byte, {2,4,5} -> 2 bytes, {3} -> 4 bytes,
/// {7} -> 3 bytes, {6} -> variable (length byte includes itself).
fn parse_sprms(fkp : Bytes, start : Int, length : Int) -> DocSprms {
  let mut ilfo = 0
  let mut in_table = false
  let mut row_end = false
  let mut j = start
  while j + 2 <= start + length {
    let op = doc_u16le(fkp, j)
    let spra = (op >> 13) & 7
    let op_len = match spra {
      0 | 1 => 1
      2 | 4 | 5 => 2
      3 => 4
      7 => 3
      6 => {
        if j + 3 <= start + length {
          fkp[j + 2].to_int() + 1
        } else {
          0
        }
      }
      _ => 0
    }
    if op_len <= 0 || j + 2 + op_len > start + length {
      break
    }
    if op == 0x460B && op_len >= 2 {
      ilfo = doc_u16le(fkp, j + 2)
    } else if op == 0x2416 && op_len >= 1 {
      // sprmPFInTable: operand 1 -> paragraph inside a table cell.
      if fkp[j + 2].to_int() != 0 {
        in_table = true
      }
    } else if op == 0x2417 && op_len >= 1 {
      // sprmPTtp: operand 1 -> row-terminator paragraph.
      if fkp[j + 2].to_int() != 0 {
        row_end = true
        in_table = true
      }
    }
    j = j + 2 + op_len
  }
  DocSprms::{ ilfo, in_table, row_end }
}

///|
/// Assemble AST blocks: Heading 1-9 from istd, List items for ilfo,
/// pipe tables from in_table paragraphs (row ends from row_end), and
/// plain paragraphs otherwise. Falls back to splitting main text on
/// newlines when the paragraph table is missing. Table rendering mirrors
/// the wps2md reference: cells accumulate until a row_end paragraph
/// commits the row; the first row becomes the table header.
fn build_doc_blocks(
  main_text : String,
  paragraphs : Array[DocParagraph],
) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  if paragraphs.length() == 0 {
    for line in main_text.split("\n") {
      let cleaned = clean_doc_text(line.to_owned())
      if cleaned.length() > 0 {
        blocks.push(@ast.text_paragraph(cleaned))
      }
    }
    return blocks
  }
  let mut list_items : Array[Array[@ast.Inline]] = []
  let mut table_rows : Array[Array[Array[@ast.Inline]]] = []
  let mut current_row : Array[Array[@ast.Inline]] = []
  for para in paragraphs {
    if para.in_table {
      if para.row_end {
        if current_row.length() > 0 {
          table_rows.push(current_row)
          current_row = []
        }
      } else {
        if para.text.length() > 0 {
          current_row.push(@ast.text_inlines(para.text))
        }
      }
      continue
    }
    if current_row.length() > 0 {
      table_rows.push(current_row)
      current_row = []
    }
    if table_rows.length() > 0 {
      flush_doc_table(blocks, table_rows)
      table_rows = []
    }
    if para.ilfo > 0 {
      if para.text.length() > 0 {
        list_items.push(@ast.text_inlines(para.text))
      }
      continue
    }
    if list_items.length() > 0 {
      blocks.push(@ast.List(list_items, false))
      list_items = []
    }
    if para.text.length() == 0 {
      continue
    }
    if para.istd >= 1 && para.istd <= 9 {
      blocks.push(@ast.text_heading(para.istd, para.text))
    } else {
      blocks.push(@ast.text_paragraph(para.text))
    }
  }
  if current_row.length() > 0 {
    table_rows.push(current_row)
  }
  if table_rows.length() > 0 {
    flush_doc_table(blocks, table_rows)
  }
  if list_items.length() > 0 {
    blocks.push(@ast.List(list_items, false))
  }
  blocks
}

///|
/// Push a table block: first row becomes the header, the rest become rows.
fn flush_doc_table(
  blocks : Array[@ast.Block],
  rows : Array[Array[Array[@ast.Inline]]],
) -> Unit {
  if rows.length() == 0 {
    return
  }
  let headers = rows[0]
  let body : Array[Array[Array[@ast.Inline]]] = []
  for i in 1..<rows.length() {
    body.push(rows[i])
  }
  blocks.push(@ast.Table(headers, body))
}

///|
/// Normalize control characters inside extracted text:
/// 0x07 cell/row mark -> tab, 0x0B soft break -> newline,
/// 0x0C page break -> double newline, 0x0D paragraph mark -> newline,
/// field codes (0x13/0x14/0x15), NUL and 0x7F removed, other C0 stripped.
fn clean_doc_text(input : String) -> String {
  let sb = StringBuilder::new()
  for ch in input {
    let code = ch.to_int()
    if code == 0x07 {
      sb.write_string("\t")
    } else if code == 0x0B {
      sb.write_string("\n")
    } else if code == 0x0C {
      sb.write_string("\n\n")
    } else if code == 0x0D {
      sb.write_string("\n")
    } else if code == 0x13 || code == 0x15 || code == 0x00 || code == 0x7F {
      ()
    } else if code == 0x14 {
      sb.write_string(" ")
    } else if code < 0x20 || code == 0x7F {
      ()
    } else {
      sb.write_char(ch)
    }
  }
  sb.to_string().trim().to_owned()
}

///|
fn doc_warning_diagnostics(
  _file_path : String,
  warnings : Array[String],
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for warning in warnings {
    diagnostics.push(
      @core.warning_diagnostic(
        warning,
        Some(@core.Parse(Some("WordDocument"))),
        Some(@core.ArchiveEntry("WordDocument")),
        None,
      ),
    )
  }
  diagnostics
}

///|
fn render_doc_failure(
  error : @core.ConversionError,
  phase : @core.ConversionPhase?,
  source : @core.DiagnosticSource?,
  hint : @core.DiagnosticHint?,
) -> String {
  @core.error_diagnostic(error, phase, source, hint).render()
}

///|
fn doc_u16le(b : Bytes, o : Int) -> Int {
  if o + 2 > b.length() {
    return 0
  }
  b[o].to_int() | (b[o + 1].to_int() << 8)
}

///|
fn doc_u32le(b : Bytes, o : Int) -> Int {
  if o + 4 > b.length() {
    return 0
  }
  b[o].to_int() |
  (b[o + 1].to_int() << 8) |
  (b[o + 2].to_int() << 16) |
  (b[o + 3].to_int() << 24)
}

///|
fn doc_u32le_uint(b : Bytes, o : Int) -> UInt {
  if o + 4 > b.length() {
    return 0
  }
  b[o].to_uint() |
  (b[o + 1].to_uint() << 8) |
  (b[o + 2].to_uint() << 16) |
  (b[o + 3].to_uint() << 24)
}

///|
fn doc_min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
