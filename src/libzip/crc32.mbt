// CRC32 校验模块

///|
/// CRC32 查找表
let crc32_table : Array[UInt] = Array::make(256, 0)

///|
/// 初始化 CRC32 查找表
fn init_crc32_table() -> Unit {
  for i = 0; i < 256; i = i + 1 {
    let mut crc = i.to_uint()
    for j = 0; j < 8; j = j + 1 {
      if (crc & 1.to_uint()) != 0.to_uint() {
        crc = (crc >> 1) ^ 0xEDB88320
      } else {
        crc = crc >> 1
      }
    }
    crc32_table[i] = crc
  }
}

///|
/// 计算 CRC32 校验值
pub fn crc32(data : Bytes) -> UInt {
  if crc32_table[1] == 0 {
    init_crc32_table()
  }
  
  let mut crc : UInt = 0xFFFFFFFF
  for i = 0; i < data.length(); i = i + 1 {
    let index = ((crc ^ data[i].to_uint()) & 0xFF).reinterpret_as_int()
    crc = (crc >> 8) ^ crc32_table[index]
  }
  crc ^ 0xFFFFFFFF
}
