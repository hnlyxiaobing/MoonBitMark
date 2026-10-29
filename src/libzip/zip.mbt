// libzip 主实现文件

///|
/// 单个归档允许的累计解压字节数上限（512 MiB）。
///
/// 单个条目上限（`zip_max_inflate_bytes`，256 MiB）挡不住「多个中等条目叠加」：
/// 一个只有几百 KB 的 docx / xlsx / epub 可以塞进上百个各解压到几十 MB 的
/// 条目，而媒体抽取路径（`extract_*_assets`）会把它们一次性读进内存。
/// 512 MiB 对最大 fixture 归档（解压累计 32.31 MiB）留了约 16 倍余量。
///
/// 该额度按归档为单位累计：`ZipArchive` 由 `open` 构造，额度随之重置，不做
/// 跨调用的全局可变状态（并发下不会串味）。计费以条目名为键替换旧值，因此
/// 重复读取同一条目不会重复消耗额度（读取结果保持幂等）。
let zip_max_archive_inflate_bytes : Int32 = 536870912

///|
/// ZIP 归档结构。
///
/// 外部包只能读取、不能构造或改写字段：解压额度计数若能被外部伪造，
/// 单条目与归档级解压上限都会失效。读取一律走本包公开方法。
pub struct ZipArchive {
  /// 原始数据
  data : Bytes
  /// 文件条目列表
  entries : Array[ZipEntry]
  /// 已计入解压额度的累计字节数
  mut inflate_bytes_used : Int32
  /// 各条目已计费的解压字节数（按条目名去重）
  charged_bytes : Map[String, Int32]
}

///|
/// ZIP 文件条目
struct ZipEntry {
  /// 文件名
  name : String
  /// 压缩方法
  compression_method : Int32
  /// 压缩大小
  compressed_size : Int32
  /// 原始大小
  uncompressed_size : Int32
  /// 数据偏移
  data_offset : Int32
  /// CRC32
  crc32 : UInt32
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
        Some(ZipArchive::{
          data: buffer,
          entries,
          inflate_bytes_used: 0,
          charged_bytes: Map([]),
        })
      }
      None => None
    }
  }
}

///|
/// 查找 EOCD (End of Central Directory) 记录
fn find_eocd(buffer : Bytes) -> Int32? {
  // EOCD 签名: 0x06054b50
  // 从文件末尾向前搜索
  let mut pos = buffer.length() - 22
  while pos >= 0 {
    if read_uint32_le(buffer, pos) == 0x06054b50 {
      return Some(pos)
    } else {
      pos = pos - 1
    }
  }
  None
}

///|
/// 读取小端序 UInt32
fn read_uint32_le(buffer : Bytes, offset : Int32) -> UInt32 {
  buffer[offset].to_uint() |
  (buffer[offset + 1].to_uint() << 8) |
  (buffer[offset + 2].to_uint() << 16) |
  (buffer[offset + 3].to_uint() << 24)
}

///|
/// 解析中央目录
fn parse_central_directory(
  buffer : Bytes,
  eocd_offset : Int32,
) -> Array[ZipEntry] {
  // 从 EOCD 获取中央目录偏移
  // EOCD 格式: 偏移16是中央目录偏移(4字节UInt32)
  let cd_offset = read_uint32_le(buffer, eocd_offset + 16).reinterpret_as_int()
  let num_entries = read_uint16_le(buffer, eocd_offset + 10).reinterpret_as_int()

  let entries : Array[ZipEntry] = Array(capacity=0)
  let mut pos = cd_offset
  let mut remaining = num_entries

  // 中央目录必须完全落在归档内；否则立即停止解析。
  if cd_offset < 0 || cd_offset > buffer.length() {
    return entries
  }

  while remaining > 0 {
    match parse_central_dir_entry(buffer, pos) {
      Some(entry) => {
        entries.push(entry.0)
        pos = pos + entry.1
        remaining = remaining - 1
      }
      None => break
    }
  }
  entries
}

///|
/// 读取小端序 UInt16
fn read_uint16_le(buffer : Bytes, offset : Int32) -> UInt32 {
  buffer[offset].to_uint() | (buffer[offset + 1].to_uint() << 8)
}

