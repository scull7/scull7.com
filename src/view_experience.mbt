// Extracted from shell.mbt — Item 1 modularization

fn view_experience(data : ResumeView) -> @dom.DomNode {
  @dom.div() <| [
    @dom.h2(class="section-title") <| [@dom.text("work experience")],
    @dom.div() <| data.experience.map(job =>
      @dom.div(class="job", id="job-" + job.id) <| [
        @dom.div(class="job-head") <| [
          @dom.div(class="job-title") <| [
            @dom.text(job.role + " · "),
            @dom.span(class="company") <| [@dom.text(job.company)],
          ],
          @dom.div(class="job-meta") <| [@dom.text(job.dates + " · " + job.location)],
        ],
        @dom.ul() <| job.bullets.map(b => @dom.li() <| [@dom.text(b)]),
      ]
    ),
  ]
}

