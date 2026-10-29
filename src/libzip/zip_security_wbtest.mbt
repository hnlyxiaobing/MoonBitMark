// White-box regression tests for the ZIP container parser.
//
// The cases below cover the bounds hardening in `zip.mbt` and the output cap
// in `deflate.mbt`: a malformed archive must be rejected instead of reading
// out of bounds, and an entry whose declared uncompressed size exceeds the
// limit must be refused instead of being expanded.

///|
fn zip_put_u16(buf : Buffer, value : Int32) -> Unit {
  buf.write_byte((value & 0xFF).to_byte())
  buf.write_byte(((value >> 8) & 0xFF).to_byte())
}

///|
fn zip_put_u32(buf : Buffer, value : Int32) -> Unit {
  zip_put_u16(buf, value & 0xFFFF)
  zip_put_u16(buf, (value >> 16) & 0xFFFF)
}

///|
/// Build a minimal single-entry (stored) ZIP archive whose central directory
/// declares `declared` as the uncompressed size of the entry.
fn zip_with_declared_size(declared : Int32) -> Bytes {
  let buf = Buffer()
  // Local file header: 30 bytes fixed part + 1 byte file name.
  zip_put_u32(buf, 0x04034b50)
  zip_put_u16(buf, 20) // version needed
  zip_put_u16(buf, 0) // flags
  zip_put_u16(buf, 0) // method: store
  zip_put_u16(buf, 0) // mod time
  zip_put_u16(buf, 0) // mod date
  zip_put_u32(buf, 0) // crc32
  zip_put_u32(buf, 0) // compressed size
  zip_put_u32(buf, declared) // uncompressed size
  zip_put_u16(buf, 1) // file name length
  zip_put_u16(buf, 0) // extra field length
  buf.write_byte(b'a')
  // Central directory header: 46 bytes fixed part + 1 byte file name.
  zip_put_u32(buf, 0x02014b50)
  zip_put_u16(buf, 20) // version made by
  zip_put_u16(buf, 20) // version needed
  zip_put_u16(buf, 0) // flags
  zip_put_u16(buf, 0) // method: store
  zip_put_u16(buf, 0) // mod time
  zip_put_u16(buf, 0) // mod date
  zip_put_u32(buf, 0) // crc32
  zip_put_u32(buf, 0) // compressed size
  zip_put_u32(buf, declared) // uncompressed size
  zip_put_u16(buf, 1) // file name length
  zip_put_u16(buf, 0) // extra field length
  zip_put_u16(buf, 0) // comment length
  zip_put_u16(buf, 0) // disk number start
  zip_put_u16(buf, 0) // internal attributes
  zip_put_u32(buf, 0) // external attributes
  zip_put_u32(buf, 0) // relative offset of local header
  buf.write_byte(b'a')
  // End of central directory: 22 bytes.
  zip_put_u32(buf, 0x06054b50)
  zip_put_u16(buf, 0) // disk number
  zip_put_u16(buf, 0) // disk with central directory
  zip_put_u16(buf, 1) // entries on this disk
  zip_put_u16(buf, 1) // total entries
  zip_put_u32(buf, 47) // central directory size
  zip_put_u32(buf, 31) // central directory offset
  zip_put_u16(buf, 0) // comment length
  buf.to_bytes()
}

///|
/// Build the same archive but with a central directory offset that points
/// outside of the buffer.
fn zip_with_bad_central_directory_offset(offset : Int32) -> Bytes {
  let buf = Buffer()
  zip_put_u32(buf, 0x06054b50)
  zip_put_u16(buf, 0) // disk number
  zip_put_u16(buf, 0) // disk with central directory
  zip_put_u16(buf, 1) // entries on this disk
  zip_put_u16(buf, 1) // total entries
  zip_put_u32(buf, 47) // central directory size
  zip_put_u32(buf, offset) // central directory offset
  zip_put_u16(buf, 0) // comment length
  buf.to_bytes()
}

