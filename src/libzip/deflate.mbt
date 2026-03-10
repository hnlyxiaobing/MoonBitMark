// Deflate 解压模块
// 实现 RFC 1951 DEFLATE 解压缩算法

///|
/// Deflate 解压主函数
pub fn deflate_decompress(input : Bytes) -> Bytes? {
  let reader = BitReader::new(input)
  let output : Array[Byte] = Array::new()
  
  // 读取头部
  let bfinal_result = reader.read_bits(1)
  let bfinal = match bfinal_result {
    Ok(v) => v == 1
    Err(_) => return None
  }
  ignore(bfinal)
  
  let btype_result = reader.read_bits(2)
  let btype = match btype_result {
    Ok(v) => v
    Err(_) => return None
  }
  
  match btype {
    0 => decompress_stored(reader, output)
    1 => decompress_fixed_huffman(reader, output)
    2 => decompress_dynamic_huffman(reader, output)
    _ => None
  }
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
/// 解压存储块 (无压缩)
fn decompress_stored(reader : BitReader, output : Array[Byte]) -> Bytes? {
  // 对齐到字节边界
  reader.align_to_byte()
  
  // 读取 LEN 和 NLEN
  let len_result = reader.read_uint16_le()
  let len = match len_result {
    Ok(v) => v
    Err(_) => return None
  }
  let nlen_result = reader.read_uint16_le()
  let nlen = match nlen_result {
    Ok(v) => v
    Err(_) => return None
  }
  
  // 验证 NLEN 是 LEN 的补码
  if (len ^ nlen) != 0xFFFF {
    return None
  }
  
  // 读取原始数据
  for _ in 0..<len {
    let byte_result = reader.read_byte()
    match byte_result {
      Ok(b) => output.push(b)
      Err(_) => return None
    }
  }
  
  Some(bytes_from_array(output))
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
/// 解压固定 Huffman 编码块
fn decompress_fixed_huffman(reader : BitReader, output : Array[Byte]) -> Bytes? {
  // 使用滑动窗口 - 用 Array 代替 FixedArray 以支持修改
  let window : Array[Byte] = Array::new()
  // 预填充窗口
  for _ in 0..<32768 {
    window.push(b'\x00')
  }
  
  let mut window_pos = 0
  let mut done = false
  
  while !done {
    // 解码下一个符号
    let symbol_result = decode_fixed_symbol(reader)
    let symbol = match symbol_result {
      Ok(s) => s
      Err(_) => return None
    }
    
    if symbol < 256 {
      // 字面量字节
      let byte = int_to_byte(symbol)
      output.push(byte)
      window[window_pos] = byte
      window_pos = (window_pos + 1) & 0x7FFF
    } else if symbol == 256 {
      // 块结束
      done = true
    } else {
      // 长度-距离对
      let length_result = decode_length(reader, symbol)
      let length = match length_result {
        Ok(l) => l
        Err(_) => return None
      }
      
      let dist_code_result = reader.read_bits_reverse(5)
      let dist_code = match dist_code_result {
        Ok(d) => d
        Err(_) => return None
      }
      
      let distance_result = decode_distance(reader, dist_code)
      let distance = match distance_result {
        Ok(d) => d
        Err(_) => return None
      }
      
      // 从滑动窗口复制
      for i in 0..<length {
        let src_pos = (window_pos - distance + i) & 0x7FFF
        let byte = window[src_pos]
        output.push(byte)
        window[window_pos] = byte
        window_pos = (window_pos + 1) & 0x7FFF
      }
    }
  }
  
  Some(bytes_from_array(output))
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
  // 读取前7位判断范围
  let first7_result = reader.read_bits_reverse(7)
  let first7 = match first7_result {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  
  if first7 < 0x18 {
    // 0-143: 8位编码
    let bit8_result = reader.read_bits(1)
    let bit8 = match bit8_result {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    Ok((first7 << 1) | bit8)
  } else if first7 < 0x60 {
    // 144-255: 9位编码
    let extra_result = reader.read_bits(2)
    let extra = match extra_result {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    Ok(144 + (((first7 - 0x18) << 2) | extra))
  } else if first7 < 0x68 {
    // 256-279: 7位编码
    Ok(256 + (first7 - 0x60))
  } else {
    // 280-287: 8位编码
    let bit8_result = reader.read_bits(1)
    let bit8 = match bit8_result {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    Ok(280 + (((first7 - 0x68) << 1) | bit8))
  }
}

///|
/// 逆向读取位 (MSB优先)
fn BitReader::read_bits_reverse(self : BitReader, count : Int) -> Result[Int, String] {
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
    
    result = (result << to_read) | bits
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
    0|1|2|3|4|5|6|7 => 0
    8|9|10|11 => 1
    12|13|14|15 => 2
    16|17|18|19 => 3
    20|21|22|23 => 4
    24|25|26|27 => 5
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
    0|1|2|3 => 0
    4|5 => 1
    6|7 => 2
    8|9 => 3
    10|11 => 4
    12|13 => 5
    14|15 => 6
    16|17 => 7
    18|19 => 8
    20|21 => 9
    22|23 => 10
    24|25 => 11
    26|27 => 12
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
/// 解压动态 Huffman 编码块
fn decompress_dynamic_huffman(reader : BitReader, output : Array[Byte]) -> Bytes? {
  // 读取动态表信息
  let hlit_result = reader.read_bits(5)
  let hlit = match hlit_result {
    Ok(v) => v + 257
    Err(_) => return None
  }
  let hdist_result = reader.read_bits(5)
  let hdist = match hdist_result {
    Ok(v) => v + 1
    Err(_) => return None
  }
  let hclen_result = reader.read_bits(4)
  let hclen = match hclen_result {
    Ok(v) => v + 4
    Err(_) => return None
  }
  
  // 读取码长码顺序
  let code_length_order : FixedArray[Int] = FixedArray::makei(19, fn(i : Int) -> Int {
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
  
  // 读取码长码
  let code_lengths : FixedArray[Int] = FixedArray::makei(19, fn(_) { 0 })
  
  for i in 0..<hclen {
    let len_result = reader.read_bits(3)
    let len = match len_result {
      Ok(v) => v
      Err(_) => return None
    }
    code_lengths[code_length_order[i]] = len
  }
  
  // 构建码长 Huffman 树
  let tree_result = build_huffman_tree(code_lengths)
  let code_length_tree = match tree_result {
    Ok(t) => t
    Err(_) => return None
  }
  
  // 读取字面量/长度和距离编码长度
  let total = hlit + hdist
  let lit_len_dist : FixedArray[Int] = FixedArray::makei(total, fn(_) { 0 })
  let mut i = 0
  
  while i < total {
    let code_result = decode_huffman(reader, code_length_tree)
    let code = match code_result {
      Ok(v) => v
      Err(_) => return None
    }
    
    match code {
      0..=15 => {
        lit_len_dist[i] = code
        i = i + 1
      }
      16 => {
        // 重复上一个码 3-6 次
        let repeat_result = reader.read_bits(2)
        let repeat = match repeat_result {
          Ok(v) => v + 3
          Err(_) => return None
        }
        let prev = if i > 0 { lit_len_dist[i - 1] } else { 0 }
        for _ in 0..<repeat {
          if i < total {
            lit_len_dist[i] = prev
            i = i + 1
          }
        }
      }
      17 => {
        // 重复 0 共 3-10 次
        let repeat_result = reader.read_bits(3)
        let repeat = match repeat_result {
          Ok(v) => v + 3
          Err(_) => return None
        }
        for _ in 0..<repeat {
          if i < total {
            lit_len_dist[i] = 0
            i = i + 1
          }
        }
      }
      18 => {
        // 重复 0 共 11-138 次
        let repeat_result = reader.read_bits(7)
        let repeat = match repeat_result {
          Ok(v) => v + 11
          Err(_) => return None
        }
        for _ in 0..<repeat {
          if i < total {
            lit_len_dist[i] = 0
            i = i + 1
          }
        }
      }
      _ => return None
    }
  }
  
  // 构建字面量/长度 Huffman 树
  let lit_len_lengths = fixedarray_slice(lit_len_dist, 0, hlit)
  let lit_len_tree_result = build_huffman_tree(lit_len_lengths)
  let lit_len_tree = match lit_len_tree_result {
    Ok(t) => t
    Err(_) => return None
  }
  
  // 构建距离 Huffman 树
  let dist_lengths = fixedarray_slice(lit_len_dist, hlit, total)
  let dist_tree_result = build_huffman_tree(dist_lengths)
  let dist_tree = match dist_tree_result {
    Ok(t) => t
    Err(_) => return None
  }
  
  // 解码数据
  let window : Array[Byte] = Array::new()
  for _ in 0..<32768 {
    window.push(b'\x00')
  }
  
  let mut window_pos = 0
  let mut done = false
  
  while !done {
    let symbol_result = decode_huffman(reader, lit_len_tree)
    let symbol = match symbol_result {
      Ok(v) => v
      Err(_) => return None
    }
    
    if symbol < 256 {
      // 字面量字节
      let byte = int_to_byte(symbol)
      output.push(byte)
      window[window_pos] = byte
      window_pos = (window_pos + 1) & 0x7FFF
    } else if symbol == 256 {
      // 块结束
      done = true
    } else {
      // 长度-距离对
      let length_result = decode_length(reader, symbol)
      let length = match length_result {
        Ok(l) => l
        Err(_) => return None
      }
      let dist_code_result = decode_huffman(reader, dist_tree)
      let dist_code = match dist_code_result {
        Ok(d) => d
        Err(_) => return None
      }
      let distance_result = decode_distance(reader, dist_code)
      let distance = match distance_result {
        Ok(d) => d
        Err(_) => return None
      }
      
      // 从滑动窗口复制
      for j in 0..<length {
        let src_pos = (window_pos - distance + j) & 0x7FFF
        let byte = window[src_pos]
        output.push(byte)
        window[window_pos] = byte
        window_pos = (window_pos + 1) & 0x7FFF
      }
    }
  }
  
  Some(bytes_from_array(output))
}

///|
/// 切片 FixedArray
fn fixedarray_slice(arr : FixedArray[Int], start : Int, end : Int) -> FixedArray[Int] {
  FixedArray::makei(end - start, fn(i : Int) -> Int {
    arr[start + i]
  })
}

///|
/// Huffman 树节点
priv struct HuffmanNode {
  mut symbol : Int
  mut left : Int
  mut right : Int
}

///|
/// Huffman 树
priv struct HuffmanTree {
  nodes : FixedArray[HuffmanNode]
  root : Int
}

///|
/// 构建 Huffman 树
fn build_huffman_tree(lengths : FixedArray[Int]) -> Result[HuffmanTree, String] {
  // 计算每个码长的数量
  let max_len = 15
  
  // 计算每个长度的符号数量
  let bl_count : FixedArray[Int] = FixedArray::makei(max_len + 1, fn(_) { 0 })
  for i in 0..<lengths.length() {
    let len = lengths[i]
    if len > 0 && len <= max_len {
      bl_count[len] = bl_count[len] + 1
    }
  }
  
  // 计算每个码长的起始码
  let mut code : Int = 0
  let next_code : FixedArray[Int] = FixedArray::makei(max_len + 1, fn(_) { 0 })
  
  for bits in 1..=max_len {
    code = (code + bl_count[bits - 1]) << 1
    next_code[bits] = code
  }
  
  // 分配码字并记录
  let codes : FixedArray[Int] = FixedArray::makei(lengths.length(), fn(_) { 0 })
  let code_lens : FixedArray[Int] = FixedArray::makei(lengths.length(), fn(_) { 0 })
  
  for i in 0..<lengths.length() {
    let len = lengths[i]
    if len > 0 && len <= max_len {
      codes[i] = next_code[len]
      code_lens[i] = len
      next_code[len] = next_code[len] + 1
    }
  }
  
  // 构建树 - 使用可变数组
  let nodes : Array[HuffmanNode] = Array::new()
  nodes.push(HuffmanNode::{ symbol: -1, left: -1, right: -1 })  // 根节点
  
  for i in 0..<lengths.length() {
    let len = code_lens[i]
    if len == 0 {
      continue
    }
    
    let mut node = 0
    let code_val = codes[i]
    
    for bit in 0..<len {
      let b = (code_val >> (len - 1 - bit)) & 1
      let current = nodes[node]
      
      if b == 0 {
        // 左分支
        if current.left < 0 {
          let new_node = HuffmanNode::{ symbol: -1, left: -1, right: -1 }
          nodes.push(new_node)
          nodes[node].left = nodes.length() - 1
        }
        node = nodes[node].left
      } else {
        // 右分支
        if current.right < 0 {
          let new_node = HuffmanNode::{ symbol: -1, left: -1, right: -1 }
          nodes.push(new_node)
          nodes[node].right = nodes.length() - 1
        }
        node = nodes[node].right
      }
    }
    
    nodes[node].symbol = i
  }
  
  // 转换为 FixedArray
  let node_count = nodes.length()
  let fixed_nodes = FixedArray::makei(node_count, fn(i : Int) -> HuffmanNode {
    nodes[i]
  })
  
  Ok(HuffmanTree::{ nodes: fixed_nodes, root: 0 })
}

///|
/// 使用 Huffman 树解码符号
fn decode_huffman(reader : BitReader, tree : HuffmanTree) -> Result[Int, String] {
  let mut node_idx = tree.root
  let mut found = false
  let mut result = -1
  
  while !found {
    let current = tree.nodes[node_idx]
    
    if current.symbol >= 0 {
      found = true
      result = current.symbol
    } else {
      let bit_result = reader.read_bits_reverse(1)
      let bit = match bit_result {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      
      if bit == 0 {
        if current.left < 0 {
          return Err("Invalid Huffman code")
        }
        node_idx = current.left
      } else {
        if current.right < 0 {
          return Err("Invalid Huffman code")
        }
        node_idx = current.right
      }
    }
  }
  
  Ok(result)
}
