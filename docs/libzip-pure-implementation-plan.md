# MoonBit 纯实现 libzip 库开发计划

## 执行摘要

本项目旨在用纯 MoonBit 实现一个 ZIP 解析库，完全替代当前通过 FFI 调用的 C 语言 libzip 库。实现后将获得更好的跨平台兼容性、内存安全性和开发体验，同时保持性能不低于原实现。

**关键优势**:
- ✅ 零外部依赖，纯 MoonBit 实现
- ✅ 与现有 API 完全兼容，平滑迁移
- ✅ 性能目标 ≥ 原 C 实现的 90%
- ✅ 自动内存管理，无需手动释放
- ✅ 支持流式读取大文件
- ✅ 完整的测试覆盖

## 1. 项目背景

### 1.1 当前状态

当前 MoonBitMark 项目在处理 DOCX 文件时，通过 FFI 调用 C 语言的 libzip 库来解压 ZIP 格式的 DOCX 文件。

**现有 FFI 接口** (`src/formats/docx/ffi/libzip/libzip.mbt`):
- `ZipHandle` - ZIP 归档句柄
- `zip_open_from_buffer` - 从内存缓冲区打开 ZIP
- `zip_close` - 关闭归档
- `zip_fopen` - 打开归档内的文件
- `zip_fread` - 读取文件内容
- `zip_fclose` - 关闭文件
- `zip_stat` - 获取文件统计信息

### 1.2 目标

用纯 MoonBit 实现一个 ZIP 解析库，替代 FFI 依赖的 libzip，实现：
- 无外部 C 库依赖
- 跨平台兼容性（Windows/Linux/macOS）
- 支持 DOCX 文件所需的 ZIP 功能
- 性能不低于原 C 实现
- API 使用便捷性优于原 FFI 接口

## 1.3 API 对比分析

| 原 FFI 接口 | MoonBit 实现 | 改进点 |
|-------------|--------------|--------|
| `ZipHandle::open(buffer)` | `ZipArchive::open(buffer)` | 相同签名，类型更安全 |
| `read_file_entry(archive, name)` | `read_file_entry(archive, name)` | 完全一致 |
| `zip_close(archive)` | `close_archive(archive)` | 语义更清晰 |
| 手动内存管理 | 自动 GC | 无需手动释放 |
| 同步阻塞 | 支持异步流式 | 更好的大文件支持 |

## 2. ZIP 格式技术分析

### 2.1 ZIP 文件结构

```
[Local File Header 1]
[File Data 1]
[Data Descriptor 1 (可选)]
...
[Local File Header N]
[File Data N]
[Data Descriptor N (可选)]
[Central Directory Header 1]
...
[Central Directory Header N]
[End of Central Directory Record]
```

### 2.2 核心数据结构

| 结构 | 偏移 | 大小 | 说明 |
|------|------|------|------|
| Local File Header | 0 | 30+ | 文件头 |
| Central Directory | - | 46+ | 中央目录 |
| EOCD Record | - | 22 | 结束记录 |

### 2.3 需要实现的压缩算法

DOCX 文件通常使用的压缩方式：
- **Store (0)** - 无压缩（常用）
- **Deflate (8)** - DEFLATE 压缩（常用）

## 3. API 设计规范

### 3.1 核心 API (与现有 FFI 完全兼容)

```moonbit
///|
/// ZIP 归档句柄 (对应原 ZipHandle)
pub(all) type ZipArchive

///|
/// 从内存缓冲区打开 ZIP 归档
pub fn ZipArchive::open(buffer : Bytes) -> ZipArchive?

///|
/// 读取 ZIP 中指定文件 (直接返回 Bytes)
pub fn read_file_entry(archive : ZipArchive, name : String) -> Bytes?

///|
/// 关闭 ZIP 归档
pub fn close_archive(archive : ZipArchive) -> Unit
```

### 3.2 增强 API (性能优化版本)

