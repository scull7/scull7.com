# scull7.com

Nathan Sculli — personal resume site.

**Stack:** [Elm](https://elm-lang.org) UI · [Melange](https://melange.re) ports (OCaml→JS) · Vite · vanilla CSS · vim UX  
**Data:** [JSON Resume](https://jsonresume.org) (`public/resume.json`)  
**Deploy:** Netlify → https://scull7.com

## Prerequisites

```bash
# Elm 0.19.1
npm install -g elm

# opam (OCaml package manager) — required for Melange
# https://opam.ocaml.org/doc/Install.html
opam --version

node -v   # 20+
```

## One-time setup

```bash
npm install
# Create local opam switch + install Melange/Dune (first run is slow)
npm run opam:init
# or, if switch already exists:
npm run opam:deps
```

## Quick start

```bash
npm run dev      # Melange watch + Vite → http://localhost:5173
npm run build
npm run preview
```

**No TypeScript. No ReScript.**  
- UI and state: **Elm**  
- Browser interop (focus, blur, scroll, key preventDefault): **Melange** (OCaml)  

## Crawlable HTML

`vite build` (via `npm run build` and `scripts/netlify-build.sh`) runs a Vite
plugin in `scripts/crawlable-resume.mjs` that reads `public/resume.json` and
writes static HTML into `<noscript id="crawlable-resume">`. Source `index.html`
keeps that delimiter empty; `dist/index.html` is filled at build. Career facts
come from JSON — do not hand-edit them in HTML. No extra npm packages.

```bash
npm run inject:resume   # print the fragment (Node stdlib)
npm run build           # injects into dist/index.html
```

## Structure

```
src/elm/
  Main.elm           # shell, keyboard, palette, terminal
  Resume.elm         # JSON Resume decode + map
  Format.elm / Buffers.elm / Fuzzy.elm / Highlight.elm / Views.elm / Ports.elm
src/melange/
  main.ml            # boot Elm + port wiring (Melange)
  dune               # melange.emit → _build/.../main.js
src/main.js          # Vite entry imports Melange output
scripts/
  crawlable-resume.mjs  # JSON Resume → <noscript id="crawlable-resume">
  netlify-build.sh
public/
  resume.json
  styles/{galaxy,vim}.css
dune-project
scull7.opam
```

## Vim UX

Palette-primary: `:` / `/` open the command palette; the bottom cmdline **echoes** what you type.

| Key / command | Action |
|---|---|
| `j` `k` / arrows | Move buffer focus |
| `gg` / `G` | Top / bottom |
| `/` `:` | Search / command palette |
| `Esc` `Ctrl-[` | Cancel |
| Terminal buffer | Input autofocused |

## Testing

```bash
npm test                 # elm make + build + Playwright e2e
npx playwright install chromium   # once
```

## Melange notes

Ports (`focus`, `blur`, `scrollBuffer`) are defined in Elm and subscribed in
`src/melange/main.ml`. Build with:

```bash
npm run melange          # opam exec -- dune build @site
```

Output: `_build/default/src/melange/output/src/melange/main.js`  
Runtime packages: npm `melange` + `melange.js`.