///|
test "zip entry whose declared size exceeds the limit is refused" {
  let archive = match ZipArchive::open(zip_with_declared_size(268435457)) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  assert_eq(ZipArchive::list_entries(archive).length(), 1)
  assert_eq(read_file_entry_decompressed(archive, "a"), None)
}

///|
test "zip entry at the size limit is still accepted" {
  let archive = match ZipArchive::open(zip_with_declared_size(268435456)) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  assert_eq(ZipArchive::list_entries(archive).length(), 1)
  match read_file_entry_decompressed(archive, "a") {
    Some(bytes) => assert_eq(bytes.length(), 0)
    None => fail("entry at the limit must not be refused")
  }
}

///|
test "zip archive with a central directory offset outside the buffer yields no entries" {
  let archive = match
    ZipArchive::open(zip_with_bad_central_directory_offset(0x7FFFFFFF)) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  assert_eq(ZipArchive::list_entries(archive).length(), 0)
  assert_eq(read_file_entry(archive, "a"), None)
  assert_eq(read_file_entry_decompressed(archive, "a"), None)
}

///|
test "zip archive with a negative central directory offset yields no entries" {
  let archive = match
    ZipArchive::open(zip_with_bad_central_directory_offset(0xFFFFFFFF)) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  assert_eq(ZipArchive::list_entries(archive).length(), 0)
  assert_eq(read_file_entry(archive, "a"), None)
}

///|
test "deflate rejects a truncated stream instead of returning partial data" {
  let compressed : Bytes = b"\xf3\x48\xcd\xc9\xc9\x57\x08\xcf\x2f\xca\x49\x01"
  assert_eq(deflate_decompress(compressed), None)
}

///|
/// A single file entry to write into a synthetic archive.
///
/// `payload` is the raw byte sequence placed after the local file header
/// (already compressed when `method` is 8), `declared` is the uncompressed
/// size recorded in both headers and `crc` the CRC32 recorded in both.
struct ZipPayload {
  name : String
  payload : Bytes
  compression : Int32
  declared : Int32
  crc : Int32
}

///|
/// Build a ZIP archive out of `items`: local headers + payloads, then the
/// central directory, then the EOCD trailer. Sizes and offsets are all
/// computed from the real payload lengths, so the only thing a caller can lie
/// about is `declared` / `crc` -- which is exactly what the tests below need.
fn zip_build(items : Array[ZipPayload]) -> Bytes {
  let buf = Buffer()
  let offsets : Array[Int32] = Array(capacity=0)
  for item in items {
    offsets.push(buf.length())
    let name = @utf8.encode(item.name)
    zip_put_u32(buf, 0x04034b50) // local file header signature
    zip_put_u16(buf, 20) // version needed
    zip_put_u16(buf, 0) // flags
    zip_put_u16(buf, item.compression) // compression method
    zip_put_u16(buf, 0) // mod time
    zip_put_u16(buf, 0) // mod date
    zip_put_u32(buf, item.crc) // crc32
    zip_put_u32(buf, item.payload.length()) // compressed size
    zip_put_u32(buf, item.declared) // uncompressed size
    zip_put_u16(buf, name.length()) // file name length
    zip_put_u16(buf, 0) // extra field length
    for i = 0; i < name.length(); i = i + 1 {
      buf.write_byte(name[i])
    }
    for i = 0; i < item.payload.length(); i = i + 1 {
      buf.write_byte(item.payload[i])
    }
  }
  let cd_offset = buf.length()
  let mut index = 0
  for item in items {
    let name = @utf8.encode(item.name)
    zip_put_u32(buf, 0x02014b50) // central directory header signature
    zip_put_u16(buf, 20) // version made by
    zip_put_u16(buf, 20) // version needed
    zip_put_u16(buf, 0) // flags
    zip_put_u16(buf, item.compression) // compression method
    zip_put_u16(buf, 0) // mod time
    zip_put_u16(buf, 0) // mod date
    zip_put_u32(buf, item.crc) // crc32
    zip_put_u32(buf, item.payload.length()) // compressed size
    zip_put_u32(buf, item.declared) // uncompressed size
    zip_put_u16(buf, name.length()) // file name length
    zip_put_u16(buf, 0) // extra field length
    zip_put_u16(buf, 0) // comment length
    zip_put_u16(buf, 0) // disk number start
    zip_put_u16(buf, 0) // internal attributes
    zip_put_u32(buf, 0) // external attributes
    zip_put_u32(buf, offsets[index]) // relative offset of local header
    for i = 0; i < name.length(); i = i + 1 {
      buf.write_byte(name[i])
    }
    index = index + 1
  }
  let cd_size = buf.length() - cd_offset
  zip_put_u32(buf, 0x06054b50) // end of central directory signature
  zip_put_u16(buf, 0) // disk number
  zip_put_u16(buf, 0) // disk with central directory
  zip_put_u16(buf, items.length()) // entries on this disk
  zip_put_u16(buf, items.length()) // total entries
  zip_put_u32(buf, cd_size) // central directory size
  zip_put_u32(buf, cd_offset) // central directory offset
  zip_put_u16(buf, 0) // comment length
  buf.to_bytes()
}

