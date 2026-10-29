// White-box regression tests for the Word binary (.doc) FKP page parser.
//
// The cases below cover the bounds hardening in `parse_paragraph_table`:
// a crafted FKP page number must not overflow the `pn * 512` computation, and
// a crafted paragraph count must not push the RGBX index past the end of the
// 512 byte page.

///|
fn doc_security_bytes(b64 : String) -> Bytes {
  @base64.decode(b64, ignore_whitespace=true) catch {
    _ => Bytes::new(0)
  }
}

///|
/// A 512 byte FKP page (all zero bytes).
fn doc_security_fkp_page_b64() -> String {
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAA="
}

///|
/// A 512 byte FKP page whose last byte claims 200 paragraphs.
fn doc_security_fkp_page_200_paragraphs_b64() -> String {
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAMg="
}

///|
/// A PLCF with a single FKP page number of 0xFFFFFFFF.
fn doc_security_plcf_page_minus_one_b64() -> String {
  "AAAAAAAAAAD/////"
}

///|
test "doc paragraph table ignores an fkp page number that overflows" {
  let paragraphs = parse_paragraph_table(
    doc_security_bytes(doc_security_fkp_page_b64()),
    Some(doc_security_bytes(doc_security_plcf_page_minus_one_b64())),
    0,
    12,
    None,
  )
  assert_eq(paragraphs.length(), 0)
}

///|
test "doc paragraph table ignores an fkp page count beyond the page size" {
  let paragraphs = parse_paragraph_table(
    doc_security_bytes(doc_security_fkp_page_200_paragraphs_b64()),
    Some(doc_security_bytes("AAAAAAAAAAAAAAAA")),
    0,
    12,
    None,
  )
  assert_eq(paragraphs.length(), 0)
}

///|
test "doc little endian readers return zero for out of range offsets" {
  let data = doc_security_bytes("AAAAAAAAAAAAAAAA")
  assert_eq(doc_u16le(data, -1), 0)
  assert_eq(doc_u16le(data, 16), 0)
  assert_eq(doc_u32le(data, -1), 0)
  assert_eq(doc_u32le(data, 16), 0)
  assert_eq(doc_u32le_uint(data, -1), 0)
  assert_eq(doc_u32le_uint(data, 16), 0)
}
