///|
priv enum PdfDocumentMode {
  FastTextOnly
  Mixed
  RecoveryOnly
}

///|
priv enum PdfPageProviderKind {
  NativeTextFast
  NativeTextStructured
  LayoutEnhanced
  OcrRecovery
  Hybrid
} derive(Eq)

///|
priv enum PdfTextQuality {
  Empty
  VeryPoor
  Weak
  Good
  Strong
}

///|
priv enum PdfLayoutComplexity {
  Simple
  Medium
  Complex
}

///|
priv enum PdfRouteFlag {
  SuspectTable
  SuspectCode
  SuspectFormula
  SuspectMultiColumn
  SuspectScanned
  SuspectHeaderFooter
  SuspectBrokenSpacing
} derive(Eq)

///|
priv struct PdfPageRoute {
  page_no : Int32
  provider : PdfPageProviderKind
  text_quality : PdfTextQuality
  layout_complexity : PdfLayoutComplexity
  flags : Array[PdfRouteFlag]
}

///|
priv struct PdfRouteSummary {
  total_pages : Int32
  native_fast_pages : Int32
  structured_pages : Int32
  recovery_pages : Int32
  flagged_pages : Int32
}

///|
priv struct PdfRoutePlan {
  document_mode : PdfDocumentMode
  pages : Array[PdfPageRoute]
  summary : PdfRouteSummary
}

///|
priv struct PdfRawLine {
  text : String
}

///|
priv struct PdfLayoutWord {
  text : String
  left : Int32
  right : Int32
} derive(FromJson)

///|
priv struct PdfLayoutLine {
  text : String
  left : Int32
  top : Int32
  right : Int32
  bottom : Int32
  words : Array[PdfLayoutWord]
} derive(FromJson)

///|
priv struct PdfLayoutPage {
  page_no : Int32
  width : Int32
  lines : Array[PdfLayoutLine]
} derive(FromJson)

///|
priv struct PdfLayoutPayload {
  pages : Array[PdfLayoutPage]
} derive(FromJson)

///|
priv struct PdfPageExtraction {
  page_no : Int32
  source_kind : PdfPageProviderKind
  raw_text : String?
  lines : Array[PdfRawLine]
  layout : PdfLayoutPage?
}

///|
priv struct PdfNativeExtraction {
  raw_pages : Array[String]
  pages : Array[PdfPageExtraction]
  provider : String?
  warnings : Array[String]
  used_text_fallback : Bool
}

///|
priv struct PdfPageText {
  number : Int32
  raw_text : String
  chunks : Array[String]
  layout : PdfLayoutPage?
}

///|
priv struct PdfNormalizationResult {
  pages : Array[PdfPageText]
  removed_header_count : Int32
  removed_footer_count : Int32
  merged_partial_numbering_count : Int32
}

///|
priv struct PdfListItem {
  text : String
  ordered : Bool
}

///|
priv enum PdfBlockKind {
  Paragraph
  Heading(Int32)
  List(Bool)
}

///|
priv struct PdfBlockCandidate {
  kind : PdfBlockKind
  text : String
}

///|
priv struct PdfStructureSummary {
  heading_count : Int32
  list_block_count : Int32
  list_item_count : Int32
  paragraph_count : Int32
  merged_paragraph_count : Int32
}

///|
priv struct PdfStructureResult {
  blocks : Array[@ast.Block]
  annotations : Array[@ast.BlockAnnotation]
  summary : PdfStructureSummary
}

///|
priv struct PdfAssemblyResult {
  normalization : PdfNormalizationResult
  metadata : Map[String, String]
  document : @ast.Document
}
