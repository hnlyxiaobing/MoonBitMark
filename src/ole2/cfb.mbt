// OLE2 / Compound File Binary ([MS-CFB]) container parser.
// Pure MoonBit reader for the legacy Microsoft Office binary container
// (.doc / .xls / .ppt / .wps family). Supports v3 (512-byte sectors) and
// v4 (4096-byte sectors) layouts, DIFAT chains, FAT/MiniFAT stream chains,
// the 128-byte directory entries and the mini stream.

///|
// FAT special sector values ([MS-CFB] 2.3.1).
let cfb_freesect : UInt = 0xFFFFFFFF

///|
let cfb_endofchain : UInt = 0xFFFFFFFE

///|
// Header signature: D0 CF 11 E0 A1 B1 1A E1.
let cfb_magic : Bytes = b"\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1"

///|
// Header byte order marker (little endian).
let cfb_byte_order_le : Int = 0xFFFE

///|
/// One 128-byte directory entry of the CFB directory chain.
pub(all) struct CfbDirectoryEntry {
  name : String
  /// 1 = storage, 2 = stream, 5 = root entry, 0 = unallocated
  entry_type : Int
  start_sector : UInt
  stream_size : UInt
}

///|
/// An opened OLE2 compound file.
pub(all) struct CfbArchive {
  data : Bytes
  sector_size : Int
  mini_sector_size : Int
  mini_cutoff : UInt
  fat : Array[UInt]
  minifat : Array[UInt]
  entries : Array[CfbDirectoryEntry]
  ministream : Bytes
}

///|
fn cfb_u16le(b : Bytes, o : Int) -> Int {
  b[o].to_int() | (b[o + 1].to_int() << 8)
}

///|
fn cfb_u32le(b : Bytes, o : Int) -> UInt {
  b[o].to_uint() |
  (b[o + 1].to_uint() << 8) |
  (b[o + 2].to_uint() << 16) |
  (b[o + 3].to_uint() << 24)
}

