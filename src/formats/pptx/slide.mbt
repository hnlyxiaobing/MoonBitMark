// PPTX Slide Processing - Process slides and generate Markdown

///|
pub fn process_slides(
  archive : @libzip.ZipArchive,
  slide_refs : Array[SlideRef],
) -> (Array[@ast.Block], Array[String]) {
  let result = process_slides_with_assets_and_annotations(archive, slide_refs, {})
  (result.0, result.2)
}

fn process_slides_with_assets_and_annotations(
  archive : @libzip.ZipArchive,
  slide_refs : Array[SlideRef],
  asset_placeholders : Map[String, String],
) -> (Array[@ast.Block], Array[@ast.BlockAnnotation], Array[String]) {
  let blocks : Array[@ast.Block] = []
  let annotations : Array[@ast.BlockAnnotation] = []
  let warnings : Array[String] = []

  if slide_refs.length() == 0 {
    return (blocks, annotations, warnings)
  }

  for slide_ref in slide_refs {
    let slide_path = slide_ref.slide_path
    let (relationships, relationship_warnings) = parse_slide_relationships(
      archive, slide_path,
    )
    for warning in relationship_warnings {
      warnings.push(warning)
    }

    match @libzip.read_file_entry_decompressed(archive, slide_path) {
      Some(xml_bytes) => {
        let xml_string = @utf8.decode(xml_bytes) catch {
          _ => "__PPTX_SLIDE_DECODE_ERROR__"
        }
        if xml_string == "__PPTX_SLIDE_DECODE_ERROR__" {
          warnings.push(
            "Failed to decode slide XML as UTF-8: Slide \{slide_ref.slide_num} (\{slide_path}).",
          )
        } else {
          let (slide_blocks, slide_annotations, slide_warnings) = process_slide_xml_with_relationships_with_annotations(
            xml_string,
            slide_ref.slide_num,
            slide_path,
            archive,
            relationships,
            asset_placeholders,
          )
          for warning in slide_warnings {
            warnings.push(warning)
          }
          for block in slide_blocks {
            blocks.push(block)
          }
          for annotation in slide_annotations {
            annotations.push(annotation)
          }
        }
      }
      None =>
        warnings.push(
          "Failed to read slide XML: Slide \{slide_ref.slide_num} (\{slide_path}).",
        )
    }
  }

  (blocks, annotations, warnings)
}

fn process_slide_xml_with_relationships_with_annotations(
  xml : String,
  slide_num : Int,
  slide_path : String,
  archive : @libzip.ZipArchive,
  relationships : Array[SlideRelationship],
  asset_placeholders : Map[String, String],
) -> (Array[@ast.Block], Array[@ast.BlockAnnotation], Array[String]) {
  let (blocks, warning) = process_slide_xml(xml, slide_num, slide_path)
  let annotations : Array[@ast.BlockAnnotation] = annotate_pptx_blocks(
    blocks, slide_num, slide_path, "slide",
  )
  let warnings : Array[String] = []
  match warning {
    Some(message) => {
      warnings.push(message)
      return (blocks, annotations, warnings)
    }
    None => ()
  }

  let (chart_blocks, chart_annotations, chart_warnings) = extract_related_chart_blocks(
    archive, slide_num, slide_path, relationships,
  )
  for block in chart_blocks {
    blocks.push(block)
  }
  for annotation in chart_annotations {
    annotations.push(annotation)
  }
  for chart_warning in chart_warnings {
    warnings.push(chart_warning)
  }

  let (note_blocks, note_annotations, note_warnings) = extract_related_note_blocks(
    archive, slide_num, slide_path, relationships,
  )
  for block in note_blocks {
    blocks.push(block)
  }
  for annotation in note_annotations {
    annotations.push(annotation)
  }
  for note_warning in note_warnings {
    warnings.push(note_warning)
  }

  let (asset_blocks, asset_annotations, asset_warnings) = extract_related_asset_blocks(
    slide_num, slide_path, relationships, asset_placeholders,
  )
  for block in asset_blocks {
    blocks.push(block)
  }
  for annotation in asset_annotations {
    annotations.push(annotation)
  }
  for asset_warning in asset_warnings {
    warnings.push(asset_warning)
  }

  (blocks, annotations, warnings)
}

