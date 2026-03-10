// libzip 主实现文件

///|
/// ZIP 归档结构
pub(all) struct ZipArchive {
  /// 原始数据
  data : Bytes
  /// 文件条目列表
  entries : Array[ZipEntry]
}

///|
/// ZIP 文件条目
struct ZipEntry {
  /// 文件名
  name : String
  /// 压缩方法
  compression_method : Int
  /// 压缩大小
  compressed_size : Int
  /// 原始大小
  uncompressed_size : Int
  /// 数据偏移
  data_offset : Int
  /// CRC32
  crc32 : UInt
}

///|
/// 从内存缓冲区打开 ZIP 归档
pub fn ZipArchive::open(buffer : Bytes) -> ZipArchive? {
  // 检查最小长度
  if buffer.length() < 22 {
    None
  } else {
    // 解析 EOCD (End of Central Directory)
    let eocd_offset = find_eocd(buffer)
    match eocd_offset {
      Some(offset) => {
        let entries = parse_central_directory(buffer, offset)
        Some(ZipArchive::{ data: buffer, entries: entries })
      }
      None => None
    }
  }
}
