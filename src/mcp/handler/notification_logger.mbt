// MoonBitMark MCP Handler - Notification-based Logger
//
// In STDIO mode, the server must not use println for logging because it would
// corrupt the JSON-RPC stream. Instead, this logger emits JSON-RPC
// notifications/method = "notifications/message" to stdout.

///|
pub(all) struct NotificationLogger {
  name : String
  min_level : @types.McpLoggingLevel
}

///|
pub fn NotificationLogger::new(name : String) -> NotificationLogger {
  NotificationLogger::{ name, min_level: @types.McpLoggingLevel::Info, }
}

///|
pub fn NotificationLogger::set_min_level(
  self : NotificationLogger,
  level : @types.McpLoggingLevel,
) -> NotificationLogger {
  NotificationLogger::{ name: self.name, min_level: level, }
}

///|
pub async fn NotificationLogger::log(
  self : NotificationLogger,
  level : @types.McpLoggingLevel,
  message : String,
) -> Unit {
  if mcp_level_should_emit(self.min_level, level) {
    let notification = @types.McpLoggingNotification::{
      level,
      logger: self.name,
      data: @types.String(message),
    }
    let json = notification.to_jsonrpc().to_string()
    ignore(@stdio.stdout.write(json + "\n") catch { _ => () })
  }
}

///|
pub async fn NotificationLogger::debug(
  self : NotificationLogger,
  message : String,
) -> Unit {
  self.log(@types.McpLoggingLevel::Debug, message)
}

///|
pub async fn NotificationLogger::info(
  self : NotificationLogger,
  message : String,
) -> Unit {
  self.log(@types.McpLoggingLevel::Info, message)
}

///|
pub async fn NotificationLogger::warn(
  self : NotificationLogger,
  message : String,
) -> Unit {
  self.log(@types.McpLoggingLevel::Warning, message)
}

///|
pub async fn NotificationLogger::error(
  self : NotificationLogger,
  message : String,
) -> Unit {
  self.log(@types.McpLoggingLevel::Error, message)
}

///|
fn mcp_level_should_emit(
  min_level : @types.McpLoggingLevel,
  message_level : @types.McpLoggingLevel,
) -> Bool {
  let min_rank = mcp_level_rank(min_level)
  let msg_rank = mcp_level_rank(message_level)
  msg_rank >= min_rank
}

///|
fn mcp_level_rank(level : @types.McpLoggingLevel) -> Int {
  match level {
    @types.McpLoggingLevel::Debug => 0
    @types.McpLoggingLevel::Info => 1
    @types.McpLoggingLevel::Notice => 2
    @types.McpLoggingLevel::Warning => 3
    @types.McpLoggingLevel::Error => 4
    @types.McpLoggingLevel::Critical => 5
    @types.McpLoggingLevel::Alert => 6
    @types.McpLoggingLevel::Emergency => 7
  }
}
