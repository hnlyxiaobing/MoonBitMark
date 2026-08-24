// Word Binary Converter - decoding & metadata helpers (appended part)

///|
/// Decode `chars` UTF-16LE code units at byte offset `off` (surrogate aware).
fn decode_utf16le(bytes : Bytes, off : Int, chars : Int) -> String {
  let sb = StringBuilder()
  let mut i = 0
  while i < chars {
    let u = doc_u16le(bytes, off + i * 2)
    if u >= 0xD800 && u <= 0xDBFF && i + 1 < chars {
      let lo = doc_u16le(bytes, off + (i + 1) * 2)
      if lo >= 0xDC00 && lo <= 0xDFFF {
        let cp = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)
        sb.write_char(cp.unsafe_to_char())
        i = i + 2
        continue
      }
    }
    if !(u >= 0xD800 && u <= 0xDFFF) {
      sb.write_char(u.unsafe_to_char())
    }
    i = i + 1
  }
  sb.to_string()
}

///|
/// Decode `chars` bytes as cp1252 (ASCII + Windows-1252 high region).
fn decode_cp1252(bytes : Bytes, off : Int, chars : Int) -> String {
  let sb = StringBuilder()
  for i in 0..<chars {
    let byte = bytes[off + i].to_int()
    if byte < 0x80 {
      sb.write_char(byte.unsafe_to_char())
    } else if byte >= 0xA0 {
      // Latin-1 region maps 1:1 to U+00A0..U+00FF.
      sb.write_char(byte.unsafe_to_char())
    } else {
      match cp1252_high(byte) {
        Some(cp) => sb.write_char(cp.unsafe_to_char())
        None => ()
      }
    }
  }
  sb.to_string()
}

///|
/// Windows-1252 code points for the 0x80..0x9F control region.
fn cp1252_high(byte : Int) -> Int? {
  match byte {
    0x80 => Some(0x20AC) // EURO SIGN
    0x82 => Some(0x201A) // SINGLE LOW-9 QUOTATION MARK
    0x83 => Some(0x0192) // LATIN SMALL LETTER F WITH HOOK
    0x84 => Some(0x201E) // DOUBLE LOW-9 QUOTATION MARK
    0x85 => Some(0x2026) // HORIZONTAL ELLIPSIS
    0x86 => Some(0x2020) // DAGGER
    0x87 => Some(0x2021) // DOUBLE DAGGER
    0x88 => Some(0x02C6) // MODIFIER LETTER CIRCUMFLEX ACCENT
    0x89 => Some(0x2030) // PER MILLE SIGN
    0x8A => Some(0x0160) // LATIN CAPITAL LETTER S WITH CARON
    0x8B => Some(0x2039) // SINGLE LEFT-POINTING ANGLE QUOTATION MARK
    0x8C => Some(0x0152) // LATIN CAPITAL LIGATURE OE
    0x8E => Some(0x017D) // LATIN CAPITAL LETTER Z WITH CARON
    0x91 => Some(0x2018) // LEFT SINGLE QUOTATION MARK
    0x92 => Some(0x2019) // RIGHT SINGLE QUOTATION MARK
    0x93 => Some(0x201C) // LEFT DOUBLE QUOTATION MARK
    0x94 => Some(0x201D) // RIGHT DOUBLE QUOTATION MARK
    0x95 => Some(0x2022) // BULLET
    0x96 => Some(0x2013) // EN DASH
    0x97 => Some(0x2014) // EM DASH
    0x98 => Some(0x02DC) // SMALL TILDE
    0x99 => Some(0x2122) // TRADE MARK SIGN
    0x9A => Some(0x0161) // LATIN SMALL LETTER S WITH CARON
    0x9B => Some(0x203A) // SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
    0x9C => Some(0x0153) // LATIN SMALL LIGATURE OE
    0x9E => Some(0x017E) // LATIN SMALL LETTER Z WITH CARON
    0x9F => Some(0x0178) // LATIN CAPITAL LETTER Y WITH DIAERESIS
    _ => None
  }
}

