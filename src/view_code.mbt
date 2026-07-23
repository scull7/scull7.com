// Extracted from shell.mbt — Item 1 modularization

fn view_code(buf : BufferDef) -> @dom.DomNode {
  @dom.div() <| [
    @dom.h2(class="section-title") <| [@dom.text(buf.label)],
    @dom.pre(class="code-block") <| highlight_code(code_sample(buf.sample)),
    @dom.p(class="code-caption") <| [
      @dom.text("sample buffer · read-only · syntax tint"),
    ],
  ]
}
