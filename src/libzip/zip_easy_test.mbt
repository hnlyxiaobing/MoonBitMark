// libzip 基础测试

///|
test "spec - open returns option type" {
  // 测试 open 函数返回 Option 类型
  let result : ZipArchive? = ZipArchive::open(b"")
  ignore(result)
}

///|
test "bit reader - read_bits LSB first" {
  // 测试 LSB first 读取
  // 字节 0xF3 = 11110011
  // LSB first 读取 3 位应该是: 011 = 3
  // LSB first 再读取 3 位应该是: 110 = 6 (注意：这是从原来的位 3 开始读)
  let data : Bytes = b"\xf3"
  let reader = BitReader::new(data)

  let r1 = reader.read_bits(3)
  match r1 {
    Ok(v) => {
      // 从位 0,1,2 读取: bits 0,1,2 = 1,1,1 -> LSB first = 111 = 7
      // Wait, let me recalculate:
      // 0xF3 = 11110011
      // bit 0 = 1, bit 1 = 1, bit 2 = 0
      // LSB first reading 3 bits: result = bit0 | (bit1<<1) | (bit2<<2) = 1|2|0 = 3
      assert_eq(v, 3)
    }
    Err(e) => fail("read_bits failed: \{e}")
  }

  // 继续读取 3 位
  let r2 = reader.read_bits(3)
  match r2 {
    Ok(v) => {
      // 现在从位 3,4,5 读取
      // bit 3 = 0, bit 4 = 1, bit 5 = 1
      // LSB first: 0 | (1<<1) | (1<<2) = 6
      assert_eq(v, 6)
    }
    Err(e) => fail("read_bits failed: \{e}")
  }
}

///|
test "bit reader - read_bits_reverse MSB first" {
  // 测试 MSB first 读取 (用于 Huffman 码)
  // 字节 0xF3 = 11110011
  // MSB first 读取 3 位应该是: 111 = 7
  let data : Bytes = b"\xf3"
  let reader = BitReader::new(data)

  let r1 = reader.read_bits_reverse(3)
  match r1 {
    Ok(v) => {
      // 从位 0,1,2 读取，但解释为 MSB first
      // bit 0 = 1, bit 1 = 1, bit 2 = 0
      // MSB first: (bit0<<2) | (bit1<<1) | bit2 = 4|2|0 = 6
      assert_eq(v, 6)
    }
    Err(e) => fail("read_bits_reverse failed: \{e}")
  }
}

///|
test "deflate - fixed huffman decode first symbol" {
  // 测试 "Hello World" 的第一个符号解码
  // 压缩数据: f348cdc9c95708cf2fca490100
  // 第一个字节 0xF3 = 11110011
  // BFINAL = bit 0 = 1
  // BTYPE = bits 1-2 = 01 = 1 (fixed huffman)
  // 第一个 Huffman 码从 bit 3 开始

  let compressed : Bytes = b"\xf3\x48\xcd\xc9\xc9\x57\x08\xcf\x2f\xca\x49\x01\x00"
  let reader = BitReader::new(compressed)

  // 读取 BFINAL 和 BTYPE
  let bfinal = reader.read_bits(1)
  let btype = reader.read_bits(2)

  match bfinal {
    Ok(v) => assert_eq(v, 1)
    Err(e) => fail("bfinal failed: \{e}")
  }

  match btype {
    Ok(v) => assert_eq(v, 1)
    Err(e) => fail("btype failed: \{e}")
  }

  // 现在读取第一个 Huffman 码的前 7 位 (MSB first)
  let first7 = reader.read_bits_reverse(7)
  match first7 {
    Ok(v) => {
      // 'H' = 72, 在 fixed huffman 中码字是 72+48=120=01111000 (8位)
      // 前 7 位是 0111100 = 60
      assert_eq(v, 60)
    }
    Err(e) => fail("first7 failed: \{e}")
  }
}

///|
test "deflate decompress simple" {
  // Test a simple deflate-compressed string
  // This is "Hello World" compressed with deflate (no zlib wrapper)
  let compressed : Bytes = b"\xf3\x48\xcd\xc9\xc9\x57\x08\xcf\x2f\xca\x49\x01\x00"
  let result = deflate_decompress(compressed)
  match result {
    Some(decompressed) => {
      let len = decompressed.length()
      let mut text = ""
      let mut i = 0
      while i < len {
        let b = decompressed[i].to_int()
        text = text + Char::from_int(b).to_string()
        i = i + 1
      }
      assert_eq(text, "Hello World")
    }
    None => fail("Deflate decompression failed")
  }
}

