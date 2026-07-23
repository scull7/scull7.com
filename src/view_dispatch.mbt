// Extracted from shell.mbt — Item 1 modularization

fn buffer_content(
  data : ResumeView,
  buf : BufferDef,
  term_lines : @resource.Signal[Array[String]],
  on_term : (String) -> Unit,
) -> @dom.DomNode {
  match buf.kind {
    Home => view_home(data)
    Experience => view_experience(data)
    Highlights => view_highlights(data)
    Skills => view_skills(data)
    OpenSource => view_oss(data)
    Code => view_code(buf)
    Relay => view_relay()
    Terminal => view_terminal(term_lines, on_term)
    Help => view_help()
  }
}

