// ZIP 文件格式定义

///|
/// ZIP 文件签名常量
pub let local_file_header_sig : UInt = 0x04034b50

///|
pub let central_dir_sig : UInt = 0x02014b50

///|
pub let end_of_central_dir_sig : UInt = 0x06054b50

///|
/// 压缩方法
pub enum CompressionMethod {
  Store(Int) // 无压缩
  Deflate(Int) // DEFLATE 压缩
  Unknown(Int) // 未知方法
} derive(Show, Eq)
