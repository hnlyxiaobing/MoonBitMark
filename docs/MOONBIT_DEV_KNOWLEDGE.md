# MoonBit 开发与调试知识总结

> 从 MoonBitMark 项目中提炼的核心知识，用于指导 MoonBit 项目开发和调试

---

## 📋 MoonBit 常见错误与解决方案

### 1. String 切片操作
```moonbit
// ✅ 正确
let substring = s[start:end].to_string()
let from_start = s[start:].to_string()

// ⚠️ 注意：切片可能抛出异常，函数需声明 raise
fn process(s : String) -> String raise {
  s[0:5].to_string()
}
```

### 2. 错误处理声明
```moonbit
// ⚠️ 任何使用可能抛出异常的操作的函数都必须声明 raise
fn process(s : String) -> String raise {
  let part = s[0:5].to_string()
}
```

### 3. 可变变量声明
```moonbit
let mut counter = 1
counter = counter + 1  // 只有需要重新赋值的变量才用 mut
```

### 4. 方法调用 vs 函数调用
```moonbit
// ✅ MoonBit 使用方法调用，不是独立函数
s.to_lower()      // 不是 to_lowercase(s)
s.trim()
s.length()
s.find(pattern[:])
```

### 5. Array 初始化
```moonbit
// ✅ 需要类型注解
let cells : Array[String] = Array::new()
// 或
let cells = Array::new[String]()
```

### 6. 错误类型定义
```moonbit
// ✅ 使用 suberror，不是 enum
suberror MyError {
  NotFound
  InvalidInput(String)
}

fn f() -> Unit raise MyError { ... }
```

### 7. 模块导入

```
// moon.pkg 文件格式（新格式）
import {
  "moonbitlang/core/builtin",
  "moonbitlang/core/array",
  "moonbitlang/async/fs",
}
```

### 8. 类型定义
```moonbit
// ✅ 结构体使用 struct，不是 type
struct Point {
  x : Int
  y : Int
}

// ✅ 错误类型使用 suberror，不是 enum
suberror MyError {
  NotFound
  InvalidInput(String)
}
```

### 9. Bytes 构建
```moonbit
// ❌ Bytes 没有 op_set 方法
// bytes[idx] = byte  // 错误

// ✅ 使用 @buffer 构建 Bytes
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}
```

### 10. 可选值处理
```moonbit
// ❌ 没有问号操作符
// let x = opt?  // 错误

// ✅ 使用 match 或 if-is
match opt {
  Some(v) => v
  None => default
}

// 或
if opt is Some(v) {
  v
} else {
  default
}
```

### 11. 空代码块语法
```moonbit
// ❌ {} 表示空 Map，不是空代码块
if condition {
  {}  // 错误：这是一个空的 Map
}

// ✅ 使用 () 表示空操作
if condition {
  ()  // 正确：空语句
}
```

---

## 文件操作模式

### 读取文件到 Bytes
```moonbit
pub async fn read_file_to_bytes(file_path : String) -> Bytes raise {
  let file = @fs.open(file_path, mode=ReadOnly)
  // 获取文件大小
  let size = file.size()
  // 创建固定大小缓冲区
  let buffer : FixedArray[Byte] = FixedArray::make(size, b'\x00')
  // 读取文件
  let bytes_read = file.read(buffer)
  file.close()
  
  // 转换为 Bytes
  let arr : Array[Byte] = Array::new()
  for i = 0; i < bytes_read; i = i + 1 {
    arr.push(buffer[i])
  }
  bytes_from_array(arr)
}
```

---

## XML 解析模式

### SAX 风格事件驱动解析
```moonbit
pub enum ParseEvent {
  ElementStart(ElementStartEvent)  // <tag attr="value">
  ElementEnd(ElementEndEvent)      // </tag>
  TextContent(TextEvent)           // text content
}

// 使用示例
let events = @xml.parse_xml(xml_content)
for event in events {
  match event {
    { ElementStart: { name, attributes } } => 
      // 处理开始标签
    { ElementEnd: { name } } => 
      // 处理结束标签
    { TextContent: { content } } => 
      // 处理文本内容
  }
}
```

### 字符串切片与 raise
```moonbit
// 字符串切片函数必须声明 raise
fn parse_attribute(s : String, start : Int) -> (String, String, Int) raise {
  let name_end = find_char(s, '=', start)
  let name = s[start:name_end].to_string()
  // ...
}

// 使用 try/catch 处理错误
fn safe_parse(s : String) -> Result[Data, ParseError] {
  try {
    Ok(parse_internal(s))
  } catch {
    e => Error(ParseError::from(e))
  }
}
```

---

## FFI 绑定（已弃用）

> **注意:** 从 v0.4.0 开始，MoonBitMark 项目已完全移除 FFI 依赖，
> 使用纯 MoonBit 实现替代。以下内容仅作参考保留。

### FFI 声明模式
```moonbit
extern "c" {
  fn zip_open(path : String) -> ZipHandle
  fn zip_read(handle : ZipHandle, name : String) -> Bytes
  fn zip_close(handle : ZipHandle) -> Unit
}
```

### C 存根代码结构
```c
// stub.c
#include <moonbit/moonbit_runtime.h>

moonbit_bytes_t moonbit_zip_read(moonbit_bytes_t path, moonbit_bytes_t name) {
  // C 实现
  return moonbit_make_bytes(data, len);
}
```

