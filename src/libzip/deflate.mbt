// Deflate 解压模块
// 实现 RFC 1951 DEFLATE 解压缩算法

///|
/// Deflate 解压主函数（支持 RFC 1951 多块流）
pub fn deflate_decompress(input : Bytes) -> Bytes? {
  let reader = BitReader::new(input)
  let state = InflateState::new()

  // RFC 1951: DEFLATE 数据流由一个或多个块组成，每块有 bfinal 标志
  let mut is_final = false
  while !is_final {
    // 读取 bfinal (1 bit): 1 = 最后一块
    let bfinal_result = reader.read_bits(1)
    let bfinal = match bfinal_result {
      Ok(v) => v == 1
      Err(_) => return None
    }
    is_final = bfinal

    // 读取块类型 (2 bits)
    let btype_result = reader.read_bits(2)
    let btype = match btype_result {
      Ok(v) => v
      Err(_) => return None
    }

    // 解压当前块到 output（各函数返回 Bool 表示成功/失败）
    let ok = match btype {
      0 => decompress_stored_block(reader, state)
      1 => decompress_fixed_huffman_block(reader, state)
      2 => decompress_dynamic_huffman_block(reader, state)
      _ => return None
    }
    if !ok {
      return None
    }
  }

  Some(bytes_from_array(state.output))
}

///|
priv struct InflateState {
  output : Array[Byte]
  window : Array[Byte]
  mut window_pos : Int
  mut produced : Int
}

///|
fn InflateState::new() -> InflateState {
  let output : Array[Byte] = Array::new()
  let window : Array[Byte] = Array::new()
  for _ in 0..<32768 {
    window.push(b'\x00')
  }
  InflateState::{ output, window, window_pos: 0, produced: 0 }
}

///|
fn InflateState::write_byte(self : InflateState, byte : Byte) -> Unit {
  self.output.push(byte)
  self.window[self.window_pos] = byte
  self.window_pos = (self.window_pos + 1) & 0x7FFF
  self.produced = self.produced + 1
}

///|
fn InflateState::copy_from_distance(
  self : InflateState,
  distance : Int,
  length : Int,
) -> Bool {
  if distance <= 0 || distance > 32768 {
    return false
  }
  if distance > self.produced {
    return false
  }

  let copy_start = self.window_pos - distance
  for i in 0..<length {
    let src_pos = (copy_start + i) & 0x7FFF
    self.write_byte(self.window[src_pos])
  }
  true
}

///|
/// 位读取器
priv struct BitReader {
  mut byte_pos : Int
  mut bit_pos : Int
  data : Bytes
}

///|
fn BitReader::new(data : Bytes) -> BitReader {
  BitReader::{ byte_pos: 0, bit_pos: 0, data }
}

///|
/// 读取指定位数 (LSB 优先)
fn BitReader::read_bits(self : BitReader, count : Int) -> Result[Int, String] {
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
/// 对齐到字节边界
fn BitReader::align_to_byte(self : BitReader) -> Unit {
  if self.bit_pos > 0 {
    self.bit_pos = 0
    self.byte_pos = self.byte_pos + 1
  }
}

///|
/// 读取字节
fn BitReader::read_byte(self : BitReader) -> Result[Byte, String] {
  if self.byte_pos >= self.data.length() {
    return Err("Unexpected end of input")
  }
  let b = self.data[self.byte_pos]
  self.byte_pos = self.byte_pos + 1
  Ok(b)
}

///|
/// 读取 UInt16 (小端序)
fn BitReader::read_uint16_le(self : BitReader) -> Result[Int, String] {
  let lo_result = self.read_byte()
  let lo = match lo_result {
    Ok(b) => b
    Err(e) => return Err(e)
  }
  let hi_result = self.read_byte()
  let hi = match hi_result {
    Ok(b) => b
    Err(e) => return Err(e)
  }
  Ok(lo.to_int() | (hi.to_int() << 8))
}

///|
/// 解压存储块 (无压缩) — 写入 output，返回是否成功
fn decompress_stored_block(reader : BitReader, state : InflateState) -> Bool {
  // 对齐到字节边界
  reader.align_to_byte()

  // 读取 LEN 和 NLEN
  let len_result = reader.read_uint16_le()
  let len = match len_result {
    Ok(v) => v
    Err(_) => return false
  }
  let nlen_result = reader.read_uint16_le()
  let nlen = match nlen_result {
    Ok(v) => v
    Err(_) => return false
  }

  // 验证 NLEN 是 LEN 的补码
  if (len ^ nlen) != 0xFFFF {
    return false
  }

  // 读取原始数据
  for _ in 0..<len {
    let byte_result = reader.read_byte()
    match byte_result {
      Ok(b) => state.write_byte(b)
      Err(_) => return false
    }
  }

  true
}

///|
/// 将 Array[Byte] 转换为 Bytes
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}

