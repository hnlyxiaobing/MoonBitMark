// MoonBitMark - Main Conversion Engine

///|
pub(all) struct ConverterRegistration {
  name : String
  priority : Int
}

///|
pub(all) struct MarkItDown {
  converters : Array[ConverterRegistration]
}

///|
pub fn MarkItDown::new() -> MarkItDown {
  let converters : Array[ConverterRegistration] = [
    { name: "docx", priority: 100 },
    { name: "epub", priority: 95 },
    { name: "pptx", priority: 90 },
    { name: "xlsx", priority: 85 },
    { name: "pdf", priority: 80 },
    { name: "html", priority: 70 },
    { name: "json", priority: 50 },
    { name: "csv", priority: 40 },
    { name: "text", priority: 10 },
  ]
  MarkItDown::{ converters }
}

///|
pub fn MarkItDown::detect_converter_name(
  self : MarkItDown,
  input : String,
) -> String raise {
  let info = stream_info_of_input(@core.InputSource::from_string(input))
  self.select_converter(info).name
}

///|
pub async fn MarkItDown::convert(
  self : MarkItDown,
  input : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult raise {
  self.convert_source(@core.InputSource::from_string(input), ctx=ctx)
}

///|
pub async fn MarkItDown::convert_source(
  self : MarkItDown,
  input : @core.InputSource,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult raise {
  ignore(ctx)
  let info = stream_info_of_input(input)
  let converter = self.select_converter(info)
  run_converter(converter.name, input)
}

///|
pub fn MarkItDown::select_converter(
  self : MarkItDown,
  info : @core.StreamInfo,
) -> ConverterRegistration raise {
  let mut selected : ConverterRegistration? = None
  for converter in self.converters {
    if accepts_converter(converter.name, info) {
      match selected {
        Some(current) =>
          if converter.priority > current.priority {
            selected = Some(converter)
          }
        None => selected = Some(converter)
      }
    }
  }

  match selected {
    Some(converter) => converter
    None => fail("Unsupported input: " + describe_stream_info(info))
  }
}

///|
fn stream_info_of_input(input : @core.InputSource) -> @core.StreamInfo {
  match input {
    @core.FileInput(path, _) =>
      @core.StreamInfo::{
        mimetype: None,
        extension: file_extension(path),
        filename: file_name(path),
        url: None,
        charset: None,
      }
    @core.UrlInput(url, _) =>
      @core.StreamInfo::{
        mimetype: Some("text/html"),
        extension: file_extension(url),
        filename: file_name(url),
        url: Some(url),
        charset: None,
      }
    @core.BytesInput(name, _, mimetype) =>
      @core.StreamInfo::{
        mimetype,
        extension: option_extension(name),
        filename: name,
        url: None,
        charset: None,
      }
  }
}

///|
fn describe_stream_info(info : @core.StreamInfo) -> String {
  match info.url {
    Some(url) => url
    None =>
      match info.filename {
        Some(filename) => filename
        None =>
          match info.extension {
            Some(extension) => extension
            None => "<unknown>"
          }
      }
  }
}

///|
fn option_extension(name : String?) -> String? {
  match name {
    Some(value) => file_extension(value)
    None => None
  }
}

///|
fn file_name(path : String) -> String? {
  let normalized = path.replace(old="\\", new="/")
  match find_last_char(normalized, '/') {
    Some(index) =>
      if index + 1 < normalized.length() {
        Some(normalized[index + 1:].to_string())
      } else {
        None
      }
    None =>
      if normalized.length() > 0 {
        Some(normalized)
      } else {
        None
      }
  }
}

///|
fn file_extension(path : String) -> String? {
  let normalized = path.replace(old="\\", new="/")
  let basename = match find_last_char(normalized, '/') {
    Some(index) => normalized[index + 1:].to_string()
    None => normalized
  }
  match find_last_char(basename, '.') {
    Some(index) => Some(basename[index:].to_lower().to_string())
    None => None
  }
}

///|
fn find_last_char(s : String, target : Char) -> Int? {
  let mut found = -1
  let mut i = 0
  for ch in s {
    if ch == target {
      found = i
    }
    i = i + 1
  }
  if found >= 0 {
    Some(found)
  } else {
    None
  }
}

///|
fn accepts_converter(name : String, info : @core.StreamInfo) -> Bool {
  match name {
    "docx" => @docx.DocxConverter::accepts(info)
    "epub" => @epub.EpubConverter::accepts(info)
    "pptx" => @pptx.PptxConverter::accepts(info)
    "xlsx" => @xlsx.XlsxConverter::accepts(info)
    "pdf" => @pdf.PdfConverter::accepts(info)
    "html" => @html.HtmlConverter::accepts(info)
    "json" => @json.JsonConverter::accepts(info)
    "csv" => @csv.CsvConverter::accepts(info)
    "text" => @text.TextConverter::accepts(info)
    _ => false
  }
}

///|
async fn run_converter(
  name : String,
  input : @core.InputSource,
) -> @core.ConvertResult raise {
  let input_name = match input {
    @core.FileInput(path, _) => path
    @core.UrlInput(url, _) => url
    @core.BytesInput(_, _, _) => fail("Bytes input is not supported yet")
  }

  match name {
    "docx" => @docx.DocxConverter::convert(input_name)
    "epub" => @epub.EpubConverter::convert(input_name)
    "pptx" => @pptx.PptxConverter::convert(input_name)
    "xlsx" => @xlsx.XlsxConverter::convert(input_name)
    "pdf" => @pdf.PdfConverter::convert(input_name)
    "html" => @html.HtmlConverter::convert(input_name)
    "json" => @json.JsonConverter::convert(input_name)
    "csv" => @csv.CsvConverter::convert(input_name)
    "text" => @text.TextConverter::convert(input_name)
    _ => fail("Unknown converter: " + name)
  }
}