///|
fn process_slide_xml(
  xml : String,
  slide_num : Int,
  slide_path : String,
) -> (Array[@ast.Block], String?) {
  match @xml.parse_xml(xml) {
    Ok(events) => {
      let blocks = extract_slide_blocks(events, slide_num)
      (blocks, None)
    }
    Err(_) =>
      (
        [],
        Some("Failed to parse slide XML: Slide \{slide_num} (\{slide_path})."),
      )
  }
}

///|
priv struct SlideRelationship {
  target : String
  type_name : String
}

///|
fn parse_slide_relationships(
  archive : @libzip.ZipArchive,
  slide_path : String,
) -> (Array[SlideRelationship], Array[String]) {
  let relationships : Array[SlideRelationship] = []
  let warnings : Array[String] = []
  let rel_path = slide_relationship_path(slide_path)
  match @libzip.read_file_entry_decompressed(archive, rel_path) {
    Some(xml_bytes) => {
      let xml_string = @utf8.decode(xml_bytes) catch {
        _ => "__PPTX_REL_DECODE_ERROR__"
      }
      if xml_string == "__PPTX_REL_DECODE_ERROR__" {
        warnings.push(
          "Failed to decode slide relationships as UTF-8: \{rel_path}.",
        )
        return (relationships, warnings)
      }
      match @xml.parse_xml(xml_string) {
        Ok(events) =>
          extract_slide_relationship_events(events, slide_path, relationships)
        Err(_) =>
          warnings.push("Failed to parse slide relationships XML: \{rel_path}.")
      }
    }
    None => ()
  }
  (relationships, warnings)
}

///|
fn extract_slide_relationship_events(
  events : Array[@xml.ParseEvent],
  slide_path : String,
  relationships : Array[SlideRelationship],
) -> Unit {
  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let local_name = pptx_local_name(evt.name)
        if local_name == "Relationship" {
          let target = match evt.attributes.get("Target") {
            Some(value) => value
            None => ""
          }
          let type_name = match evt.attributes.get("Type") {
            Some(value) => value
            None => ""
          }
          if target != "" && type_name != "" {
            relationships.push(SlideRelationship::{
              target: resolve_pptx_target(slide_path, target),
              type_name,
            })
          }
        }
      }
      _ => ()
    }
  }
}

///|
fn slide_relationship_path(slide_path : String) -> String {
  let normalized = normalize_pptx_entry(slide_path)
  let file_name = path_basename(normalized)
  let directory = path_directory(normalized)
  directory + "/_rels/" + file_name + ".rels"
}

///|
fn extract_related_note_blocks(
  archive : @libzip.ZipArchive,
  slide_num : Int,
  slide_path : String,
  relationships : Array[SlideRelationship],
) -> (Array[@ast.Block], Array[@ast.BlockAnnotation], Array[String]) {
  let blocks : Array[@ast.Block] = []
  let annotations : Array[@ast.BlockAnnotation] = []
  let warnings : Array[String] = []
  for relationship in relationships {
    if relationship.type_name.has_suffix("/notesSlide") {
      match @libzip.read_file_entry_decompressed(archive, relationship.target) {
        Some(xml_bytes) => {
          let xml_string = @utf8.decode(xml_bytes) catch {
            _ => "__PPTX_NOTES_DECODE_ERROR__"
          }
          if xml_string == "__PPTX_NOTES_DECODE_ERROR__" {
            warnings.push(
              "Failed to decode notes XML as UTF-8: \{relationship.target}.",
            )
          } else {
            let (note_blocks, note_warning) = notes_blocks_from_xml(
              xml_string,
              relationship.target,
            )
            match note_warning {
              Some(message) => warnings.push(message)
              None => ()
            }
            for block in note_blocks {
              blocks.push(block)
            }
            for
              annotation in annotate_pptx_blocks(
                note_blocks,
                slide_num,
                relationship.target,
                "notes",
              ) {
              annotations.push(annotation)
            }
          }
        }
        None =>
          warnings.push(
            "Failed to read notes XML referenced by \{slide_path}: \{relationship.target}.",
          )
      }
    }
  }
  (blocks, annotations, warnings)
}

///|
fn notes_blocks_from_xml(
  xml : String,
  notes_path : String,
) -> (Array[@ast.Block], String?) {
  match @xml.parse_xml(xml) {
    Ok(events) => {
      let paragraphs = extract_notes_paragraphs(events)
      if paragraphs.length() == 0 {
        return ([], None)
      }
      let blocks : Array[@ast.Block] = [@ast.text_heading(4, "Speaker Notes")]
      for paragraph in paragraphs {
        blocks.push(@ast.text_paragraph(paragraph))
      }
      (blocks, None)
    }
    Err(_) => ([], Some("Failed to parse notes XML: \{notes_path}."))
  }
}

