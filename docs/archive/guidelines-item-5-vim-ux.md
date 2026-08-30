# Implementation Guidelines — Item 5: Vim command UX authenticity

> **ARCHIVED — historical, not live guidance.**
> This document is from the MoonBit/Luna era of scull7.com and describes a stack the
> site no longer uses. The live stack is **Elm 0.19.1 for the UI and Melange 7
> (OCaml → JS) for ports, build tooling, and e2e** — see [`README.md`](../../README.md)
> and [`docs/ROADMAP.md`](../ROADMAP.md). Kept for provenance only; do not implement
> from it.

**Repo:** `/Users/nathansculli/src/scull7.com`  
**Plan:** `docs/archive/IMPROVEMENT-PLAN.md` §5  
**Product choice:** **Option B (palette-primary)** + light hybrid cmdline echo  
(Default from plan / prior kickoff. Full bottom cmdline editor = follow-up.)

---

## 1. Goal

Make command/search UX predictable and more vim-like without rewriting chrome: palette remains the editor; bottom cmdline mirrors typed text; `g` pending times out; Esc synonyms work; terminal input does not steal global nav; help documents modes.

---

## 2. Non-goals

- Full Option A bottom cmdline editor
- Visual mode, macros, registers
- Perfect fzf algorithm (simple score is enough)

---

## 3. Files

| File | Changes |
|------|---------|
| `src/shell_fuzzy.mbt` | **NEW** — score + sort helpers for palette |
| `src/shell_focus.mbt` | `schedule_clear_g`, `scroll_buffer`, `active_is_terminal_input` |
| `src/shell_app.mbt` | g timeout, Esc synonyms, fuzzy items, cmdline mirror, terminal guard, Ctrl-f/b, palette j/k |
| `src/view_help.mbt` | Mode diagram + expanded keys |
| `README.md` | Align mode table |
| `docs/archive/verification-item-5.md` | After implement |
| `e2e/navigation.mjs` | Optional: g-timeout or cmdline mirror smoke |

---

## 4. Details

### 4.1 Fuzzy score

```moonbit
// lower score = better; None = no match
fn fuzzy_score(query : String, text : String) -> Int?
```

Rules for non-empty query (lowercase both):
1. exact → 0
2. prefix → 10
3. substring → 30 + index
4. else subsequence (chars in order) → 100 + gaps, or None

Sort palette buffer/cmd lists by score ascending; empty query keeps original order.

### 4.2 g pending timeout

```moonbit
extern "js" fn g_arm_timeout(ms : Int, cb : () -> Unit) -> Int  // returns handle
extern "js" fn g_clear_timeout(handle : Int) -> Unit
```

On first `g`: set pending true, arm 500–800ms clear. On `gg` or timeout: clear pending. On other keys while pending: clear pending (except second g).

### 4.3 Esc synonyms

Treat as Escape when palette open or normal:
- `Escape`
- `Ctrl-[` (key `[` with ctrlKey)
- `Ctrl-c` (key `c` with ctrlKey) — only when palette open or not typing in terminal

### 4.4 Cmdline mirror (hybrid light)

When `palette_open`:
- cmdline shows `:` or `/` + `palette_query` (dyn text)
When closed: existing msg/status

### 4.5 Terminal guard

If `document.activeElement` has class `terminal-input`, skip global hjkl/g/G/:/` (allow Esc to blur + NORMAL).

### 4.6 Scrolling

`Ctrl-f` / `Ctrl-b`: scroll `#buffer-body` by ~90% clientHeight.  
Optional `zz`: scroll so middle of body is centered (nice-to-have).

### 4.7 Palette j/k

When palette open, `j`/`k` move focus like arrows (preventDefault).

### 4.8 Help

ASCII mode diagram:

```
NORMAL  --:-->  COMMAND (palette)  --Esc--> NORMAL
NORMAL  --/-->  SEARCH  (palette)  --Esc--> NORMAL
NORMAL  --i-->  (n/a — insert unused)
terminal input focused → shell keys ignored
```

---

## 5. Acceptance

- [ ] Help mode diagram matches behavior
- [ ] g pending clears within ~1s idle
- [ ] `:` always focuses palette (no black hole)
- [ ] Cmdline shows typed command while palette open
- [ ] Terminal input: j does not move buffer list
- [ ] Fuzzy: typing `exp` ranks experience high
- [ ] Build + unit + e2e green

---

## 6. Risks

| Risk | Mitigation |
|------|------------|
| Ctrl-c copy conflict | Only intercept when palette open |
| Timeout leaks | Clear previous handle before arm |
