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

///|
/// 查找 EOCD (End of Central Directory) 记录
fn find_eocd(buffer : Bytes) -> Int? {
  // EOCD 签名: 0x06054b50
  // 从文件末尾向前搜索
  let mut pos = buffer.length() - 22
  while pos >= 0 {
    if read_uint32_le(buffer, pos) == 0x06054b50 {
      Some(pos)
    } else {
      pos = pos - 1
    }
  }
  None
}

///|
/// 读取小端序 UInt32
fn read_uint32_le(buffer : Bytes, offset : Int) -> UInt {
  (buffer[offset].to_uint()) |
  (buffer[offset + 1].to_uint() << 8) |
  (buffer[offset + 2].to_uint() << 16) |
  (buffer[offset + 3].to_uint() << 24)
}

///|
/// 解析中央目录
fn parse_central_directory(buffer : Bytes, eocd_offset : Int) -> Array[ZipEntry] {
  // 从 EOCD 获取中央目录偏移
  let cd_offset = read_uint16_le(buffer, eocd_offset + 16).to_int()
  let num_entries = read_uint16_le(buffer, eocd_offset + 10).to_int()
  
  let entries : Array[ZipEntry] = Array::new()
  let mut pos = cd_offset
  
  for i = 0; i < num_entries; i = i + 1 {
    let entry = parse_central_dir_entry(buffer, pos)
    entries.push(entry)
    pos = pos + get_central_dir_entry_size(buffer, pos)
  }
  entries
}

///|
/// 读取小端序 UInt16
fn read_uint16_le(buffer : Bytes, offset : Int) -> UInt {
  (buffer[offset].to_uint()) |
  (buffer[offset + 1].to_uint() << 8)
}

///|
/// 解析单个中央目录条目
fn parse_central_dir_entry(buffer : Bytes, offset : Int) -> ZipEntry {
  // Central Directory Header 固定部分 46 字节
  let name_len = read_uint16_le(buffer, offset + 28).to_int()
  let extra_len = read_uint16_le(buffer, offset + 30).to_int()
  let comment_len = read_uint16_le(buffer, offset + 32).to_int()
  
  // 读取文件名
  let name_start = offset + 46
  let name = bytes_to_string(buffer, name_start, name_len)
  
  ZipEntry::{
    name: name,
    compression_method: read_uint16_le(buffer, offset + 10).to_int(),
    compressed_size: read_uint32_le(buffer, offset + 20).to_int(),
    uncompressed_size: read_uint32_le(buffer, offset + 24).to_int(),
    data_offset: read_uint32_le(buffer, offset + 42).to_int(),
    crc32: read_uint32_le(buffer, offset + 16)
  }
}

///|
/// 获取中央目录条目大小
fn get_central_dir_entry_size(buffer : Bytes, offset : Int) -> Int {
  46 + read_uint16_le(buffer, offset + 28).to_int() +
       read_uint16_le(buffer, offset + 30).to_int() +
       read_uint16_le(buffer, offset + 32).to_int()
}

///|
/// 将字节转换为字符串
fn bytes_to_string(buffer : Bytes, offset : Int, len : Int) -> String {
  let bytes = buffer[offset:offset + len]
  bytes.to_string()
}

///|
/// 读取 ZIP 中指定文件内容
pub fn read_file_entry(archive : ZipArchive, name : String) -> Bytes? {
  // 查找文件条目
  let mut found : ZipEntry? = None
  for entry in archive.entries {
    if entry.name == name {
      found = Some(entry)
    }
  }
  
  match found {
    Some(entry) => {
      // 读取文件数据
      let data_start = entry.data_offset + 30 + 
                       read_uint16_le(archive.data, entry.data_offset + 26).to_int() +
                       read_uint16_le(archive.data, entry.data_offset + 28).to_int()
      archive.data[data_start:data_start + entry.compressed_size]
    }
    None => None
  }
}
