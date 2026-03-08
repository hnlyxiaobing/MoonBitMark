// expat FFI Bindings
// XML parser library

///|
/// XML parser handle
type XML_Parser

///|
/// XML position info
struct XML_Position {
  line_number : Int
  column_number : Int
}

///|
/// XML parsing status
enum XML_Status {
  XML_STATUS_OK
  XML_STATUS_ERROR
}

// ============================================================================
// Parser creation and destruction
// ============================================================================

///|
/// Create a new XML parser
extern "c" fn XML_ParserCreate(encoding : Bytes) -> XML_Parser = "moonbit_xml_parser_create"

///|
/// Free an XML parser
extern "c" fn XML_ParserFree(parser : XML_Parser) -> Unit = "moonbit_xml_parser_free"

// ============================================================================
// Parsing
// ============================================================================

///|
/// Parse XML data
extern "c" fn XML_Parse(parser : XML_Parser, data : Bytes, len : Int, is_final : Int) -> XML_Status = "moonbit_xml_parse"

///|
/// Get error code from parser
extern "c" fn XML_GetErrorCode(parser : XML_Parser) -> Int = "moonbit_xml_get_error_code"

///|
/// Get error message
extern "c" fn XML_ErrorString(code : Int) -> Bytes = "moonbit_xml_error_string"

///|
/// Get current line number
extern "c" fn XML_GetCurrentLineNumber(parser : XML_Parser) -> Int = "moonbit_xml_get_current_line_number"

// ============================================================================
// Callback handlers
// ============================================================================

///|
/// Set element handler (start/end element callbacks)
extern "c" fn XML_SetElementHandler(
  parser : XML_Parser,
  start_handler : Int,  // Function pointer
  end_handler : Int     // Function pointer
) -> Unit = "moonbit_xml_set_element_handler"

///|
/// Set character data handler
extern "c" fn XML_SetCharacterDataHandler(
  parser : XML_Parser,
  handler : Int  // Function pointer
) -> Unit = "moonbit_xml_set_character_data_handler"

// ============================================================================
// Constants
// ============================================================================

///|
/// XML status OK
pub let XML_STATUS_OK_VALUE : Int = 1

///|
/// XML status error
pub let XML_STATUS_ERROR_VALUE : Int = 0

///|
/// True for final parse chunk
pub let XML_TRUE : Int = 1

///|
/// False for non-final parse chunk
pub let XML_FALSE : Int = 0

// ============================================================================
// Safe wrappers
// ============================================================================

///|
/// Parse complete XML document
pub fn parse_xml_document(xml_data : Bytes) -> Unit raise {
  let parser = XML_ParserCreate(Nil)
  
  if parser == Nil {
    fail("Failed to create XML parser")
  }
  
  let status = XML_Parse(parser, xml_data, xml_data.length(), XML_TRUE)
  
  if status == XML_STATUS_ERROR {
    let error_code = XML_GetErrorCode(parser)
    let error_msg = XML_ErrorString(error_code)
    let line_num = XML_GetCurrentLineNumber(parser)
    
    XML_ParserFree(parser)
    
    fail("XML parse error at line \{line_num}: \{error_msg.to_string()}")
  }
  
  XML_ParserFree(parser)
}
