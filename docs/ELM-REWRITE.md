# Elm + Melange stack

**Updated:** 2026-08-22

| Layer | Tech |
|-------|------|
| UI / state / HTTP | Elm 0.19.1 |
| Ports, Accept negotiation, Vite, e2e, Netlify edge | **Melange 7** (OCaml → JS via Dune) |
| Bundler | Vite + vite-plugin-elm (config emitted from Melange) |
| Styles | galaxy/vim CSS |
| Data | `public/resume.json` |

Authored JavaScript is not part of this stack. Dune emits browser, Node, edge, and e2e artifacts under `_build/`. See [FRAMEWORK-EXTRACT.md](FRAMEWORK-EXTRACT.md) / Pinto T-14 for the planned public-framework / private-site split.

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