///|
fn cfb_has_prefix(bytes : Bytes, prefix : Bytes) -> Bool {
  if bytes.length() < prefix.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if bytes[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
/// Quick check for the OLE2 header signature.
pub fn cfb_is_ole2_signature(bytes : Bytes) -> Bool {
  cfb_has_prefix(bytes, cfb_magic)
}

///|
/// Open a CFB archive, returning a human-readable failure reason.
pub fn CfbArchive::open_explained(buffer : Bytes) -> Result[CfbArchive, String] {
  if buffer.length() < 512 {
    return Err(
      "truncated OLE2 container: \{buffer.length()} bytes is smaller than a 512-byte CFB header",
    )
  }
  if !cfb_has_prefix(buffer, cfb_magic) {
    return Err("not an OLE2 container: bad header signature")
  }
  if cfb_u16le(buffer, 0x1C) != cfb_byte_order_le {
    return Err(
      "unsupported OLE2 container: byte order marker is not little endian",
    )
  }
  let sshift = cfb_u16le(buffer, 0x1E)
  let mshift = cfb_u16le(buffer, 0x20)
  if sshift != 9 && sshift != 12 {
    return Err(
      "unsupported OLE2 container: sector shift \{sshift} (expected 9 or 12)",
    )
  }
  if mshift != 6 {
    return Err(
      "unsupported OLE2 container: mini sector shift \{mshift} (expected 6)",
    )
  }
  let sector_size = 1 << sshift
  let mini_sector_size = 1 << mshift
  let max_sectors = (buffer.length() - 512 + sector_size - 1) / sector_size
  let first_dir = cfb_u32le(buffer, 0x30)
  let mini_cutoff = cfb_u32le(buffer, 0x38)
  let first_minifat = cfb_u32le(buffer, 0x3C)
  let first_difat = cfb_u32le(buffer, 0x44)
  // Build the DIFAT: 109 slots in the header, then optional chain sectors.
  let difat : Array[UInt] = []
  for i in 0..<109 {
    let v = cfb_u32le(buffer, 0x4C + i * 4)
    if v == cfb_freesect {
      break
    }
    difat.push(v)
  }
  let mut difat_sec = first_difat
  let mut difat_chain_steps = 0
  while difat_sec != cfb_endofchain && difat_sec != cfb_freesect {
    let off = 512 + difat_sec.reinterpret_as_int() * sector_size
    if off + sector_size > buffer.length() {
      return Err(
        "corrupt OLE2 container: DIFAT chain references a sector past end of file",
      )
    }
    if difat_sec.reinterpret_as_int() >= max_sectors {
      return Err(
        "corrupt OLE2 container: DIFAT chain sector number out of range",
      )
    }
    difat_chain_steps = difat_chain_steps + 1
    if difat_chain_steps > max_sectors {
      return Err("corrupt OLE2 container: DIFAT chain contains a loop")
    }
    let per_sector = sector_size / 4 - 1
    for i in 0..<per_sector {
      let v = cfb_u32le(buffer, off + i * 4)
      if v == cfb_freesect {
        break
      }
      difat.push(v)
    }
    difat_sec = cfb_u32le(buffer, off + per_sector * 4)
  }
  // Assemble the FAT from the DIFAT-listed sectors.
  let fat : Array[UInt] = []
  for sec in difat {
    let idx = sec.reinterpret_as_int()
    if idx < 0 || idx >= max_sectors {
      return Err(
        "corrupt OLE2 container: DIFAT entry sector number out of range",
      )
    }
    let off = 512 + idx * sector_size
    if off + sector_size > buffer.length() {
      return Err("corrupt OLE2 container: FAT sector extends past end of file")
    }
    for i in 0..<(sector_size / 4) {
      fat.push(cfb_u32le(buffer, off + i * 4))
    }
  }
  if fat.length() == 0 {
    return Err("corrupt OLE2 container: no FAT sectors")
  }
  let archive = CfbArchive::{
    data: buffer,
    sector_size,
    mini_sector_size,
    mini_cutoff,
    fat,
    minifat: [],
    entries: [],
    ministream: b"",
  }
  // Directory chain.
  let dir_bytes = match archive.read_fat_chain(first_dir, -1) {
    Some(bytes) => bytes
    None =>
      return Err("corrupt OLE2 container: directory sector chain is broken")
  }
  if dir_bytes.length() < 128 {
    return Err("corrupt OLE2 container: directory chain is too short")
  }
  let entries : Array[CfbDirectoryEntry] = []
  for i in 0..<(dir_bytes.length() / 128) {
    let entry = parse_cfb_directory_entry(dir_bytes, i * 128)
    if entry.entry_type != 0 {
      entries.push(entry)
    }
  }
  if entries.length() == 0 || entries[0].entry_type != 5 {
    return Err("corrupt OLE2 container: missing root directory entry")
  }
  let archive = CfbArchive::{ ..archive, entries, }
  // MiniFAT chain.
  let minifat : Array[UInt] = []
  if first_minifat != cfb_endofchain && first_minifat != cfb_freesect {
    let minifat_bytes = match archive.read_fat_chain(first_minifat, -1) {
      Some(bytes) => bytes
      None =>
        return Err("corrupt OLE2 container: MiniFAT sector chain is broken")
    }
    for i in 0..<(minifat_bytes.length() / 4) {
      minifat.push(cfb_u32le(minifat_bytes, i * 4))
    }
  }
  let archive = CfbArchive::{ ..archive, minifat, }
  // Mini stream lives at the root entry's FAT chain.
  let root = entries[0]
  let ministream = if root.stream_size > 0 &&
    root.start_sector != cfb_endofchain {
    match
      archive.read_fat_chain(
        root.start_sector,
        root.stream_size.reinterpret_as_int(),
      ) {
      Some(bytes) => bytes
      None => b""
    }
  } else {
    b""
  }
  let archive = CfbArchive::{ ..archive, ministream, }
  Ok(archive)
}

///|
/// Open a CFB archive, mirroring the `ZipArchive::open` convention.
pub fn CfbArchive::open(buffer : Bytes) -> CfbArchive? {
  match CfbArchive::open_explained(buffer) {
    Ok(archive) => Some(archive)
    Err(_) => None
  }
}

///|
fn parse_cfb_directory_entry(bytes : Bytes, off : Int) -> CfbDirectoryEntry {
  let name_len = cfb_u16le(bytes, off + 0x40)
  let mut char_count = name_len / 2
  if char_count > 0 {
    char_count = char_count - 1 // trailing null is included in the length
  }
  if char_count > 31 {
    char_count = 31
  }
  CfbDirectoryEntry::{
    name: cfb_decode_utf16le(bytes, off, char_count),
    entry_type: bytes[off + 0x42].to_int(),
    start_sector: cfb_u32le(bytes, off + 0x74),
    stream_size: cfb_u32le(bytes, off + 0x78),
  }
}

///|
fn cfb_decode_utf16le(bytes : Bytes, offset : Int, char_count : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < char_count {
    let u = cfb_u16le(bytes, offset + i * 2)
    if u == 0 {
      break
    }
    if u >= 0xD800 && u <= 0xDBFF && i + 1 < char_count {
      let lo = cfb_u16le(bytes, offset + (i + 1) * 2)
      if lo >= 0xDC00 && lo <= 0xDFFF {
        let cp = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)
        sb.write_char(cp.unsafe_to_char())
        i = i + 2
        continue
      }
    }
    // Keep control characters: special streams such as
    // "\x05SummaryInformation" legitimately start with U+0005.
    if !(u >= 0xD800 && u <= 0xDFFF) {
      sb.write_char(u.unsafe_to_char())
    }
    i = i + 1
  }
  sb.to_string()
}

///|
/// Follow a sector chain through `table`, stopping at ENDOFCHAIN.
/// Returns None on out-of-range sectors or loops.
fn cfb_chain_sectors(start : UInt, table : Array[UInt]) -> Array[UInt]? {
  let out : Array[UInt] = []
  let mut cur = start
  let limit = table.length() + 1
  while cur != cfb_endofchain && cur != cfb_freesect {
    let idx = cur.reinterpret_as_int()
    if idx < 0 || idx >= table.length() {
      return None
    }
    // A valid chain never revisits a sector; longer than the table = loop.
    if out.length() >= limit {
      return None
    }
    out.push(cur)
    cur = table[idx]
  }
  Some(out)
}

///|
/// Read `size` bytes following a FAT chain; `size < 0` means "whole chain".
fn CfbArchive::read_fat_chain(
  self : CfbArchive,
  start : UInt,
  size : Int,
) -> Bytes? {
  if start == cfb_endofchain || start == cfb_freesect {
    if size <= 0 {
      return Some(b"")
    }
    return None
  }
  let sectors = match cfb_chain_sectors(start, self.fat) {
    Some(sectors) => sectors
    None => return None
  }
  let buf = Buffer()
  let mut remaining = size
  for sec in sectors {
    if size >= 0 && remaining <= 0 {
      break
    }
    let off = 512 + sec.reinterpret_as_int() * self.sector_size
    if off >= self.data.length() {
      return None
    }
    let end = cfb_imin(off + self.sector_size, self.data.length())
    if size < 0 {
      buf.write_bytes(self.data[off:end])
    } else {
      let take = cfb_imin(remaining, end - off)
      buf.write_bytes(self.data[off:off + take])
      remaining = remaining - take
    }
  }
  Some(buf.to_bytes())
}

///|
/// Read `size` bytes following a MiniFAT chain through the mini stream.
fn CfbArchive::read_mini_chain(
  self : CfbArchive,
  start : UInt,
  size : Int,
) -> Bytes? {
  if size <= 0 {
    return Some(b"")
  }
  if self.ministream.length() == 0 && self.minifat.length() == 0 {
    return None
  }
  let sectors = match cfb_chain_sectors(start, self.minifat) {
    Some(sectors) => sectors
    None => return None
  }
  let buf = Buffer()
  let mut remaining = size
  for ms in sectors {
    if remaining <= 0 {
      break
    }
    let off = ms.reinterpret_as_int() * self.mini_sector_size
    if off >= self.ministream.length() {
      return None
    }
    let end = cfb_imin(off + self.mini_sector_size, self.ministream.length())
    let take = cfb_imin(remaining, end - off)
    buf.write_bytes(self.ministream[off:off + take])
    remaining = remaining - take
  }
  Some(buf.to_bytes())
}

///|
fn cfb_imin(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn CfbArchive::find_entry(
  self : CfbArchive,
  name : String,
) -> CfbDirectoryEntry? {
  for entry in self.entries {
    if entry.entry_type == 2 && entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
/// Whether a stream with the given name exists.
pub fn CfbArchive::has_stream(self : CfbArchive, name : String) -> Bool {
  match self.find_entry(name) {
    Some(_) => true
    None => false
  }
}

///|
/// Names of all stream entries in the container.
pub fn CfbArchive::stream_names(self : CfbArchive) -> Array[String] {
  let names : Array[String] = []
  for entry in self.entries {
    if entry.entry_type == 2 {
      names.push(entry.name)
    }
  }
  names
}

///|
/// Read the full contents of a stream.
/// Small streams (below the header mini cutoff) are served from the mini
/// stream through the MiniFAT; larger ones follow the FAT chain.
pub fn CfbArchive::read_stream(self : CfbArchive, name : String) -> Bytes? {
  let entry = match self.find_entry(name) {
    Some(entry) => entry
    None => return None
  }
  let size = entry.stream_size.reinterpret_as_int()
  if size <= 0 {
    return Some(b"")
  }
  if size < self.mini_cutoff.reinterpret_as_int() {
    self.read_mini_chain(entry.start_sector, size)
  } else {
    self.read_fat_chain(entry.start_sector, size)
  }
}
