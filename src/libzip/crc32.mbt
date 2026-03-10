// CRC32 校验模块

///|
/// 计算 CRC32 校验值
pub fn crc32(data : Bytes) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for i = 0; i < data.length(); i = i + 1 {
    let byte = data[i].to_uint()
    let index = (crc ^ byte) & 0xFF
    crc = update_crc(crc, index)
  }
  crc ^ 0xFFFFFFFF
}

///|
/// 更新 CRC 值
fn update_crc(crc : UInt, index : UInt) -> UInt {
  let result = crc >> 8
  let poly : UInt = 0xEDB88320
  let table_val = get_table_value(index)
  result ^ table_val
}

///|
/// 获取查找表值
fn get_table_value(index : UInt) -> UInt {
  let mut crc = index
  let poly : UInt = 0xEDB88320
  for _j = 0; _j < 8; _j = _j + 1 {
    if is_odd(crc) {
      crc = (crc >> 1) ^ poly
    } else {
      crc = crc >> 1
    }
  }
  crc
}

///|
/// 判断是否为奇数
fn is_odd(n : UInt) -> Bool {
  n % 2.to_uint() == 1.to_uint()
}