///|
priv struct NoteContext {
  mut in_text : Bool
  mut current_text : String
  paragraphs : Array[String]
}

///|
fn extract_notes_paragraphs(events : Array[@xml.ParseEvent]) -> Array[String] {
  let ctx = NoteContext::{ in_text: false, current_text: "", paragraphs: [] }
  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let local_name = pptx_local_name(evt.name)
        if local_name == "p" {
          ctx.current_text = ""
        } else if local_name == "t" {
          ctx.in_text = true
        }
      }
      @xml.TextContent(evt) =>
        if ctx.in_text {
          ctx.current_text = ctx.current_text + evt.content
        }
      @xml.ElementEnd(evt) => {
        let local_name = pptx_local_name(evt.name)
        if local_name == "t" {
          ctx.in_text = false
        } else if local_name == "p" {
          let paragraph = normalize_pptx_text(ctx.current_text)
          if paragraph != "" {
            ctx.paragraphs.push(paragraph)
          }
          ctx.current_text = ""
        }
      }
    }
  }
  compact_pptx_lines(ctx.paragraphs)
}

///|
fn extract_related_chart_blocks(
  archive : @libzip.ZipArchive,
  slide_num : Int,
  slide_path : String,
  relationships : Array[SlideRelationship],
) -> (Array[@ast.Block], Array[@ast.BlockAnnotation], Array[String]) {
  let blocks : Array[@ast.Block] = []
  let annotations : Array[@ast.BlockAnnotation] = []
  let warnings : Array[String] = []
  let mut chart_index = 1
  for relationship in relationships {
    if relationship.type_name.has_suffix("/chart") {
      match @libzip.read_file_entry_decompressed(archive, relationship.target) {
        Some(xml_bytes) => {
          let xml_string = @utf8.decode(xml_bytes) catch {
            _ => "__PPTX_CHART_DECODE_ERROR__"
          }
          if xml_string == "__PPTX_CHART_DECODE_ERROR__" {
            warnings.push(
              "Failed to decode chart XML as UTF-8: \{relationship.target}.",
            )
          } else {
            let (chart, chart_warning) = parse_chart_xml(
              xml_string,
              relationship.target,
            )
            match chart_warning {
              Some(message) => warnings.push(message)
              None => ()
            }
            match chart {
              Some(value) => {
                let chart_blocks = render_chart_blocks(value, chart_index)
                for block in chart_blocks {
                  blocks.push(block)
                }
                for
                  annotation in annotate_pptx_blocks(
                    chart_blocks,
                    slide_num,
                    relationship.target,
                    "chart",
                  ) {
                  annotations.push(annotation)
                }
                chart_index = chart_index + 1
              }
              None => ()
            }
          }
        }
        None =>
          warnings.push(
            "Failed to read chart XML referenced by \{slide_path}: \{relationship.target}.",
          )
      }
    }
  }
  (blocks, annotations, warnings)
}

///|
fn extract_related_asset_blocks(
  slide_num : Int,
  slide_path : String,
  relationships : Array[SlideRelationship],
  asset_placeholders : Map[String, String],
) -> (Array[@ast.Block], Array[@ast.BlockAnnotation], Array[String]) {
  let blocks : Array[@ast.Block] = []
  let annotations : Array[@ast.BlockAnnotation] = []
  let warnings : Array[String] = []
  let seen_targets : Array[String] = []
  for relationship in relationships {
    if !pptx_relationship_is_embedded_asset(relationship) {
      continue
    }
    if seen_targets.contains(relationship.target) {
      continue
    }
    seen_targets.push(relationship.target)
    match asset_placeholders.get(relationship.target) {
      Some(placeholder) => {
        if blocks.length() == 0 {
          blocks.push(@ast.text_heading(4, "Slide Assets"))
          annotations.push(
            pptx_block_annotation(slide_num, slide_path, "asset-index"),
          )
        }
        if pptx_relationship_is_image(relationship) {
          blocks.push(
            @ast.Paragraph([
              @ast.Image(@core.file_name_only(relationship.target), placeholder),
            ]),
          )
        } else {
          blocks.push(
            @ast.Paragraph([
              @ast.Link(
                [@ast.Text(@core.file_name_only(relationship.target))],
                placeholder,
              ),
            ]),
          )
        }
        annotations.push(
          pptx_block_annotation(slide_num, relationship.target, "asset"),
        )
      }
      None =>
        warnings.push(
          "PPTX slide asset relationship did not resolve to extracted asset: " +
          relationship.target,
        )
    }
  }
  (blocks, annotations, warnings)
}

