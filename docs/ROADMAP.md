# scull7.com — Current State & Roadmap

**Date:** 2026-08-07  
**Audience:** product + engineering (you + agents)  
**Live:** https://scull7.com  
**Canonical data:** `public/resume.json` (JSON Resume)

---

## 1. What the site is

A personal resume / portfolio presented as a **vim-inspired IDE shell**:

| Surface | Role |
|---------|------|
| Buffer sidebar | “Files” = resume sections + demos |
| Main pane | Active buffer content |
| Statusline + cmdline | Mode + messages; echoes `:` / `/` query |
| Command palette | Fuzzy open buffers / run `:` commands |
| Demos | Code samples, Relay viz, live terminal |

**Differentiators:** keyboard-first UX, glassmorphic galaxy aesthetic, JSON Resume interoperability, stack that showcases functional languages you care about (Elm, OCaml/Melange, historically Rust/Reason).

---

## 2. Current state (as of this review)

### 2.1 Production

| Item | Status |
|------|--------|
| https://scull7.com | **200** — serving Elm build (asset hash matches post–PR #2) |
| PR #2 Elm + ReScript rewrite | **Merged** to `main` (`89c7e22`) |
| Local branch `feat/elm-rescript-rewrite` | Behind `main` merge; **has uncommitted Melange migration** |
| Netlify build | Elm + ReScript path on `main`; Melange Netlify path only in local WIP |

### 2.2 Stack (intended / in-flight)

| Layer | On `main` (live) | Local WIP (uncommitted) |
|-------|------------------|-------------------------|
| UI / state / HTTP | Elm 0.19.1 | same |
| Ports / bootstrap | ReScript 11 | **Melange 7** + Dune + opam |
| Bundler | Vite + vite-plugin-elm | same |
| CSS | `public/styles/{galaxy,vim}.css` | same |
| Data | `public/resume.json` | same |

**Local WIP reality:** Melange builds and e2e were green in session; not yet committed/PRd. Until that lands, treat ReScript as production and Melange as the next ship.

### 2.3 Feature inventory

