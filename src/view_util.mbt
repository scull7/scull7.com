// Extracted from shell.mbt — Item 1 modularization

fn attr_s(v : String) -> @dom.Attr {
  @dom.Attr::AttrString(v)
}

///|
fn split_paragraphs(s : String) -> Array[String] {
  let out : Array[String] = []
  for part in s.split("\n") {
    let t = part.trim().to_owned()
    if !t.is_empty() {
      out.push(t)
    }
  }
  out
}

///|
fn pills(items : Array[String], hot : Bool) -> Array[@dom.DomNode] {
  let cls = if hot { "pill hot" } else { "pill" }
  items.map(s => @dom.span(class=cls) <| [@dom.text(s)])
}

