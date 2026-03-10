// CRC32 校验模块
// 使用 IEEE 802.3 标准多项式 (0xEDB88320)

///|
/// CRC32 多项式 (反向表示)
let crc32_poly : UInt = 0xEDB88320

///|
/// 构建 CRC32 查找表
fn build_crc32_table() -> FixedArray[UInt] {
  FixedArray::makei(256, fn(i : Int) -> UInt {
    let mut c : UInt = i.reinterpret_as_uint()
    for _ in 0..<8 {
      if (c & 1U) == 1U {
        c = (c >> 1) ^ crc32_poly
      } else {
        c = c >> 1
      }
    }
    c
  })
}

///|
/// CRC32 查找表 (延迟初始化)
fn get_crc32_table() -> FixedArray[UInt] {
  build_crc32_table()
}

///|
/// 计算 CRC32 校验值
/// 使用 IEEE 802.3 标准算法
pub fn crc32(data : Bytes) -> UInt {
  let table = get_crc32_table()
  let mut crc : UInt = 0xFFFFFFFF

  for i in 0..<data.length() {
    let byte : UInt = data[i].to_uint()
    let index = (crc ^ byte) & 0xFF
    crc = (crc >> 8) ^ table[index.reinterpret_as_int()]
  }

  crc ^ 0xFFFFFFFF
}

///|
/// 继续计算 CRC32 (用于流式处理)
/// 初始值应传入 0，后续调用传入上一次的结果
pub fn crc32_continue(data : Bytes, init : UInt) -> UInt {
  let table = get_crc32_table()
  let mut crc = init

  for i in 0..<data.length() {
    let byte : UInt = data[i].to_uint()
    let index = (crc ^ byte) & 0xFF
    crc = (crc >> 8) ^ table[index.reinterpret_as_int()]
  }

  crc
}

///|
/// 计算 CRC32 并返回十六进制字符串
pub fn crc32_hex(data : Bytes) -> String {
  let crc = crc32(data)
  // 使用 UInt 的 to_string 基数转换
  // MoonBit 暂不支持 UInt 的 hex 格式化，手动实现
  let hex_chars = "0123456789abcdef"
  let mut result = ""
  let mut n = crc
  for _ in 0..<8 {
    let digit = (n >> 28).reinterpret_as_int()
    let ch = hex_chars[digit]
    result = result + ch.to_string()
    n = n << 4
  }
  result
}