///|
test "deflate decompress dynamic huffman" {
  // 测试动态 Huffman 编码的解压
  // 这是一段使用动态 Huffman 压缩的文本
  let original = "The quick brown fox jumps over the lazy dog. \nThis is a longer text that should compress with dynamic Huffman coding.\nThe compression algorithm will analyze the frequency of each character\nand build custom Huffman trees for both literals and distances.\n"
  let compressed : Bytes = b"\x3d\x8f\xcd\x15\xc2\x30\x0c\x83\xef\x9d\x42\x13\x74\x0e\x06\x60\x01\x37\x71\x1a\x43\x62\x43\x7e\x80\x32\x3d\x86\x03\xef\xf9\x26\x7d\x96\x74\xce\x8c\xfb\x94\x70\xc5\xd6\xec\xa9\x48\xf6\xc2\x65\xd6\x5b\x91\x35\x1f\x3e\x48\xde\xae\x0a\x0e\x25\x48\x2d\xe8\x63\x0a\x0f\x31\xcd\x36\x5e\x09\x0c\x3d\xab\x0d\x59\x8c\x94\x64\xc4\xf9\x3d\x9e\x13\x1b\x5c\x43\x3c\x3b\x4d\x25\x5c\xf5\xf3\x23\x21\x09\xa9\x63\x57\xb9\xd2\x3b\x95\x1b\x94\x1d\x67\x56\x25\xa4\xd1\xd3\x53\x17\x9e\x42\xcc\xf5\x4f\x68\x8d\x8c\x3c\x8e\x99\x94\x94\x9c\x05\x4f\xc3\x20\x29\x8f\x94\xea\x58\x98\xde\xc7\x57\xd3\x3a\xfa\xed\x8c\xcd\xf9\xf4\x1b\xf9\xad\x59\x75\x6f\xd7\xef\x9e\xb5\xf6\x97\xab\xfe\x05\xde\xb7\xb5\x7e"
  let result = deflate_decompress(compressed)
  match result {
    Some(decompressed) => {
      let len = decompressed.length()
      let mut text = ""
      let mut i = 0
      while i < len {
        let b = decompressed[i].to_int()
        text = text + Char::from_int(b).to_string()
        i = i + 1
      }
      assert_eq(text, original)
    }
    None => fail("Deflate decompression failed")
  }
}

///|
/// 位读取器 (公开用于测试)
pub struct BitReader {
  mut byte_pos : Int
  mut bit_pos : Int
  data : Bytes
}

///|
pub fn BitReader::new(data : Bytes) -> BitReader {
  BitReader::{ byte_pos: 0, bit_pos: 0, data }
}

///|
pub fn BitReader::read_bits(self : BitReader, count : Int) -> Result[Int, String] {
  let mut result = 0
  let mut bits_read = 0

  while bits_read < count {
    if self.byte_pos >= self.data.length() {
      return Err("Unexpected end of input")
    }

    let available = 8 - self.bit_pos
    let needed = count - bits_read
    let to_read = if available < needed { available } else { needed }

    let byte = self.data[self.byte_pos].to_int()
    let mask = (1 << to_read) - 1
    let bits = (byte >> self.bit_pos) & mask

    result = result | (bits << bits_read)
    bits_read = bits_read + to_read
    self.bit_pos = self.bit_pos + to_read

    if self.bit_pos >= 8 {
      self.bit_pos = 0
      self.byte_pos = self.byte_pos + 1
    }
  }

  Ok(result)
}

///|
pub fn BitReader::read_bits_reverse(self : BitReader, count : Int) -> Result[Int, String] {
  let mut result = 0
  let mut bits_read = 0

  while bits_read < count {
    if self.byte_pos >= self.data.length() {
      return Err("Unexpected end of input")
    }

    let byte = self.data[self.byte_pos].to_int()
    let bit = (byte >> self.bit_pos) & 1

    // MSB first: 每次左移结果，新位作为 LSB
    result = (result << 1) | bit
    bits_read = bits_read + 1
    self.bit_pos = self.bit_pos + 1

    if self.bit_pos >= 8 {
      self.bit_pos = 0
      self.byte_pos = self.byte_pos + 1
    }
  }

  Ok(result)
}