///|
/// 解析单个中央目录条目，返回条目本身与其占用的字节数。
/// 数据越界时返回 None。
fn parse_central_dir_entry(
  buffer : Bytes,
  offset : Int32,
) -> (ZipEntry, Int32)? {
  // Central Directory Header 固定部分 46 字节
  if offset < 0 || offset > buffer.length() || buffer.length() - offset < 46 {
    return None
  }
  let name_len = read_uint16_le(buffer, offset + 28).reinterpret_as_int()
  let extra_len = read_uint16_le(buffer, offset + 30).reinterpret_as_int()
  let comment_len = read_uint16_le(buffer, offset + 32).reinterpret_as_int()
  let entry_size = 46 + name_len + extra_len + comment_len
  if entry_size > buffer.length() - offset {
    return None
  }

  // 读取文件名
  let name_start = offset + 46
  let name = bytes_to_string(buffer, name_start, name_len)

  let entry = ZipEntry::{
    name,
    compression_method: read_uint16_le(buffer, offset + 10).reinterpret_as_int(),
    compressed_size: read_uint32_le(buffer, offset + 20).reinterpret_as_int(),
    uncompressed_size: read_uint32_le(buffer, offset + 24).reinterpret_as_int(),
    data_offset: read_uint32_le(buffer, offset + 42).reinterpret_as_int(),
    crc32: read_uint32_le(buffer, offset + 16),
  }
  Some((entry, entry_size))
}

///|
/// 将字节转换为字符串
fn bytes_to_string(buffer : Bytes, offset : Int32, len : Int32) -> String {
  let bytes = if offset < 0 ||
    len < 0 ||
    offset > buffer.length() ||
    len > buffer.length() - offset {
    b""
  } else {
    buffer[offset:offset + len].to_owned()
  }
  // 使用 UTF-8 解码，如果失败则尝试直接转换
  @utf8.decode(bytes) catch {
    _ => {
      // 回退到逐字节转换（ASCII 兼容）
      let mut result = ""
      let mut i = 0
      while i < bytes.length() {
        let b = bytes[i]
        // 简单地将字节转为字符
        result = result + b.to_int().unsafe_to_char().to_string()
        i = i + 1
      }
      result
    }
  }
}

///|
/// 计算条目数据在归档中的字节区间，返回 (start, end)。
/// 本地文件头越界或压缩尺寸非法时返回 None。
fn zip_entry_data_range(data : Bytes, entry : ZipEntry) -> (Int32, Int32)? {
  let header = entry.data_offset
  if header < 0 || header > data.length() {
    return None
  }
  let remaining = data.length() - header
  // 本地文件头固定 30 字节，必须完整位于归档内
  if remaining < 30 {
    return None
  }
  let name_len = read_uint16_le(data, header + 26).reinterpret_as_int()
  let extra_len = read_uint16_le(data, header + 28).reinterpret_as_int()
  // 30 + 65535 + 65535 不会溢出 Int32
  let overhead = 30 + name_len + extra_len
  if overhead > remaining {
    return None
  }
  let data_start = header + overhead
  let size = entry.compressed_size
  if size < 0 || size > data.length() - data_start {
    return None
  }
  Some((data_start, data_start + size))
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
    Some(entry) =>
      // 读取文件数据
      match zip_entry_data_range(archive.data, entry) {
        Some(range) => Some(archive.data[range.0:range.1].to_owned())
        None => None
      }
    None => None
  }
}

///|
/// 关闭 ZIP 归档 (MoonBit 自动管理内存，此函数为兼容 API)
pub fn close_archive(archive : ZipArchive) -> Unit {
  ignore(archive)
}

///|
/// 获取 ZIP 归档中的文件列表
pub fn ZipArchive::list_entries(self : ZipArchive) -> Array[String] {
  let names : Array[String] = Array(capacity=0)
  for entry in self.entries {
    names.push(entry.name)
  }
  names
}

///|
/// 检查 ZIP 中是否存在指定文件
pub fn ZipArchive::has_file(self : ZipArchive, name : String) -> Bool {
  for entry in self.entries {
    if entry.name == name {
      return true
    }
  }
  false
}

///|
/// 记录某个条目已解压的字节数，并检查归档累计上限。
///
/// 以条目名为键替换旧值，保证同一条目被重复读取时不会重复计费。
/// 返回 false 表示累计已超限，调用方应按「条目损坏」处理。
fn ZipArchive::charge_inflate_bytes(
  self : ZipArchive,
  name : String,
  bytes : Int32,
  limit : Int32,
) -> Bool {
  let previous = match self.charged_bytes.get(name) {
    Some(value) => value
    None => 0
  }
  let base = self.inflate_bytes_used - previous
  if bytes > limit - base {
    return false
  }
  self.charged_bytes[name] = bytes
  self.inflate_bytes_used = base + bytes
  true
}

