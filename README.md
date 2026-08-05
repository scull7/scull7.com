# scull7.com

Nathan Sculli — personal resume site.

**Stack:** [Elm](https://elm-lang.org) UI · [ReScript](https://rescript-lang.org) ports/bootstrap · Vite · vanilla CSS · vim UX  
**Data:** [JSON Resume](https://jsonresume.org) (`public/resume.json`)  
**Deploy:** Netlify → https://scull7.com

## Prerequisites

```bash
# Elm 0.19.1
npm install -g elm
# or: https://guide.elm-lang.org/install/elm.html

node -v   # 20+
```

## Quick start

```bash
npm install
npm run dev      # ReScript watch + Vite → http://localhost:5173
npm run build
npm run preview
```

**No TypeScript. No app-level plain JavaScript UI.**  
- UI and state: Elm  
- Browser interop (focus, scroll, key preventDefault): ReScript ports  

## Structure

```
src/elm/
  Main.elm           # shell, keyboard, palette, terminal
  Resume.elm         # JSON Resume decode + map
  Format.elm         # dates, slugify
  Buffers.elm        # buffer catalog + code samples
  Fuzzy.elm          # palette ranking
  Highlight.elm      # lightweight syntax tint
  Views.elm          # buffer body views
  Ports.elm          # focus, scrollBuffer
src/rescript/
  Main.res           # boot Elm + port wiring
public/
  resume.json
  styles/{galaxy,vim}.css
```

## Vim UX

Palette-primary (Option B): `:` / `/` open the command palette; the bottom cmdline **echoes** what you type.

```
NORMAL  --:-->  COMMAND (palette)  --Esc--> NORMAL
NORMAL  --/-->  SEARCH  (palette)  --Esc--> NORMAL
```

| Key / command | Action |
|---|---|
| `j` `k` / arrows | Move buffer focus |
| `gg` / `G` | Top / bottom (`g` pending clears ~600ms) |
| `/` | Fuzzy search palette |
| `:` | Command palette |
| `Ctrl-[` `Ctrl-c` | Esc synonyms |
| `Ctrl-f` `Ctrl-b` | Page buffer body |
| `z` | Center buffer scroll |
| `:help` `:ls` `:e` `:open` `:q` | Buffer commands |
| `Enter` / `Esc` | Open / cancel |
| Terminal input focused | Shell keys ignored |

## Testing

```bash
npm test                 # elm make + build + Playwright e2e
npm run test:e2e
npx playwright install chromium   # once
```

## Resume data

```bash
npx resume-cli validate public/resume.json
```
