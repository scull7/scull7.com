// Extracted from shell.mbt — Item 1 modularization

fn view_help() -> @dom.DomNode {
  let rows : Array[(String, String)] = [
    (":  /  Esc", "Command palette · search · cancel"),
    ("Ctrl-[  Ctrl-c", "Esc synonyms (palette / cancel)"),
    (":help  :ls  :q", "Help · list buffers · home"),
    (":e / :open {name}", "Open buffer by name"),
    ("j k  ↑ ↓", "Move buffer focus"),
    ("Enter  l", "Open focused buffer"),
    ("gg  G", "Top / bottom of buffer list"),
    ("Ctrl-f  Ctrl-b", "Page buffer body down / up"),
    ("z", "Center buffer body scroll"),
    ("?", "Open this help"),
  ]
  let kids : Array[@dom.DomNode] = [
    @dom.h2(class="section-title") <| [@dom.text("help.txt")],
    @dom.p(class="summary", style="margin-bottom:12px") <| [
      @dom.text("Vim-inspired navigation. Palette-primary commands (Option B)."),
    ],
    @dom.pre(class="code-block help-modes") <| [
      @dom.text(
        "modes\n" +
        "  NORMAL  -- : -->  COMMAND (palette)  -- Esc -->  NORMAL\n" +
        "  NORMAL  -- / -->  SEARCH  (palette)  -- Esc -->  NORMAL\n" +
        "  NORMAL  -- ? -->  help.txt\n" +
        "\n" +
        "rules\n" +
        "  · Bottom cmdline echoes :query / /query while palette is open\n" +
        "  · g pending auto-clears after ~600ms (gg still works)\n" +
        "  · Terminal input focused → shell keys ignored (Esc blurs)\n" +
        "  · Insert mode is unused — stay in NORMAL + palette",
      ),
    ],
    @dom.h2(class="section-title", style="margin-top:20px") <| [@dom.text("keys")],
  ]
  let grid : Array[@dom.DomNode] = []
  for row in rows {
    let (cmd, desc) = row
    grid.push(@dom.div(class="cmd") <| [@dom.text(cmd)])
    grid.push(@dom.div(class="desc") <| [@dom.text(desc)])
  }
  kids.push(@dom.div(class="help-grid") <| grid)
  @dom.div() <| kids
}
