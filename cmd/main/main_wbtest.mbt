///|
test "parse args enables frontmatter and output file" {
  let options = parse_args([
    "moonbitmark", "--frontmatter", "demo.docx", "out.md",
  ])
  inspect(options.input, content="demo.docx")
  inspect(options.output, content="Some(\"out.md\")")
  inspect(options.ctx.output_mode, content="FrontMatterMarkdown")
}

///|
test "parse args supports metadata and asset flags" {
  let options = parse_args([
    "moonbitmark", "--no-metadata", "--asset-dir", "assets", "demo.epub",
  ])
  inspect(options.ctx.keep_metadata, content="false")
  inspect(options.ctx.asset_output_dir, content="Some(\"assets\")")
}

///|
test "parse args supports ocr flags" {
  let options = parse_args([
    "moonbitmark", "--ocr", "force", "--ocr-lang", "chi_sim", "--ocr-images", "--ocr-backend",
    "mock", "--ocr-timeout", "2500", "scan.png",
  ])
  inspect(options.ctx.ocr.mode, content="Force")
  inspect(options.ctx.ocr.language, content="chi_sim")
  inspect(options.ctx.ocr.enable_embedded_images, content="true")
  inspect(options.ctx.ocr.backend, content="Some(\"mock\")")
  inspect(options.ctx.ocr.timeout_ms, content="Some(2500)")
}

///|
test "parse args supports detect and diagnostics flags" {
  let options = parse_args([
    "moonbitmark", "--detect-only", "--diag-json", "demo.html",
  ])
  inspect(options.detect_only, content="true")
  inspect(options.diag_json, content="true")
}

///|
test "parse args supports dump ast" {
  let options = parse_args(["moonbitmark", "--dump-ast", "demo.html"])
  inspect(options.dump_ast, content="true")
}

///|
test "parse args rejects missing input" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--frontmatter",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to fail without an input")
  }
}

///|
test "parse args rejects output with detect only" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--detect-only", "demo.docx", "out.md",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to reject output with detect-only")
  }
}

///|
test "parse args rejects dump ast with detect only" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--detect-only", "--dump-ast", "demo.docx",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to reject dump-ast with detect-only")
  }
}

///|
test "parse args rejects invalid ocr mode" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--ocr", "sometimes", "demo.png",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to reject invalid ocr mode")
  }
}

///|
test "validate output path rejects input overwrite" {
  let result : Result[Unit, Error] = try? validate_output_path(
    "fixtures\\scan.png", "fixtures/scan.png",
  )
  guard result is Err(_) else {
    fail("expected validate_output_path to reject overwrite path")
  }
}
