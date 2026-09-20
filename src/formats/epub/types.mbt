// EPUB Converter Types
// Type definitions for EPUB parsing and conversion

///|
/// EPUB metadata extracted from OPF file
pub(all) struct EpubMetadata {
  mut title : String?
  mut authors : Array[String]
  mut language : String?
  mut publisher : String?
  mut date : String?
  mut description : String?
  mut identifier : String?
} derive(Debug, Eq, ToJson)

///|
pub extend EpubMetadata with @debug.Debug::{to_repr}

///|
pub extend EpubMetadata with Eq::{not_equal, equal}

///|
pub extend EpubMetadata with ToJson::{to_json}

///|
/// Create default EpubMetadata
pub fn EpubMetadata::default() -> EpubMetadata {
  EpubMetadata::{
    title: None,
    authors: Array(capacity=0),
    language: None,
    publisher: None,
    date: None,
    description: None,
    identifier: None,
  }
}

///|
/// Manifest item from OPF
pub(all) struct ManifestItem {
  id : String
  href : String
  media_type : String
  properties : String?
} derive(Debug, Eq, ToJson)

///|
pub extend ManifestItem with @debug.Debug::{to_repr}

///|
pub extend ManifestItem with Eq::{not_equal, equal}

///|
pub extend ManifestItem with ToJson::{to_json}

///|
/// Spine item from OPF (reading order)
pub(all) struct SpineItem {
  idref : String
  linear : Bool
} derive(Debug, Eq, ToJson)

///|
pub extend SpineItem with @debug.Debug::{to_repr}

///|
pub extend SpineItem with Eq::{not_equal, equal}

///|
pub extend SpineItem with ToJson::{to_json}

///|
/// EPUB package information
pub(all) struct EpubPackage {
  metadata : EpubMetadata
  manifest : Map[String, ManifestItem]
  spine : Array[SpineItem]
  opf_dir : String
} derive(Debug)

///|
pub extend EpubPackage with @debug.Debug::{to_repr}

///|
/// EPUB converter struct
pub(all) struct EpubConverter {
  dummy : Int
}