```moonbit
///|
/// 高效批量读取多个文件
pub fn read_multiple_files(archive : ZipArchive, names : Array[String]) -> Map[String, Bytes?]

///|
/// 流式读取大文件 (避免一次性加载到内存)
pub fn stream_file_reader(archive : ZipArchive, name : String) -> FileStream?
```

### 3.2 错误类型 (与原 FFI 兼容)

```moonbit
pub suberror ZipError {
  InvalidSignature      // 无效的 ZIP 签名
  CorruptedHeader       // 损坏的文件头
  FileNotFound(String)  // 文件不存在 (对应原 FFI 返回 None)
  UnsupportedMethod(Int) // 不支持的压缩方法
  DecompressFailed(String) // 解压失败
  CrcMismatch           // CRC 校验失败
  MemoryAllocationFailed // 内存分配失败
  InvalidParameter       // 无效参数
}
```

### 3.3 性能优化特性

| 特性 | 原 C libzip | MoonBit 实现目标 |
|------|-------------|------------------|
| 内存管理 | 手动管理 | 自动垃圾回收 |
| 零拷贝读取 | 部分支持 | 完全支持 |
| 并行处理 | 无 | 异步流式读取 |
| 缓存机制 | 简单缓存 | 智能预读缓存 |

### 3.4 兼容性保证

**API 层面**:
- 保持函数签名兼容: `ZipHandle::open` → `ZipArchive::open`
- 错误处理一致: 返回 `Option[T]` 而非抛出异常
- 内存安全: 无需手动释放资源

**行为层面**:
- 文件顺序: 保持原有遍历顺序
- 编码处理: UTF-8 文件名支持
- 压缩算法: 优先支持 Store(0) 和 Deflate(8)

### 3.5 迁移策略

**Phase 1**: 并行实现
- 保留原 FFI 代码
- 新增纯 MoonBit 实现
- 通过编译开关切换

**Phase 2**: 逐步替换
- 修改 DOCX 转换器调用新 API
- 移除 FFI 依赖
- 清理旧代码

**Phase 3**: 优化升级
- 启用增强 API
- 性能调优
- 完善错误处理

## 4. 使用 Spec-Test-Development 流程

### 4.1 为什么适合使用此流程

| 适用性 | 说明 |
|--------|------|
| API 明确 | ZIP 解析有清晰的接口定义 |
| 标准格式 | ZIP 格式规范明确，测试用例可预测 |
| 分层实现 | 可以先定义接口，再逐步实现各层 |
| 独立模块 | libzip 是独立包，便于测试隔离 |

### 4.2 开发流程

```
Step 1: 创建 spec 文件 (zip_spec.mbt)
    |
Step 2: 编写测试用例
    |
Step 3: moon check 验证类型
    |
Step 4: 实现 zip.mbt
    |
Step 5: moon test 验证功能
```

### 4.3 Spec 文件示例

文件: `src/libzip/zip_spec.mbt`

```moonbit
///|
pub(all) suberror ZipError {
  InvalidSignature
  CorruptedHeader
  FileNotFound(String)
  UnsupportedMethod(Int)
  DecompressFailed(String)
  CrcMismatch
} derive(Show, Eq)

///|
#declaration_only
pub type ZipArchive

///|
#declaration_only
pub fn ZipArchive::from_bytes(data : Bytes) -> Result[ZipArchive, ZipError] {
  ...
}
```

## 5. 实现计划

### 5.1 阶段划分

| 阶段 | 内容 | 优先级 |
|------|------|--------|
| Phase 1 | ZIP 结构解析 (读取目录) | 高 |
| Phase 2 | Store 解压 (无压缩) | 高 |
| Phase 3 | Deflate 解压 | 中 |
| Phase 4 | CRC 校验 | 中 |
| Phase 5 | 错误处理完善 | 低 |

### 5.2 文件结构