///|
/// Minimal SummaryInformation property set parsing: title, author,
/// created date and page count. Unknown/broken properties are skipped.
/// Layout follows MS-OLEPS PropertySetStream: header (28 bytes) + FMTID
/// (16 bytes) + u32 section offset; the section holds size, property
/// count and a PID/offset directory.
fn parse_summary_information(archive : @ole2.CfbArchive) -> Map[String, String] {
  let metadata = Map([])
  let stream_name = "\u{05}SummaryInformation"
  match archive.read_stream(stream_name) {
    None => metadata
    Some(props) => {
      if props.length() < 48 {
        return metadata
      }
      let sec_off = doc_u32le(props, 44)
      if sec_off + 8 > props.length() {
        return metadata
      }
      let num_props = doc_u32le(props, sec_off + 4)
      let mut i = 0
      while i < num_props {
        let dir_off = sec_off + 8 + i * 8
        if dir_off + 8 > props.length() {
          break
        }
        let prop_id = doc_u32le(props, dir_off)
        // Property offsets in the directory are relative to the section start.
        let val_off = doc_u32le(props, dir_off + 4) + sec_off
        if val_off + 8 > props.length() {
          i = i + 1
          continue
        }
        let vt = doc_u16le(props, val_off)
        if prop_id == 2 && vt == 30 {
          match read_prop_lpstr(props, val_off) {
            Some(value) => metadata["title"] = value
            None => ()
          }
        } else if prop_id == 4 && vt == 30 {
          match read_prop_lpstr(props, val_off) {
            Some(value) => metadata["author"] = value
            None => ()
          }
        } else if prop_id == 2 && vt == 31 {
          match read_prop_lpwstr(props, val_off) {
            Some(value) => metadata["title"] = value
            None => ()
          }
        } else if prop_id == 4 && vt == 31 {
          match read_prop_lpwstr(props, val_off) {
            Some(value) => metadata["author"] = value
            None => ()
          }
        } else if prop_id == 12 && vt == 64 {
          metadata["created"] = read_prop_filetime(props, val_off)
        } else if prop_id == 14 && vt == 3 {
          metadata["page_count"] = read_prop_i4(props, val_off)
        }
        i = i + 1
      }
      metadata
    }
  }
}

///|
/// VT_LPSTR: u32 byte count (including the trailing null) followed by
/// ANSI text. The trailing null is dropped from the decoded value.
fn read_prop_lpstr(props : Bytes, val_off : Int) -> String? {
  let cch = doc_u32le(props, val_off + 4)
  let text_off = val_off + 8
  if cch <= 1 || text_off + cch > props.length() {
    return None
  }
  let value = decode_cp1252(props, text_off, cch - 1)
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    None
  } else {
    Some(trimmed)
  }
}

///|
/// VT_LPWSTR: u32 character count (including the trailing null) followed
/// by UTF-16LE text. The trailing null is dropped from the decoded value.
fn read_prop_lpwstr(props : Bytes, val_off : Int) -> String? {
  let cch = doc_u32le(props, val_off + 4)
  let text_off = val_off + 8
  if cch <= 1 || text_off + cch * 2 > props.length() {
    return None
  }
  let value = decode_utf16le(props, text_off, cch - 1)
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    None
  } else {
    Some(trimmed)
  }
}

///|
/// VT_FILETIME: 64-bit 100ns ticks since 1601-01-01, rendered as YYYY-MM-DD.
fn read_prop_filetime(props : Bytes, val_off : Int) -> String {
  let ft = doc_u64le(props, val_off + 4)
  if ft == 0UL {
    return ""
  }
  let days_1601 = ft / 864000000000UL
  let days = days_1601.to_int() - 134774 // 1601 -> 1970 epoch
  let (year, month, day) = civil_from_days(days)
  year.to_string() + "-" + pad2(month) + "-" + pad2(day)
}

///|
fn pad2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
/// Convert a days-since-1970 count to a (year, month, day) civil date
/// (Howard Hinnant's `civil_from_days` algorithm).
fn civil_from_days(z : Int) -> (Int, Int, Int) {
  let zz = z + 719468
  let era = if zz >= 0 { zz / 146097 } else { (zz - 146096) / 146097 }
  let doe = zz - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let year = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let day = doy - (153 * mp + 2) / 5 + 1
  let month = if mp < 10 { mp + 3 } else { mp - 9 }
  (if month <= 2 { year + 1 } else { year }, month, day)
}

///|
/// VT_I4: signed 32-bit integer.
fn read_prop_i4(props : Bytes, val_off : Int) -> String {
  let raw = doc_u32le_uint(props, val_off + 4)
  raw.reinterpret_as_int().to_string()
}

///|
fn doc_u64le(b : Bytes, o : Int) -> UInt64 {
  if o + 8 > b.length() {
    return 0UL
  }
  b[o].to_uint64() |
  (b[o + 1].to_uint64() << 8) |
  (b[o + 2].to_uint64() << 16) |
  (b[o + 3].to_uint64() << 24) |
  (b[o + 4].to_uint64() << 32) |
  (b[o + 5].to_uint64() << 40) |
  (b[o + 6].to_uint64() << 48) |
  (b[o + 7].to_uint64() << 56)
}
