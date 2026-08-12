# Elm + Melange stack

**Updated:** 2026-08-07

| Layer | Tech |
|-------|------|
| UI / state / HTTP | Elm 0.19.1 |
| Ports & bootstrap | **Melange 7** (OCaml → JS via Dune) |
| Bundler | Vite + vite-plugin-elm |
| Styles | galaxy/vim CSS |
| Data | `public/resume.json` |

## Ports

| Port | Direction | Purpose |
|------|-----------|---------|
| `focus` | Elm → JS | Focus palette / restore / terminal |
| `blur` | Elm → JS | Blur sticky palette input on close |
| `scrollBuffer` | Elm → JS | Ctrl-f/b page, `z` center |

ReScript was removed in favor of Melange. Interop lives in `src/melange/main.ml`.

## Build

```bash
npm run opam:init   # once
npm run melange     # dune build @site
npm run build       # melange + vite
```
