///|
fn assemble_pdf_document(
  title : String?,
  extraction : PdfNativeExtraction,
  route_plan : PdfRoutePlan,
) -> PdfAssemblyResult {
  let normalization = normalize_pdf_extraction(extraction, route_plan)
  let structure = reconstruct_pdf_blocks_with_routes(
    normalization.pages,
    route_plan,
  )
  let metadata = build_pdf_metadata(
    route_plan, extraction, normalization, structure,
  )
  let document = @ast.Document::{ title, metadata, blocks: structure.blocks }
  PdfAssemblyResult::{ normalization, metadata, document }
}

///|
fn build_pdf_metadata(
  route_plan : PdfRoutePlan,
  extraction : PdfNativeExtraction,
  normalization : PdfNormalizationResult,
  structure : PdfStructureResult,
) -> Map[String, String] {
  let metadata = Map::new()
  metadata["format"] = "pdf"
  metadata["page_count"] = normalization.pages.length().to_string()
  metadata["pdf_text_provider"] = match extraction.provider {
    Some(provider) if provider != "" => provider
    _ => "unknown"
  }
  metadata["pdf_text_fallback_used"] = extraction.used_text_fallback.to_string()
  if extraction.warnings.length() > 0 {
    metadata["pdf_text_warning_count"] = extraction.warnings
      .length()
      .to_string()
  }
  metadata["route_document_mode"] = route_plan.document_mode.label()
  metadata["route_native_fast_pages"] = route_plan.summary.native_fast_pages.to_string()
  metadata["route_structured_pages"] = route_plan.summary.structured_pages.to_string()
  metadata["route_recovery_pages"] = route_plan.summary.recovery_pages.to_string()
  metadata["route_flagged_pages"] = route_plan.summary.flagged_pages.to_string()

  let route_provider_summary = summarize_route_providers(route_plan)
  if route_provider_summary != "" {
    metadata["route_providers"] = route_provider_summary
  }

  let route_flag_summary = summarize_route_flags(route_plan)
  if route_flag_summary != "" {
    metadata["route_flags"] = route_flag_summary
  }

  let route_text_quality_summary = summarize_route_text_quality(route_plan)
  if route_text_quality_summary != "" {
    metadata["route_text_quality"] = route_text_quality_summary
  }

  let route_layout_complexity_summary = summarize_route_layout_complexity(
    route_plan,
  )
  if route_layout_complexity_summary != "" {
    metadata["route_layout_complexity"] = route_layout_complexity_summary
  }

  if normalization.removed_header_count > 0 {
    metadata["removed_header_count"] = normalization.removed_header_count.to_string()
  }
  if normalization.removed_footer_count > 0 {
    metadata["removed_footer_count"] = normalization.removed_footer_count.to_string()
  }
  if normalization.merged_partial_numbering_count > 0 {
    metadata["merged_partial_numbering_count"] = normalization.merged_partial_numbering_count.to_string()
  }

  if structure.summary.heading_count > 0 {
    metadata["heading_count"] = structure.summary.heading_count.to_string()
  }
  if structure.summary.list_block_count > 0 {
    metadata["list_block_count"] = structure.summary.list_block_count.to_string()
    metadata["list_item_count"] = structure.summary.list_item_count.to_string()
  }
  metadata["paragraph_count"] = structure.summary.paragraph_count.to_string()
  if structure.summary.merged_paragraph_count > 0 {
    metadata["merged_paragraph_count"] = structure.summary.merged_paragraph_count.to_string()
  }

  metadata
}
