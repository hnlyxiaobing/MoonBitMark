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
  page_no : Int
  provider : PdfPageProviderKind
  text_quality : PdfTextQuality
  layout_complexity : PdfLayoutComplexity
  flags : Array[PdfRouteFlag]
}

///|
priv struct PdfRouteSummary {
  total_pages : Int
  native_fast_pages : Int
  structured_pages : Int
  recovery_pages : Int
  flagged_pages : Int
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
priv struct PdfPageExtraction {
  page_no : Int
  source_kind : PdfPageProviderKind
  raw_text : String?
  lines : Array[PdfRawLine]
}

///|
priv struct PdfNativeExtraction {
  raw_pages : Array[String]
  pages : Array[PdfPageExtraction]
  provider : String?
  warnings : Array[String]
  used_fallback : Bool
}

///|
priv struct PdfPageText {
  number : Int
  raw_text : String
  chunks : Array[String]
}

///|
priv struct PdfNormalizationResult {
  pages : Array[PdfPageText]
  removed_header_count : Int
  removed_footer_count : Int
  merged_partial_numbering_count : Int
}

///|
priv struct PdfListItem {
  text : String
  ordered : Bool
}

///|
priv enum PdfBlockKind {
  Paragraph
  Heading(Int)
  List(Bool)
}

///|
priv struct PdfBlockCandidate {
  kind : PdfBlockKind
  text : String
}

///|
priv struct PdfStructureSummary {
  heading_count : Int
  list_block_count : Int
  list_item_count : Int
  paragraph_count : Int
  merged_paragraph_count : Int
}

///|
priv struct PdfStructureResult {
  blocks : Array[@ast.Block]
  summary : PdfStructureSummary
}

///|
priv struct PdfAssemblyResult {
  normalization : PdfNormalizationResult
  metadata : Map[String, String]
  document : @ast.Document
}
