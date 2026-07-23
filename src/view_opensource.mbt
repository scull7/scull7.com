// Extracted from shell.mbt — Item 1 modularization

fn view_oss(data : ResumeView) -> @dom.DomNode {
  @dom.div() <| [
    @dom.h2(class="section-title") <| [@dom.text("open source")],
    @dom.div() <| data.open_source.map(o =>
      @dom.div(class="oss-card") <| [
        @dom.h2(class="section-title") <| [
          @dom.a(
            href=o.url,
            attrs=[("target", attr_s("_blank")), ("rel", attr_s("noopener"))],
          ) <| [@dom.text(o.name)],
          @dom.text(" "),
          @dom.span(class="pill") <| [@dom.text(o.lang)],
        ],
        @dom.p() <| [@dom.text(o.blurb)],
      ]
    ),
    @dom.p(style="margin-top:18px;color:var(--text-mute);font-family:var(--font-mono);font-size:12px") <| [
      @dom.text("github.com/scull7 · crates.io/users/scull7"),
    ],
  ]
}

