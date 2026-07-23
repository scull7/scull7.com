# scull7.com

Nathan Sculli — personal resume site.

**Stack:** [Luna UI](https://luna.mizchi.workers.dev/) on **MoonBit** + Vite · vanilla CSS · vim UX  
**Data:** [JSON Resume](https://jsonresume.org) (`public/resume.json`)  
**Deploy:** Netlify → https://scull7.com

## Prerequisites

```bash
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
source ~/.zshrc
moon version
```

## Quick start

```bash
npm install
moon update
npm run dev      # http://localhost:5173
npm run build
npm run preview
```

**No TypeScript. No app-level JavaScript UI.** The site is a MoonBit + Luna app.

## Structure

```
src/
  main.mbt                 # boot, load resume, mount shell
  shell_app.mbt            # vim chrome, keyboard, commands
  shell_content.mbt        # buffer body host (paint_body)
  view_*.mbt               # per-buffer views + dispatch
  model.mbt                # JSON Resume types + map + fetch
  format.mbt               # pure date/slug helpers
  buffers.mbt              # buffer catalog + code samples
  moon.pkg.json
public/
  resume.json              # JSON Resume source of truth
  styles/{galaxy,vim}.css
  og.svg
main.js                    # Vite entry → import "mbt:scull7/site"
moon.mod.json
vite.config.js
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
# unit (MoonBit whitebox) + production build + Playwright e2e
npm test

# separately
npm run test:unit          # moon test --target js
npm run test:e2e           # build + vite preview + e2e/navigation.mjs
npm run test:e2e:only      # against an already-running server (BASE_URL=…)

# first-time Playwright browsers (if needed)
npx playwright install chromium
```

Unit coverage: `format_*`, `slugify`, `map_resume`, buffer catalog (`src/*_wbtest.mbt`).  
E2E coverage: home load, experience/skills body switch, code highlight spans, `:` palette focus.

## Resume data

```bash
npx resume-cli validate public/resume.json
```
