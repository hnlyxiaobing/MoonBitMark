// libzip 基础测试

///|
test "spec - open returns option type" {
  // 测试 open 函数返回 Option 类型
  let result : ZipArchive? = ZipArchive::open(b"")
  ignore(result)
}