| Feature | Status | Notes |
|---------|--------|-------|
| Resume home / hero / links | Done | From JSON Resume basics |
| Experience, highlights, skills, OSS, education | Done | Mapped in `Resume.elm` |
| Code sample buffers + syntax tint | Done | Lightweight tokenizer, not full language grammar |
| Relay viz demo | Done | Decorative + aria-label |
| Live terminal mini-shell | Done | Autofocus on open (post keyboard fix) |
| Palette `:` / `/` + fuzzy rank | Done | Cmdline echo |
| Esc / Ctrl-[ / focus restore | Done | Fixed sticky palette-input focus |
| Mobile collapsible buffers | Done | 44px taps in CSS |
| a11y landmarks (listbox, dialog, live region) | Partial | Present; no axe CI |
| Elm unit tests (`elm-test`) | **Missing** | Only Playwright e2e |
| Deep-link URL → buffer | **Missing** | Always boots `README.md` |
| SEO / SSR / noscript content | **Weak** | SPA shell; crawlers see little resume text |
| Printable / PDF CV | **Missing** | |
| Contact form | **Missing** | mailto only |
| Blog / writing | **Missing** | |
| Theme toggle (light) | **Missing** | dark-only |
| i18n | **Missing** | EN only |
| CI (GitHub Actions) | **Missing** | Netlify only |
| Split `Main.elm` (~1.1k LOC) | **Debt** | Commands/keyboard/view still colocated |

### 2.4 Architecture snapshot

```
Browser
  └─ Vite entry (main.js)
       └─ Melange main.ml  [WIP]  or  ReScript Main.res  [main]
            ├─ Elm.Main.init(flags)
            ├─ ports: focus | blur | scrollBuffer
            └─ capture keydown preventDefault
Elm
  ├─ Http → /resume.json → Resume.mapResume
  ├─ Buffers catalog (static)
  ├─ Views per BufferKind
  └─ Keyboard / palette / terminal state machine (Main.elm)
```

### 2.5 Risks (ordered)

1. **Deploy toolchain weight** — Melange needs opam switch on Netlify; cold builds will be slow/fragile without caching `_opam`.
2. **God-module `Main.elm`** — high regression cost for keyboard/palette (already bitten twice).
3. **SEO / shareability** — recruiters and OG scrapers get thin HTML.
4. **Docs drift** — `docs/IMPROVEMENT-PLAN.md` still describes MoonBit; verifications are historical.
5. **Branch hygiene** — Melange work uncommitted on a branch whose name still says rescript; `main` is ahead via merge commit.

---

## 3. Goals (next 1–2 quarters)

| Goal | Success signal |
|------|----------------|
| **Reliable platform** | Melange (or deliberate ReScript stay) on `main`; Netlify green & cached; CI on PR |
| **Recruiter-grade first paint** | Readable resume without JS; solid OG; optional print CSS |
| **Delightful vim shell** | Deep links, history, more authentic cmdline without breaking a11y |
| **Content leverage** | Resume.json remains SoT; optional posts/projects without CMS |
| **Maintainability** | `Main.elm` split; elm-test + expanded e2e; stale MoonBit docs archived |

---

## 4. Roadmap (phased)

### Phase 0 — Stabilize & ship Melange (1–3 days) — **do first**

| # | Work | Why |
|---|------|-----|
| 0.1 | Commit Melange migration; rename branch/PR to `feat/elm-melange-ports` | WIP is the real stack direction |
| 0.2 | Netlify: cache `~/.opam` + project `_opam`; fail fast with clear logs | Avoid 10–20m cold builds / timeouts |
| 0.3 | Smoke: production deploy checklist (home, exp, `:`, Esc, terminal focus) | Keyboard regressions are high cost |
| 0.4 | Archive/relabel MoonBit docs (`docs/archive/…`) + point README at Melange | Stop agent confusion |

**Exit:** Melange on `main`, scull7.com green, docs match stack.

---

### Phase 1 — Platform quality (1–2 weeks)

| # | Work | Effort | Impact |
|---|------|--------|--------|
| 1.1 | **Split `Main.elm`** → `Shell/Update.elm`, `Shell/View.elm`, `Shell/Commands.elm`, `Shell/Keyboard.elm`, `Shell/Palette.elm` | M | Unblocks all features |
| 1.2 | **elm-test** for `Format`, `Resume.mapResume`, `Fuzzy`, `Highlight` (fixtures) | S–M | Catch mapping bugs without browser |
| 1.3 | **Expand Playwright**: Esc cycle, j/k after palette, terminal autofocus, deep-link (once 2.1 exists) | S | Lock keyboard contract |
| 1.4 | **GitHub Actions**: `elm make` + `dune build @site` + `npm run build` + e2e on PR | M | Don’t rely on Netlify alone |
| 1.5 | **Error UX**: resume load failure page with retry; offline banner optional | S | Professional polish |

**Exit:** PR CI green; unit + e2e; Main.elm &lt; ~300 lines per module.

---

### Phase 2 — Discovery & content product (2–4 weeks)

| # | Work | Effort | Impact |
|---|------|--------|--------|
| 2.1 | **URL routing** — `/#/experience`, `/e/experience.md`, or path `/experience` via Netlify redirects + Elm `Browser.application` | M | Shareable sections |
| 2.2 | **SSR-ish or static HTML fallback** — build-time inject summary + top jobs into `index.html` or prerender | M–L | SEO + noscript |
| 2.3 | **Print stylesheet** — `@media print` linear CV from same model | S–M | “Download PDF” via print |
| 2.4 | **JSON Resume export badge** — visible link + schema.org `Person`/`JobPosting` JSON-LD | S | Interop + SEO |
| 2.5 | **Content modules** — optional `public/posts/*.md` or more code samples from real repos (fetch at build) | M | Depth without CMS |
| 2.6 | **Contact** — optional form (Netlify Forms / Formspree) with spam protection | S–M | Conversion |

**Exit:** LinkedIn bio can deep-link to experience; Google sees name/role/summary; print works.

---

### Phase 3 — Vim shell depth (optional differentiator) (2–4 weeks)

Pick **one** primary direction; don’t boil the ocean.

| Option | Description | Fit |
|--------|-------------|-----|
| **A. Bottom cmdline editor** | Real `:` line at bottom; palette becomes completion popup | Most “vim” |
| **B. Palette+ (default)** | Keep palette; add history (`:`↑), multi-match scoring, `:set` toggles | Less work |
| **C. Buffer chrome** | Tabs for open buffers, `:bnext`, marks (`ma` / `'a`) | Power-user |

Recommended concrete backlog for **B**:

| # | Work |
|---|------|
| 3.1 | Command history (session + `localStorage` via Melange port) |
| 3.2 | `:theme dark\|light`, `:wrap`, reduced-motion already CSS — surface toggles |
| 3.3 | In-buffer search `/` that highlights in body (not only buffer names) |
| 3.4 | `Ctrl-d` / `Ctrl-u` half-page; mouse wheel already native |
| 3.5 | Terminal: job control aesthetic only; keep sandboxed (no real shell) |

**Exit:** New visitor can navigate resume fully without mouse in &lt;30s; power users feel rewarded.

---

### Phase 4 — Visual & brand (ongoing / parallel)

| # | Work |
|---|------|
| 4.1 | Light theme + `prefers-color-scheme` |
| 4.2 | Motion: optional richer Relay viz (still reduced-motion safe) |
| 4.3 | Code highlight: map sample language → slightly richer token sets; or tree-sitter WASM (heavy — avoid unless needed) |
| 4.4 | Custom OG image generation from resume basics (build script → `og.png`) |
| 4.5 | Favicon / app icons / PWA optional (offline resume cache) |

---

### Phase 5 — Extensions (later / opportunistic)

| Idea | Notes |
|------|-------|
| **Writing / TIL** | Markdown buffers or separate `/blog` with same chrome |
| **Talks / slides** | Link-out or embedded PDF buffers |
| **Live “proof”** | Embed WASM demos (Rust cents calculator) as buffers |
| **i18n** | Only if targeting non-EN markets |
| **Analytics** | Privacy-friendly (Plausible/Fathom); no dark patterns |
| **A/B none** | Keep one strong narrative |

---

## 5. Explicit non-goals (for now)

- Full vim (macros, visual mode, registers, plugins)
- Real remote shell / arbitrary code execution in terminal
- Headless CMS / WordPress
- React/Next rewrite
- Perfect pixel clone of a terminal emulator

---

## 6. Suggested sequencing (tracer bullets)

```text
Week 0     Phase 0: ship Melange, Netlify cache, doc archive
Week 1–2   Phase 1: split Main.elm, elm-test, CI, e2e expand
Week 3–4   Phase 2.1–2.4: routing + SEO/print/JSON-LD
Week 5+    Phase 3 (palette history) ∥ Phase 4 (theme/OG)
Later      Phase 5 as content ideas appear
```

---

## 7. Metrics (lightweight)

| Metric | How | Target |
|--------|-----|--------|
| Deploy success rate | Netlify | ≥ 95% |
| e2e on main | CI | always green |
| LCP / INP | Web Vitals (field or lab) | “Good” on mobile |
| Keyboard path | Manual / e2e | open exp via `j`/`Enter` or `:e exp` &lt; 10 keys |
| Resume freshness | `meta.lastModified` in resume.json | update when jobs change |

---

## 8. Decision log (needed soon)

| Decision | Options | Recommendation |
|----------|---------|----------------|
| Ports language | Stay ReScript vs Melange | **Melange** (matches OCaml story; already implemented locally) |
| Routing style | hash vs path | **hash first** (`#/experience`) then path if SEO needs it |
| SEO strategy | prerender vs static inject | **static inject summary + jobs into index.html at build** (simplest) |
| PDF | print CSS vs server PDF | **print CSS** first |

---

## 9. Agent-ready next tickets

1. **Ship Melange:** commit WIP, PR, Netlify opam cache, deploy.  
2. **Split Main.elm** into Shell/* modules (behavior-preserving).  
3. **elm-test fixture** for `mapResume` from minimal JSON.  
4. **Browser.application + hash routes** for each buffer id.  
5. **Build step** inject noscript resume blurb + JSON-LD into `index.html`.  
6. **Print CSS** for linear CV.  
7. **CI workflow** `.github/workflows/ci.yml`.  
8. **Archive** MoonBit improvement docs; leave one pointer in ROADMAP.

---

## 10. Summary

The site is a **working, distinctive Elm resume shell** on production, with a **Melange ports migration ready but unshipped**. The highest leverage path is: **stabilize toolchain → modularize shell → deep links + SEO/print → deepen vim UX without losing a11y**. Content stays driven by `resume.json`; demos stay optional flavor, not the product.

When in doubt: **fewer features, sharper keyboard path, better first impression for a hiring manager on a phone.**
