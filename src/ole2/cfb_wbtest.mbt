// White-box tests for the [MS-CFB] container parser.
// Fixtures are built in-memory with a minimal CFB writer so the tests stay
// hermetic (no binary blobs on disk). Bytes is immutable in this core
// version, so the writer assembles Array[Byte] buffers and converts at the
// end.

///|
struct TestStream {
  name : String
  data : Bytes
}

///|
fn arr_set16(arr : Array[Byte], off : Int, v : Int) -> Unit {
  arr.set(off, (v & 0xFF).to_byte())
  arr.set(off + 1, ((v >> 8) & 0xFF).to_byte())
}

///|
fn arr_set32(arr : Array[Byte], off : Int, v : UInt) -> Unit {
  arr.set(off, (v & 0xFF).to_byte())
  arr.set(off + 1, ((v >> 8) & 0xFF).to_byte())
  arr.set(off + 2, ((v >> 16) & 0xFF).to_byte())
  arr.set(off + 3, ((v >> 24) & 0xFF).to_byte())
}

///|
fn arr_of_bytes(data : Bytes) -> Array[Byte] {
  let out : Array[Byte] = Array(capacity=0)
  for b in data {
    out.push(b)
  }
  out
}

///|
fn arr_write_bytes(buf : Array[Byte], data : Bytes) -> Unit {
  for b in data {
    buf.push(b)
  }
}

///|
fn bytes_of_arr(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(arr[:])
}

///|
fn pad_to_sectors(data : Bytes, sector_size : Int) -> Bytes {
  let rem = data.length() % sector_size
  if rem == 0 {
    data
  } else {
    let out = arr_of_bytes(data)
    for _ in 0..<(sector_size - rem) {
      out.push(b'\x00')
    }
    bytes_of_arr(out)
  }
}

///|
fn make_directory_entry(
  name_utf16 : Array[Byte],
  entry_type : Int,
  start : UInt,
  size : UInt,
) -> Array[Byte] {
  let entry : Array[Byte] = Array::make(128, b'\x00')
  for i in 0..<name_utf16.length() {
    entry.set(i, name_utf16[i])
  }
  arr_set16(entry, 0x40, name_utf16.length() + 2)
  entry.set(0x42, entry_type.to_byte())
  entry.set(0x43, 1) // color: black
  arr_set32(entry, 0x44, 0xFFFFFFFF) // left sibling
  arr_set32(entry, 0x48, 0xFFFFFFFF) // right sibling
  arr_set32(entry, 0x4C, 0xFFFFFFFF) // child
  arr_set32(entry, 0x74, start)
  arr_set32(entry, 0x78, size)
  entry
}

///|
fn utf16le_of(name : String) -> Array[Byte] {
  let out : Array[Byte] = Array(capacity=0)
  for ch in name {
    let v = ch.to_int()
    out.push((v & 0xFF).to_byte())
    out.push(((v >> 8) & 0xFF).to_byte())
  }
  out
}

