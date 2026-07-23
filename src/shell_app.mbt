// Vim-inspired resume shell (Luna DOM + signals).

///|
priv enum Mode {
  Normal
  Command
  Search
} derive(Eq)

///|
priv struct PaletteItem {
  label : String
  desc : String
  action_id : String
} 

///|
fn mode_label(m : Mode) -> String {
  match m {
    Normal => "NORMAL"
    Command => "COMMAND"
    Search => "SEARCH"
  }
}

///|
fn mode_class(m : Mode) -> String {
  match m {
    Normal => "mode"
    Command => "mode command"
    Search => "mode search"
  }
}

///|
fn is_mobile() -> Bool {
  let mql = @js_dom.matchMedia("(max-width: 860px)")
  let matches : Bool = mql.as_any()["matches"].cast()
  matches
}


pub fn shell_app(data : ResumeView) -> @dom.DomNode {
  let mode = @resource.signal(Normal)
  let focus_idx = @resource.signal(0)
  let active_id = @resource.signal("README.md")
  let msg = @resource.signal("Press : for commands · / to search · ? for help")
  let msg_kind = @resource.signal("")
  let g_pending = @resource.signal(false)
  let buffers_collapsed = @resource.signal(is_mobile())
  let palette_open = @resource.signal(false)
  let palette_mode = @resource.signal("command")
  let palette_query = @resource.signal("")
  let palette_focus = @resource.signal(0)
  let term_lines = @resource.signal([
    "scull7.com interactive shell — type help",
    "try: help | whoami | ls | open experience | clear",
  ])
  // Imperative body host — Luna show/index_each don't remount on value change alone.
  let body_host : Ref[@js_dom.Element?] = Ref(None)
  let term_handler : Ref[(String) -> Unit] = Ref(fn(_raw) { () })
  let focus_return = Ref("buffer-list")
  let g_timer = Ref(0)

  let active_buf = @resource.memo(fn() {
    match find_buffer(active_id.get()) {
      Some(b) => b
      None => buffers[0]
    }
  })

  fn set_msg(text_ : String, kind : String) {
    msg.set(text_)
    msg_kind.set(kind)
  }

  fn clear_g_pending() {
    g_pending.set(false)
    if g_timer.val != 0 {
      clear_timeout_handle(g_timer.val)
      g_timer.val = 0
    }
  }

  fn arm_g_pending() {
    clear_g_pending()
    g_pending.set(true)
    g_timer.val = arm_timeout(600, fn() { g_pending.set(false); g_timer.val = 0 })
  }

  fn is_escape_key(ev : @js_dom.KeyboardEvent) -> Bool {
    if ev.key == "Escape" {
      true
    } else if ev.ctrlKey && (ev.key == "[" || ev.key == "c") {
      true
    } else {
      false
    }
  }

  fn paint_body() {
    content_paint_body(body_host, term_handler, active_id, data, term_lines)
  }

  fn open_buffer(id : String, silent : Bool) {
    match find_buffer(id) {
      None => set_msg("E94: No matching buffer for " + id, "error")
      Some(buf) => {
        active_id.set(id)
        let mut idx = 0
        let mut i = 0
        for b in buffers {
          if b.id == id {
            idx = i
            break
          }
          i = i + 1
        }
        focus_idx.set(idx)
        paint_body()
        if !silent && is_mobile() {
          buffers_collapsed.set(true)
        }
        if !silent {
          set_msg("\"" + buf.label + "\" opened", "ok")
        }
      }
    }
  }

  fn open_by_query(q : String) -> Bool {
    if q.is_empty() {
      set_msg("E32: No file name", "error")
      return false
    }
    match find_buffer_by_query(q) {
      None => {
        set_msg("E94: No matching buffer for " + q, "error")
        false
      }
      Some(b) => {
        open_buffer(b.id, false)
        true
      }
    }
  }

  fn move_focus(delta : Int) {
    let n = buffers.length()
    let cur = focus_idx.get()
    let next = ((cur + delta) % n + n) % n
    focus_idx.set(next)
  }

  fn run_command(raw : String) {
    let trimmed = raw.trim().to_owned()
    if trimmed.is_empty() {
      return
    }
    let parts = trimmed.split(" ").map(v => v.to_owned()).collect()
    let head = if parts.length() > 0 { parts[0].to_lower() } else { "" }
    let mut arg = ""
    if parts.length() > 1 {
      let mut i = 1
      while i < parts.length() {
        if i > 1 {
          arg = arg + " "
        }
        arg = arg + parts[i]
        i = i + 1
      }
    }
    match head {
      "help" => open_buffer("help.txt", false)
      "ls" => {
        if is_mobile() {
          buffers_collapsed.set(false)
        }
        let mut list = ""
        let mut i = 0
        for b in buffers {
          let mark = if i == focus_idx.get() { "%" } else { " " }
          list = list + mark + " " + b.label + "  "
          i = i + 1
        }
        set_msg(list, "")
      }
      "q" | "quit" | "home" => open_buffer("README.md", false)
      "experience" => open_buffer("experience.md", false)
      "skills" => open_buffer("skills.md", false)
      "oss" => open_buffer("opensource.md", false)
      "terminal" => open_buffer("terminal", false)
      "relay" => open_buffer("relay-viz", false)
      "e" | "open" => {
        let _ = open_by_query(arg)
      }
      _ => {
        if !open_by_query(trimmed) {
          set_msg("E492: Not an editor command: " + trimmed, "error")
        }
      }
    }
  }

  fn palette_items() -> Array[PaletteItem] {
    let q = palette_query.get()
    if palette_mode.get() == "search" {
      let scored : Array[(Int, Int, PaletteItem)] = []
      let mut i = 0
      for b in buffers {
        let item : PaletteItem = { label: b.label, desc: b.badge, action_id: b.id }
        match fuzzy_rank_label(q, b.label, b.badge) {
          Some(s) => scored.push((s, i, item))
          None => ()
        }
        i = i + 1
      }
      sort_scored(scored)
    } else {
      let cmds : Array[PaletteItem] = [
        { label: ":help", desc: "Show help", action_id: "cmd:help" },
        { label: ":ls", desc: "List buffers", action_id: "cmd:ls" },
        { label: ":q", desc: "Go home", action_id: "cmd:q" },
        { label: ":terminal", desc: "Live terminal", action_id: "cmd:terminal" },
        { label: ":relay", desc: "Relay viz", action_id: "cmd:relay" },
      ]
      let scored : Array[(Int, Int, PaletteItem)] = []
      let mut i = 0
      for c in cmds {
        match fuzzy_rank_label(q, c.label, c.desc) {
          Some(s) => scored.push((s, i, c))
          None => ()
        }
        i = i + 1
      }
      for b in buffers {
        let item : PaletteItem = {
          label: ":e " + b.label,
          desc: "open buffer",
          action_id: b.id,
        }
        match fuzzy_rank_label(q, b.label + " " + item.label, b.badge) {
          Some(s) => scored.push((s, i, item))
          None => ()
        }
        i = i + 1
      }
      sort_scored(scored)
    }
  }

  fn close_palette() {
    clear_g_pending()
    palette_open.set(false)
    mode.set(Normal)
    defer_focus(focus_return.val)
  }

  fn accept_palette() {
    let items = palette_items()
    if items.length() == 0 {
      if palette_mode.get() == "command" {
        run_command(palette_query.get())
      }
      palette_open.set(false)
      mode.set(Normal)
      defer_focus("buffer-body")
      return
    }
    let idx = palette_focus.get()
    let safe = if idx < items.length() { idx } else { 0 }
    let item = items[safe]
    palette_open.set(false)
    mode.set(Normal)
    if item.action_id.has_prefix("cmd:") {
      run_command(item.action_id[4:].to_owned())
    } else {
      open_buffer(item.action_id, false)
    }
    defer_focus("buffer-body")
  }

  fn open_palette(kind : String) {
    focus_return.val = active_element_id("buffer-list")
    palette_mode.set(kind)
    palette_query.set("")
    palette_focus.set(0)
    palette_open.set(true)
    mode.set(if kind == "search" { Search } else { Command })
    defer_focus("palette-input")
  }

  fn on_term(raw : String) {
    term_lines.update(ls => {
      let n = ls.copy()
      n.push("scull7@resume:~$ " + raw)
      n
    })
    let trimmed = raw.trim().to_owned()
    let parts = trimmed.split(" ").map(v => v.to_owned()).collect()
    let cmd = if parts.length() > 0 { parts[0].to_lower() } else { "" }
    let mut arg = ""
    if parts.length() > 1 {
      let mut i = 1
      while i < parts.length() {
        if i > 1 { arg = arg + " " }
        arg = arg + parts[i]
        i = i + 1
      }
    }
    let reply = match cmd {
      "" => ""
      "help" => "commands: help whoami ls open cat clear skills contact fortune"
      "whoami" => data.profile.name + " — " + data.profile.tagline
      "ls" => buffers.map(b => b.label).join("  ")
      "open" | "e" | "cat" => {
        let target = if arg.is_empty() { "README.md" } else { arg }
        if open_by_query(target) { "opened " + target } else { "no such buffer: " + target }
      }
      "clear" => {
        term_lines.set([])
        ""
      }
      "skills" => data.skills.languages_active.join(", ")
      "contact" =>
        data.profile.email + "  " + data.profile.github + "  " + data.profile.linkedin
      "fortune" => "Talk is cheap. Show me the code. — Linus"
      "pwd" => "~/scull7.com"
      "echo" => arg
      _ => "command not found: " + cmd
    }
    if !reply.is_empty() {
      term_lines.update(ls => {
        let n = ls.copy()
        n.push(reply)
        n
      })
    }
    // Re-paint terminal buffer so new lines show.
    if active_id.get() == "terminal" {
      paint_body()
    }
  }
  term_handler.val = on_term

  // Global keyboard via document EventTarget
  let _ = @resource.effect(fn() {
    let doc = @js_dom.document()
    doc.as_event_target().addEventListener("keydown", fn(ev_any) {
      let ev : @js_dom.KeyboardEvent = ev_any.cast()

      // Palette-primary command/search UI
      if palette_open.get() {
        if is_escape_key(ev) {
          ev.preventDefault()
          close_palette()
          return
        }
        // Don't steal Ctrl/Cmd browser shortcuts except Ctrl-[ / Ctrl-c above
        if ev.metaKey || (ev.ctrlKey && ev.key != "[" && ev.key != "c") {
          return
        }
        match ev.key {
          "Tab" => {
            ev.preventDefault()
            defer_focus("palette-input")
          }
          "ArrowDown" | "j" => {
            ev.preventDefault()
            let n = palette_items().length()
            if n > 0 {
              palette_focus.set((palette_focus.get() + 1) % n)
            }
          }
          "ArrowUp" | "k" => {
            ev.preventDefault()
            let n = palette_items().length()
            if n > 0 {
              palette_focus.set((palette_focus.get() - 1 + n) % n)
            }
          }
          "Enter" => {
            ev.preventDefault()
            accept_palette()
          }
          _ => ()
        }
        return
      }

      let tag_any = ev.target().as_any()["tagName"]
      let tag : String = tag_any.cast()
      let in_field = tag.to_lower() == "input" || tag.to_lower() == "textarea"
      let in_term = active_is_terminal_input()

      if in_field || in_term {
        if is_escape_key(ev) {
          ev.preventDefault()
          mode.set(Normal)
          // blur terminal so shell keys resume
          defer_focus("buffer-body")
        }
        return
      }

      if mode.get() != Normal {
        return
      }

      // Page scroll (vim-ish)
      if ev.ctrlKey && (ev.key == "f" || ev.key == "b" || ev.key == "F" || ev.key == "B") {
        ev.preventDefault()
        scroll_buffer_page(if ev.key == "f" || ev.key == "F" { 1 } else { -1 })
        return
      }

      if is_escape_key(ev) {
        clear_g_pending()
        set_msg("", "")
        return
      }

      match ev.key {
        ":" => {
          ev.preventDefault()
          clear_g_pending()
          open_palette("command")
        }
        "/" => {
          ev.preventDefault()
          clear_g_pending()
          open_palette("search")
        }
        "?" => {
          ev.preventDefault()
          clear_g_pending()
          open_buffer("help.txt", false)
        }
        "j" | "ArrowDown" => {
          ev.preventDefault()
          clear_g_pending()
          move_focus(1)
        }
        "k" | "ArrowUp" => {
          ev.preventDefault()
          clear_g_pending()
          move_focus(-1)
        }
        "Enter" | "l" | "ArrowRight" => {
          ev.preventDefault()
          clear_g_pending()
          open_buffer(buffers[focus_idx.get()].id, false)
        }
        "g" => {
          if g_pending.get() {
            ev.preventDefault()
            clear_g_pending()
            focus_idx.set(0)
            set_msg("gg → top", "")
          } else {
            arm_g_pending()
          }
        }
        "G" => {
          ev.preventDefault()
          clear_g_pending()
          focus_idx.set(buffers.length() - 1)
          set_msg("G → bottom", "")
        }
        "z" => {
          // zz — center buffer body (single z is enough for this shell)
          ev.preventDefault()
          clear_g_pending()
          scroll_buffer_center()
          set_msg("z → center", "")
        }
        _ => {
          if g_pending.get() && ev.key != "Shift" && ev.key != "Control" &&
            ev.key != "Alt" && ev.key != "Meta" {
            clear_g_pending()
          }
        }
      }
    })
  })

  open_buffer("README.md", true)

  @dom.div(id="vim-root") <| [
    @dom.div(class="galaxy", attrs=[("aria-hidden", attr_s("true"))]) <| [],
    @dom.div(class="workspace") <| [
      @dom.aside(
        dyn_class=fn() {
          if buffers_collapsed.get() {
            "buffer-list glass is-collapsed"
          } else {
            "buffer-list glass"
          }
        },
        id="buffer-list",
        attrs=[("tabindex", attr_s("0")), ("aria-label", attr_s("Buffer sidebar"))],
      ) <| [
        @dom.button(
          class="buffer-list-header",
          id="buffer-toggle",
          attrs=[("aria-controls", attr_s("buffer-items"))],
          on=@dom.events().click(fn(_) { buffers_collapsed.update(v => !v) }),
        ) <| [
          @dom.span(class="title") <| [
            @dom.span(class="chevron", attrs=[("aria-hidden", attr_s("true"))]) <| [@dom.text("▾")],
            @dom.text(" buffers"),
          ],
          @dom.span(class="hint") <| [@dom.text(":ls")],
        ],
        @dom.ul(
          class="buffer-items",
          id="buffer-items",
          attrs=[
            ("role", attr_s("listbox")),
            ("aria-label", attr_s("Buffers")),
          ],
        ) <| [
          @dom.index_each(
            fn() { buffers },
            fn(get_buf, index) {
              @dom.li(
                dyn_class=fn() {
                  let b = get_buf()
                  let mut cls = "buffer-item"
                  if index == focus_idx.get() {
                    cls = cls + " focused"
                  }
                  if b.id == active_id.get() {
                    cls = cls + " active"
                  }
                  cls
                },
                attrs=[
                  ("role", attr_s("option")),
                  ("tabindex", attr_s("-1")),
                ],
                dyn_attrs=[
                  (
                    "aria-selected",
                    @dom.attr_dynamic(fn() {
                      if index == focus_idx.get() {
                        "true"
                      } else {
                        "false"
                      }
                    }),
                  ),
                ],
                on=@dom.events().click(fn(_) {
                  focus_idx.set(index)
                  open_buffer(get_buf().id, false)
                }),
              ) <| [
                @dom.span(class="icon", attrs=[("aria-hidden", attr_s("true"))]) <| [
                  @dom.text_dyn(fn() { get_buf().icon }),
                ],
                @dom.span(class="name") <| [@dom.text_dyn(fn() { get_buf().label })],
                @dom.span(class="badge") <| [@dom.text_dyn(fn() { get_buf().badge })],
              ]
            },
          ),
        ],
      ],
      @dom.section(class="buffer-pane glass-strong") <| [
        @dom.div(class="buffer-tabbar") <| [
          @dom.div(class="buffer-tab active") <| [
            @dom.text_dyn(fn() { active_buf().icon + " " + active_buf().label }),
          ],
        ],
        buffer_body_host(body_host, term_handler, active_id, data, term_lines),
      ],
    ],
    @dom.div(class="bottom-chrome") <| [
      @dom.footer_(class="statusline") <| [
        @dom.span(dyn_class=fn() { mode_class(mode.get()) }) <| [
          @dom.text_dyn(fn() { mode_label(mode.get()) }),
        ],
        @dom.span(class="file") <| [@dom.text_dyn(fn() { active_buf().label })],
        @dom.span(class="spacer") <| [],
        @dom.span(class="meta") <| [
          @dom.span() <| [@dom.text(data.profile.location)],
          @dom.span() <| [
            @dom.text_dyn(fn() { (focus_idx.get() + 1).to_string() + ":1" }),
          ],
          @dom.span() <| [@dom.text("utf-8")],
        ],
      ],
      @dom.div(class="cmdline") <| [
        @dom.span(
          class="msg",
          dyn_class=fn() {
            if palette_open.get() {
              "msg cmdline-echo"
            } else {
              let k = msg_kind.get()
              if k.is_empty() { "msg" } else { "msg " + k }
            }
          },
          attrs=[
            ("role", attr_s("status")),
            ("aria-live", attr_s("polite")),
            ("aria-atomic", attr_s("true")),
          ],
        ) <| [
          @dom.text_dyn(fn() {
            if palette_open.get() {
              let pfx = if palette_mode.get() == "search" { "/" } else { ":" }
              pfx + palette_query.get()
            } else {
              msg.get()
            }
          }),
        ],
      ],
    ],
    @dom.div(
      dyn_class=fn() {
        if palette_open.get() { "palette open" } else { "palette" }
      },
      id="palette",
      attrs=[
        ("role", attr_s("dialog")),
        ("aria-modal", attr_s("true")),
        ("aria-label", attr_s("Command palette")),
      ],
      dyn_attrs=[
        (
          "aria-hidden",
          @dom.attr_dynamic(fn() {
            if palette_open.get() { "false" } else { "true" }
          }),
        ),
      ],
    ) <| [
      @dom.div(class="palette-panel glass-strong") <| [
        @dom.div(class="palette-input-row") <| [
          @dom.span(class="pfx", attrs=[("aria-hidden", attr_s("true"))]) <| [
            @dom.text_dyn(fn() {
              if palette_mode.get() == "search" { "/" } else { ":" }
            }),
          ],
          @dom.input(
            id="palette-input",
            attrs=[
              ("autocomplete", attr_s("off")),
              ("spellcheck", attr_s("false")),
              ("aria-label", attr_s("Command or search")),
              ("role", attr_s("searchbox")),
            ],
            on=@dom.events().input(fn(e) {
              let inp = @js_dom.HTMLInputElement::cast_from_element(e.target())
              palette_query.set(inp.value)
              palette_focus.set(0)
            }),
          ),
        ],
        @dom.ul(
          class="palette-results",
          attrs=[
            ("role", attr_s("listbox")),
            ("aria-label", attr_s("Palette results")),
          ],
        ) <| [
          @dom.index_each(
            palette_items,
            fn(get_item, index) {
              @dom.li(
                dyn_class=fn() {
                  if index == palette_focus.get() { "focused" } else { "" }
                },
                attrs=[("role", attr_s("option")), ("tabindex", attr_s("-1"))],
                dyn_attrs=[
                  (
                    "aria-selected",
                    @dom.attr_dynamic(fn() {
                      if index == palette_focus.get() {
                        "true"
                      } else {
                        "false"
                      }
                    }),
                  ),
                ],
                on=@dom.events().click(fn(_) {
                  palette_focus.set(index)
                  accept_palette()
                }),
              ) <| [
                @dom.span() <| [@dom.text_dyn(fn() { get_item().label })],
                @dom.span(class="desc") <| [@dom.text_dyn(fn() { get_item().desc })],
              ]
            },
          ),
        ],
      ],
    ],
  ]
}
