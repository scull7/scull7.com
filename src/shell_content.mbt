// Content host — isolated imperative buffer body routing.
// Luna show/index_each do not remount when only active buffer id changes.

///|
fn content_paint_body(
  body_host : Ref[@js_dom.Element?],
  term_handler : Ref[(String) -> Unit],
  active_id : @resource.Signal[String],
  data : ResumeView,
  term_lines : @resource.Signal[Array[String]],
) -> Unit {
  match body_host.val {
    None => ()
    Some(el) => {
      let node = match find_buffer(active_id.get()) {
        Some(buf) =>
          buffer_content(
            data,
            buf,
            term_lines,
            fn(s) { (term_handler.val)(s) },
          )
        None => @dom.div() <| [@dom.text("Empty buffer")]
      }
      @dom.render_to(el, node)
    }
  }
}

///|
fn buffer_body_host(
  body_host : Ref[@js_dom.Element?],
  term_handler : Ref[(String) -> Unit],
  active_id : @resource.Signal[String],
  data : ResumeView,
  term_lines : @resource.Signal[Array[String]],
) -> @dom.DomNode {
  @dom.div(
    class="buffer-body",
    id="buffer-body",
    attrs=[
      ("tabindex", attr_s("0")),
      ("role", attr_s("region")),
      ("aria-label", attr_s("Buffer content")),
    ],
    ref_=fn(el) {
      body_host.val = Some(el)
      content_paint_body(body_host, term_handler, active_id, data, term_lines)
    },
  ) <| []
}