///|
/// 解压固定 Huffman 编码块 — 写入 output，返回是否成功
fn decompress_fixed_huffman_block(
  reader : BitReader,
  state : InflateState,
) -> Bool {
  let mut done = false

  while !done {
    // 解码下一个符号
    let symbol_result = decode_fixed_symbol(reader)
    let symbol = match symbol_result {
      Ok(s) => s
      Err(_) => return false
    }

    if symbol < 256 {
      // 字面量字节
      state.write_byte(int_to_byte(symbol))
    } else if symbol == 256 {
      // 块结束
      done = true
    } else {
      // 长度-距离对
      let length_result = decode_length(reader, symbol)
      let length = match length_result {
        Ok(l) => l
        Err(_) => return false
      }

      let dist_code_result = reader.read_bits_reverse(5)
      let dist_code = match dist_code_result {
        Ok(d) => d
        Err(_) => return false
      }

      let distance_result = decode_distance(reader, dist_code)
      let distance = match distance_result {
        Ok(d) => d
        Err(_) => return false
      }

      if !state.copy_from_distance(distance, length) {
        return false
      }
    }
  }

  true
}

///|
/// Int 转 Byte
fn int_to_byte(n : Int) -> Byte {
  // 使用 UInt 中间转换
  let u : UInt = n.reinterpret_as_uint()
  u.to_byte()
}

