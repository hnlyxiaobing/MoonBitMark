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
```json
// ✅ 导入具体的子包
{
  "import": [
    "moonbitlang/core/builtin",
    "moonbitlang/core/array",
    "moonbitlang/async/fs"
  ]
}
```

---

## 🔧 FFI 绑定最佳实践

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

### 性能优化
- **批量 FFI 调用** - 减少调用次数
- **流式处理** - 降低内存占用
- **结果缓存** - 避免重复查询
- **FFI 开销** - 约 50-500 纳秒/次，通常 < 5% 总耗时

---

## 📁 项目结构规范

```
project/
├── src/
│   ├── core/              # 核心模块
│   ├── formats/           # 格式转换器
│   │   ├── html/
│   │   ├── pdf/
│   │   └── docx/
│   │       ├── converter.mbt
│   │       ├── ffi/
│   │       │   ├── libzip.mbt
│   │       │   ├── expat.mbt
│   │       │   └── stub.c
│   │       └── moon.pkg.json
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

### moon.pkg.json 配置
```json
{
  "import": [
    "moonbitlang/moonbitmark/src/core",
    "moonbitlang/async/fs"
  ],
  "native-stub": ["ffi/stub.c"],
  "link": {
    "native": {
      "cc-link-flags": "-lzip -lexpat"
    }
  }
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

### UInt 位运算限制

**问题：** MoonBit 的 `UInt` 类型在位运算时有类型限制

```moonbit
// ❌ 错误 - 类型不匹配
if (crc & 1.to_uint()) == 1.to_uint() { ... }

// ⚠️ 变通方案 - 使用取模判断奇偶
if n % 2.to_uint() != 0.to_uint() { ... }
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

## 📝 当前已知问题

### 1. CRC32 完整实现受限
- **状态：** 简化实现（求和）
- **原因：** UInt 位运算类型限制

### 2. Deflate 完整实现受限
- **状态：** 简化实现（直通）
- **原因：** Huffman 解码复杂度高

---

**最后更新：** 2026-03-10  
**来源：** MoonBitMark 项目文档提炼