///|
fn annotate_pptx_blocks(
  blocks : Array[@ast.Block],
  slide_num : Int,
  resource : String,
  kind : String,
) -> Array[@ast.BlockAnnotation] {
  let annotations : Array[@ast.BlockAnnotation] = []
  for _ in blocks {
    annotations.push(pptx_block_annotation(slide_num, resource, kind))
  }
  annotations
}

///|
fn pptx_block_annotation(
  slide_num : Int,
  resource : String,
  kind : String,
) -> @ast.BlockAnnotation {
  @ast.BlockAnnotation::{
    id: "",
    source_hint: Some("slide: " + slide_num.to_string()),
    origin_hint: Some("resource: " + resource + "; kind: " + kind),
    diagnostics: [],
  }
}

///|
fn pptx_relationship_is_embedded_asset(
  relationship : SlideRelationship,
) -> Bool {
  pptx_relationship_is_image(relationship) ||
  relationship.type_name.has_suffix("/package") ||
  relationship.type_name.has_suffix("/oleObject") ||
  relationship.target.has_prefix("ppt/embeddings/")
}

///|
fn pptx_relationship_is_image(relationship : SlideRelationship) -> Bool {
  relationship.type_name.has_suffix("/image") ||
  relationship.target.has_prefix("ppt/media/")
}

///|
priv struct ChartSeries {
  name : String
  categories : Array[String]
  values : Array[String]
}

///|
priv struct ChartData {
  title : String?
  series : Array[ChartSeries]
}

///|
priv enum ChartTextRole {
  NoRole
  TitleRole
  SeriesNameRole
  CategoryRole
  ValueRole
} derive(Eq)

///|
priv struct ChartContext {
  path : Array[String]
  mut current_text : String
  mut current_role : ChartTextRole
  title_parts : Array[String]
  mut current_series_name : String
  mut current_categories : Array[String]
  mut current_values : Array[String]
  series : Array[ChartSeries]
}

///|
fn parse_chart_xml(xml : String, chart_path : String) -> (ChartData?, String?) {
  match @xml.parse_xml(xml) {
    Ok(events) => {
      let ctx = ChartContext::{
        path: [],
        current_text: "",
        current_role: NoRole,
        title_parts: [],
        current_series_name: "",
        current_categories: [],
        current_values: [],
        series: [],
      }
      for event in events {
        match event {
          @xml.ElementStart(evt) => handle_chart_element_start(ctx, evt)
          @xml.TextContent(evt) =>
            if ctx.current_role != NoRole {
              ctx.current_text = ctx.current_text + evt.content
            }
          @xml.ElementEnd(evt) => handle_chart_element_end(ctx, evt.name)
        }
      }
      if ctx.series.length() == 0 &&
        compact_pptx_lines(ctx.title_parts).length() == 0 {
        return (None, None)
      }
      let title = chart_title_from_parts(ctx.title_parts)
      (Some(ChartData::{ title, series: copy_chart_series(ctx.series) }), None)
    }
    Err(_) => (None, Some("Failed to parse chart XML: \{chart_path}."))
  }
}

///|
fn handle_chart_element_start(
  ctx : ChartContext,
  evt : @xml.ElementStartEvent,
) -> Unit {
  let local_name = pptx_local_name(evt.name)
  ctx.path.push(local_name)
  if local_name == "ser" {
    ctx.current_series_name = ""
    ctx.current_categories = []
    ctx.current_values = []
  } else if local_name == "t" || local_name == "v" {
    ctx.current_text = ""
    ctx.current_role = chart_text_role(ctx.path)
  }
}

///|
fn handle_chart_element_end(ctx : ChartContext, name : String) -> Unit {
  let local_name = pptx_local_name(name)
  if local_name == "t" || local_name == "v" {
    let text = normalize_pptx_text(ctx.current_text)
    if text != "" {
      match ctx.current_role {
        TitleRole => ctx.title_parts.push(text)
        SeriesNameRole =>
          ctx.current_series_name = append_chart_text(
            ctx.current_series_name,
            text,
          )
        CategoryRole => ctx.current_categories.push(text)
        ValueRole => ctx.current_values.push(text)
        NoRole => ()
      }
    }
    ctx.current_text = ""
    ctx.current_role = NoRole
  } else if local_name == "ser" {
    if ctx.current_series_name != "" || ctx.current_values.length() > 0 {
      ctx.series.push(ChartSeries::{
        name: ctx.current_series_name,
        categories: copy_string_array(ctx.current_categories),
        values: copy_string_array(ctx.current_values),
      })
    }
    ctx.current_series_name = ""
    ctx.current_categories = []
    ctx.current_values = []
  }
  ignore(ctx.path.pop())
}

