// libzip API 规范文件
// 使用 declare 声明待实现的类型和函数

///|
/// ZIP 解析错误类型
pub(all) suberror ZipError {
  /// 无效的 ZIP 签名
  InvalidSignature
  /// 损坏的文件头
  CorruptedHeader
  /// 文件不存在
  FileNotFound(String)
  /// 不支持的压缩方法
  UnsupportedMethod(Int)
  /// 解压失败
  DecompressFailed(String)
  /// CRC 校验失败
  CrcMismatch
} derive(Show, Eq)

///|
/// ZIP 归档句柄 (对应原 FFI 的 ZipHandle)
declare pub type ZipArchive

///|
/// 从内存缓冲区打开 ZIP 归档
declare pub fn ZipArchive::open(buffer : Bytes) -> ZipArchive?

///|
/// 读取 ZIP 中指定文件内容
declare pub fn read_file_entry(archive : ZipArchive, name : String) -> Bytes?

///|
/// 关闭 ZIP 归档
declare pub fn close_archive(archive : ZipArchive) -> Unit

///|
/// 获取 ZIP 归档中的文件列表
declare pub fn ZipArchive::list_entries(self : ZipArchive) -> Array[String]

///|
/// 检查 ZIP 中是否存在指定文件
declare pub fn ZipArchive::has_file(self : ZipArchive, name : String) -> Bool
