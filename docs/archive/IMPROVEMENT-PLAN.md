# scull7.com — Top 5 Improvement Plan

> **ARCHIVED — historical, not live guidance.**
> This document is from the MoonBit/Luna era of scull7.com and describes a stack the
> site no longer uses. The live stack is **Elm 0.19.1 for the UI and Melange 7
> (OCaml → JS) for ports, build tooling, and e2e** — see [`README.md`](../../README.md)
> and [`docs/ROADMAP.md`](../ROADMAP.md). Kept for provenance only; do not implement
> from it.

**Date:** 2026-07-18  
**Scope:** Full-site review after MoonBit + Luna port  
**Goal:** Make the site more maintainable, accessible, polished, testable, and “vim-true”

---

## Current state (brief)

| Layer | Status |
|-------|--------|
| Stack | MoonBit + Luna + Vite · vanilla CSS · JSON Resume |
| Core UX | Buffer sidebar, statusline, `:` / `/` palette, demos |
| Pain points | God-file shell, imperative body paint, thin a11y, no tests |

**Key code facts:**

- `src/shell.mbt` ~816 lines: UI, keyboard state machine, commands, terminal, palette
- Body content uses **imperative** `@dom.render_to` into a ref host because Luna `show` / `index_each` do not remount when only the active buffer id changes
- Hero `h1` uses `background-clip: text` + `color: transparent` (fragile if clip unsupported)
- No unit or e2e tests in-repo
- Palette input is not auto-focused on open; `Insert` mode is unused; `g`-pending has no timeout

---

## Top 5 priorities

| # | Item | Why it ranks high |
|---|------|-------------------|
| 1 | **Modularize shell + first-class content routing** | Unblocks every feature; reduces regression risk from the paint_body workaround |
| 2 | **Accessibility & focus management** | Resume site must work with keyboard + AT; palette/focus bugs feel “broken” |
| 3 | **Visual polish (hero, code, glass hierarchy)** | First impression; currently uneven (gradient title, plain code buffers) |
| 4 | **Automated tests (model + navigation e2e)** | Buffer switching already bit us twice; resume.json is the source of truth |
| 5 | **Vim command UX authenticity** | Differentiator of the site; cmdline/palette still feel half-finished |

---

## 1. Modularize shell + first-class content routing

### Problem

- All interaction lives in one file (`shell.mbt`).
- Content switching depends on a **ref + `paint_body()`** side channel instead of declarative Luna trees.
- Views (`view_home`, `view_experience`, …), commands, palette, and terminal are tangled → hard to change one without breaking others.

### Desired outcome

```
src/
  shell/
    app.mbt           # composition root, chrome layout
    state.mbt         # Mode, signals, open_buffer
    commands.mbt      # :help :e :ls :q parsers
    palette.mbt       # : and / UI
    keyboard.mbt      # document keydown
    terminal.mbt      # live terminal buffer
  views/
    home.mbt
    experience.mbt
    highlights.mbt
    skills.mbt
    opensource.mbt
    code.mbt
    relay.mbt
    help.mbt
  model.mbt / format.mbt / buffers.mbt  # keep
```

### Approach

1. **Extract pure modules first** (no behavior change):
   - `views/*` from current `view_*` functions
   - `commands.mbt` from `run_command` / `open_by_query` / `palette_items`
2. **Replace imperative body paint** with one of:
   - **Preferred:** keyed content node — e.g. `index_each` over `[active_id]` **and** force length change via epoch pair `[epoch, id]`, or a small custom `keyed(key, render)` helper wrapping Luna `show` toggle (document the pattern once).
   - **Acceptable:** keep `body_host` + `paint_body` but isolate it in `content_host.mbt` with a single public `set_active_buffer(id)`.
3. **Wire `main.mbt`** only to `shell_app(data)` export (unchanged public API).
4. Delete dead paths (`Insert` mode or implement it; remove unused package aliases in `moon.pkg.json`).

### Acceptance criteria

- [ ] `shell.mbt` either gone or &lt; ~150 lines of composition
- [ ] Opening a buffer does **not** require callers outside `content_host` / state module to call `paint_body`
- [ ] Click + keyboard open still switch body content (manual + e2e from item 4)
- [ ] `moon build --target js --release` clean (warnings triage optional)

### Effort

**M–L** (2–4 focused sessions)

---

## 2. Accessibility & focus management

### Problem

