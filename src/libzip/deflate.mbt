// Deflate 解压模块
// 实现 RFC 1951 DEFLATE 解压缩

///|
/// Deflate 解压器
struct DeflateDecoder {
  /// 输入数据
  input : Bytes
  /// 当前字节位置
  byte_pos : Int
  /// 当前位位置
  bit_pos : Int
  /// 输出缓冲区
  output : @buffer.T[Byte]
}

///|
/// 读取 1 位
fn read_bit(self : DeflateDecoder) -> Int {
  let byte = self.input[self.byte_pos].to_int()
  let bit = (byte >> self.bit_pos) & 1
  self.bit_pos = self.bit_pos + 1
  if self.bit_pos == 8 {
    self.bit_pos = 0
    self.byte_pos = self.byte_pos + 1
  }
  bit
}

///|
/// 读取 n 位 (小端序)
fn read_bits(self : DeflateDecoder, n : Int) -> Int {
  let mut result = 0
  for i = 0; i < n; i = i + 1 {
    result = result | (read_bit(self) << i)
  }
  result
}
