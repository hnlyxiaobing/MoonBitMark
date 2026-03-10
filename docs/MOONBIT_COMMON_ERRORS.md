# MoonBit 常见错误总结

本文档记录在 MoonBitMark 项目开发过程中遇到的常见错误和解决方案。

---

## 1. String 切片操作

### ❌ 错误写法
```moonbit
let substring = s.substring(start, end).to_string()  // 参数数量错误
```

### ✅ 正确写法
```moonbit
let substring = s[start:end].to_string()  // 使用切片语法
let from_start = s[start:].to_string()    // 从 start 到结尾
let to_end = s[:end].to_string()          // 从开头到 end
```

### 📝 注意
- 切片操作可能抛出异常（越界），函数需要声明 `raise`
- `StringView` 需要调用 `.to_string()` 转换为 `String`

---

## 2. 函数错误处理声明

### ❌ 错误写法
```moonbit
fn process(s : String) -> String {
  let part = s[0:5].to_string()  // 使用切片但未声明 raise
}
```

### ✅ 正确写法
```moonbit
fn process(s : String) -> String raise {
  let part = s[0:5].to_string()  // 声明 raise
}
```

### 📝 规则
- 任何使用可能抛出异常的操作的函数都必须声明 `raise`
- 错误会向上传播，调用者需要处理或继续声明 `raise`

---

## 3. 可变变量声明

### ❌ 错误写法
```moonbit
let counter = 1
counter = counter + 1  // 错误：counter 不可变
```

### ✅ 正确写法
```moonbit
let mut counter = 1
counter = counter + 1  // 正确：声明为可变
```

### 📝 注意
- `let` 声明的变量默认不可变
- 只有需要重新赋值的变量才用 `let mut`
- 可变容器（如 `Array`）本身不需要 `mut`，除非要重新赋值整个容器

---

## 4. 方法调用 vs 函数调用

### ❌ 错误写法
```moonbit
let lower = to_lowercase(s)  // 不存在独立函数
```

### ✅ 正确写法
```moonbit
let lower = s.to_lower()  // 使用方法调用
```

### 📝 常见方法
- `s.to_lower()` - 转小写（不是 `to_lowercase()`）
- `s.trim()` - 去除空白
- `s.length()` - 获取长度
- `s.find(pattern[:])` - 查找子串
- `s.split(delimiter)` - 分割字符串

---

## 5. Array 初始化

### ❌ 错误写法
```moonbit
let mut cells = Array::new()
cells.push(content)  // 类型推断问题
```

### ✅ 正确写法
```moonbit
let cells : Array[String] = Array::new()
cells.push(content)

// 或者直接初始化
let cells = Array::new[String]()
```

---

## 6. 模式匹配语法

### ❌ 错误写法
```moonbit
match opt {
  Some(x) => ...
  // 缺少 None 分支
}
```

### ✅ 正确写法
```moonbit
match opt {
  Some(x) => ...
  None => ...
}

// 或使用 if-let
if opt is Some(x) {
  ...
}
```

---

## 7. 错误类型定义

### ❌ 错误写法
```moonbit
enum MyError {
  NotFound
  InvalidInput(String)
}

fn f() -> Unit raise MyError { ... }  // 不能直接用 enum
```

### ✅ 正确写法
```moonbit
suberror MyError {
  NotFound
  InvalidInput(String)
}

fn f() -> Unit raise MyError { ... }
```

### 📝 注意
- 使用 `suberror` 定义错误类型，不是 `enum`
- `Error` 是通用错误类型，可以自动转换

---

## 8. 循环变量

### ❌ 错误写法
```moonbit
for i = 0; i < n; i = i + 1 {
  // i 在循环内不可变
}
```

### ✅ 正确写法
```moonbit
// 方式 1：C 风格循环，i 不可变
for i = 0; i < n; i = i + 1 {
  // 使用 i
}

// 方式 2：范围循环
for i in 0..<n {
  // 使用 i
}

// 方式 3：需要可变状态时用 let mut
let mut acc = 0
for i in 0..<n {
  acc = acc + i
}
```

---

## 9. 函数别名和方法

### ❌ 错误写法
```moonbit
let result = find_from(haystack, needle, start)  // 不存在独立函数
```

### ✅ 正确写法
```moonbit
// 自定义函数需要自己定义
fn find_from(haystack : String, needle : String, start : Int) -> Option[Int] raise {
  if start >= haystack.length() {
    None
  } else {
    let substring = haystack[start:].to_string()
    match substring.find(needle[:]) {
      Some(pos) => Some(start + pos)
      None => None
    }
  }
}
```

### 📝 MoonBit 标准库方法
- `s.find(pattern[:])` - 从头查找
- 没有内置的 `find_from()`，需要自己实现

---

## 10. 类型注解

### ❌ 错误写法
```moonbit
fn process(data) -> String {  // 缺少参数类型注解
  data.to_string()
}
```

### ✅ 正确写法
```moonbit
fn process(data : String) -> String {
  data.to_string()
}

// 顶层函数必须有完整的类型注解
```

### 📝 规则
- 顶层函数：参数和返回值都必须有类型注解
- 局部函数：可以省略，由编译器推断
- 泛型函数：需要声明类型参数 `[T]`

---

## 11. 泛型语法

### ❌ 错误写法
```moonbit
fn map(array, f) -> Array {  // 缺少泛型参数
  ...
}
```