///|
fn chart_text_role(path : Array[String]) -> ChartTextRole {
  if path_contains(path, "ser") {
    if path_contains(path, "val") {
      return ValueRole
    }
    if path_contains(path, "cat") {
      return CategoryRole
    }
    if path_contains(path, "tx") {
      return SeriesNameRole
    }
  }
  if path_contains(path, "title") {
    return TitleRole
  }
  NoRole
}

///|
fn chart_title_from_parts(parts : Array[String]) -> String? {
  let title = compact_pptx_lines(parts).join(" ")
  if title == "" {
    None
  } else {
    Some(title)
  }
}

///|
fn append_chart_text(current : String, next : String) -> String {
  if current == "" {
    next
  } else {
    current + " " + next
  }
}

///|
fn render_chart_blocks(
  chart : ChartData,
  chart_index : Int,
) -> Array[@ast.Block] {
  let blocks : Array[@ast.Block] = []
  let title = match chart.title {
    Some(value) if value != "" => value
    _ => "Chart " + chart_index.to_string()
  }
  blocks.push(@ast.text_heading(4, title))

  if chart.series.length() == 0 {
    return blocks
  }

  let categories = merged_chart_categories(chart.series)
  let row_count = max_chart_row_count(chart.series, categories.length())
  let headers : Array[Array[@ast.Inline]] = [@ast.text_inlines("Category")]
  let mut series_index = 1
  for series in chart.series {
    let header = if series.name != "" {
      series.name
    } else {
      "Series " + series_index.to_string()
    }
    headers.push(@ast.text_inlines(header))
    series_index = series_index + 1
  }

  let rows : Array[Array[Array[@ast.Inline]]] = []
  let mut row_index = 0
  while row_index < row_count {
    let row : Array[Array[@ast.Inline]] = []
    row.push(@ast.text_inlines(chart_category_at(categories, row_index)))
    for series in chart.series {
      let value = if row_index < series.values.length() {
        series.values[row_index]
      } else {
        ""
      }
      row.push(@ast.text_inlines(value))
    }
    rows.push(row)
    row_index = row_index + 1
  }
  blocks.push(@ast.Table(headers, rows))
  blocks
}

///|
fn merged_chart_categories(series : Array[ChartSeries]) -> Array[String] {
  for item in series {
    if item.categories.length() > 0 {
      return copy_string_array(item.categories)
    }
  }
  []
}

///|
fn max_chart_row_count(
  series : Array[ChartSeries],
  category_count : Int,
) -> Int {
  let mut row_count = category_count
  for item in series {
    if item.values.length() > row_count {
      row_count = item.values.length()
    }
  }
  row_count
}

///|
fn chart_category_at(categories : Array[String], index : Int) -> String {
  if index < categories.length() {
    categories[index]
  } else {
    "Item " + (index + 1).to_string()
  }
}

///|
fn copy_chart_series(values : Array[ChartSeries]) -> Array[ChartSeries] {
  let copied : Array[ChartSeries] = []
  for value in values {
    copied.push(ChartSeries::{
      name: value.name,
      categories: copy_string_array(value.categories),
      values: copy_string_array(value.values),
    })
  }
  copied
}

///|
fn path_contains(path : Array[String], segment : String) -> Bool {
  for item in path {
    if item == segment {
      return true
    }
  }
  false
}

///|
priv enum ShapeKind {
  Title
  Subtitle
  Body
  Generic
} derive(Eq)

///|
priv enum ShapeParagraphKind {
  Plain
  Bullet
  Numbered
} derive(Eq)

///|
priv struct ShapeParagraph {
  text : String
  kind : ShapeParagraphKind
}

///|
priv struct SlideContext {
  mut in_text : Bool
  mut current_text : String
  mut in_shape : Bool
  mut shape_kind : ShapeKind
  mut shape_name : String
  mut current_paragraph_kind : ShapeParagraphKind
  mut shape_paragraphs : Array[ShapeParagraph]
  mut in_table : Bool
  mut in_table_cell : Bool
  mut current_cell_paragraphs : Array[String]
  mut current_row : Array[String]
  mut table_rows : Array[Array[String]]
  blocks : Array[@ast.Block]
}

