# Implementation Guidelines — Item 2: Accessibility & focus management

**Repo:** `/Users/nathansculli/src/scull7.com`  
**Plan:** `docs/IMPROVEMENT-PLAN.md` §2

---

## 1. Goal

Make the vim resume shell keyboard-accessible and AT-friendly: palette focuses on open and restores focus on Esc; buffer list exposes listbox semantics; cmdline messages are announced; hero name remains visible without gradient-clip; motion respects `prefers-reduced-motion`. Do not change resume content or break buffer navigation.

---

## 2. Non-goals

- Full axe zero-issues on every optional decorative node
- Perfect vim Insert mode
- Item 3 code highlighting / item 5 cmdline redesign (except shared focus hooks)
- New dependencies required (Playwright already present for checks)

---

## 3. Files to touch

| File | Changes |
|------|---------|
| `src/shell_app.mbt` | Focus helpers; open/close palette; aria attrs on list/palette/status/cmdline; body tabindex |
| `src/view_home.mbt` | Optional: ensure h1 stays plain text (CSS handles fallback) |
| `public/styles/vim.css` | Hero h1 fallback; reduced-motion for packets; focus ring polish; palette dialog styles if needed |
| `public/styles/galaxy.css` | Ensure twinkle disabled under reduced-motion (extend existing block) |
| `docs/verification-item-2.md` | Write after implement (verifier) |

Optional small module: `src/shell_focus.mbt` with focus helpers only — keep flat under `src/`.

---

## 4. Implementation details

### 4.1 Focus palette input on open

In `open_palette`:

1. Set signals as today (`palette_open`, mode, clear query).
2. After open, focus `#palette-input`:

```moonbit
fn focus_palette_input() {
  let doc = @js_dom.document()
  match doc.getElementById("palette-input") {
    None => ()
    Some(el) => {
      let inp = @js_dom.HTMLInputElement::cast_from_element(el)
      inp.focus()
    }
  }
}
```

Call via short delay if ref not mounted yet — prefer:

```moonbit
// after palette_open.set(true)
// schedule microtask/timeout so DOM updates first
```

Use existing pattern: `@js_dom.window().requestAnimationFrame` or a tiny `extern "js"` setTimeout 0 to call focus after Luna paints.

```moonbit
extern "js" fn defer_focus(id : String) -> Unit =
  #| (id) => { requestAnimationFrame(() => { const el = document.getElementById(id); if (el) el.focus(); }); }
```

Call `defer_focus("palette-input")` from `open_palette`.

### 4.2 Restore focus on Esc

Track `focus_return_id : Ref[String]` default `"buffer-body"` or `"buffer-list"`.

On `open_palette`: store `document.activeElement?.id` if any, else `"buffer-list"`.

On Esc close palette:

```moonbit
fn restore_focus() {
  defer_focus(focus_return.val) // or getElementById + HTMLElement::focus
}
palette_open.set(false)
mode.set(Normal)
restore_focus()
```

Apply in both palette Escape branch and `accept_palette` (after action, focus buffer-body).

### 4.3 Buffer list semantics

On `ul.buffer-items`:

```moonbit
attrs=[
  ("role", attr_s("listbox")),
  ("aria-label", attr_s("Buffers")),
]
```

On each `li.buffer-item`:

```moonbit
attrs=[
  ("role", attr_s("option")),
  // aria-selected must be reactive — use dyn_attrs if available
]
```

Check Luna `dyn_attrs` on `li` — if supported:

```moonbit
dyn_attrs=[
  ("aria-selected", Dynamic(fn() {
    if index == focus_idx.get() { "true" } else { "false" }
  })),
]
```

If `dyn_attrs` awkward, set static `aria-selected` only for active buffer via dyn_class path isn't enough — prefer dyn_attrs.

Also `tabindex="-1"` on options (roving later optional); listbox can be `tabindex="0"`.

