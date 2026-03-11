// EPUB Converter Types
// Type definitions for EPUB parsing and conversion

///|
/// EPUB metadata extracted from OPF file
pub(all) struct EpubMetadata {
  mut title : Option[String]
  mut authors : Array[String]
  mut language : Option[String]
  mut publisher : Option[String]
  mut date : Option[String]
  mut description : Option[String]
  mut identifier : Option[String]
} derive(Show, Eq, ToJson)

///|
/// Create default EpubMetadata
pub fn EpubMetadata::default() -> EpubMetadata {
  EpubMetadata::{
    title: None,
    authors: Array::new(),
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
  properties : Option[String]
} derive(Show, Eq, ToJson)

///|
/// Spine item from OPF (reading order)
pub(all) struct SpineItem {
  idref : String
  linear : Bool
} derive(Show, Eq, ToJson)

///|
/// EPUB package information
pub(all) struct EpubPackage {
  metadata : EpubMetadata
  manifest : Map[String, ManifestItem]
  spine : Array[SpineItem]
  opf_dir : String
} derive(Show)

///|
/// EPUB converter struct
pub(all) struct EpubConverter {
  dummy : Int
}