///|
/// `len` zero bytes.
fn zip_zero_bytes(len : Int32) -> Bytes {
  let buf = Buffer()
  for i = 0; i < len; i = i + 1 {
    buf.write_byte(b'\x00')
  }
  buf.to_bytes()
}

///|
/// Raw DEFLATE stream that expands to 65536 zero bytes: 78 bytes on the wire,
/// a 840:1 ratio. Still well inside the RFC 1951 worst case (~1032:1), so it
/// is a realistic shape for a bomb rather than a synthetic edge case.
fn zip_deflate_bomb() -> Bytes {
  b"\xed\xc1\x01\x01\x00\x00\x00\x80\x90\xfe\xaf\xee\x08\x0a\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x6a"
}

///|
/// Read an entry and describe the failure as text. Every `ZipError` variant is
/// mapped so a test can assert on the exact diagnostic instead of on a bool.
fn zip_read_error_text(
  archive : ZipArchive,
  name : String,
  max_bytes : Int32,
  archive_limit : Int32,
) -> String {
  try {
    ignore(
      read_file_entry_decompressed_limited(archive, name, max_bytes, archive_limit),
    )
    "entry was accepted"
  } catch {
    InvalidSignature => "invalid signature"
    CorruptedHeader => "corrupted header"
    FileNotFound(missing) => "file not found: " + missing
    UnsupportedMethod(code) => "unsupported method: " + code.to_string()
    DecompressFailed(text) => text
    CrcMismatch => "crc mismatch"
  }
}

///|
/// Read an entry that is expected to succeed, aborting the test otherwise.
fn zip_read_expected(
  archive : ZipArchive,
  name : String,
  max_bytes : Int32,
  archive_limit : Int32,
) -> Bytes raise {
  read_file_entry_decompressed_limited(archive, name, max_bytes, archive_limit) catch {
    _ => fail("entry within the limits must not be refused")
  }
}

///|
/// A high-ratio entry whose declared uncompressed size (1024 bytes) is a lie:
/// it really expands to 65536 bytes. 1024 == the limit, so the declared-size
/// pre-check passes and only the streaming cap inside the inflater can stop
/// it. The call must return a diagnosable size-limit error -- not abort the
/// process, and not be reported as corrupt data.
test "zip entry that understates its uncompressed size is stopped by the inflate cap" {
  let archive = match
    ZipArchive::open(zip_build([
      ZipPayload::{
        name: "a",
        payload: zip_deflate_bomb(),
        compression: 8,
        declared: 1024,
        crc: 0,
      },
    ])) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  assert_eq(
    zip_read_error_text(archive, "a", 1024, 536870912),
    "decompression size limit exceeded: limit=1024 bytes",
  )
  // `read_file_entry_decompressed` keeps the production cap, so it accepts
  // the same 64 KiB expansion; that is why the case is driven through the
  // private entry point with a 1 KiB budget instead of the public one.
  assert_eq(read_file_entry_decompressed(archive, "a").unwrap().length(), 65536)
}

