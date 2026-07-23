// Extracted from shell.mbt — Item 1 modularization

fn view_highlights(data : ResumeView) -> @dom.DomNode {
  @dom.div() <| [
    @dom.h2(class="section-title") <| [@dom.text("career highlights")],
    @dom.ul() <| data.highlights.map(h =>
      @dom.li(style="margin:10px 0;color:var(--text-dim)") <| [@dom.text(h)]
    ),
    @dom.h2(class="section-title", style="margin-top:28px") <| [@dom.text("education")],
    @dom.div() <| data.education.map(e =>
      @dom.div(class="job") <| [
        @dom.div(class="job-head") <| [
          @dom.div(class="job-title") <| [@dom.text(e.school)],
          @dom.div(class="job-meta") <| [@dom.text(e.dates)],
        ],
        @dom.div(style="color:var(--text-dim)") <| [@dom.text(e.detail)],
      ]
    ),
  ]
}

