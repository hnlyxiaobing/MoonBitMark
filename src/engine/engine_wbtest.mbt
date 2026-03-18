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
async test "data uri image assets are materialized to asset dir" {
  let dir = "tmp-engine-assets"
  let stray_dir = "116109112451011101031051101014597115115101116115"
  ignore(@fs.remove(dir + "/image-1.png") catch { _ => () })
  ignore(@fs.rmdir(dir) catch { _ => () })
  ignore(@fs.rmdir(stray_dir) catch { _ => () })
  ignore(@fs.mkdir(dir, permission=0o755, recursive=true) catch { _ => () })

  let (rewritten, warnings, diagnostics, asset_count) = materialize_data_uri_assets(
    "![demo](data:image/png;base64,SGVsbG8=)", dir,
  )
  inspect(rewritten, content="![demo](tmp-engine-assets/image-1.png)")
  inspect(asset_count, content="1")
  inspect(warnings.length(), content="0")
  inspect(diagnostics.length(), content="0")

  let file = @fs.open(dir + "/image-1.png", mode=ReadOnly)
  let buffer : FixedArray[Byte] = FixedArray::make(8, b'\x00')
  let count = file.read(buffer)
  file.close()
  inspect(count, content="5")
  inspect(buffer[0].to_int(), content="72")
  inspect(buffer[4].to_int(), content="111")
  let stray_dir_created = try {
    ignore(@fs.rmdir(stray_dir))
    true
  } catch {
    _ => false
  }
  inspect(stray_dir_created, content="false")

  ignore(@fs.remove(dir + "/image-1.png") catch { _ => () })
  ignore(@fs.rmdir(dir) catch { _ => () })
  ignore(@fs.rmdir(stray_dir) catch { _ => () })
}