///|
fn extract_slide_blocks(
  events : Array[@xml.ParseEvent],
  slide_num : Int,
) -> Array[@ast.Block] {
  let ctx = SlideContext::{
    in_text: false,
    current_text: "",
    in_shape: false,
    shape_kind: Generic,
    shape_name: "",
    current_paragraph_kind: Plain,
    shape_paragraphs: [],
    in_table: false,
    in_table_cell: false,
    current_cell_paragraphs: [],
    current_row: [],
    table_rows: [],
    blocks: [@ast.text_heading(2, "Slide " + slide_num.to_string())],
  }

  for event in events {
    match event {
      @xml.ElementStart(evt) => handle_slide_element_start(ctx, evt)
      @xml.ElementEnd(evt) => handle_slide_element_end(ctx, evt.name)
      @xml.TextContent(evt) =>
        if ctx.in_text {
          ctx.current_text = ctx.current_text + evt.content
        }
    }
  }

  ctx.blocks
}

///|
fn handle_slide_element_start(
  ctx : SlideContext,
  evt : @xml.ElementStartEvent,
) -> Unit {
  let local_name = pptx_local_name(evt.name)

  match local_name {
    "sp" => begin_shape(ctx)
    "cNvPr" => update_shape_kind_from_name(ctx, evt.attributes.get("name"))
    "ph" => update_shape_kind_from_placeholder(ctx, evt.attributes.get("type"))
    "tbl" => begin_table(ctx)
    "tr" => if ctx.in_table { ctx.current_row = [] }
    "tc" =>
      if ctx.in_table {
        ctx.in_table_cell = true
        ctx.current_cell_paragraphs = []
      }
    "p" => begin_shape_paragraph(ctx)
    "buChar" =>
      if ctx.in_shape && !ctx.in_table {
        ctx.current_paragraph_kind = Bullet
      }
    "buAutoNum" =>
      if ctx.in_shape && !ctx.in_table {
        ctx.current_paragraph_kind = Numbered
      }
    "br" =>
      if ctx.in_shape || (ctx.in_table && ctx.in_table_cell) {
        ctx.current_text = ctx.current_text + "\n"
      }
    "t" => ctx.in_text = true
    _ => ()
  }
}

///|
fn handle_slide_element_end(ctx : SlideContext, name : String) -> Unit {
  let local_name = pptx_local_name(name)

  match local_name {
    "t" => ctx.in_text = false
    "p" => finish_paragraph(ctx)
    "tc" => finish_table_cell(ctx)
    "tr" => finish_table_row(ctx)
    "tbl" => finish_table(ctx)
    "sp" => finish_shape(ctx)
    _ => ()
  }
}

///|
fn begin_shape(ctx : SlideContext) -> Unit {
  ctx.in_shape = true
  ctx.shape_kind = Generic
  ctx.shape_name = ""
  ctx.current_paragraph_kind = Plain
  ctx.shape_paragraphs = []
}

///|
fn finish_shape(ctx : SlideContext) -> Unit {
  if !ctx.in_shape {
    return
  }
  let paragraphs = compact_shape_paragraphs(ctx.shape_paragraphs)
  if paragraphs.length() > 0 {
    emit_shape_blocks(ctx, paragraphs)
  }
  ctx.in_shape = false
  ctx.shape_kind = Generic
  ctx.shape_name = ""
  ctx.current_paragraph_kind = Plain
  ctx.shape_paragraphs = []
}

///|
fn begin_shape_paragraph(ctx : SlideContext) -> Unit {
  ctx.current_text = ""
  if ctx.in_shape && !ctx.in_table {
    ctx.current_paragraph_kind = Plain
  }
}

///|
fn begin_table(ctx : SlideContext) -> Unit {
  ctx.in_table = true
  ctx.in_table_cell = false
  ctx.current_cell_paragraphs = []
  ctx.current_row = []
  ctx.table_rows = []
}

///|
fn finish_paragraph(ctx : SlideContext) -> Unit {
  let paragraph = normalize_pptx_text(ctx.current_text)
  if paragraph != "" {
    if ctx.in_table && ctx.in_table_cell {
      ctx.current_cell_paragraphs.push(paragraph)
    } else if ctx.in_shape {
      ctx.shape_paragraphs.push(ShapeParagraph::{
        text: paragraph,
        kind: ctx.current_paragraph_kind,
      })
    }
  }
  ctx.current_text = ""
  ctx.current_paragraph_kind = Plain
}

