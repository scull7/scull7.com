# Implementation Guidelines — Item 3: Visual polish (hero, code, glass hierarchy)

> **ARCHIVED — historical, not live guidance.**
> This document is from the MoonBit/Luna era of scull7.com and describes a stack the
> site no longer uses. The live stack is **Elm 0.19.1 for the UI and Melange 7
> (OCaml → JS) for ports, build tooling, and e2e** — see [`README.md`](../../README.md)
> and [`docs/ROADMAP.md`](../ROADMAP.md). Kept for provenance only; do not implement
> from it.

**Repo:** `/Users/nathansculli/src/scull7.com`  
**Plan:** `docs/archive/IMPROVEMENT-PLAN.md` §3

---

## 1. Goal

Make the resume site feel deliberately designed: reliable hero typography, syntax-colored code samples (Rust + Reason at minimum), clearer glass/sidebar hierarchy, better mobile buffer taps, and a lightly labeled relay viz — without changing resume content or breaking navigation/a11y from Items 1–2.

---

## 2. Non-goals

- Full Tree-sitter / Prism dependency
- Redesign of vim cmdline (Item 5)
- Automated screenshot CI (manual Playwright screenshot optional)
- Changing `public/resume.json` career content

---

## 3. Files to touch

| File | Changes |
|------|---------|
| `src/highlight.mbt` | **NEW** — lightweight tokenizer → `Array[DomNode]` spans |
| `src/view_code.mbt` | Use highlighter instead of plain `@dom.text` |
| `src/view_relay.mbt` | `aria-label` / caption on canvas; keep decorative packets |
| `public/styles/vim.css` | Hero depth, buffer hierarchy, mobile 44px rows, code block polish, section rhythm, optional enter fade |
| `public/styles/galaxy.css` | Opaque glass fallback if needed; enter animation respect reduced-motion |
| `docs/archive/verification-item-3.md` | After implement |

Keep `code_sample` strings in `buffers.mbt` as source text (highlighter consumes them).

---

## 4. Implementation details

### 4.1 Hero

Already has gradient + `@supports` + forced-colors from Item 2. Add:

```css
.hero h1 {
  filter: drop-shadow(0 0 24px rgba(92, 225, 255, 0.25));
}
/* only when clip works — avoid muddy solid fallback */
@supports ((background-clip: text) or (-webkit-background-clip: text)) {
  .hero h1 {
    text-shadow: none; /* prefer drop-shadow on element */
  }
}
.hero .tagline { letter-spacing: 0.02em; }
.hero-links a { transition: border-color .15s, color .15s, background .15s; }
```

### 4.2 Code highlighting

New `src/highlight.mbt`:

```moonbit
/// Emit child nodes for <pre class="code-block">
fn highlight_code(src : String) -> Array[@dom.DomNode]
```

Token classes (match existing CSS):

| Class | Meaning |
|-------|---------|
| `cm` | line `//` and block `(* *)` comments |
| `st` | double-quoted strings |
| `nu` | numbers |
| `kw` | keywords (`fn`, `let`, `use`, `pub`, `async`, `open`, `|>` adjacent words, etc.) |
| `ty` | Type-ish idents: start with uppercase, or known (`Cents`, `Result`, `String`, …) |
| `fn` | ident immediately followed by `(` |
| (none) | plain text / punctuation |

Scanner rules (single pass over UTF-16/code units as MoonBit `String` allows):

1. Whitespace → plain (keep as-is)
2. `//` → rest of line `cm`
3. `(*` → until `*)` `cm`
4. `"` → string with simple `\"` escape → `st`
5. digit run → `nu`
6. ident run → classify kw / ty / look-ahead `(` for `fn` / plain
7. else single char plain

`view_code.mbt`:

```moonbit
@dom.pre(class="code-block") <| highlight_code(code_sample(buf.sample))
```

### 4.3 Glass / buffer hierarchy

```css
.buffer-item { opacity: 0.78; }
.buffer-item:hover,
.buffer-item.focused,
.buffer-item.active { opacity: 1; }

.buffer-item.active {
  background: rgba(92, 225, 255, 0.06);
  box-shadow: inset 2px 0 0 var(--accent-cyan);
}

.buffer-pane.glass-strong {
  box-shadow: var(--shadow-glow);
}

.section-title {
  margin-top: 4px;
  margin-bottom: 14px;
  padding-bottom: 6px;
  border-bottom: 1px solid rgba(140, 160, 220, 0.12);
}

.buffer-body {
  /* subtle enter — only if not reduced motion */
}
```

Optional:

```css
@keyframes buffer-in {
  from { opacity: 0.55; transform: translateY(4px); }
  to { opacity: 1; transform: none; }
}
.buffer-body > * {
  animation: buffer-in 0.22s ease-out;
}
@media (prefers-reduced-motion: reduce) {
  .buffer-body > * { animation: none; }
}
```

Note: body content is re-painted; animation on direct child is OK.

### 4.4 Mobile

Inside `@media (max-width: 860px)`:

```css
.buffer-item {
  min-height: 44px;
  padding: 12px 12px;
}
.buffer-list-header {
  min-height: 44px;
}
```

### 4.5 Relay viz

```moonbit
@dom.div(
  class="relay-canvas",
  attrs=[
    ("role", attr_s("img")),
    ("aria-label", attr_s("Relay routes client workloads to the AMD GPU fleet via Event API")),
  ],
)
```

Add a short visible caption under canvas if missing.

### 4.6 Code block chrome

Slightly stronger border/glow; optional language badge already via buffer label `h2`.

---

## 5. Public API — do not break

- `shell_app`, `load_resume`, buffer ids, CSS class names for layout/chrome
- Item 2 focus ids: `palette-input`, `buffer-body`, `buffer-list`

---

## 6. Verify

```bash
export PATH="$HOME/.moon/bin:$PATH"
cd /Users/nathansculli/src/scull7.com
moon build --target js --release
npm run build
# vite dev or preview + Playwright:
# - open cents.rs → pre.code-block .kw and .ty/.fn count > 0
# - open bs_result.re → .cm and .kw present
# - open relay-viz → [aria-label] on canvas
# - click experience still works
# - statusline height stable (no jump) optional visual
```

---

## 7. Acceptance checklist

- [ ] Hero still readable + has depth (shadow/glow)
- [ ] Rust sample (`cents` or `relay`) has colored kw/ty/fn/st/cm
- [ ] Reason sample has colored tokens
- [ ] Inactive buffer rows quieter; active/focused clearer
- [ ] Mobile buffer rows ≥44px tap target (CSS)
- [ ] Relay canvas labeled
- [ ] Reduced-motion: no continuous animations; no buffer-in if reduced
- [ ] Build green; nav + palette focus still work

---

## 8. Risks

| Risk | Mitigation |
|------|------------|
| Tokenizer mis-splits UTF-8 | Prefer MoonBit char iteration; comments/strings first |
| Too many DOM nodes in code | Samples are short (&lt;20 lines) |
| Animation jank on every paint | Short 0.22s; disabled under reduced-motion |
