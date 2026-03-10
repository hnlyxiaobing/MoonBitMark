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