///|
fn finish_table_cell(ctx : SlideContext) -> Unit {
  if !ctx.in_table || !ctx.in_table_cell {
    return
  }
  let lines = compact_pptx_lines(ctx.current_cell_paragraphs)
  ctx.current_row.push(lines.join("\n"))
  ctx.current_cell_paragraphs = []
  ctx.in_table_cell = false
}

///|
fn finish_table_row(ctx : SlideContext) -> Unit {
  if !ctx.in_table {
    return
  }
  let row = compact_pptx_lines(ctx.current_row)
  if row.length() > 0 {
    ctx.table_rows.push(copy_string_array(row))
  }
  ctx.current_row = []
}

///|
fn finish_table(ctx : SlideContext) -> Unit {
  if !ctx.in_table {
    return
  }
  let rows = compact_table_rows(ctx.table_rows)
  if rows.length() > 0 {
    let headers : Array[Array[@ast.Inline]] = []
    for header in rows[0] {
      headers.push(@ast.text_inlines(header))
    }
    let body_rows : Array[Array[Array[@ast.Inline]]] = []
    let mut row_index = 1
    while row_index < rows.length() {
      let body_row : Array[Array[@ast.Inline]] = []
      for cell in rows[row_index] {
        body_row.push(@ast.text_inlines(cell))
      }
      body_rows.push(body_row)
      row_index = row_index + 1
    }
    ctx.blocks.push(@ast.Table(headers, body_rows))
  }
  ctx.in_table = false
  ctx.in_table_cell = false
  ctx.current_cell_paragraphs = []
  ctx.current_row = []
  ctx.table_rows = []
}

///|
fn emit_shape_blocks(
  ctx : SlideContext,
  paragraphs : Array[ShapeParagraph],
) -> Unit {
  match ctx.shape_kind {
    Title => {
      ctx.blocks.push(@ast.text_heading(3, paragraphs[0].text))
      let mut index = 1
      while index < paragraphs.length() {
        ctx.blocks.push(@ast.text_paragraph(paragraphs[index].text))
        index = index + 1
      }
    }
    Body | Subtitle | Generic => {
      if ctx.shape_kind == Body &&
        paragraphs.length() > 1 &&
        all_shape_paragraphs_are_plain(paragraphs) {
        let items : Array[Array[@ast.Inline]] = []
        for paragraph in paragraphs {
          items.push(@ast.text_inlines(paragraph.text))
        }
        ctx.blocks.push(@ast.List(items, false))
        return
      }
      emit_shape_paragraph_sequence(ctx.blocks, paragraphs)
    }
  }
}

///|
fn emit_shape_paragraph_sequence(
  blocks : Array[@ast.Block],
  paragraphs : Array[ShapeParagraph],
) -> Unit {
  let mut pending_items : Array[Array[@ast.Inline]] = []
  let mut pending_ordered = false
  let mut has_pending_list = false
  for paragraph in paragraphs {
    match paragraph.kind {
      Plain => {
        flush_shape_list(
          blocks, pending_items, has_pending_list, pending_ordered,
        )
        has_pending_list = false
        pending_ordered = false
        blocks.push(@ast.text_paragraph(paragraph.text))
      }
      Bullet | Numbered => {
        let next_ordered = paragraph.kind == Numbered
        if has_pending_list && pending_ordered != next_ordered {
          flush_shape_list(
            blocks, pending_items, has_pending_list, pending_ordered,
          )
          pending_items = []
          has_pending_list = false
        }
        if !has_pending_list {
          pending_items = []
          pending_ordered = next_ordered
          has_pending_list = true
        }
        pending_items.push(@ast.text_inlines(paragraph.text))
      }
    }
  }
  flush_shape_list(blocks, pending_items, has_pending_list, pending_ordered)
}

///|
fn flush_shape_list(
  blocks : Array[@ast.Block],
  items : Array[Array[@ast.Inline]],
  has_items : Bool,
  ordered : Bool,
) -> Unit {
  if has_items && items.length() > 0 {
    blocks.push(@ast.List(items, ordered))
  }
}

///|
fn all_shape_paragraphs_are_plain(paragraphs : Array[ShapeParagraph]) -> Bool {
  for paragraph in paragraphs {
    if paragraph.kind != Plain {
      return false
    }
  }
  true
}

