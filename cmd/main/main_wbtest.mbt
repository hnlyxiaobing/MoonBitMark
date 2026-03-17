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
test "parse args rejects missing input" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--frontmatter",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to fail without an input")
  }
}
