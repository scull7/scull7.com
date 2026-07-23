// Extracted from shell.mbt — Item 1 modularization

fn view_terminal(lines : @resource.Signal[Array[String]], on_submit : (String) -> Unit) -> @dom.DomNode {
  @dom.div() <| [
    @dom.h2(class="section-title") <| [@dom.text("live terminal")],
    @dom.div(class="terminal glass") <| [
      @dom.div(class="terminal-output") <| [
        @dom.index_each(
          fn() { lines.get() },
          fn(get_line, _) { @dom.div() <| [@dom.text_dyn(fn() { get_line() })] },
        ),
      ],
      @dom.div(class="terminal-input-row") <| [
        @dom.span(class="terminal-prompt") <| [@dom.text("scull7@resume:~$")],
        @dom.input(
          class="terminal-input",
          attrs=[
            ("autocomplete", attr_s("off")),
            ("spellcheck", attr_s("false")),
          ],
          on=@dom.events().keydown(e => {
            if e.key == "Enter" {
              e.preventDefault()
              let inp = @js_dom.HTMLInputElement::cast_from_element(e.target())
              let v = inp.value
              on_submit(v)
              inp.value = ""
            }
          }),
        ),
      ],
    ],
  ]
}