///|
fn update_shape_kind_from_name(ctx : SlideContext, name : String?) -> Unit {
  guard ctx.in_shape else { return }
  match name {
    Some(value) => {
      ctx.shape_name = value
      let lowered = value.to_lower()
      if lowered.contains("subtitle") {
        promote_shape_kind(ctx, Subtitle)
      } else if lowered.contains("title") {
        promote_shape_kind(ctx, Title)
      } else if lowered.contains("content placeholder") ||
        lowered.contains("text placeholder") {
        promote_shape_kind(ctx, Body)
      }
    }
    None => ()
  }
}

///|
fn update_shape_kind_from_placeholder(
  ctx : SlideContext,
  placeholder_type : String?,
) -> Unit {
  guard ctx.in_shape else { return }
  match placeholder_type {
    Some(kind) => {
      let lowered = kind.to_lower()
      if lowered == "title" || lowered == "ctrtitle" {
        promote_shape_kind(ctx, Title)
      } else if lowered == "subtitle" {
        promote_shape_kind(ctx, Subtitle)
      } else if lowered == "body" || lowered == "obj" {
        promote_shape_kind(ctx, Body)
      }
    }
    None =>
      if ctx.shape_name.to_lower().contains("content placeholder") {
        promote_shape_kind(ctx, Body)
      }
  }
}

///|
fn promote_shape_kind(ctx : SlideContext, next : ShapeKind) -> Unit {
  match next {
    Title => ctx.shape_kind = Title
    Subtitle => if ctx.shape_kind != Title { ctx.shape_kind = Subtitle }
    Body => if ctx.shape_kind == Generic { ctx.shape_kind = Body }
    Generic => ()
  }
}

///|
fn normalize_pptx_text(text : String) -> String {
  let trimmed = text.trim()
  if trimmed == "" {
    return ""
  }
  let mut result = ""
  let mut pending_space = false
  for ch in trimmed {
    if ch == '\n' || ch == '\r' || ch == '\t' || ch == ' ' {
      pending_space = result != ""
    } else {
      if pending_space {
        result = result + " "
        pending_space = false
      }
      result = result + ch.to_string()
    }
  }
  result
}

///|
fn compact_pptx_lines(values : Array[String]) -> Array[String] {
  let compacted : Array[String] = []
  for value in values {
    let normalized = normalize_pptx_text(value)
    if normalized != "" {
      compacted.push(normalized)
    }
  }
  compacted
}

///|
fn compact_shape_paragraphs(
  values : Array[ShapeParagraph],
) -> Array[ShapeParagraph] {
  let compacted : Array[ShapeParagraph] = []
  for value in values {
    let normalized = normalize_pptx_text(value.text)
    if normalized != "" {
      compacted.push(ShapeParagraph::{ text: normalized, kind: value.kind })
    }
  }
  compacted
}

///|
fn compact_table_rows(rows : Array[Array[String]]) -> Array[Array[String]] {
  let compacted : Array[Array[String]] = []
  for row in rows {
    let normalized = compact_pptx_lines(row)
    if normalized.length() > 0 {
      compacted.push(normalized)
    }
  }
  compacted
}

///|
fn copy_string_array(values : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn path_directory(path : String) -> String {
  let normalized = normalize_pptx_entry(path)
  match @core.find_last_char(normalized, '/') {
    Some(index) => normalized[:index].to_string()
    None => ""
  }
}

///|
fn path_basename(path : String) -> String {
  let normalized = normalize_pptx_entry(path)
  match @core.find_last_char(normalized, '/') {
    Some(index) => normalized[index + 1:].to_string()
    None => normalized
  }
}

///|
fn resolve_pptx_target(base_entry : String, target : String) -> String {
  let segments : Array[String] = []
  for segment in path_directory(base_entry).split("/").to_array() {
    if segment != "" {
      segments.push(segment.to_string())
    }
  }
  for
    segment in strip_leading_slashes(normalize_pptx_entry(target))
    .split("/")
    .to_array() {
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      ignore(segments.pop())
    } else {
      segments.push(segment.to_string())
    }
  }
  segments.join("/")
}

///|
fn strip_leading_slashes(path : String) -> String {
  let mut result = ""
  let mut started = false
  for ch in path {
    if !started && ch == '/' {
      continue
    }
    started = true
    result = result + ch.to_string()
  }
  result
}

///|
fn normalize_pptx_entry(path : String) -> String {
  path.replace(old="\\", new="/")
}