///|
/// Build a minimal but well-formed v3 (512-byte sector) CFB file.
/// Layout: sector 0 = FAT, sector 1 = directory, then big-stream sectors,
/// then the mini stream, then the MiniFAT.
fn build_test_cfb(streams : Array[TestStream]) -> Bytes {
  let cutoff = 4096
  let sector_size = 512
  let big : Array[TestStream] = Array(capacity=0)
  let small : Array[TestStream] = Array(capacity=0)
  for stream in streams {
    if stream.data.length() >= cutoff {
      big.push(stream)
    } else {
      small.push(stream)
    }
  }
  // Assign big-stream sectors.
  let big_start : Array[Int] = Array(capacity=0)
  let big_padded_len : Array[Int] = Array(capacity=0)
  let mut next_sector = 2
  for stream in big {
    let padded = pad_to_sectors(stream.data, sector_size)
    big_start.push(next_sector)
    big_padded_len.push(padded.length())
    next_sector = next_sector + padded.length() / sector_size
  }
  // Pack small streams into the mini stream (64-byte units).
  let mini_unit = 64
  let ministream : Array[Byte] = Array(capacity=0)
  let minifat : Array[UInt] = Array(capacity=0)
  let small_start : Array[UInt] = Array(capacity=0)
  for stream in small {
    let start_unit : UInt = minifat.length().reinterpret_as_uint()
    let units = (stream.data.length() + mini_unit - 1) / mini_unit
    for b in stream.data {
      ministream.push(b)
    }
    for _ in 0..<(units * mini_unit - stream.data.length()) {
      ministream.push(b'\x00')
    }
    for u in 0..<units {
      let next : UInt = if u == units - 1 {
        0xFFFFFFFE
      } else {
        start_unit + (u + 1).reinterpret_as_uint()
      }
      minifat.push(next)
    }
    small_start.push(start_unit)
  }
  let ministream_bytes = bytes_of_arr(ministream)
  let ministream_padded = pad_to_sectors(ministream_bytes, sector_size)
  let ministream_start = next_sector
  let ministream_sectors = ministream_padded.length() / sector_size
  next_sector = next_sector + ministream_sectors
  // MiniFAT sectors.
  let minifat_padded_len = (minifat.length() * 4 + sector_size - 1) /
    sector_size *
    sector_size
  let minifat_bytes : Array[Byte] = Array::make(minifat_padded_len, b'\x00')
  for i in 0..<minifat.length() {
    arr_set32(minifat_bytes, i * 4, minifat[i])
  }
  let minifat_start = next_sector
  let minifat_sectors = minifat_padded_len / sector_size
  next_sector = next_sector + minifat_sectors
  // Directory sector.
  let dir_start = 1
  let dir : Array[Byte] = Array::make(sector_size, b'\x00')
  let root = make_directory_entry(
    utf16le_of("Root Entry"),
    5,
    ministream_start.reinterpret_as_uint(),
    ministream_bytes.length().reinterpret_as_uint(),
  )
  for i in 0..<128 {
    dir.set(i, root[i])
  }
  let mut slot = 1
  for i in 0..<big.length() {
    let de = make_directory_entry(
      utf16le_of(big[i].name),
      2,
      big_start[i].reinterpret_as_uint(),
      big[i].data.length().reinterpret_as_uint(),
    )
    for j in 0..<128 {
      dir.set(slot * 128 + j, de[j])
    }
    slot = slot + 1
  }
  for i in 0..<small.length() {
    let de = make_directory_entry(
      utf16le_of(small[i].name),
      2,
      small_start[i],
      small[i].data.length().reinterpret_as_uint(),
    )
    for j in 0..<128 {
      dir.set(slot * 128 + j, de[j])
    }
    slot = slot + 1
  }
  dir.set(511, (slot - 1).to_byte())
  // FAT sector.
  let total_sectors = next_sector
  let fat : Array[Byte] = Array::make(sector_size, b'\xFF')
  arr_set32(fat, 0, 0xFFFFFFFD) // sector 0 is the FAT itself
  arr_set32(fat, 1, 0xFFFFFFFE) // directory chain end
  for i in 0..<big.length() {
    let start = big_start[i]
    let sectors = big_padded_len[i] / sector_size
    for s in 0..<sectors {
      let next : UInt = if s == sectors - 1 {
        0xFFFFFFFE
      } else {
        (start + s + 1).reinterpret_as_uint()
      }
      arr_set32(fat, (start + s) * 4, next)
    }
  }
  for s in 0..<ministream_sectors {
    let next : UInt = if s == ministream_sectors - 1 {
      0xFFFFFFFE
    } else {
      (ministream_start + s + 1).reinterpret_as_uint()
    }
    arr_set32(fat, (ministream_start + s) * 4, next)
  }
  for s in 0..<minifat_sectors {
    let next : UInt = if s == minifat_sectors - 1 {
      0xFFFFFFFE
    } else {
      (minifat_start + s + 1).reinterpret_as_uint()
    }
    arr_set32(fat, (minifat_start + s) * 4, next)
  }
  // Assemble the file: header + sectors in order.
  let header : Array[Byte] = Array::make(512, b'\x00')
  let magic = b"\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1"
  for i in 0..<8 {
    header.set(i, magic[i])
  }
  arr_set16(header, 0x18, 0x003E)
  arr_set16(header, 0x1A, 0x0003)
  arr_set16(header, 0x1C, 0xFFFE)
  arr_set16(header, 0x1E, 9)
  arr_set16(header, 0x20, 6)
  arr_set16(header, 0x28, 0) // num dir sectors (v3: 0)
  arr_set16(header, 0x2C, 1) // num FAT sectors
  arr_set32(header, 0x30, dir_start.reinterpret_as_uint())
  arr_set32(header, 0x38, cutoff.reinterpret_as_uint())
  let mf_start_field : UInt = if minifat_sectors == 0 {
    0xFFFFFFFE
  } else {
    minifat_start.reinterpret_as_uint()
  }
  arr_set32(header, 0x3C, mf_start_field)
  arr_set32(header, 0x40, minifat_sectors.reinterpret_as_uint())
  arr_set32(header, 0x44, 0xFFFFFFFE) // no DIFAT chain
  arr_set32(header, 0x48, 0) // no DIFAT chain sectors
  arr_set32(header, 0x4C, 0) // DIFAT[0] = FAT sector 0
  for i in 1..<109 {
    arr_set32(header, 0x4C + i * 4, 0xFFFFFFFF)
  }
  let out : Array[Byte] = Array(capacity=0)
  for b in bytes_of_arr(header) {
    out.push(b)
  }
  for b in bytes_of_arr(fat) {
    out.push(b)
  }
  for b in bytes_of_arr(dir) {
    out.push(b)
  }
  for stream in big {
    arr_write_bytes(out, pad_to_sectors(stream.data, sector_size))
  }
  arr_write_bytes(out, ministream_padded)
  arr_write_bytes(out, bytes_of_arr(minifat_bytes))
  // Every claimed sector must be present in the file.
  let written = 512 + total_sectors * sector_size
  while out.length() < written {
    out.push(b'\x00')
  }
  bytes_of_arr(out)
}

