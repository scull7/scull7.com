# scull7.com

Nathan Sculli — personal resume site.

**Stack:** Astra (MoonBit SSG) · vanilla CSS · vim-inspired keyboard UX  
**Theme:** glassmorphic frosted panels on a deep-space galaxy background  
**Deploy:** Netlify → https://scull7.com

## Quick start

```bash
# prerequisites: moon + astra CLI
#   curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
#   npm i -g @luna_ui/astra

npm run dev      # http://localhost:7777
npm run build    # → dist/
npm run preview  # static preview of dist/
```

## Vim UX

| Key / command | Action |
|---|---|
| `hjkl` / arrows | Move focus across buffers |
| `gg` / `G` | Jump top / bottom of buffer list |
| `/` | Fuzzy search buffers |
| `:` | Command palette |
| `:help` | Show help |
| `:ls` | List open buffers |
| `:e {name}` / `:open {name}` | Open buffer |
| `:q` | Close overlay / return home |
| `Enter` | Open focused buffer |
| `Esc` | Cancel command / search |

## Structure

```
docs/
  index.md                 # home (vim shell host)
  experience/*.md          # optional static mirror pages
  public/
    css/galaxy.css         # galaxy + glass
    css/vim.css            # statusline, palette, buffers
    js/vim-shell.js        # keyboard engine + data
    js/data.js             # resume content
    islands/               # web components (terminal, relay viz)
    og.svg
astra.config.json
netlify.toml
```