### 4.4 Palette dialog semantics

On `#palette` when open:

```moonbit
attrs=[
  ("role", attr_s("dialog")),
  ("aria-modal", attr_s("true")),
  ("aria-label", attr_s("Command palette")),
]
```

Results `ul`: `role="listbox"`. Items: `role="option"`.

**Focus trap (light):** On Tab/Shift-Tab while palette open, if focus would leave panel, preventDefault and cycle between input and first/last result — or trap only on input + results. Minimum: Tab from input stays in palette (preventDefault on Tab and focus input again if only one tabbable).

### 4.5 aria-live on messages

Cmdline message span:

```moonbit
attrs=[
  ("role", attr_s("status")),
  ("aria-live", attr_s("polite")),
  ("aria-atomic", attr_s("true")),
]
```

Statusline mode/file optional `aria-live="off"` (avoid noise).

### 4.6 Buffer body

```moonbit
// buffer_body_host in shell_content.mbt
attrs=[("tabindex", attr_s("0")), ("aria-label", attr_s("Buffer content"))]
```

### 4.7 CSS

**Hero fallback** in `vim.css` after `.hero h1` block:

```css
.hero h1 {
  color: var(--text); /* fallback */
  background: linear-gradient(...);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  color: transparent; /* only after clip setup — use @supports */
}

@supports not ((background-clip: text) or (-webkit-background-clip: text)) {
  .hero h1 {
    background: none;
    color: var(--accent-cyan);
    -webkit-text-fill-color: var(--accent-cyan);
  }
}

@media (forced-colors: active) {
  .hero h1 {
    background: none;
    color: CanvasText;
    -webkit-text-fill-color: CanvasText;
  }
}
```

**Reduced motion** — in galaxy + vim:

```css
@media (prefers-reduced-motion: reduce) {
  .galaxy::before,
  .relay-packet { animation: none !important; }
}
```

**Focus rings** — ensure `.buffer-item:focus-visible`, `.palette-input:focus-visible`, buttons.

### 4.8 preventDefault scoping

Only preventDefault for keys the app handles when not in a text field (already partially done). Do not capture browser Ctrl/Cmd shortcuts.

---

## 5. Migration steps

1. Add `defer_focus` + `focus_return` ref in `shell_app.mbt`
2. Wire `open_palette` / Esc / `accept_palette`
3. Add ARIA attrs to list, palette, cmdline, body host
4. CSS hero + motion + focus
5. Build + Playwright checks below

---

## 6. Public API — do not break

- `shell_app`, `load_resume`, buffer navigation, CSS class names for layout

---

## 7. Verify commands

```bash
export PATH="$HOME/.moon/bin:$PATH"
cd /Users/nathansculli/src/scull7.com
moon build --target js --release
npm run build
npm run preview -- --host 127.0.0.1 --port 4173
```

Playwright:

1. Goto `/`
2. Press `:` → `#palette-input` is `document.activeElement`
3. Press Escape → palette closed; focus not on body null
4. Click experience still works
5. Query `[role=listbox]`, `[role=option]`
6. Optional: `@axe-core/playwright` if easy to add; else manual checklist

---

## 8. Acceptance checklist

- [ ] `:` and `/` focus palette input immediately (after rAF)
- [ ] Esc closes palette and restores focus
- [ ] Buffer list has listbox/option semantics
- [ ] Cmdline messages have aria-live polite
- [ ] Hero readable without background-clip
- [ ] Reduced-motion kills continuous animations
- [ ] Buffer switch still works
- [ ] Build green

---

## 9. Risks

| Risk | Mitigation |
|------|------------|
| Focus before input mounted | `requestAnimationFrame` / double rAF |
| dyn_attrs not working | Fall back to aria-selected on active only via re-paint of list (index_each already reactive dyn_class) |
| Focus trap fights vim keys | Only trap Tab, not j/k when palette open (j/k already handled in palette mode) |