///|
fn bytes_of_ascii(text : String) -> Bytes {
  @utf8.encode(text)
}

///|
test "cfb big stream roundtrip" {
  let payload_arr : Array[Byte] = Array(capacity=0)
  for i in 0..<8192 {
    payload_arr.push((i % 251).to_byte())
  }
  let payload = bytes_of_arr(payload_arr)
  let cfb = build_test_cfb([
    TestStream::{ name: "WordDocument", data: payload, },
  ])
  let archive = CfbArchive::open(cfb)
  let opened = match archive {
    Some(_) => true
    None => false
  }
  inspect(opened, content="true")
  let a = archive.unwrap()
  inspect(a.has_stream("WordDocument"), content="true")
  debug_inspect(
    a.stream_names(),
    content=(
      #|["WordDocument"]
    ),
  )
  let data = a.read_stream("WordDocument").unwrap()
  inspect(data.length(), content="8192")
  inspect(data == payload, content="true")
}

///|
test "cfb mini stream roundtrip" {
  let payload = bytes_of_ascii("hello mini stream")
  let cfb = build_test_cfb([TestStream::{ name: "Small", data: payload, }])
  let a = CfbArchive::open(cfb).unwrap()
  inspect(a.has_stream("Small"), content="true")
  let data = a.read_stream("Small").unwrap()
  inspect(data == payload, content="true")
}

///|
test "cfb mixed big and mini streams" {
  let big = Bytes::make(4096, b'B')
  let small1 = bytes_of_ascii("tiny")
  let small2 = Bytes::make(200, b's')
  let cfb = build_test_cfb([
    TestStream::{ name: "Big", data: big, },
    TestStream::{ name: "Small1", data: small1, },
    TestStream::{ name: "Small2", data: small2, },
  ])
  let a = CfbArchive::open(cfb).unwrap()
  inspect(a.stream_names().length(), content="3")
  inspect(a.read_stream("Big").unwrap() == big, content="true")
  inspect(a.read_stream("Small1").unwrap() == small1, content="true")
  inspect(a.read_stream("Small2").unwrap() == small2, content="true")
}