- Site is keyboard-forward but not fully accessible:
  - Palette opens without focusing `#palette-input`
  - Buffer list is clickable `<li>` without `role="option"` / listbox pattern consistently exposed to AT after Luna render
  - No focus trap in palette; Tab can escape underlay
  - Hero title uses transparent fill (screen readers OK, high-contrast/forced-colors may fail)
  - No `aria-live` on statusline/cmdline messages
  - Document-level keydown may fight browser shortcuts without careful `preventDefault` scoping

### Desired outcome

- Palette: open → focus input; Esc → close and restore focus to buffer list / body
- Status/cmdline: `aria-live="polite"` for messages
- Buffer list: `role="listbox"`, items `role="option"` + `aria-selected`
- Visible focus rings on interactive chrome (already partial via `:focus-visible`)
- `prefers-reduced-motion` already present — extend to packet animations / twinkle
- Fallback solid color for `.hero h1` when `background-clip: text` unsupported

### Approach

1. Audit with keyboard-only pass + axe (or Playwright + axe-core) on home + one buffer + palette open.
2. Implement focus helpers in `keyboard.mbt` / `palette.mbt`:
   - `focus_palette_input()`, `restore_focus()`
3. Add semantic attrs in Luna `attrs=[...]` on list/palette roots.
4. CSS: `@supports not ((-webkit-background-clip: text) or (background-clip: text))` fallback for h1.
5. Ensure bottom chrome is not the only focus sink; buffer body `tabindex="0"` when appropriate.

### Acceptance criteria

- [ ] `: ` / `/` focuses the palette text field immediately
- [ ] Esc from palette returns focus to a sensible control
- [ ] axe critical/serious issues = 0 on main flows
- [ ] Forced-colors / no-clip: name remains readable

### Effort

**S–M** (1–2 sessions)

---

## 3. Visual polish (hero, code, glass hierarchy)

### Problem

- Hero name relies on gradient clipping; can read as “missing” in some engines.
- Code buffers are monochrome plain text (no token colors) despite CSS hooks (`.code-block .kw` etc. exist in CSS from earlier design).
- Glass panels / sidebar / body hierarchy is OK but dense; mobile collapsed sidebar chevron/UX can be clearer.
- Relay viz is decorative but not labeled for meaning beyond copy.

### Desired outcome

- Reliable, striking hero (gradient where supported, solid cyan/white fallback).
- Code samples with lightweight highlighting (static spans from MoonBit, or a tiny highlighter over sample strings).
- Clearer visual depth: active buffer glow, quieter inactive list items, consistent section rhythm.
- Optional: subtle page enter transition (respect reduced motion).

### Approach

1. **Hero CSS** — fallback color + optional `text-shadow` for depth; keep gradient as progressive enhancement.
2. **Code samples** — extend `buffers.mbt` / `views/code.mbt` to emit structured nodes (`span.kw`, `span.ty`, …) matching `vim.css`, or store pre-tokenized fragments in data.
3. **Chrome CSS pass** — tighten spacing scale, active row left accent already present; ensure glass `backdrop-filter` has opaque fallback background (already mostly true).
4. **Mobile** — larger tap targets (min 44px) on buffer rows; clearer collapsed header.
5. Screenshot before/after at 1280 and 390 widths.

### Acceptance criteria

- [ ] Hero readable in Safari, Chrome, Firefox (desktop + one mobile width)
- [ ] At least Rust + Reason samples show distinct token colors
- [ ] No layout shift of statusline on buffer switch
- [ ] Reduced-motion: no continuous packet/twinkle animation

### Effort

**S–M** (1–2 sessions)

---

## 4. Automated tests (model + navigation e2e)

### Problem

- Resume mapping and buffer navigation are high-churn and already regressed (clicks updating tab only).
- No `*_test.mbt` / Playwright suite in the project.
- JSON Resume shape is normalized ad hoc; invalid JSON only fails at runtime in the browser.

### Desired outcome

| Layer | Tool | Covers |
|-------|------|--------|
| Unit | `moon test` | `format_date`, `slugify`, `map_resume` fixtures |
| E2E | Playwright | load site, click buffer, assert body text; open `:` palette |

### Approach

1. **Fixtures:** `src/testdata/minimal_resume.json` (tiny valid ResumeDoc).
2. **Moon tests:**
   - `format_test.mbt` — date ranges, slugify edge cases
   - `model_test.mbt` — parse fixture string → `map_resume` → expect company/role counts
3. **Playwright** (`e2e/navigation.spec.ts` or `.mjs` to stay TS-light — prefer **plain JS** to match “no TS” preference):
   - `beforeEach`: `page.goto` preview or `vite preview`
   - click `experience.md` → expect “work experience” / TensorWave role
   - press `:` → palette visible + input focused (after item 2)
