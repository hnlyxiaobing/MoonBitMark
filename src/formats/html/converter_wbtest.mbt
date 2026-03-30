///|
test "html title and warnings" {
  inspect(
    extract_title("<html><head><title> Demo </title></head></html>"),
    content="Some(\"Demo\")",
  )
  inspect(
    collect_html_warnings("<style>a{}</style><script>x()</script>").length(),
    content="2",
  )
}

///|
test "html direct ast document" {
  let doc = html_to_document(
    "<body><h1>Demo</h1><p>Hello <strong>world</strong></p><ul><li>A</li><li>B</li></ul></body>",
    Some("Demo"),
  )
  inspect(doc.blocks.length(), content="3")
}

///|
test "html prepends title when body heading differs" {
  let doc = html_to_document(
    "<html><head><title>Simple Table Test</title></head><body><h1>Sample Data Table</h1></body></html>",
    Some("Simple Table Test"),
  )
  inspect(
    @ast.render_markdown(doc),
    content="Simple Table Test\n\n# Sample Data Table",
  )
}

///|
test "html unwraps div containers into nested blocks" {
  let doc = html_to_document(
    "<body><div><h2>Nested</h2><p>Hello</p><ul><li>A</li><li>B</li></ul></div></body>",
    None,
  )
  inspect(@ast.render_markdown(doc), content="## Nested\n\nHello\n\n- A\n- B")
}

///|
test "html warning diagnostics carry typed source" {
  let diagnostics = html_warning_diagnostics(
    "https://example.com", "<style>a{}</style><script>x()</script>",
  )
  inspect(diagnostics.length(), content="2")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: normalize/preprocess\n  Source: https://example.com\n  Message: Dropped <script> blocks during HTML conversion.\n  Hint: Scripts are intentionally removed before Markdown rendering.",
  )
}

///|
test "html table cells preserve inline formatting" {
  inspect(
    @ast.render_inlines(
      extract_html_table_cells(
        "<tr><td><strong>Total Products:</strong></td><td>4</td></tr>",
        None,
      )[0].content,
    ),
    content="**Total Products:**",
  )
}

///|
test "html unwraps header containers" {
  let doc = html_to_document(
    "<body><header><h2>Hero</h2><p>Intro</p></header></body>",
    None,
  )
  inspect(@ast.render_markdown(doc), content="## Hero\n\nIntro")
}

///|
test "html blockquote keeps nested paragraph and list structure" {
  let doc = html_to_document(
    "<body><article><blockquote><p>Quoted <strong>lead</strong>.</p><ul><li>Point A</li><li>Point B</li></ul></blockquote></article></body>",
    None,
  )
  inspect(
    @ast.render_markdown(doc),
    content="> Quoted **lead**.\n> \n> - Point A\n> - Point B",
  )
}

///|
test "html resolves base urls and filters unsafe link/image sources" {
  inspect(
    html_document_base(
      "https://example.com/posts/page.html", "<html><head><base href=\"../articles/\"></head></html>",
    ),
    content="Some(\"https://example.com/articles\")",
  )
  let doc = html_to_document_with_base(
    "<body><p><a href=\"guide.html#intro\">Guide</a></p><p><a href=\"javascript:alert(1)\">Bad Link</a></p><p><img alt=\"Lazy\" data-src=\"images/lazy.png\"/></p><p><img alt=\"Tracker\" src=\"javascript:evil()\"/></p></body>",
    Some("Base Demo"),
    Some("https://example.com/articles/index.html"),
  )
  inspect(
    @ast.render_markdown(doc),
    content="Base Demo\n\n[Guide](https://example.com/articles/guide.html#intro)\n\nBad Link\n\n![Lazy](https://example.com/articles/images/lazy.png)\n\nTracker",
  )
}

///|
test "html merges grouped table headers from colspan and rowspan" {
  let doc = html_to_document(
    "<body><table><tr><th rowspan=\"2\">Region</th><th colspan=\"2\">Sales</th><th rowspan=\"2\">Total</th></tr><tr><th>Q1</th><th>Q2</th></tr><tr><td>NA</td><td>10</td><td>11</td><td>21</td></tr></table></body>",
    None,
  )
  inspect(
    @ast.render_markdown(doc),
    content="| Region | Sales Q1 | Sales Q2 | Total |\n| --- | --- | --- | --- |\n| NA | 10 | 11 | 21 |",
  )
}

///|
test "html parses standalone pre code blocks" {
  inspect(
    take_tag_parts(
      "<pre><code class=\"language-js\">const total = 42;</code></pre>", "pre",
    )
    is Some(_),
    content="true",
  )
  let block = parse_pre_html_block(
    "<pre><code class=\"language-js\">const total = 42;</code></pre>",
  )
  inspect(
    match block {
      Some((value, _)) =>
        @ast.render_markdown(@ast.Document::{
          title: None,
          metadata: {},
          blocks: [value],
        })
      None => "none"
    },
    content="``` js\nconst total = 42;\n```",
  )
}

///|
test "html keeps pre code blocks inside article flow" {
  let doc = html_to_document(
    "<body><article><h1>Main Story</h1><blockquote>Quoted insight.</blockquote><pre><code class=\"language-js\">const total = 42;</code></pre></article></body>",
    Some("Noisy Article"),
  )
  inspect(
    @ast.render_markdown(doc),
    content="Noisy Article\n\n# Main Story\n\n> Quoted insight.\n\n``` js\nconst total = 42;\n```",
  )
}
