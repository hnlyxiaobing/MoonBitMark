///|
test "rendered diagnostics are passed through" {
  let message = @core.error_diagnostic(
    @core.ZipError("Bad archive", Some("book.epub")),
    Some(@core.Load(Some("archive"))),
    Some(@core.File("book.epub")),
    Some(@core.CheckArchiveIntegrity),
  ).render()
  inspect(is_rendered_diagnostic(message), content="true")
}

///|
test "merge diagnostics deduplicates mirrored warnings" {
  let diagnostics = merge_diagnostics(
    [
      @core.warning_diagnostic(
        "Dropped <style> blocks during HTML conversion.",
        Some(@core.Normalize(Some("preprocess"))),
        Some(@core.File("demo.html")),
        Some(@core.InspectSourceDocument),
      ),
    ],
    ["Dropped <style> blocks during HTML conversion."],
    default_registration(Html, 70),
    @core.FileInput("demo.html", None),
  )
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: normalize/preprocess\n  Source: demo.html\n  Message: Dropped <style> blocks during HTML conversion.\n  Hint: Inspect the source document or run with debug context.",
  )
}

///|
test "detect container signature upgrades bytes input to docx" {
  let docx_bytes : Bytes = [
    0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5b, 0x89, 0x72,
    0x5c, 0xdd, 0x5a, 0x86, 0x0d, 0x0d, 0x00, 0x00, 0x00, 0x0d, 0x00, 0x00, 0x00,
    0x11, 0x00, 0x00, 0x00, 0x77, 0x6f, 0x72, 0x64, 0x2f, 0x64, 0x6f, 0x63, 0x75,
    0x6d, 0x65, 0x6e, 0x74, 0x2e, 0x78, 0x6d, 0x6c, 0x3c, 0x77, 0x3a, 0x64, 0x6f,
    0x63, 0x75, 0x6d, 0x65, 0x6e, 0x74, 0x2f, 0x3e, 0x50, 0x4b, 0x01, 0x02, 0x14,
    0x00, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5b, 0x89, 0x72, 0x5c, 0xdd, 0x5a,
    0x86, 0x0d, 0x0d, 0x00, 0x00, 0x00, 0x0d, 0x00, 0x00, 0x00, 0x11, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x77, 0x6f, 0x72, 0x64, 0x2f, 0x64, 0x6f, 0x63, 0x75, 0x6d, 0x65, 0x6e,
    0x74, 0x2e, 0x78, 0x6d, 0x6c, 0x50, 0x4b, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x01, 0x00, 0x3f, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x00, 0x00, 0x00,
    0x00,
  ]
  let info = enrich_stream_info(
    stream_info_of_input(@core.BytesInput(Some("sample.bin"), docx_bytes, None)),
    docx_bytes,
  )
  inspect(info.extension, content="Some(\".docx\")")
  inspect(MarkItDown::new().select_converter(info).name, content="docx")
}

///|
test "detection result render includes stream info" {
  let rendered = DetectionResult::{
    converter_name: "html",
    stream_info: @core.StreamInfo::{
      mimetype: Some("text/html"),
      extension: Some(".html"),
      filename: Some("demo.html"),
      url: Some("https://example.com/demo.html"),
      charset: None,
    },
  }.render()
  inspect(
    rendered,
    content="converter: html\nextension: .html\nmimetype: text/html\nfilename: demo.html\nurl: https://example.com/demo.html",
  )
}