### ✅ 正确写法
```moonbit
fn[S, T] map(array : Array[S], f : (S) -> T) -> Array[T] {
  let result = Array::new[T]()
  for item in array {
    result.push(f(item))
  }
  result
}
```

---

## 12. 错误传播

### ❌ 错误写法
```moonbit
fn outer() -> String raise {
  let result = inner()  // inner() 可能抛出错误
  result
}
```

### ✅ 正确写法
```moonbit
fn outer() -> String raise {
  let result = try! inner()  // 显式传播错误
  result
}

// 或直接调用（自动传播）
fn outer() -> String raise {
  inner()  // 错误自动向上传播
}
```

---

## 13. 条件表达式

### ❌ 错误写法
```moonbit
if condition {
  // MoonBit 的 if 必须有花括号
}

let value = if x > 0 { 1 }  // 缺少 else 分支（非 Unit 类型）
```

### ✅ 正确写法
```moonbit
if condition {
  // 正确
}

let value = if x > 0 { 1 } else { 0 }  // 完整 if-else

// else 可以省略的情况：返回 Unit
if condition {
  println("hello")
}
```

---

## 14. 模块导入

### ❌ 错误写法
```json
{
  "import": ["moonbitlang/core"]  // 太宽泛
}
```

### ✅ 正确写法
```json
{
  "import": [
    "moonbitlang/core/builtin",
    "moonbitlang/core/array",
    "moonbitlang/async/fs"
  ]
}
```

### 📝 规则
- 导入具体的子包，不是整个包
- 使用 `test-import` 导入仅用于测试的依赖

---

## 15. 类型定义语法

### ❌ 错误写法
```moonbit
// type 用于类型别名，不是结构体
type Point {
  x : Int
  y : Int
}
```

### ✅ 正确写法
```moonbit
// 结构体使用 struct
struct Point {
  x : Int
  y : Int
}

// 类型别名使用 type
type Coordinate = Int
type Name = String
```

### 📝 规则
- `struct` 用于定义结构体（记录类型）
- `type` 用于定义类型别名
- `enum` 用于定义枚举
- `suberror` 用于定义错误类型

---

## 16. Bytes 构建

### ❌ 错误写法
```moonbit
let bytes : Bytes = ...
bytes[idx] = byte  // Bytes 没有 op_set 方法
```

### ✅ 正确写法
```moonbit
// 使用 @buffer 构建 Bytes
let buf = @buffer.new()
buf.write_byte(b'\x41')
buf.write_byte(b'\x42')
let bytes = buf.to_bytes()

// 或从 Array[Byte] 转换
fn array_to_bytes(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}
```

### 📝 注意
- `Bytes` 类型不支持直接索引赋值
- 需要导入 `moonbitlang/core/buffer`

---

## 17. 空代码块语法

### ❌ 错误写法
```moonbit
if condition {
  {}  // 这是空的 Map，不是空语句
}
```

### ✅ 正确写法
```moonbit
if condition {
  ()  // 正确：空语句（Unit）
}

// 或者直接省略
if condition {
  // do nothing
}
```

### 📝 规则
- `{}` 是空的 Map 字面量
- `()` 是 Unit 类型，表示空操作
- 分支必须有返回值或 Unit

---

## 18. 可选值问号操作符

### ❌ 错误写法
```moonbit
let value = opt?  // MoonBit 没有问号操作符
```

### ✅ 正确写法
```moonbit
// 方式 1：使用 match
let value = match opt {
  Some(v) => v
  None => default_value
}

// 方式 2：使用 if-is
let value = if opt is Some(v) {
  v
} else {
  default_value
}

// 方式 3：使用 unwrap（可能崩溃）
let value = opt.unwrap()
```

---

## 19. 字符串切片与函数签名

### ❌ 错误写法
```moonbit
fn get_prefix(s : String) -> String {
  s[0:5].to_string()  // 未声明 raise
}
```

### ✅ 正确写法
```moonbit
fn get_prefix(s : String) -> String raise {
  s[0:5].to_string()
}

// 或使用 try/catch 包装
fn safe_get_prefix(s : String) -> String {
  try {
    s[0:5].to_string()
  } catch {
    _ => ""
  }
}
```

### 📝 规则
- 字符串切片可能抛出越界异常
- 所有使用切片的函数必须声明 `raise`
- 错误会向上传播到调用链

---

## 20. 循环语法

### ❌ 错误写法
```moonbit
loop {
  // 没有使用 continue 的 loop 是无用的
}
```

### ✅ 正确写法
```moonbit
// 无限循环使用 while true
while true {
  if done { break }
  // ...
}

// 或使用带条件的 loop
loop {
  if done { break }
  // ...
  continue  // 必须有 continue 才有意义
}
```

---

### 使用 `inspect` 代替 `println`
```moonbit
test {
  let result = process(input)
  inspect(result, content="expected output")
}
```

### 使用 `guard` 进行早期返回
```moonbit
fn safe_div(x : Int, y : Int) -> Int? {
  guard y != 0 else { None }
  Some(x / y)
}
```

---

## 资源链接

- MoonBit 官方文档：https://mooncakes.io/docs/moonbitlang/core
- MoonBit 语言参考：`D:\MySoftware\MoonBit\skills\moonbit-lang\reference\`
- MoonBit 最佳实践：参考 `moonbit-agent-guide` skill

---

**最后更新：** 2026-03-10  
**项目：** MoonBitMark
