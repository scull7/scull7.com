# Verification Report — Item 5 Vim command UX authenticity

**Date:** 2026-07-18  
**Guidelines:** `docs/guidelines-item-5-vim-ux.md`  
**Product direction:** **Option B (palette-primary)** + light cmdline echo

## Architect checklist

| Criterion | Result |
|-----------|--------|
| Help mode diagram matches behavior | **PASS** (help.txt + README) |
| `g` pending clears ~600ms | **PASS** (`arm_timeout` / `clear_g_pending`) |
| `:` focuses palette (no black hole) | **PASS** (e2e + Item 2) |
| Cmdline echoes `:query` / `/query` while open | **PASS** (e2e `:exp`) |
| Fuzzy ranks `exp` → experience | **PASS** (e2e + unit scores) |
| Esc synonyms `Ctrl-[` / `Ctrl-c` | **PASS** (e2e Ctrl-[) |
| Terminal input: shell keys ignored | **PASS** (guard in keydown) |
| Palette `j`/`k` navigate results | **PASS** (code path) |
| `Ctrl-f` / `Ctrl-b` page body; `z` center | **PASS** (FFI) |
| Unit tests | **PASS** 33/33 |
| E2E | **PASS** |
| Build | **PASS** |

## Verdict: **PASS**

## Implementation notes

| File | Change |
|------|--------|
| `src/shell_fuzzy.mbt` | score + sort for palette |
| `src/shell_fuzzy_wbtest.mbt` | score unit tests |
| `src/shell_focus.mbt` | timeout, scroll, terminal-input detect |
| `src/shell_app.mbt` | g-timeout, synonyms, fuzzy items, cmdline echo, guards |
| `src/view_help.mbt` | mode diagram + expanded keys |
| `README.md` | mode table aligned |
| `e2e/navigation.mjs` | echo, fuzzy, help, Ctrl-[ |

## Follow-ups (out of scope)

- Option A: true bottom cmdline editor
- Double-tap `zz` only (currently single `z`)
- Optional CI workflow

## Product owner

All five improvement-plan items are complete. Site is modular, accessible, polished, tested, and vim-clear under palette-primary UX.
