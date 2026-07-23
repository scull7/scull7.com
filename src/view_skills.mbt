// Extracted from shell.mbt — Item 1 modularization

fn skill_block(title : String, items : Array[String]) -> @dom.DomNode {
  @dom.div() <| [
    @dom.h2(class="section-title") <| [@dom.text(title)],
    @dom.div(class="competency-grid", style="margin-bottom:18px") <| pills(items, false),
  ]
}

///|
fn view_skills(data : ResumeView) -> @dom.DomNode {
  let s = data.skills
  @dom.div() <| [
    skill_block("languages (active)", s.languages_active),
    skill_block("languages (prior)", s.languages_prior),
    skill_block("web / ui", s.web),
    skill_block("data", s.data),
    skill_block("infrastructure", s.infra),
    skill_block("cloud", s.cloud),
    skill_block("ci / cd", s.cicd),
  ]
}

