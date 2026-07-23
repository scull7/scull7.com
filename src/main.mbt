// scull7.com — MoonBit + Luna entry

///|
fn loading_view() -> @dom.DomNode {
  @dom.div(
    class="glass",
    style="margin:24px;padding:20px;font-family:var(--font-mono,monospace);color:#9aa3bd",
  ) <| [@dom.text("loading resume.json…")]
}

///|
fn error_view(msg : String) -> @dom.DomNode {
  @dom.div(
    class="glass",
    style="margin:24px;padding:20px;font-family:var(--font-mono,monospace);color:#ff6b8a",
  ) <| [
    @dom.text("failed to load "),
    @dom.a(href="/resume.json") <| [@dom.text("/resume.json")],
    @dom.p() <| [@dom.text(msg)],
  ]
}

///|
fn main {
  let doc = @js_dom.document()
  match doc.getElementById("app") {
    None => ()
    Some(el) => {
      @dom.render_to(el, loading_view())
      @js.run_async(async fn() noraise {
        let result = try {
          load_resume("/resume.json")
        } catch {
          e => Err(e.to_string())
        } noraise {
          r => r
        }
        match result {
          Err(e) => @dom.render_to(el, error_view(e))
          Ok(data) => @dom.render_to(el, shell_app(data))
        }
      })
    }
  }
}
