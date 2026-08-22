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

**No TypeScript. No ReScript. No hand-written JS for resume inject.**  
- UI and state: **Elm**  
- Browser interop (focus, blur, scroll, key preventDefault): **Melange** (OCaml)  
- Crawlable HTML: **Melange** CLI (`src/melange/crawlable*.ml`)  

## Crawlable HTML

`dune build @site` emits a Node CLI from Melange. Vite `closeBundle` runs that
CLI so `npx vite build` fills `<noscript id="crawlable-resume">` in
`dist/index.html` from `public/resume.json`. Source `index.html` keeps the
delimiter empty. Career facts come from JSON — do not hand-edit them in HTML.

```bash
npm run inject:resume        # print the fragment
npm run inject:resume:dist   # patch dist/index.html (same CLI Vite uses)
npm run build                # melange + vite (inject in closeBundle)
```

## Structure

```
src/elm/
  Main.elm           # shell, keyboard, palette, terminal
  Resume.elm         # JSON Resume decode + map
  Format.elm / Buffers.elm / Fuzzy.elm / Highlight.elm / Views.elm / Ports.elm
src/melange/
  main.ml            # boot Elm + port wiring (Melange)
  html.ml / resume_doc.ml / crawlable.ml / crawlable_cli.ml
                     # JSON Resume → <noscript id="crawlable-resume">
  dune               # melange.emit → _build/.../main.js + crawlable CLI
src/main.js          # Vite entry imports Melange output
scripts/
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
npm test                 # elm make + T-13 crawlable proof + Playwright e2e
npm run test:t13         # no-JS Vite preview GET / + resume.json fixtures
npx playwright install chromium   # once
```

`test:t13` (`e2e/t13-crawlable.mjs`) fetches Vite preview `GET /` without executing
JavaScript and inspects only `<noscript id="crawlable-resume">`. Local
`public/resume.json` fixtures are restored with `git checkout` even on failure.

## Melange notes

Ports (`focus`, `blur`, `scrollBuffer`) are defined in Elm and subscribed in
`src/melange/main.ml`. Build with:

```bash
npm run melange          # opam exec -- dune build @site
```

Output: `_build/default/src/melange/output/src/melange/main.js`  
Runtime packages: npm `melange` + `melange.js`.