///|
test "cfb stream at mini cutoff boundary is big" {
  // Exactly 4096 bytes: size == cutoff is NOT below it -> FAT chain.
  let payload = Bytes::make(4096, b'C')
  let cfb = build_test_cfb([TestStream::{ name: "Edge", data: payload, }])
  let a = CfbArchive::open(cfb).unwrap()
  inspect(a.read_stream("Edge").unwrap() == payload, content="true")
}

///|
test "cfb multi-unit mini stream chain" {
  // 300 bytes spans 5 mini sectors; verify chain traversal.
  let payload = Bytes::make(300, b'm')
  let cfb = build_test_cfb([TestStream::{ name: "Small", data: payload, }])
  let a = CfbArchive::open(cfb).unwrap()
  let data = a.read_stream("Small").unwrap()
  inspect(data.length(), content="300")
  inspect(data == payload, content="true")
}

///|
test "cfb utf16 stream name roundtrip" {
  let payload = bytes_of_ascii("data")
  let cfb = build_test_cfb([TestStream::{ name: "数据流", data: payload, }])
  let a = CfbArchive::open(cfb).unwrap()
  debug_inspect(
    a.stream_names(),
    content=(
      #|["数据流"]
    ),
  )
  inspect(a.read_stream("数据流").unwrap() == payload, content="true")
}

///|
test "cfb bad magic is rejected" {
  let cfb = build_test_cfb([
    TestStream::{ name: "A", data: bytes_of_ascii("x"), },
  ])
  let corrupt_arr = arr_of_bytes(cfb)
  corrupt_arr.set(3, b'\x42')
  let corrupt = bytes_of_arr(corrupt_arr)
  let msg = match CfbArchive::open_explained(corrupt) {
    Err(msg) => msg
    Ok(_) => "unexpected success"
  }
  inspect(msg, content="not an OLE2 container: bad header signature")
  let opened = match CfbArchive::open(corrupt) {
    Some(_) => true
    None => false
  }
  inspect(opened, content="false")
}

///|
test "cfb truncated file is rejected" {
  let cfb = build_test_cfb([
    TestStream::{ name: "A", data: bytes_of_ascii("x"), },
  ])
  let truncated = cfb[0:300].to_owned()
  let msg = match CfbArchive::open_explained(truncated) {
    Err(msg) => msg
    Ok(_) => "unexpected success"
  }
  inspect(
    msg,
    content="truncated OLE2 container: 300 bytes is smaller than a 512-byte CFB header",
  )
}

///|
test "cfb fat loop is detected" {
  let cfb = build_test_cfb([
    TestStream::{ name: "A", data: bytes_of_ascii("x"), },
  ])
  let looped_arr = arr_of_bytes(cfb)
  // Directory is sector 1; point FAT[1] at itself to form a loop.
  // FAT sector 0 starts at file offset 512; entry 1 is at 512 + 4.
  arr_set32(looped_arr, 512 + 4, 1)
  let looped = bytes_of_arr(looped_arr)
  let msg = match CfbArchive::open_explained(looped) {
    Err(msg) => msg
    Ok(_) => "unexpected success"
  }
  inspect(
    msg,
    content="corrupt OLE2 container: directory sector chain is broken",
  )
}

///|
test "cfb missing stream returns none" {
  let cfb = build_test_cfb([
    TestStream::{ name: "A", data: bytes_of_ascii("x"), },
  ])
  let a = CfbArchive::open(cfb).unwrap()
  let missing = match a.read_stream("Nope") {
    Some(_) => false
    None => true
  }
  inspect(missing, content="true")
  inspect(a.has_stream("Nope"), content="false")
}

///|
test "cfb empty stream reads as empty bytes" {
  let cfb = build_test_cfb([TestStream::{ name: "Empty", data: b"", }])
  let a = CfbArchive::open(cfb).unwrap()
  let data = a.read_stream("Empty").unwrap()
  inspect(data.length(), content="0")
}

///|
test "cfb ole2 signature helper" {
  let cfb = build_test_cfb([
    TestStream::{ name: "A", data: bytes_of_ascii("x"), },
  ])
  inspect(cfb_is_ole2_signature(cfb), content="true")
  inspect(cfb_is_ole2_signature(b"PK\x03\x04xxxx"), content="false")
}
