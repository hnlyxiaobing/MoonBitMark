///|
pub(all) enum OcrMode {
  Off
  Auto
  Force
} derive(Debug, Eq, ToJson)

///|
pub extend OcrMode with @debug.Debug::{to_repr}

///|
pub extend OcrMode with Eq::{not_equal, equal}

///|
pub extend OcrMode with ToJson::{to_json}

///|
pub extend OcrMode with Show::{to_string, output}

///|
pub impl Show for OcrMode with fn output(self, logger) {
  Show::output(self.to_repr(), logger)
}

///|
pub fn OcrMode::label(self : OcrMode) -> String {
  match self {
    Off => "off"
    Auto => "auto"
    Force => "force"
  }
}

///|
pub(all) struct OcrConfig {
  mode : OcrMode
  language : String
  enable_embedded_images : Bool
  backend : String?
  timeout_ms : Int?
} derive(Debug, Eq, ToJson)

///|
pub extend OcrConfig with @debug.Debug::{to_repr}

///|
pub extend OcrConfig with Eq::{not_equal, equal}

///|
pub extend OcrConfig with ToJson::{to_json}

///|
pub fn OcrConfig::default() -> OcrConfig {
  OcrConfig::{
    mode: Off,
    language: "eng",
    enable_embedded_images: false,
    backend: None,
    timeout_ms: None,
  }
}

///|
pub fn OcrConfig::is_enabled(self : OcrConfig) -> Bool {
  self.mode != Off
}

///|
pub fn OcrConfig::should_process_embedded_images(self : OcrConfig) -> Bool {
  self.mode != Off && self.enable_embedded_images
}

///|
pub fn OcrConfig::backend_or_auto(self : OcrConfig) -> String {
  match self.backend {
    Some(value) if value.trim() != "" => value.trim().to_owned()
    _ => "auto"
  }
}

///|
pub fn should_attempt_for_native_text(
  config : OcrConfig,
  native_text : String,
) -> Bool {
  match config.mode {
    Off => false
    Auto => native_text.trim() == ""
    Force => true
  }
}

///|
pub(all) struct OcrResult {
  attempted : Bool
  available : Bool
  provider : String?
  text : String
  layout_json : String?
  warnings : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub extend OcrResult with @debug.Debug::{to_repr}

///|
pub extend OcrResult with Eq::{not_equal, equal}

///|
pub extend OcrResult with ToJson::{to_json}

///|
pub fn OcrResult::not_attempted() -> OcrResult {
  OcrResult::{
    attempted: false,
    available: false,
    provider: None,
    text: "",
    layout_json: None,
    warnings: [],
  }
}

///|
pub fn OcrResult::is_useful(self : OcrResult) -> Bool {
  self.available && self.text.trim() != ""
}

///|
pub fn OcrResult::provider_label(self : OcrResult) -> String {
  match self.provider {
    Some(value) if value != "" => value
    _ => "unavailable"
  }
}