```
src/libzip/
├── moon.pkg.json
├── zip_spec.mbt          # API 规范
├── zip.mbt               # 主实现
├── zip_easy_test.mbt     # 基础测试
├── zip_mid_test.mbt      # 中等测试
├── zip_difficult_test.mbt # 复杂测试
├── format.mbt            # ZIP 格式定义
├── deflate.mbt           # Deflate 解压
└── crc32.mbt             # CRC32 校验
```

### 5.3 性能基准测试

**性能目标** (相比原 C libzip):
- 启动时间: ≤ 110% (允许轻微增加)
- 读取速度: ≥ 90% (接近原生性能)
- 内存占用: ≤ 120% (GC 开销可接受)
- 大文件处理: 支持流式读取

**性能优化措施**:
- 零拷贝解析: 直接操作字节数组
- 懒加载: 按需解析中央目录
- 缓存机制: LRU 缓存常用文件
- 并行处理: 多核解压支持

**zip_easy_test.mbt** - 基础测试：
```moonbit
test "parse empty zip" { ... }
test "parse single file zip (store)" { ... }
test "read small file (<1KB)" { ... }
```

**zip_mid_test.mbt** - 中等测试：
```moonbit
test "parse multi-file zip (10 files)" { ... }
test "read medium file (100KB)" { ... }
test "deflate decompression" { ... }
```

**zip_performance_test.mbt** - 性能测试：
```moonbit
test "read large docx (10MB) performance" { ... }
test "batch read 100 small files" { ... }
test "memory usage under load" { ... }
```

## 6. ZIP 格式详细规范

### 6.1 Local File Header (30 bytes + variable)

| 偏移 | 大小 | 字段 | 值 |
|------|------|------|-----|
| 0 | 4 | 签名 | 0x04034b50 |
| 4 | 2 | 版本 | - |
| 6 | 2 | 标志 | - |
| 8 | 2 | 压缩方法 | 0=Store, 8=Deflate |
| 10 | 2 | 修改时间 | - |
| 12 | 2 | 修改日期 | - |
| 14 | 4 | CRC32 | - |
| 18 | 4 | 压缩大小 | - |
| 22 | 4 | 原始大小 | - |
| 26 | 2 | 文件名长度 | - |
| 28 | 2 | 扩展字段长度 | - |

### 6.2 End of Central Directory Record (22 bytes)

| 偏移 | 大小 | 字段 | 值 |
|------|------|------|-----|
| 0 | 4 | 签名 | 0x06054b50 |
| 4 | 2 | 磁盘号 | - |
| 6 | 2 | 中央目录起始磁盘 | - |
| 8 | 2 | 本磁盘记录数 | - |
| 10 | 2 | 总记录数 | - |
| 12 | 4 | 中央目录大小 | - |
| 16 | 4 | 中央目录偏移 | - |
| 20 | 2 | 注释长度 | - |

## 7. 开发命令

```bash
# 创建模块
moon new moonbitlang/libzip

# 类型检查
moon check

# 运行测试
moon test

# 更新快照
moon test --update

# 格式化
moon fmt

# 最终步骤
moon info && moon fmt
```

## 8. 使用便捷性提升

**相比原 FFI 的优势**:
- **类型安全**: 编译时检查，减少运行时错误
- **自动内存管理**: 无需手动释放资源
- **异常安全**: 统一错误处理机制
- **异步支持**: 流式读取大文件
- **调试友好**: 源码级调试，堆栈跟踪

**开发者体验**:
- 热重载支持
- 详细错误提示
- IDE 集成补全
- 单元测试框架

## 9. 完整的开发实施步骤

### 7.1 环境准备
```bash
# 创建独立模块
cd src/
mkdir libzip
cd libzip
moon new moonbitlang/libzip
```

### 7.2 Spec 开发阶段
```moonbit
// zip_spec.mbt
#declaration_only
pub type ZipArchive
pub fn ZipArchive::open(buffer: Bytes) -> ZipArchive?
pub fn read_file_entry(archive: ZipArchive, name: String) -> Bytes?
pub fn close_archive(archive: ZipArchive) -> Unit
```

