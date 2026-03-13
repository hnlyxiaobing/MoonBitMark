// MoonBitMark MCP Handler - Bridge to Existing Converters

///|
pub fn detect_document_type(input : String) -> String {
  if input.has_prefix("http://") || input.has_prefix("https://") {
    return "html"
  }

  let lower = input.to_lower()
  if lower.has_suffix(".pdf") {
    "pdf"
  } else if lower.has_suffix(".docx") {
    "docx"
  } else if lower.has_suffix(".html") || lower.has_suffix(".htm") {
    "html"
  } else if lower.has_suffix(".txt") {
    "text"
  } else if lower.has_suffix(".csv") {
    "csv"
  } else if lower.has_suffix(".json") {
    "json"
  } else if lower.has_suffix(".xlsx") {
    "xlsx"
  } else if lower.has_suffix(".pptx") {
    "pptx"
  } else if lower.has_suffix(".epub") {
    "epub"
  } else {
    "unknown"
  }
}

///|
pub async fn convert_to_markdown(input : String) -> String {
  match detect_document_type(input) {
    "pdf" => @pdf.PdfConverter::convert(input)
    "docx" => @docx.DocxConverter::convert(input)
    "html" => @html.HtmlConverter::convert(input)
    "text" => @text.TextConverter::convert(input)
    "csv" => @csv.CsvConverter::convert(input)
    "json" => @json.JsonConverter::convert(input)
    "xlsx" => @xlsx.XlsxConverter::convert(input)
    "pptx" => @pptx.PptxConverter::convert(input)
    "epub" => @epub.EpubConverter::convert(input)
    _ =>
      fail(
        "Unsupported document format. Supported formats: PDF, DOCX, HTML, TXT, CSV, JSON, XLSX, PPTX, EPUB",
      )
  }
}
