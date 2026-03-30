## HTML/URL Optimization Plan

Date: 2026-03-30

### Goal

Improve MoonBitMark's `HTML/URL -> Markdown` path without changing the overall architecture or introducing bridge/runtime dependencies, and make the resulting conversion quality better than MarkItDown on the covered HTML/URL scenarios.

### Baseline Findings

Local comparison against the installed `markitdown` package and the upstream implementation shows:

- MarkItDown's HTML path is `BeautifulSoup(body) -> markdownify`, with `script/style` removal only.
- MarkItDown preserves many inline/block constructs well, but it does not extract the primary readable content, does not resolve relative URLs against page/base URLs, and does not sanitize lazy/unsafe image/link sources well.
- MoonBitMark already removes `nav/aside/footer` noise, but its current string-slicing parser has weak spots:
  - nested block content in `<blockquote>` is rendered incorrectly
  - URL/base resolution is missing
  - unsafe `javascript:` links/images are not filtered
  - lazy image attributes like `data-src` are ignored
  - table header spans (`rowspan` / `colspan`) are flattened poorly
  - attribute/entity handling is too narrow

### Planned Changes

1. Keep the HTML converter pure MoonBit and package-local.
2. Add HTML parsing helpers that are still string-based, but support:
   - balanced same-tag matching
   - case-insensitive attribute parsing
   - richer entity decoding
3. Improve content selection for web pages:
   - prefer `<article>` / `<main>` content when present
   - continue dropping clear navigation/sidebar/footer noise
4. Improve block rendering:
   - render nested blockquote content from parsed blocks instead of inline-only flattening
   - improve table normalization so grouped headers produce better Markdown columns
5. Improve URL handling:
   - compute document base from input URL and `<base href>`
   - resolve relative links/images for URL inputs
   - keep safe schemes, drop unsafe executable schemes
   - support lazy image attributes such as `data-src` / `srcset`
6. Expand regression and quality coverage:
   - strengthen HTML package whitebox tests
   - add conversion-eval fixtures that expose gaps where MarkItDown is weaker

### Non-Goals

- No Python/bridge dependency for HTML conversion
- No architecture change to the engine registration model
- No AST-wide refactor unless strictly required for HTML quality

### Completion Criteria

- HTML package tests pass
- Full `moon test` passes
- `moon info` / `moon fmt` complete cleanly
- `conversion_eval` still passes and HTML cases remain regression-safe
- New HTML quality cases show MoonBitMark outperforming MarkItDown on the targeted scenarios