4. **CI optional:** GitHub Action on PR: `moon test` + `npm run build` + e2e against `vite preview`.
5. Document scripts in `package.json`: `test`, `test:e2e`.

### Acceptance criteria

- [ ] `moon test` passes locally
- [ ] E2E fails if body does not change on sidebar click
- [ ] README documents how to run tests
- [ ] No dependency on manual screenshot for navigation confidence

### Effort

**M** (1–2 sessions)

---

## 5. Vim command UX authenticity

### Problem

- Statusline + cmdline look vim-like, but:
  - Real typing for `:` / `/` goes to a **modal palette**, not the bottom cmdline
  - Bottom cmdline is mostly a **message bar**, not an editable command line
  - `g` pending has no timeout (easy to surprise-jump later)
  - `Insert` mode declared but unused
  - No `Ctrl-C` / `Ctrl-[` as Esc synonyms
  - Terminal demo and main shell keyboard can conflict when focus is unclear

### Desired outcome

- Bottom cmdline becomes the primary command/search input when mode is Command/Search **or** palette stays but cmdline mirrors the buffer (`:open exp…`).
- Clear mode rules documented in `help.txt` and README.
- Small quality fixes: `g` timeout (~500ms), Esc synonyms, disable global hjkl when palette open (already partly true).

### Approach

**Pick one product direction (decide in kickoff):**

| Option | Description | Fit |
|--------|-------------|-----|
| **A. Bottom cmdline editor** | On `:`, focus cmdline input; submit on Enter; messages use a separate echo area | Most “real vim” |
| **B. Palette-primary** | Keep palette; cmdline only echoes; polish focus + fuzzy ranking | Less work, still good |
| **C. Hybrid** | `:` opens palette **and** syncs text into cmdline prefix | Best of both, more glue |

Recommended default: **B now**, **A** as follow-up if you want deeper vim fidelity.

Concrete tasks either way:

1. Auto-focus command UI (ties to item 2).
2. Fuzzy match scoring for buffer names (substring → prefix → fzf-ish).
3. `g` pending: reset via `setTimeout` FFI or timestamp check on next key.
4. Expand help buffer with mode diagram.
5. Optional: `zz` scroll body to center; `Ctrl-F` / `Ctrl-B` page body.

### Acceptance criteria

- [ ] Written mode diagram in help matches behavior
- [ ] No stuck `g`-pending after 1s idle
- [ ] Command UI always receives keystrokes when activated (no “black hole” `:`)
- [ ] Terminal buffer: global nav keys ignored while terminal input focused

### Effort

- Option B: **S**  
- Option A: **M**

---

## Suggested execution order

```text
Week-shaped sequence (not calendar-bound):

  [1] Modularize + content routing   ──► foundation
         │
         ▼
  [4] Tests (model + e2e nav)        ──► lock behavior before polish
         │
         ├─► [2] Accessibility
         │
         ├─► [3] Visual polish
         │
         └─► [5] Vim UX (B then optional A)
```

**Dependency notes:**

- Item **4** should land right after the first vertical slice of **1** (even before full file split), so buffer switching cannot regress again.
- Item **2** and **5** share palette focus work — do focus once, reuse.
- Item **3** is mostly CSS + `buffers`/`views/code`; can parallelize with **2** after **1** starts.

---

## Out of scope (for this plan)

- Full SSR / pre-render of resume HTML for SEO (nice later; JSON Resume URL already helps tools)
- Rewriting CSS in MoonBit
- Mobile native app shell
- CMS / admin for resume.json
- Perfect vim emulation (macros, visual mode, registers)

---

## Success metrics

| Metric | Target |
|--------|--------|
| Buffer switch reliability | E2E green on every PR |
| `shell` maintainability | No single file &gt; ~300 lines without clear submodule |
| A11y | 0 critical axe issues on home + palette |
| Perceived polish | Hero + code samples pass “would I send this link?” check |
| Vim clarity | New visitor can open experience via `j`/`Enter` or `:e exp` without help from you |

---

## Kickoff checklist

1. Confirm item **5** direction: palette-primary (B) vs bottom cmdline (A).
2. Confirm package layout: single `moon.pkg` vs multiple MoonBit packages under `src/`.
3. Start item **1** with `views/` extract + e2e for navigation (item **4** thin slice).
4. Ship in small PRs: extract → content host → a11y → polish → vim.

---

*Generated from full-site review of MoonBit shell, styles, resume pipeline, and recent navigation regressions.*
