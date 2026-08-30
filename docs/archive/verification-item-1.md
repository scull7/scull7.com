# Verification Report — Item 1 Modularize shell

> **ARCHIVED — historical, not live guidance.**
> This document is from the MoonBit/Luna era of scull7.com and describes a stack the
> site no longer uses. The live stack is **Elm 0.19.1 for the UI and Melange 7
> (OCaml → JS) for ports, build tooling, and e2e** — see [`README.md`](../../README.md)
> and [`docs/ROADMAP.md`](../ROADMAP.md). Kept for provenance only; do not implement
> from it.

**Date:** 2026-07-18  
**Guidelines:** `docs/archive/guidelines-item-1-modularize-shell.md`

## Architect checklist

| Criterion | Result |
|-----------|--------|
| `shell.mbt` deleted or ≤150 lines | **PASS** — deleted |
| Views in separate `view_*.mbt` | **PASS** — 11 view files |
| Content host isolated; views never call `paint_body` | **PASS** — `shell_content.mbt` |
| Click sidebar changes main body | **PASS** (QA) |
| Keyboard open works | **PASS** (gg+Enter → README) |
| `moon build` 0 errors | **PASS** |
| `npm run build` succeeds | **PASS** |
| Site loads name/summary/buffers/statusline | **PASS** |
| `shell_app` / `load_resume` / `main` signatures | **PASS** |
| No god-file ideally &lt;300 lines | **PARTIAL** — `shell_app.mbt` ~520 lines (commands+keyboard still colocated; acceptable per “minimum viable split”) |

## Verdict: **PASS** (with noted follow-up to split commands/keyboard further)

### Layout after implementation

```
src/shell_app.mbt       ~520  chrome + keyboard + commands
src/shell_content.mbt   ~46   body_host + paint
src/view_*.mbt          small per-buffer views
src/view_dispatch.mbt   buffer_content
src/view_util.mbt       attr_s, pills, …
```

`shell.mbt` removed.

## QA results

- homeOk, expSwitches, skillsSwitches, ossSwitches, keyboardHome: all true  
- pageerrors: none  

## Product owner

Site remains a usable vim-style resume: load, browse buffers by click, keyboard home, statusline intact. Item 1 improves maintainability without user-facing regression.

## Note on agent loop

The Task/subagent tool rejected new sessions (`task_id` must start with `ses`). Architect guidelines were written to disk; implementation and verification were executed in the main agent following the same loop steps.
