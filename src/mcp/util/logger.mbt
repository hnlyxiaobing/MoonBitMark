// MoonBitMark MCP Utility - Logger

///|
pub enum LogLevel {
  Debug
  Info
  Warn
  Error
} derive(Eq)

///|
pub fn LogLevel::to_string(self : LogLevel) -> String {
  match self {
    Debug => "DEBUG"
    Info => "INFO"
    Warn => "WARN"
    Error => "ERROR"
  }
}

///|
pub(all) struct LoggerConfig {
  level : LogLevel
  enable_timestamp : Bool
  enable_color : Bool
}

///|
pub(all) struct Logger {
  config : LoggerConfig
  name : String
}

///|
pub fn Logger::default() -> Logger {
  Logger::new("", {
    level: Info,
    enable_timestamp: true,
    enable_color: false,
  })
}

///|
pub fn Logger::new(name : String, config : LoggerConfig) -> Logger {
  { config, name }
}

///|
pub fn Logger::set_level(self : Logger, level : LogLevel) -> Logger {
  {
    config: {
      level,
      enable_timestamp: self.config.enable_timestamp,
      enable_color: self.config.enable_color,
    },
    name: self.name,
  }
}

///|
pub fn Logger::log(self : Logger, level : LogLevel, message : String) -> Unit {
  if should_log(self.config.level, level) {
    println(format_prefix(self, level) + " " + message)
  }
}

///|
pub fn Logger::debug(self : Logger, message : String) -> Unit {
  self.log(Debug, message)
}

///|
pub fn Logger::info(self : Logger, message : String) -> Unit {
  self.log(Info, message)
}

///|
pub fn Logger::warn(self : Logger, message : String) -> Unit {
  self.log(Warn, message)
}

///|
pub fn Logger::error(self : Logger, message : String) -> Unit {
  self.log(Error, message)
}

///|
fn should_log(current_level : LogLevel, message_level : LogLevel) -> Bool {
  match current_level {
    Debug => true
    Info => message_level != Debug
    Warn => message_level == Warn || message_level == Error
    Error => message_level == Error
  }
}

///|
fn format_prefix(logger : Logger, level : LogLevel) -> String {
  let parts : Array[String] = []
  if logger.config.enable_timestamp {
    parts.push("[" + format_current_time() + "]")
  }
  parts.push("[" + level.to_string() + "]")
  if logger.name.length() > 0 {
    parts.push("[" + logger.name + "]")
  }
  parts.join(" ")
}

///|
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
pub fn get_current_datetime() -> DateTime {
  {
    year: 2026,
    month: 3,
    day: 13,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

///|
pub fn format_datetime(dt : DateTime) -> String {
  pad4(dt.year) + "-" +
  pad2(dt.month) + "-" +
  pad2(dt.day) + " " +
  pad2(dt.hour) + ":" +
  pad2(dt.minute) + ":" +
  pad2(dt.second) + "." +
  pad3(dt.millisecond)
}

///|
fn format_current_time() -> String {
  format_datetime(get_current_datetime())
}

///|
fn pad2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn pad3(value : Int) -> String {
  if value < 10 {
    "00" + value.to_string()
  } else if value < 100 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn pad4(value : Int) -> String {
  let text = value.to_string()
  if text.length() >= 4 {
    text
  } else if text.length() == 3 {
    "0" + text
  } else if text.length() == 2 {
    "00" + text
  } else {
    "000" + text
  }
}
