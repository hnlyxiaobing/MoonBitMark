///|
/// Targets without a filesystem (wasm, js) cannot sniff file contents;
/// detection falls back to the extension/name based StreamInfo.
async fn read_input_bytes(path : String) -> Bytes? {
  ignore(path)
  @async.pause()
  None
}
