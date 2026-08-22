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

**No TypeScript. No ReScript. No hand-authored JavaScript.**  
- UI and state: **Elm**  
- Browser interop, Accept negotiation, Vite config, Netlify edge, e2e: **Melange** (OCaml)  
- Crawlable HTML: **Melange** CLI (`src/melange/crawlable*.ml`)  
- Planned split: public framework repo, private scull7.com site — [`docs/FRAMEWORK-EXTRACT.md`](docs/FRAMEWORK-EXTRACT.md) / Pinto T-14  
- Planned interview-me v1 (recruiter-agent Q&A + calendar hold) — [`docs/INTERVIEW-ME.md`](docs/INTERVIEW-ME.md) / Pinto T-15  

## Crawlable HTML

`dune build @site` emits a Node CLI from Melange. Vite `closeBundle` runs that
CLI so `npx vite build` fills `<main id="crawlable-resume">` in
`dist/index.html` (and writes `dist/index.md`) from `public/resume.json`.
Source `index.html` keeps the delimiter empty. Career facts come from JSON —
do not hand-edit them in HTML. The fragment lives in the document body so
no-JS crawlers see an H1, nested H2/H3, and the resume text. With JavaScript
on, a tiny `has-js` class hides that block and Elm remains the only primary UI.

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
                     # JSON Resume → <main id="crawlable-resume"> + index.md
  accept.ml / resolve.ml / plan.ml / handler.ml
                     # Accept negotiation (Vite preview + Netlify edge + tests)
  vite_config.ml     # Vite config + crawlable / negotiate plugins
  negotiate_edge.ml  # Netlify edge handler (copied to netlify/edge-functions/ at build)
  e2e_*.ml           # agentic / navigation / t13 / run (npm scripts invoke the emit)
  dune               # melange.emit → _build/... browser, CLI, vite, edge, e2e
scripts/
  netlify-build.sh   # dune @site, emit edge JS, vite --config <Melange emit>
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
npm test                 # elm make + T-13 + agentic + Playwright e2e
npm run test:t13         # no-JS Vite preview GET / + resume.json fixtures
npm run test:agentic     # Accept parsing, markdown, 404, trust pages
npx playwright install chromium   # once
```

`test:t13` (Melange `e2e_t13.ml`) fetches Vite preview `GET /` without executing
JavaScript and inspects `<main id="crawlable-resume">`. Local
`public/resume.json` fixtures are restored with `git checkout` even on failure.

## Agent-readable surface

- `/llms.txt` and `/llms-full.txt` — when to use this resume site (not a SaaS API)
- `/about`, `/contact`, `/privacy`, `/for-agents` — static HTML + `.md` siblings
- Same URL serves `text/markdown` when `Accept` prefers it (`Vary: Accept`)
- Custom `404` with recovery links (Markdown when requested)
- Person JSON-LD with `name`, `description`, `url`, `sameAs`, Organization `contactPoint` + `address`

## Melange notes

Ports (`focus`, `blur`, `scrollBuffer`) are defined in Elm and subscribed in
`src/melange/main.ml`. Build with:

```bash
npm run melange          # opam exec -- dune build @site
```

Output: `_build/default/src/melange/output/src/melange/main.js`  
Runtime packages: npm `melange` + `melange.js`.
