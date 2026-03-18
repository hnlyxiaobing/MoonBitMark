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
