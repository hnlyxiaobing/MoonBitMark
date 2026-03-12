// MoonBitMark MCP Handler - Converter Bridge to Existing Formats

///|
/// 转换器桥接 - 将 MCP 请求路由到现有的格式转换器
/// 这个模块作为 MCP 工具处理层和现有转换器之间的桥梁

///|
/// 根据文件扩展名或 URL 检测文档类型
pub(all) fn detect_document_type(input : String) -> String {
  // 检查是否为 URL
  if input.has_prefix("http://") || input.has_prefix("https://") {
    return "html"
  }

  // 检查文件扩展名
  let lower = input.to_lower().to_string()

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
/// 转换文档到 Markdown (统一入口)
pub(all) async fn convert_to_markdown(input : String) -> Result[String, String] {
  let doc_type = detect_document_type(input)

  match doc_type {
    "pdf" => convert_pdf(input)
    "docx" => convert_docx(input)
    "html" => convert_html(input)
    "text" => convert_text(input)
    "csv" => convert_csv(input)
    "json" => convert_json(input)
    "xlsx" => convert_xlsx(input)
    "pptx" => convert_pptx(input)
    "epub" => convert_epub(input)
    _ => Err("Unsupported document format. Supported formats: PDF, DOCX, HTML, TXT, CSV, JSON, XLSX, PPTX, EPUB")
  }
}

///|
/// 转换 PDF 文档
fn convert_pdf(file_path : String) -> Result[String, String] {
  match @try {
    let converter = @pdf.PdfConverter::new()
    await converter.convert(file_path)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("PDF conversion failed: " + e.to_string())
  }
}

///|
/// 转换 DOCX 文档
fn convert_docx(file_path : String) -> Result[String, String] {
  match @try {
    let converter = @docx.DocxConverter::new()
    await converter.convert(file_path)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("DOCX conversion failed: " + e.to_string())
  }
}

///|
/// 转换 HTML 文档 (支持 URL 和文件路径)
fn convert_html(input : String) -> Result[String, String] {
  match @try {
    let converter = @html.HtmlConverter::new()
    await converter.convert(input)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("HTML conversion failed: " + e.to_string())
  }
}

///|
/// 转换纯文本文档
fn convert_text(file_path : String) -> Result[String, String] {
  match @try {
    let converter = @text.TextConverter::new()
    await converter.convert(file_path)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("Text conversion failed: " + e.to_string())
  }
}

///|
/// 转换 CSV 文档
fn convert_csv(file_path : String) -> Result[String, String] {
  match @try {
    let converter = @csv.CsvConverter::new()
    await converter.convert(file_path)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("CSV conversion failed: " + e.to_string())
  }
}

///|
/// 转换 JSON 文档
fn convert_json(file_path : String) -> Result[String, String] {
  match @try {
    let converter = @json.JsonConverter::new()
    await converter.convert(file_path)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("JSON conversion failed: " + e.to_string())
  }
}

///|
/// 转换 XLSX 文档
fn convert_xlsx(file_path : String) -> Result[String, String] {
  match @try {
    let converter = @xlsx.XlsxConverter::new()
    await converter.convert(file_path)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("XLSX conversion failed: " + e.to_string())
  }
}

///|
/// 转换 PPTX 文档
fn convert_pptx(file_path : String) -> Result[String, String] {
  match @try {
    let converter = @pptx.PptxConverter::new()
    await converter.convert(file_path)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("PPTX conversion failed: " + e.to_string())
  }
}

///|
/// 转换 EPUB 文档
fn convert_epub(file_path : String) -> Result[String, String] {
  match @try {
    let converter = @epub.EpubConverter::new()
    await converter.convert(file_path)
  } {
    Ok(result) => Ok(result)
    Err(e) => Err("EPUB conversion failed: " + e.to_string())
  }
}
