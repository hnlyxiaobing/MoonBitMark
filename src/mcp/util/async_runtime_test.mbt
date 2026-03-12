// MoonBitMark MCP Async Runtime Tests

use @async_runtime.*

///|
/// Test async function returning success
test "async_success" {
  let future = async(fn() {
    Ok(42)
  })

  match future.await() {
    Ok(value) => {
      assert_eq(value, 42)
    }
    Err(_) => {
      panic!("Expected success but got error")
    }
  }
}

///|
/// Test async function returning error
test "async_error" {
  let future = async(fn() {
    Err("Test error")
  })

  match future.await() {
    Ok(_) => {
      panic!("Expected error but got success")
    }
    Err(e) => {
      assert_eq(e, "Test error")
    }
  }
}

///|
/// Test Future::ready
test "future_ready" {
  let future = Future::ready(123)

  assert_true(future.is_ready())
  match future.await() {
    Ok(value) => {
      assert_eq(value, 123)
    }
    Err(_) => {
      panic!("Expected success but got error")
    }
  }
}

///|
/// Test Future::error
test "future_error" {
  let future = Future::error[Int]("Test error")

  assert_true(future.is_ready())
  match future.await() {
    Ok(_) => {
      panic!("Expected error but got success")
    }
    Err(e) => {
      assert_eq(e, "Test error")
    }
  }
}

///|
/// Test EventLoop creation
test "event_loop_creation" {
  let event_loop = EventLoop::new()

  assert_eq(event_loop.next_id, 0)
}

///|
/// Test EventLoop submit
test "event_loop_submit" {
  let event_loop = EventLoop::new()

  let future = event_loop.submit(fn() {
    Ok("Hello, async!")
  })

  match future.await() {
    Ok(value) => {
      assert_eq(value, "Hello, async!")
    }
    Err(_) => {
      panic!("Expected success but got error")
    }
  }
}

///|
/// Test block_on
test "block_on_success" {
  let future = Future::ready("Test result")

  match block_on(future) {
    Ok(value) => {
      assert_eq(value, "Test result")
    }
    Err(_) => {
      panic!("Expected success but got error")
    }
  }
}

///|
/// Test block_on with error
test "block_on_error" {
  let future = Future::error[String]("Async error")

  match block_on(future) {
    Ok(_) => {
      panic!("Expected error but got success")
    }
    Err(e) => {
      assert_eq(e, "Async error")
    }
  }
}

///|
/// Test multiple async operations
test "multiple_async" {
  let future1 = async(fn() {
    Ok(1)
  })

  let future2 = async(fn() {
    Ok(2)
  })

  let future3 = async(fn() {
    Ok(3)
  })

  match future1.await() {
    Ok(v) => assert_eq(v, 1)
    Err(_) => panic!("Expected success")
  }

  match future2.await() {
    Ok(v) => assert_eq(v, 2)
    Err(_) => panic!("Expected success")
  }

  match future3.await() {
    Ok(v) => assert_eq(v, 3)
    Err(_) => panic!("Expected success")
  }
}

///|
/// Test async with string operations
test "async_string_operations" {
  let future = async(fn() {
    let text = "Hello"
    let result = text + ", World!"
    Ok(result)
  })

  match future.await() {
    Ok(value) => {
      assert_eq(value, "Hello, World!")
    }
    Err(_) => {
      panic!("Expected success but got error")
    }
  }
}

///|
/// Test async with computation
test "async_computation" {
  let future = async(fn() {
    let mut sum = 0
    let mut i = 0
    while i < 10 {
      sum = sum + i
      i = i + 1
    }
    Ok(sum)
  })

  match future.await() {
    Ok(value) => {
      assert_eq(value, 45)
    }
    Err(_) => {
      panic!("Expected success but got error")
    }
  }
}
