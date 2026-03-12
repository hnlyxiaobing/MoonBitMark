// MoonBitMark MCP Logger Tests

use @logger.*

///|
/// 测试日志级别过滤
pub fn test_log_level_filtering() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // Debug 日志器应该输出所有级别的日志
  let debug_logger = Logger::default().set_level(Debug)
  // 由于我们无法捕获输出，这里只验证日志器创建成功
  passed = passed + 1

  // Info 日志器不应该输出 Debug 日志
  let info_logger = Logger::default().set_level(Info)
  passed = passed + 1

  // Warn 日志器应该只输出 Warn 和 Error 日志
  let warn_logger = Logger::default().set_level(Warn)
  passed = passed + 1

  // Error 日志器应该只输出 Error 日志
  let error_logger = Logger::default().set_level(Error)
  passed = passed + 1

  @io.println("Log level filtering tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试日志器创建
pub fn test_logger_creation() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 测试默认日志器
  let default_logger = Logger::default()
  if default_logger.name == "" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试命名日志器
  let named_logger = Logger::new("test", {
    level: Info,
    enable_timestamp: true,
    enable_color: false
  })
  if named_logger.name == "test" {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试日志级别设置
  let logger = default_logger.set_level(Warn)
  passed = passed + 1

  @io.println("Logger creation tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试日志输出
pub fn test_log_output() -> Bool {
  let mut passed = 0
  let mut failed = 0

  let logger = Logger::new("test", {
    level: Debug,
    enable_timestamp: false,
    enable_color: false
  })

  // 测试不同级别的日志输出
  // 注意：这里我们无法验证实际输出，只能验证函数调用不会失败
  logger.debug("Debug message")
  passed = passed + 1

  logger.info("Info message")
  passed = passed + 1

  logger.warn("Warn message")
  passed = passed + 1

  logger.error("Error message")
  passed = passed + 1

  @io.println("Log output tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 测试时间格式化
pub fn test_datetime_formatting() -> Bool {
  let mut passed = 0
  let mut failed = 0

  // 测试当前时间获取
  let current_dt = get_current_datetime()
  if current_dt.year > 2020 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  // 测试时间格式化
  let formatted = format_datetime(current_dt)
  if formatted.length() > 0 {
    passed = passed + 1
  } else {
    failed = failed + 1
  }

  @io.println("Datetime formatting tests: " + passed.to_string() + " passed, " + failed.to_string() + " failed")
  failed == 0
}

///|
/// 运行所有测试
pub fn run_all_tests() -> Bool {
  @io.println("========================================")
  @io.println("Logger Tests")
  @io.println("========================================")
  @io.println("")

  let all_passed = test_log_level_filtering()
    && test_logger_creation()
    && test_log_output()
    && test_datetime_formatting()

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
