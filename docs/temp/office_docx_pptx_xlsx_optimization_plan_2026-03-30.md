# Office Markdown Optimization Plan (2026-03-30)

## Scope

This round targets `DOCX / PPTX / XLSX` only, with two constraints:

- keep the current MoonBitMark architecture intact
- improve real Markdown semantics, not just benchmark scores

## Baseline Findings

### Current MoonBitMark vs MarkItDown

- On the local conversion-eval corpus before this round, MoonBitMark was already ahead of the installed `markitdown` baseline on `docx/pptx/xlsx`.
- The gap was especially large on `pptx` and `xlsx`, where MoonBitMark already produced structured Markdown while MarkItDown often fell back to low-fidelity or noisy output.
- However, source inspection still showed clear Office-specific capability gaps inside MoonBitMark itself.

### Capability Gaps Inside MoonBitMark

#### DOCX

- list paragraphs were emitted one-by-one instead of grouped as Markdown lists
- numbered lists lost ordered semantics
- nested list depth was flattened without any visual cue
- `w:tbl` content was ignored instead of becoming Markdown tables

#### PPTX

- slide images were only available through the extracted asset list
- slide-local media had no direct Markdown representation near the slide content

#### XLSX

- a whole worksheet was rendered as one sparse table, even when it contained multiple disconnected tables
- formula cells with no cached value could become empty
- extracted workbook assets were suppressed from the Markdown result
- title rows inside sheet regions were not promoted into a cleaner structure

## Implementation Plan

### 1. DOCX semantic block recovery

- parse `word/numbering.xml` and restore ordered vs unordered list semantics
- group consecutive list paragraphs into one Markdown list block
- preserve nested list depth with stable indentation cues
- convert `w:tbl` into Markdown tables without changing the AST architecture

### 2. PPTX slide-local asset recovery

- keep existing title/list/chart/notes logic
- attach slide-related images and embedded assets back to the corresponding slide output
- keep the existing asset extraction path for OCR and file export

### 3. XLSX region-aware rendering

- split a worksheet into disconnected non-empty regions instead of one sparse mega-table
- promote single-cell leading title rows into Markdown headings when followed by a table
- fall back to formula text when cached values are missing
- append embedded workbook assets to Markdown output instead of suppressing them

## Completed Changes

- DOCX now parses numbering definitions, groups list items, preserves ordered lists, and renders DOCX tables.
- PPTX now emits slide-local asset blocks so image slides are represented in-place instead of only in a global appendix.
- XLSX now renders disconnected sheet regions as separate tables, promotes title rows, preserves formula fallback text, and emits workbook assets.

## Validation Plan

- run `moon test` for the touched format packages first
- update affected golden Markdown fixtures
- run repository-wide `moon test`
- run `moon info`
- run `moon fmt`
- run conversion eval with baseline comparison to confirm MoonBitMark remains ahead of local MarkItDown on the Office subset