///|
/// 解码固定 Huffman 符号
fn decode_fixed_symbol(reader : BitReader) -> Result[Int, String] {
  // 读取前7位判断范围 (MSB first for Huffman codes)
  let first7_result = reader.read_bits_reverse(7)
  let first7 = match first7_result {
    Ok(v) => v
    Err(e) => return Err(e)
  }

  // RFC 1951 Fixed Huffman codes:
  // Lit Value    Bits   Codes (binary)       Codes (decimal)  First 7 bits range
  // ---------    ----   ------------------   --------------   ------------------
  //   0 - 143     8     00110000-10111111    48-191           24-95 (0x18-0x5F)
  // 144 - 255     9     110010000-111111111  400-511          100-127 (0x64-0x7F)
  // 256 - 279     7     0000000-0010111      0-23             0-23 (0x00-0x17)
  // 280 - 287     8     11000000-11000111    192-199          96-99 (0x60-0x63)

  if first7 < 0x18 {
    // 256-279: 7位编码
    Ok(256 + first7)
  } else if first7 < 0x60 {
    // 0-143: 8位编码 - 需要1个额外位 (MSB first)
    let bit8_result = reader.read_bits_reverse(1)
    let bit8 = match bit8_result {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    // code = (first7 << 1) | bit8, then subtract 48 to get literal
    Ok(((first7 << 1) | bit8) - 48)
  } else if first7 < 0x64 {
    // 280-287: 8位编码 - 需要1个额外位 (MSB first)
    let bit8_result = reader.read_bits_reverse(1)
    let bit8 = match bit8_result {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    // code = (first7 << 1) | bit8, then map to 280-287
    // 192-199 map to 280-287, so subtract 192 and add 280
    Ok(((first7 << 1) | bit8) - 192 + 280)
  } else {
    // 144-255: 9位编码 - 需要2个额外位 (MSB first)
    let extra_result = reader.read_bits_reverse(2)
    let extra = match extra_result {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    // 9-bit code = (first7 << 2) | extra
    // Codes 400-511 map to 144-255, so subtract 400 and add 144 = subtract 256
    Ok(((first7 << 2) | extra) - 256)
  }
}

///|
/// 逆向读取位 (MSB优先) - 用于 Huffman 码读取
/// 正确实现：逐位读取，每次左移结果，新位作为 LSB
fn BitReader::read_bits_reverse(
  self : BitReader,
  count : Int,
) -> Result[Int, String] {
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

///|
/// 长度码基础值表
let length_base : FixedArray[Int] = FixedArray::makei(29, fn(i : Int) -> Int {
  match i {
    0 => 3
    1 => 4
    2 => 5
    3 => 6
    4 => 7
    5 => 8
    6 => 9
    7 => 10
    8 => 11
    9 => 13
    10 => 15
    11 => 17
    12 => 19
    13 => 23
    14 => 27
    15 => 31
    16 => 35
    17 => 43
    18 => 51
    19 => 59
    20 => 67
    21 => 83
    22 => 99
    23 => 115
    24 => 131
    25 => 163
    26 => 195
    27 => 227
    _ => 258
  }
})

///|
/// 长度码额外位数表
let length_extra : FixedArray[Int] = FixedArray::makei(29, fn(i : Int) -> Int {
  match i {
    0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 => 0
    8 | 9 | 10 | 11 => 1
    12 | 13 | 14 | 15 => 2
    16 | 17 | 18 | 19 => 3
    20 | 21 | 22 | 23 => 4
    24 | 25 | 26 | 27 => 5
    _ => 0
  }
})

///|
/// 距离码基础值表
let dist_base : FixedArray[Int] = FixedArray::makei(30, fn(i : Int) -> Int {
  match i {
    0 => 1
    1 => 2
    2 => 3
    3 => 4
    4 => 5
    5 => 7
    6 => 9
    7 => 13
    8 => 17
    9 => 25
    10 => 33
    11 => 49
    12 => 65
    13 => 97
    14 => 129
    15 => 193
    16 => 257
    17 => 385
    18 => 513
    19 => 769
    20 => 1025
    21 => 1537
    22 => 2049
    23 => 3073
    24 => 4097
    25 => 6145
    26 => 8193
    27 => 12289
    28 => 16385
    _ => 24577
  }
})

///|
/// 距离码额外位数表
let dist_extra : FixedArray[Int] = FixedArray::makei(30, fn(i : Int) -> Int {
  match i {
    0 | 1 | 2 | 3 => 0
    4 | 5 => 1
    6 | 7 => 2
    8 | 9 => 3
    10 | 11 => 4
    12 | 13 => 5
    14 | 15 => 6
    16 | 17 => 7
    18 | 19 => 8
    20 | 21 => 9
    22 | 23 => 10
    24 | 25 => 11
    26 | 27 => 12
    _ => 13
  }
})

///|
/// 解码长度
fn decode_length(reader : BitReader, code : Int) -> Result[Int, String] {
  let idx = code - 257
  if idx < 0 || idx >= 29 {
    return Err("Invalid length code")
  }
  let base = length_base[idx]
  let extra = length_extra[idx]
  if extra > 0 {
    let bits_result = reader.read_bits(extra)
    match bits_result {
      Ok(bits) => Ok(base + bits)
      Err(e) => Err(e)
    }
  } else {
    Ok(base)
  }
}

///|
/// 解码距离
fn decode_distance(reader : BitReader, code : Int) -> Result[Int, String] {
  if code < 0 || code >= 30 {
    return Err("Invalid distance code")
  }
  let base = dist_base[code]
  let extra = dist_extra[code]
  if extra > 0 {
    let bits_result = reader.read_bits(extra)
    match bits_result {
      Ok(bits) => Ok(base + bits)
      Err(e) => Err(e)
    }
  } else {
    Ok(base)
  }
}

///|
/// 解压动态 Huffman 编码块 — 写入 output，返回是否成功
fn decompress_dynamic_huffman_block(
  reader : BitReader,
  state : InflateState,
) -> Bool {
  // 读取动态表信息
  let hlit_result = reader.read_bits(5)
  let hlit = match hlit_result {
    Ok(v) => v + 257
    Err(_) => return false
  }
  let hdist_result = reader.read_bits(5)
  let hdist = match hdist_result {
    Ok(v) => v + 1
    Err(_) => return false
  }
  let hclen_result = reader.read_bits(4)
  let hclen = match hclen_result {
    Ok(v) => v + 4
    Err(_) => return false
  }

  // 读取码长码顺序 (RFC 1951 规定的顺序)
  let code_length_order : FixedArray[Int] = FixedArray::makei(19, fn(
    i : Int,
  ) -> Int {
    match i {
      0 => 16
      1 => 17
      2 => 18
      3 => 0
      4 => 8
      5 => 7
      6 => 9
      7 => 6
      8 => 10
      9 => 5
      10 => 11
      11 => 4
      12 => 12
      13 => 3
      14 => 13
      15 => 2
      16 => 14
      17 => 1
      _ => 15
    }
  })

  // 读取码长码 - 使用 LSB first (这些不是 Huffman 编码)
  let code_lengths : FixedArray[Int] = FixedArray::makei(19, fn(_) { 0 })

  for i in 0..<hclen {
    let len_result = reader.read_bits(3)
    let len = match len_result {
      Ok(v) => v
      Err(_) => return false
    }
    code_lengths[code_length_order[i]] = len
  }

  // 构建码长 Huffman 树
  let tree_result = build_huffman_tree(code_lengths)
  let code_length_tree = match tree_result {
    Ok(t) => t
    Err(_) => return false
  }

  // 读取字面量/长度和距离编码长度
  let total = hlit + hdist
  let lit_len_dist : FixedArray[Int] = FixedArray::makei(total, fn(_) { 0 })
  let mut i = 0

  while i < total {
    let code_result = decode_huffman(reader, code_length_tree)
    let code = match code_result {
      Ok(v) => v
      Err(_) => return false
    }

    match code {
      0..=15 => {
        lit_len_dist[i] = code
        i = i + 1
      }
      16 => {
        // 重复上一个码 3-6 次 (LSB first for extra bits)
        if i == 0 {
          return false
        }
        let repeat_result = reader.read_bits(2)
        let repeat = match repeat_result {
          Ok(v) => v + 3
          Err(_) => return false
        }
        if i + repeat > total {
          return false
        }
        let prev = lit_len_dist[i - 1]
        for _ in 0..<repeat {
          lit_len_dist[i] = prev
          i = i + 1
        }
      }
      17 => {
        // 重复 0 共 3-10 次 (LSB first for extra bits)
        let repeat_result = reader.read_bits(3)
        let repeat = match repeat_result {
          Ok(v) => v + 3
          Err(_) => return false
        }
        if i + repeat > total {
          return false
        }
        for _ in 0..<repeat {
          lit_len_dist[i] = 0
          i = i + 1
        }
      }
      18 => {
        // 重复 0 共 11-138 次 (LSB first for extra bits)
        let repeat_result = reader.read_bits(7)
        let repeat = match repeat_result {
          Ok(v) => v + 11
          Err(_) => return false
        }
        if i + repeat > total {
          return false
        }
        for _ in 0..<repeat {
          lit_len_dist[i] = 0
          i = i + 1
        }
      }
      _ => return false
    }
  }

  // 构建字面量/长度 Huffman 树
  let lit_len_lengths = fixedarray_slice(lit_len_dist, 0, hlit)
  let lit_len_tree_result = build_huffman_tree(lit_len_lengths)
  let lit_len_tree = match lit_len_tree_result {
    Ok(t) => t
    Err(_) => return false
  }

  // 构建距离 Huffman 树
  let dist_lengths = fixedarray_slice(lit_len_dist, hlit, total)
  let dist_tree_result = build_huffman_tree(dist_lengths)
  let dist_tree = match dist_tree_result {
    Ok(t) => t
    Err(_) => return false
  }

  let mut done = false

  while !done {
    let symbol_result = decode_huffman(reader, lit_len_tree)
    let symbol = match symbol_result {
      Ok(v) => v
      Err(_) => return false
    }

    if symbol < 256 {
      // 字面量字节
      state.write_byte(int_to_byte(symbol))
    } else if symbol == 256 {
      // 块结束
      done = true
    } else {
      // 长度-距离对
      let length_result = decode_length(reader, symbol)
      let length = match length_result {
        Ok(l) => l
        Err(_) => return false
      }
      let dist_code_result = decode_huffman(reader, dist_tree)
      let dist_code = match dist_code_result {
        Ok(d) => d
        Err(_) => return false
      }
      let distance_result = decode_distance(reader, dist_code)
      let distance = match distance_result {
        Ok(d) => d
        Err(_) => return false
      }

      if !state.copy_from_distance(distance, length) {
        return false
      }
    }
  }

  true
}

///|
/// 切片 FixedArray
fn fixedarray_slice(
  arr : FixedArray[Int],
  start : Int,
  end : Int,
) -> FixedArray[Int] {
  FixedArray::makei(end - start, fn(i : Int) -> Int { arr[start + i] })
}

///|
/// Huffman 树
priv struct HuffmanTree {
  tables : FixedArray[Map[Int, Int]]
  max_len : Int
}

///|
fn reverse_low_bits(code : Int, bit_count : Int) -> Int {
  let mut result = 0
  let mut remaining = code
  for _ in 0..<bit_count {
    result = (result << 1) | (remaining & 1)
    remaining = remaining >> 1
  }
  result
}

///|
/// 构建 Huffman 树
fn build_huffman_tree(lengths : FixedArray[Int]) -> Result[HuffmanTree, String] {
  // 计算每个码长的数量
  let max_allowed_len = 15
  let mut max_len = 0

  // 计算每个长度的符号数量
  let bl_count : FixedArray[Int] = FixedArray::makei(max_allowed_len + 1, fn(
    _,
  ) {
    0
  })
  for i in 0..<lengths.length() {
    let len = lengths[i]
    if len < 0 || len > max_allowed_len {
      return Err("Invalid Huffman code length")
    }
    if len > 0 {
      bl_count[len] = bl_count[len] + 1
      if len > max_len {
        max_len = len
      }
    }
  }
  if max_len == 0 {
    return Err("Empty Huffman tree")
  }

  let mut remaining = 1
  for bits in 1..<=max_len {
    remaining = (remaining << 1) - bl_count[bits]
    if remaining < 0 {
      return Err("Oversubscribed Huffman tree")
    }
  }

  // 计算每个码长的起始码
  let mut code : Int = 0
  let next_code : FixedArray[Int] = FixedArray::makei(max_allowed_len + 1, fn(
    _,
  ) {
    0
  })

  for bits in 1..<=max_len {
    code = (code + bl_count[bits - 1]) << 1
    next_code[bits] = code
  }

  let tables : FixedArray[Map[Int, Int]] = FixedArray::makei(max_len + 1, fn(
    _,
  ) {
    Map::new()
  })

  for i in 0..<lengths.length() {
    let len = lengths[i]
    if len > 0 {
      let reversed_code = reverse_low_bits(next_code[len], len)
      tables[len][reversed_code] = i
      next_code[len] = next_code[len] + 1
    }
  }

  Ok(HuffmanTree::{ tables, max_len })
}

///|
/// 使用 Huffman 树解码符号
fn decode_huffman(
  reader : BitReader,
  tree : HuffmanTree,
) -> Result[Int, String] {
  let mut code = 0
  for bit_len in 1..<=tree.max_len {
    let bit_result = reader.read_bits(1)
    let bit = match bit_result {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    code = code | (bit << (bit_len - 1))
    match tree.tables[bit_len].get(code) {
      Some(symbol) => return Ok(symbol)
      None => ()
    }
  }

  Err("Invalid Huffman code")
}