### 内存管理要点
- MoonBit GC 管理 MoonBit 对象
- C 库管理 C 对象
- 使用 `moonbit_make_external_object` 包装 C 指针
- 字符串自动 null 终止

---

## 📁 项目结构规范

```
project/
├── src/
│   ├── core/              # 核心模块
│   ├── libzip/            # 纯 MoonBit ZIP 库
│   │   ├── crc32.mbt
│   │   ├── deflate.mbt
│   │   └── zip.mbt
│   ├── xml/               # 纯 MoonBit XML 解析器
│   │   ├── types.mbt
│   │   ├── tokenizer.mbt
│   │   └── package.mbt
│   ├── formats/           # 格式转换器
│   │   ├── html/
│   │   ├── pdf/
│   │   └── docx/
│   │       ├── converter.mbt
│   │       └── moon.pkg
│   └── cmd/
│       └── main/
├── tests/
│   └── test_data/
├── moon.mod.json
└── README.md
```

---

## 🛠️ 调试技巧

### 1. 使用 inspect 调试
```moonbit
test {
  let result = process(input)
  inspect(result, content="expected output")
}
```

### 2. 使用 guard 早期返回
```moonbit
fn safe_div(x : Int, y : Int) -> Int? {
  guard y != 0 else { None }
  Some(x / y)
}
```

### 3. 编译检查
```bash
moon check  # 检查类型错误
moon build  # 编译
moon run    # 运行
```

### 4. 查看文档
```bash
moon doc <package>  # 查看包文档
```

---

## 📦 依赖管理

### 添加依赖
```bash
moon add moonbitlang/async
```

### 常用包
- `moonbitlang/async/fs` - 文件系统
- `moonbitlang/async/http` - HTTP 客户端
- `moonbitlang/async/io` - I/O 操作
- `bobzhang/mbtpdf` - PDF 处理

### moon.pkg 配置
```
// 新格式 (moon.pkg)
import {
  "moonbitlang/moonbitmark/src/core",
  "moonbitlang/async/fs",
  "moonbitlang/core/buffer",
}
```

---

## 🌐 HTML/DOCX 转换技术要点

### HTML 转 Markdown
- 标题：`<h1>` → `#`
- 段落：`<p>` → 双换行
- 列表：`<ul>/<ol>` → `-` / `1.`
- 链接：`<a>` → `[text](url)`
- 代码：`<code>` → `` `code` ``
- 表格：`<table>` → Markdown 表格

### DOCX 转换流程
```
DOCX → ZIP 解压 (libzip) → XML → XML 解析 (expat) → Markdown
```

### URL 抓取
```moonbit
pub async fn convert_from_url(url : String) -> String raise {
  let (response, data) = @http.get(url)
  let html = data.text()  // Data.text() 自动 UTF-8 解码
  html_to_markdown(html)
}
```

---

## ⚡ 性能优化建议

1. **使用高级 API** - 让库处理底层细节
2. **流式处理大文件** - 避免一次性加载
3. **减少 FFI 调用次数** - 批量处理
4. **缓存常用结果** - 避免重复计算

---

## 📚 参考资源

- MoonBit 官方文档：https://mooncakes.io/docs/moonbitlang/core
- MoonBit 语言参考：`skills/moonbit-lang/reference/`
- MoonBit 最佳实践：`moonbit-agent-guide` skill
- C 绑定指南：`moonbit-c-binding` skill

---

---

## 🔧 libzip 纯 MoonBit 实现经验

### 已完成功能

- ✅ ZIP 结构解析
- ✅ Store 解压 (无压缩)
- ✅ Deflate 解压 (Fixed + Dynamic Huffman)
- ✅ CRC32 校验 (IEEE 802.3 标准)

### UInt 位运算变通方案

**问题：** `1.to_uint()` 返回 `Double` 类型，而非 `UInt`

**变通方案：**
```moonbit
// 使用取模判断奇偶
if n % 2.to_uint() != 0.to_uint() { ... }

// 使用 UInt 字面量
let mask : UInt = 0xFF
let result = a.land(mask)
```

### 函数可变参数

```moonbit
// ✅ 正确 - 只读访问
fn read(self : Decoder) -> Int

// ✅ 正确 - 需要修改
fn read(mut self : Decoder) -> Int {
  self.pos = self.pos + 1
}
```

---

## 🌐 HTML/DOCX 转换技术要点

### HTML 转 Markdown
- 标题：`<h1>` → `#`
- 段落：`<p>` → 双换行
- 列表：`<ul>/<ol>` → `-` / `1.`
- 链接：`<a>` → `[text](url)`
- 代码：`<code>` → `` `code` ``
- 表格：`<table>` → Markdown 表格

### DOCX 转换流程（纯 MoonBit）
```
DOCX → 读取 Bytes → ZIP 解析 (@libzip) → Deflate 解压 → XML 解析 (@xml) → Markdown
```

### URL 抓取
```moonbit
pub async fn convert_from_url(url : String) -> String raise {
  let (response, data) = @http.get(url)
  let html = data.text()  // Data.text() 自动 UTF-8 解码
  html_to_markdown(html)
}
```

---

**最后更新：** 2026-03-10  
**来源：** MoonBitMark 项目文档提炼
