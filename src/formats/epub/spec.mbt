// EPUB Converter Specification
// Spec-driven development for EPUB to Markdown conversion

///|
/// Create a new EPUB converter
pub fn EpubConverter::new() -> EpubConverter {
  EpubConverter::{ dummy: 0 }
}

///|
/// Check if this converter accepts the given file
declare pub fn EpubConverter::accepts(info : @core.StreamInfo) -> Bool

///|
/// Convert an EPUB file to Markdown string
declare pub async fn EpubConverter::convert(
  file_path : String,
) -> @core.ConvertResult
