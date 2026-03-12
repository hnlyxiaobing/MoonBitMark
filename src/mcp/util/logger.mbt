// MoonBitMark MCP Utility - Logger with Timestamp

///|
/// 日志级别
pub(all) type LogLevel =
  | Debug
  | Info
  | Warn
  | Error

pub(all) fn LogLevel::to_string(self : LogLevel) -> String {
  match self {
    Debug => "DEBUG"
    Info => "INFO"
    Warn => "WARN"
    Error => "ERROR"
  }
}

///|
/// 日志器配置
pub(all) struct LoggerConfig {
  level : LogLevel
  enable_timestamp : Bool
  enable_color : Bool
}

///|
/// 日志器
pub(all) struct Logger {
  config : LoggerConfig
  name : String
}

///|
/// 创建默认日志器
pub(all) fn Logger::default() -> Logger {
  Logger::new("", {
    level: Info,
    enable_timestamp: true,
    enable_color: false
  })
}

///|
/// 创建命名日志器
pub(all) fn Logger::new(name : String, config : LoggerConfig) -> Logger {
  { config, name }
}

///|
/// 设置日志级别
pub(all) fn Logger::set_level(self : Logger, level : LogLevel) -> Logger {
  { config: { level, ..self.config }, name: self.name }
}

///|
/// 记录日志
pub(all) fn Logger::log(self : Logger, level : LogLevel, message : String) {
  // 检查是否应该输出该级别的日志
  if should_log(self.config.level, level) {
    let prefix = format_prefix(self, level)
    let log_message = prefix + " " + message
    @io.println(log_message)
  }
}

///|
/// 记录调试日志
pub(all) fn Logger::debug(self : Logger, message : String) {
  self.log(Debug, message)
}

///|
/// 记录信息日志
pub(all) fn Logger::info(self : Logger, message : String) {
  self.log(Info, message)
}

///|
/// 记录警告日志
pub(all) fn Logger::warn(self : Logger, message : String) {
  self.log(Warn, message)
}

///|
/// 记录错误日志
pub(all) fn Logger::error(self : Logger, message : String) {
  self.log(Error, message)
}

///|
/// 判断是否应该输出该级别的日志
fn should_log(current_level : LogLevel, message_level : LogLevel) -> Bool {
  match current_level {
    Debug => true // Debug 级别输出所有日志
    Info => message_level != Debug
    Warn => message_level == Warn || message_level == Error
    Error => message_level == Error
  }
}

///|
/// 格式化日志前缀
fn format_prefix(logger : Logger, level : LogLevel) -> String {
  let mut parts = Array::empty()

  // 添加时间戳
  if logger.config.enable_timestamp {
    parts.push(get_timestamp())
  }

  // 添加日志级别
  parts.push("[" + level.to_string() + "]")

  // 添加日志器名称
  if logger.name.length() > 0 {
    parts.push("[" + logger.name + "]")
  }

  parts.join(" ")
}

///|
/// 获取当前时间戳 (基于 Unix 时间戳)
fn get_timestamp() -> String {
  // 简化实现：使用固定的模拟时间戳
  // 实际实现需要 MoonBit 的 @time 模块或类似功能
  // 格式: [2026-03-12 14:30:45.123]
  "[" + format_current_time() + "]"
}

///|
/// 格式化当前时间 (模拟实现)
fn format_current_time() -> String {
  // 这是一个简化的实现
  // 实际实现应该使用系统时间 API
  "2026-03-12 14:30:45.123"
}

///|
/// 时间工具类型
pub(all) struct DateTime {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  millisecond : Int
}

///|
/// 获取当前时间 (占位符)
pub(all) fn get_current_datetime() -> DateTime {
  // 简化实现：返回固定时间
  {
    year: 2026,
    month: 3,
    day: 12,
    hour: 14,
    minute: 30,
    second: 45,
    millisecond: 123
  }
}

///|
/// 格式化 DateTime 为字符串
pub(all) fn format_datetime(dt : DateTime) -> String {
  let mut s = ""

  // 日期部分
  s = s + dt.year.to_string()
  s = s + "-"
  if dt.month < 10 {
    s = s + "0"
  }
  s = s + dt.month.to_string()
  s = s + "-"
  if dt.day < 10 {
    s = s + "0"
  }
  s = s + dt.day.to_string()

  // 时间部分
  s = s + " "
  if dt.hour < 10 {
    s = s + "0"
  }
  s = s + dt.hour.to_string()
  s = s + ":"
  if dt.minute < 10 {
    s = s + "0"
  }
  s = s + dt.minute.to_string()
  s = s + ":"
  if dt.second < 10 {
    s = s + "0"
  }
  s = s + dt.second.to_string()
  s = s + "."
  if dt.millisecond < 100 {
    s = s + "0"
  }
  if dt.millisecond < 10 {
    s = s + "0"
  }
  s = s + dt.millisecond.to_string()

  s
}
