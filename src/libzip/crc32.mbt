// CRC32 校验模块

///|
/// CRC32 多项式
let crc32_poly : UInt = 0xEDB88320

///|
/// 预计算的 CRC32 查找表 (256 个值)
let crc32_table : Array[UInt] = {
  let table : Array[UInt] = Array::make(256, 0)
  for i = 0; i < 256; i = i + 1 {
    let mut crc = i.to_uint()
    for _j = 0; _j < 8; _j = _j + 1 {
      if (crc & 1.to_uint()) == 1.to_uint() {
        crc = (crc >> 1) ^ CRC32_POLY
      } else {
        crc = crc >> 1
      }
    }
    table[i] = crc
  }
  table
}
