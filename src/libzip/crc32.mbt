// CRC32 校验模块

///|
/// 计算 CRC32 校验值 (简化实现)
pub fn crc32(data : Bytes) -> UInt {
  let mut result : UInt = 0
  for i = 0; i < data.length(); i = i + 1 {
    result = result + data[i].to_uint()
  }
  result
}
