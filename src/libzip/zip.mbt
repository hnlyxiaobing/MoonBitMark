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
