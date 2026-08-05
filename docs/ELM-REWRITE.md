# Elm + ReScript rewrite

**Date:** 2026-08-04

Replaced MoonBit/Luna stack with:

| Layer | Tech |
|-------|------|
| UI / state / HTTP | Elm 0.19.1 |
| Ports & bootstrap | ReScript 11 |
| Bundler | Vite + vite-plugin-elm |
| Styles | Unchanged galaxy/vim CSS |
| Data | `public/resume.json` |

## Ports

| Port | Direction | Purpose |
|------|-----------|---------|
| `focus` | Elm → JS | Focus palette / restore focus after Esc |
| `scrollBuffer` | Elm → JS | Ctrl-f/b page, `z` center |

Also in ReScript (not ports): capture-phase `keydown` `preventDefault` for shell keys when not in an editable field.

## Commands

```bash
npm run dev
npm run build
npm test
```