///|
/// 读取 ZIP 中指定文件内容（自动解压）。
///
/// 失败一律返回 `None`；需要区分「超限 / CRC 不符 / 数据损坏」请用
/// `read_file_entry_decompressed_checked`。
pub fn read_file_entry_decompressed(
  archive : ZipArchive,
  name : String,
) -> Bytes? {
  let bytes = read_file_entry_decompressed_limited(
    archive,
    name,
    zip_max_inflate_bytes,
    zip_max_archive_inflate_bytes,
  ) catch {
    _ => return None
  }
  Some(bytes)
}

///|
/// 读取 ZIP 中指定文件内容（自动解压），失败时抛出可诊断的 `ZipError`。
///
/// 解压超限时错误串为 `decompression size limit exceeded: limit=<N> bytes`，
/// 与「压缩数据损坏」（`compressed data is corrupt`）和 CRC 不符
/// （`CrcMismatch`）平级，上层可据此给出不同于「文件不存在」的诊断。
pub fn read_file_entry_decompressed_checked(
  archive : ZipArchive,
  name : String,
) -> Bytes raise ZipError {
  read_file_entry_decompressed_limited(
    archive,
    name,
    zip_max_inflate_bytes,
    zip_max_archive_inflate_bytes,
  )
}

///|
/// 读取并解压单个条目，`max_bytes` 为单条目上限，`archive_limit` 为归档累计上限。
fn read_file_entry_decompressed_limited(
  archive : ZipArchive,
  name : String,
  max_bytes : Int32,
  archive_limit : Int32,
) -> Bytes raise ZipError {
  // 查找文件条目
  let mut found_entry : ZipEntry? = None
  for entry in archive.entries {
    if entry.name == name {
      found_entry = Some(entry)
    }
  }
  let entry = match found_entry {
    Some(value) => value
    None => raise FileNotFound(name)
  }
  // 读取文件数据
  let range = match zip_entry_data_range(archive.data, entry) {
    Some(value) => value
    None => raise CorruptedHeader
  }
  let compressed_data = archive.data[range.0:range.1].to_owned()
  // 条目声明的解压后大小超过上限时直接拒绝：`uncompressed_size` 由打包方
  // 填写，谎报成更大值没有意义，先挡一层最省事（谎报成更小值由下面的实际
  // 输出上限兜住）。
  let declared_size = entry.uncompressed_size
  if declared_size > max_bytes {
    raise DecompressFailed(
      "decompression size limit exceeded: limit=" +
      max_bytes.to_string() +
      " bytes, declared=" +
      declared_size.to_string() +
      " bytes",
    )
  }

  // 根据压缩方法处理
  let inflated : Bytes = match compression_method_from_int(
    entry.compression_method,
  ) {
    Store(_) =>
      // 未压缩条目同样受上限约束
      if compressed_data.length() > max_bytes {
        raise DecompressFailed(
          "decompression size limit exceeded: limit=" +
          max_bytes.to_string() +
          " bytes",
        )
      } else {
        compressed_data
      }
    Deflate(_) =>
      match deflate_decompress_limited(compressed_data, max_bytes) {
        Ok(value) => value
        Err(SizeLimitExceeded(limit)) =>
          raise DecompressFailed(
            "decompression size limit exceeded: limit=" +
            limit.to_string() +
            " bytes",
          )
        Err(Corrupt) => raise DecompressFailed("compressed data is corrupt")
      }
    Unknown(code) => raise UnsupportedMethod(code)
  }

  // CRC32 校验：只在中央目录记录了非 0 值时进行（部分打包器对目录条目与
  // 空文件写 0）。不一致说明条目已损坏或被篡改，按「条目损坏」处理，与
  // 上面各失败分支返回同一种形态。
  if entry.crc32 != 0 && crc32(inflated) != entry.crc32 {
    raise CrcMismatch
  }

  // 归档累计上限
  if !archive.charge_inflate_bytes(name, inflated.length(), archive_limit) {
    raise DecompressFailed(
      "decompression size limit exceeded: archive limit=" +
      archive_limit.to_string() +
      " bytes",
    )
  }
  inflated
}
