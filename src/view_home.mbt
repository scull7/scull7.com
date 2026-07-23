// Extracted from shell.mbt — Item 1 modularization

fn view_home(data : ResumeView) -> @dom.DomNode {
  let paragraphs = split_paragraphs(data.summary)
  @dom.div() <| [
    @dom.div(class="hero") <| [
      @dom.div(class="hero-kicker") <| [@dom.text("~/scull7.com")],
      @dom.h1() <| [@dom.text(data.profile.name)],
      @dom.p(class="tagline") <| [@dom.text(data.profile.tagline)],
      @dom.div(class="hero-links") <| [
        @dom.a(href="mailto:" + data.profile.email) <| [@dom.text(data.profile.email)],
        @dom.a(
          href=data.profile.linkedin,
          attrs=[("target", attr_s("_blank")), ("rel", attr_s("noopener"))],
        ) <| [@dom.text("linkedin/in/scull7")],
        @dom.a(
          href=data.profile.github,
          attrs=[("target", attr_s("_blank")), ("rel", attr_s("noopener"))],
        ) <| [@dom.text("github.com/scull7")],
      ],
    ],
    @dom.h2(class="section-title") <| [@dom.text("summary")],
    @dom.div() <| paragraphs.map(para => @dom.p(class="summary") <| [@dom.text(para)]),
    @dom.div(class="competency-grid") <| pills(data.competencies, true),
    @dom.div(class="help-strip") <| [
      @dom.span() <| [
        @dom.text(": command · / search · j/k buffers · Enter open · gg/G · ? help"),
      ],
    ],
  ]
}

