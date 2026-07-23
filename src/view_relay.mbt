// Extracted from shell.mbt — Item 1 modularization

fn view_relay() -> @dom.DomNode {
  @dom.div(class="relay-viz") <| [
    @dom.h2(class="section-title") <| [@dom.text("relay · gpu cloud control plane")],
    @dom.div(
      class="relay-canvas",
      attrs=[
        ("role", attr_s("img")),
        (
          "aria-label",
          attr_s(
            "Relay routes client workloads to the AMD GPU fleet via the Event API",
          ),
        ),
      ],
    ) <| [
      @dom.div(class="relay-node", style="left:18%;top:50%") <| [@dom.text("clients")],
      @dom.div(class="relay-node primary", style="left:50%;top:30%") <| [@dom.text("Relay")],
      @dom.div(class="relay-node", style="left:50%;top:70%") <| [@dom.text("Event API")],
      @dom.div(class="relay-node gpu", style="left:82%;top:50%") <| [@dom.text("AMD GPU fleet")],
      @dom.div(class="relay-packet", attrs=[("aria-hidden", attr_s("true"))]) <| [],
      @dom.div(class="relay-packet b", attrs=[("aria-hidden", attr_s("true"))]) <| [],
      @dom.div(class="relay-packet c", attrs=[("aria-hidden", attr_s("true"))]) <| [],
    ],
    @dom.p(class="relay-caption") <| [
      @dom.text("clients → Relay → Event API → AMD GPU fleet"),
    ],
    @dom.div(class="relay-stats") <| [
      @dom.div(class="relay-stat") <| [
        @dom.div(class="label") <| [@dom.text("Role")],
        @dom.div(class="value", style="font-size:15px") <| [@dom.text("Dir Eng · IC")],
      ],
      @dom.div(class="relay-stat") <| [
        @dom.div(class="label") <| [@dom.text("Domain")],
        @dom.div(class="value", style="font-size:15px") <| [@dom.text("GPU clouds")],
      ],
      @dom.div(class="relay-stat") <| [
        @dom.div(class="label") <| [@dom.text("Impact")],
        @dom.div(class="value", style="font-size:15px") <| [@dom.text("Record delivery")],
      ],
      @dom.div(class="relay-stat") <| [
        @dom.div(class="label") <| [@dom.text("Stack")],
        @dom.div(class="value", style="font-size:15px") <| [@dom.text("Rust · distributed")],
      ],
    ],
    @dom.p(class="summary", style="font-size:14px;color:var(--text-dim)") <| [
      @dom.text(
        "At TensorWave, Relay turns workload intent into scheduled GPU capacity. " +
        "As Director of Engineering and primary IC, I architected and shipped the service " +
        "that unlocked the largest AMD-based GPU clouds under aggressive timelines.",
      ),
    ],
  ]
}
