// MoonBitMark MCP JSON Parser Tests

use @json_parser.*

///|
/// 测试基本 JSON 值解析
pub fn test_basic_values() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 测试布尔值
  match parse_json("true") {
    Ok(Bool(true)) => passed = passed + 1
    _ => failed = failed + 1
  }

  match parse_json("false") {
    Ok(Bool(false)) => passed = passed + 1
    _ => failed = failed + 1
  }

  // 测试 null
  match parse_json("null") {
    Ok(Null) => passed = passed + 1
    _ => failed = failed + 1
  }

  // 测试数字
  match parse_json("42") {
    Ok(Number(42)) => passed = passed + 1
    _ => failed = failed + 1
  }

  match parse_json("-42") {
    Ok(Number(-42)) => passed = passed + 1
    _ => failed = failed + 1
  }

  // 测试浮点数
  match parse_json("3.14") {
    Ok(Float(_)) => passed = passed + 1
    _ => failed = failed + 1
  }

  // 测试科学计数法
  match parse_json("1.5e+10") {
    Ok(Float(_)) => passed = passed + 1
    _ => failed = failed + 1
  }

  match parse_json("-1.5e-10") {
    Ok(Float(_)) => passed = passed + 1
    _ => failed = failed + 1
  }

  // 测试字符串
  match parse_json("\"hello\"") {
    Ok(String(s)) if s == "hello" => passed = passed + 1
    _ => failed = failed + 1
  }

  // 测试带转义的字符串
  match parse_json("\"hello\\nworld\"") {
    Ok(String(_)) => passed = passed + 1
    _ => failed = failed + 1
  }

  @io.println("Basic values tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试 JSON 对象解析
pub fn test_objects() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 空对象
  match parse_json("{}") {
    Ok(Object(m)) if m.length() == 0 => passed = passed + 1
    _ => failed = failed + 1
  }

  // 简单对象
  match parse_json("{\"key\":\"value\"}") {
    Ok(Object(m)) => {
      match m.get("key") {
        Some(String("value")) => passed = passed + 1
        _ => failed = failed + 1
      }
    }
    _ => failed = failed + 1
  }

  // 嵌套对象
  match parse_json("{\"outer\":{\"inner\":\"value\"}}") {
    Ok(Object(m)) => {
      match m.get("outer") {
        Some(Object(inner_m)) => {
          match inner_m.get("inner") {
            Some(String("value")) => passed = passed + 1
            _ => failed = failed + 1
          }
        }
        _ => failed = failed + 1
      }
    }
    _ => failed = failed + 1
  }

  @io.println("Object tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试 JSON 数组解析
pub fn test_arrays() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 空数组
  match parse_json("[]") {
    Ok(Array(arr)) if arr.length() == 0 => passed = passed + 1
    _ => failed = failed + 1
  }

  // 简单数组
  match parse_json("[1,2,3]") {
    Ok(Array(arr)) if arr.length() == 3 => passed = passed + 1
    _ => failed = failed + 1
  }

  // 嵌套数组
  match parse_json("[[1,2],[3,4]]") {
    Ok(Array(arr)) if arr.length() == 2 => passed = passed + 1
    _ => failed = failed + 1
  }

  // 混合类型数组
  match parse_json("[1,\"two\",true,null]") {
    Ok(Array(arr)) if arr.length() == 4 => passed = passed + 1
    _ => failed = failed + 1
  }

  @io.println("Array tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试 Unicode 转义
pub fn test_unicode_escape() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 简单的 ASCII Unicode 转义
  match parse_json("\"\\u0041\"") {
    Ok(String(_)) => passed = passed + 1
    _ => failed = failed + 1
  }

  // Unicode 转义在字符串中
  match parse_json("\"hello\\u0020world\"") {
    Ok(String(_)) => passed = passed + 1
    _ => failed = failed + 1
  }

  @io.println("Unicode escape tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试错误处理
pub fn test_errors() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 无效 JSON
  match parse_json("{invalid}") {
    Err(_) => passed = passed + 1
    Ok(_) => failed = failed + 1
  }

  // 不完整的 JSON
  match parse_json("{\"key\":") {
    Err(_) => passed = passed + 1
    Ok(_) => failed = failed + 1
  }

  // 无效的转义序列
  match parse_json("\"\\x\"") {
    Err(_) => passed = passed + 1
    Ok(_) => failed = failed + 1
  }

  @io.println("Error handling tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 运行所有测试
pub fn run_all_tests() -> Bool {
  @io.println("========================================")
  @io.println("JSON Parser Tests")
  @io.println("========================================")
  @io.println("")

  let all_passed = test_basic_values()
    && test_objects()
    && test_arrays()
    && test_unicode_escape()
    && test_errors()

  @io.println("")
  @io.println("========================================")
  if all_passed {
    @io.println("All tests passed!")
  } else {
    @io.println("Some tests failed!")
  }
  @io.println("========================================")

  all_passed
}
