// Static buffer catalog + code samples (UI-only).

///|
pub enum BufferKind {
  Home
  Experience
  Highlights
  Skills
  OpenSource
  Code
  Relay
  Terminal
  Help
} derive(Eq, Show)

///|
pub struct BufferDef {
  id : String
  icon : String
  kind : BufferKind
  label : String
  badge : String
  sample : String
} derive(Show, Eq)

///|
pub let buffers : Array[BufferDef] = [
  { id: "README.md", icon: "📄", kind: Home, label: "README.md", badge: "home", sample: "" },
  { id: "experience.md", icon: "💼", kind: Experience, label: "experience.md", badge: "work", sample: "" },
  { id: "highlights.md", icon: "✦", kind: Highlights, label: "highlights.md", badge: "proof", sample: "" },
  { id: "skills.md", icon: "⚙", kind: Skills, label: "skills.md", badge: "stack", sample: "" },
  { id: "opensource.md", icon: "⌘", kind: OpenSource, label: "opensource.md", badge: "oss", sample: "" },
  { id: "cents.rs", icon: "🦀", kind: Code, label: "cents.rs", badge: "rust", sample: "cents" },
  { id: "bs_result.re", icon: "λ", kind: Code, label: "bs_result.re", badge: "ocaml", sample: "result" },
  { id: "relay.rs", icon: "⚡", kind: Code, label: "relay.rs", badge: "gpu", sample: "relay" },
  { id: "relay-viz", icon: "◈", kind: Relay, label: "relay-viz", badge: "demo", sample: "" },
  { id: "terminal", icon: ">_", kind: Terminal, label: "terminal", badge: "live", sample: "" },
  { id: "help.txt", icon: "?", kind: Help, label: "help.txt", badge: "docs", sample: "" },
]

///|
pub fn find_buffer(id : String) -> BufferDef? {
  for b in buffers {
    if b.id == id {
      return Some(b)
    }
  }
  None
}

///|
pub fn find_buffer_by_query(q : String) -> BufferDef? {
  let needle = q.to_lower()
  for b in buffers {
    let id = b.id.to_lower()
    let label = b.label.to_lower()
    if id == needle || label == needle || label.has_prefix(needle) || id.contains(needle) {
      return Some(b)
    }
  }
  None
}

///|
pub fn code_sample(key : String) -> String {
  match key {
    "cents" =>
      "// cents — monetary values as integer cents (Rust)\nuse cents::Cents;\n\nfn transfer(from: &mut Cents, to: &mut Cents, amount: Cents) -> Result<()> {\n    from.checked_sub(amount)?;\n    to.checked_add(amount)?;\n    Ok(())\n}\n\nlet fee = Cents::from_dollars(\"1.50\")?; // 150 cents"
    "result" =>
      "(* bs-result — category-theory Result for ReasonML *)\nopen BsResult;\n\nlet parseUser = (json) =>\n  json\n  |> decodeField(\"id\", Decode.int)\n  |> flatMap(id =>\n       decodeField(\"email\", Decode.string, json)\n       |> map(email => {id, email})\n     );"
    "relay" =>
      "// Relay (conceptual) — GPU cloud control plane\npub async fn route_event(\n    evt: Event,\n    bus: &EventBus,\n    fleet: &GpuFleet,\n) -> Result<Ack> {\n    let plan = fleet.schedule(evt.workload())?;\n    bus.publish(plan.as_control_msg()).await?;\n    Ok(Ack::accepted(plan.id()))\n}"
    _ => "// empty"
  }
}