### 7.3 实现优先级
1. **Week 1**: ZIP 结构解析 + Store 解压
2. **Week 2**: Deflate 解压算法
3. **Week 3**: 性能优化 + 缓存机制
4. **Week 4**: 集成测试 + 性能调优

## 10. 风险评估与应对

| 风险 | 概率 | 影响 | 应对措施 |
|------|------|------|----------|
| 性能不如 C 实现 | 中 | 高 | 分阶段优化，保持 FFI 备选 |
| Deflate 算法复杂 | 中 | 中 | 优先实现 Store，Deflate 后期优化 |
| 内存占用过高 | 低 | 中 | GC 调优，流式处理 |

## 11. 验收标准

**功能性**:
- [x] 能正确解析标准 ZIP 文件
- [x] 支持 Store(0) 和 Deflate(8) 压缩
- [x] 正确处理 UTF-8 文件名
- [x] 完整提取 DOCX 内部文件

**性能性**:
- [ ] 读取速度 ≥ 原 C 实现的 90%
- [ ] 内存占用 ≤ 原实现的 120%
- [ ] 支持 100MB+ DOCX 文件

**易用性**:
- [x] API 与 FFI 完全兼容
- [x] 自动内存管理
- [x] 详细错误信息

## 11.1 实现经验与踩坑记录

### Deflate 解压实现要点

#### 1. 位读取方向

DEFLATE 中有两种位读取方式：
- **LSB-first**: 字段值读取（如 hlit, hdist, hclen）
- **MSB-first**: Huffman 码读取

```moonbit
// LSB-first: 直接读取
fn read_bits(self : BitReader, count : Int) -> Result[Int, String] {
  // 低位先读，结果直接或上去
  result = result | (bits << bits_read)
}

// MSB-first: 每次左移结果
fn read_bits_reverse(self : BitReader, count : Int) -> Result[Int, String] {
  // 高位先读，结果左移后加入新位
  result = (result << 1) | bit
}
```

#### 2. 滑动窗口复制

**关键点**: 复制源位置必须在循环开始前固定，不能随 window_pos 变化。

```moonbit
// ✅ 正确实现
let copy_start = window_pos - distance
for j in 0..<length {
  let src_pos = (copy_start + j) & 0x7FFF
  // ...
  window_pos = (window_pos + 1) & 0x7FFF
}

// ❌ 错误实现（会导致输出损坏）
for j in 0..<length {
  let src_pos = (window_pos - distance + j) & 0x7FFF  // window_pos 在变！
  // ...
  window_pos = (window_pos + 1) & 0x7FFF
}
```

#### 3. Huffman 树构建

使用 RFC 1951 规范的 canonical Huffman 编码：
1. 统计每个码长的符号数量
2. 计算每个码长的起始码值
3. 按码长和符号顺序分配码字

### 已解决的 Bug

| Bug | 症状 | 原因 | 解决方案 |
|-----|------|------|----------|
| 位读取方向 | Huffman 解码错误 | MSB-first 实现错误 | 逐位读取，每次左移 |
| 滑动窗口 | 输出部分损坏 | window_pos 在循环中变化 | 提前保存 copy_start |

## 12. 参考资源

- [ZIP File Format Specification](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)
- [RFC 1951 - DEFLATE Compressed Data Format](https://tools.ietf.org/html/rfc1951)
- 现有 FFI 实现: `src/formats/docx/ffi/libzip/`
- MoonBit 异步编程指南

## 13. 结论与下一步

通过遵循此开发计划，我们将获得一个完全由 MoonBit 实现的 ZIP 解析库，能够无缝替换现有的 C libzip FFI 绑定。该实现将提供更好的开发体验和跨平台兼容性，同时保持甚至超越原有的性能表现。

**立即行动项**:
1. 创建 `src/libzip/` 目录结构
2. 初始化 moon.pkg.json
3. 开始 Spec 文件编写
4. 按阶段实现核心功能

此计划确保了开发过程的可控性和最终成果的质量，为 MoonBitMark 项目的长期发展奠定基础。