///|
/// A high-ratio entry that reports its real size and a correct CRC must still
/// be accepted: the cap exists to stop bombs, not legitimate compressible
/// content (spreadsheet XML, zero padding in synced documents, media stills).
test "zip high ratio entry that reports its real size is accepted" {
  let expected = zip_zero_bytes(65536)
  let archive = match
    ZipArchive::open(zip_build([
      ZipPayload::{
        name: "a",
        payload: zip_deflate_bomb(),
        compression: 8,
        declared: 65536,
        crc: crc32(expected).reinterpret_as_int(),
      },
    ])) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  let inflated = zip_read_expected(archive, "a", 268435456, 536870912)
  assert_eq(inflated.length(), 65536)
  assert_true(inflated == expected)
}

///|
/// One byte of the payload no longer matches the checksum recorded in the
/// central directory. The read path must report the entry as corrupt rather
/// than returning the tampered bytes.
test "zip entry whose payload does not match the recorded crc is reported as corrupt" {
  // CRC32("hello") == 0x3610a686. Recording it next to "hallo" gives the same
  // length and a valid central directory, but the checksum no longer holds.
  let archive = match
    ZipArchive::open(zip_build([
      ZipPayload::{
        name: "a",
        payload: b"hallo",
        compression: 0,
        declared: 5,
        crc: 0x3610a686,
      },
    ])) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  assert_eq(zip_read_error_text(archive, "a", 268435456, 536870912), "crc mismatch")
  assert_eq(read_file_entry_decompressed(archive, "a"), None)
}

///|
/// The debuggable API must surface the same mismatch as a `ZipError`, so call
/// sites can tell it apart from a missing entry.
test "zip entry with a valid crc is returned byte for byte" {
  // cb 48 cd c9 c9 07 00 is raw DEFLATE for b"hello".
  let archive = match
    ZipArchive::open(zip_build([
      ZipPayload::{
        name: "a",
        payload: b"\xcb\x48\xcd\xc9\xc9\x07\x00",
        compression: 8,
        declared: 5,
        crc: 0x3610a686,
      },
    ])) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  let inflated = read_file_entry_decompressed_checked(archive, "a") catch {
    _ => fail("an entry with a matching crc must not be refused")
  }
  assert_eq(inflated.length(), 5)
  assert_eq(inflated, b"hello")
}

///|
/// Two entries that are each fine on their own but together exceed the
/// per-archive budget. The charge is keyed by entry name, so re-reading an
/// entry that was already paid for stays within the budget.
test "zip archive refuses further entries once the cumulative budget is spent" {
  let archive = match
    ZipArchive::open(zip_build([
      ZipPayload::{ name: "a", payload: b"hello", compression: 0, declared: 5, crc: 0x3610a686 },
      ZipPayload::{ name: "b", payload: b"hello", compression: 0, declared: 5, crc: 0x3610a686 },
    ])) {
    Some(value) => value
    None => fail("failed to open synthetic archive")
  }
  // 5 bytes fit in an 8 byte budget, the second 5 bytes do not.
  let first = zip_read_expected(archive, "a", 268435456, 8)
  assert_eq(first.length(), 5)
  assert_eq(
    zip_read_error_text(archive, "b", 268435456, 8),
    "decompression size limit exceeded: archive limit=8 bytes",
  )
  // Re-reading `a` does not consume the budget a second time.
  let again = zip_read_expected(archive, "a", 268435456, 8)
  assert_eq(again, b"hello")
}
