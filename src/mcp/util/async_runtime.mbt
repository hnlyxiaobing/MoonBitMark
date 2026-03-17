// MoonBitMark MCP Utility - Minimal Future Runtime

///|
pub enum TaskState {
  Pending
  Completed
  Failed(String)
}

///|
pub(all) struct AsyncTask[T] {
  id : Int
  state : TaskState
  result : T?
}

///|
pub(all) struct Future[T] {
  completed : Bool
  value : T?
  error : String?
}

///|
pub(all) struct EventLoop {
  mut next_id : Int
}

///|
pub fn EventLoop::new() -> EventLoop {
  { next_id: 0 }
}

///|
pub fn[T] EventLoop::submit(
  self : EventLoop,
  task_fn : () -> Result[T, String],
) -> Future[T] {
  self.next_id = self.next_id + 1
  match task_fn() {
    Ok(value) => Future::ready(value)
    Err(message) => Future::error(message)
  }
}

///|
pub fn EventLoop::tick(self : EventLoop) -> Unit {
  ignore(self)
}

///|
pub fn EventLoop::run(self : EventLoop) -> Unit {
  ignore(self)
}

///|
pub fn[T] Future::wait(self : Future[T]) -> Result[T, String] {
  if !self.completed {
    return Err("Future not completed yet")
  }

  match self.value {
    Some(value) => Ok(value)
    None =>
      match self.error {
        Some(message) => Err(message)
        None => Err("Future completed without value or error")
      }
  }
}

///|
pub fn[T] Future::is_ready(self : Future[T]) -> Bool {
  self.completed
}

///|
pub fn[T] Future::ready(value : T) -> Future[T] {
  { completed: true, value: Some(value), error: None }
}

///|
pub fn[T] Future::error(message : String) -> Future[T] {
  { completed: true, value: None, error: Some(message) }
}

///|
pub fn TaskState::pending() -> TaskState {
  Pending
}

///|
pub fn TaskState::completed() -> TaskState {
  Completed
}

///|
pub fn TaskState::failed(message : String) -> TaskState {
  Failed(message)
}

///|
pub fn[T] spawn(task_fn : () -> Result[T, String]) -> Future[T] {
  let event_loop = EventLoop::new()
  event_loop.submit(task_fn)
}

///|
pub fn[T] block_on(future : Future[T]) -> Result[T, String] {
  future.wait()
}
