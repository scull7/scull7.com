# AVRIL Intent — Phase 2 Discoverability

**Status:** Human-authorized intent. Not a backlog. Not AXEL authorization.  
**Date:** 2026-08-21  
**Workspace:** `/Users/nathansculli/src/scull7.com`  
**Live:** https://scull7.com  
**SoT:** `public/resume.json` (JSON Resume)

AVRIL reads this file and stops at a triple-blessed backlog. Do not implement. Pinto is the only board.

---

## Conductor activation

Using `code-writer` + `avril`.

> “Run AVRIL — Architect proposes PBIs, Product Owner then QA Architect then Visionary CTO each explicitly BLESS or REJECT, revise until unanimous — and stop at a blessed backlog without writing implementation yourself.”

| Parameter | Value |
|---|---|
| Generator | `planning-architect-agent` |
| Adversaries (fixed order) | PO → QA → CTO |
| Personas | `/Users/nathansculli/src/crossr-skills/.agents/agents/` |
| Skills | `code-writer` + `/Users/nathansculli/src/crossr-skills/.agents/skills/avril/SKILL.md` |
| Board | **Pinto is source of truth.** Existing `.pinto/` (key `T`). New IDs continue (`T-11`…). `pinto automate --plan … --dry-run --json` before multi-step writes. |
| Blessed output | Pinto + `docs/plans/phase2-discoverability-avril-blessed-backlog.md` (summary only) |
| Size | Small vertical slices. Reviewable in one short pass. |

Do not reopen Phase 1 items except to depend on them. **Do not touch T-8.**

---

## Intent (one paragraph)

Search engines and no-JS clients currently see an empty `#app`. Keep the vim/terminal product and the dual IC + leadership identity **unchanged**. Add crawler plumbing (`robots.txt`, `sitemap.xml`, canonical) and **build-time static HTML** of name, label, summary, contact anchors, current job (TensorWave), and the next two roles (Sub Zero Corp, Banner), generated from `resume.json`. No headline rewrite. No second visual site.

Trigger: GPT 5.5 web search found LinkedIn, not scull7.com body text. Prior ROADMAP already named this gap (static inject). GPT’s “rebuild as executive profile / case studies / blog” is **rejected** for this slice.

---

## Locked human decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Identity | **Keep** dual IC + leadership. No hero/title/OG rewrite. |
| 2 | Slice | **Discoverability only** |
| 3 | Crawlable body | Plumbing **plus** build-time static HTML of basics + TensorWave + next 2 jobs |
| 4 | Aesthetic | Terminal UI unchanged. JSON Resume remains SoT. |
| 5 | T-8 | Out of this slice (registrar recovery). |

**Static HTML must include (from JSON, not hard-coded career facts):**

- `basics.name`, `basics.label`, `basics.summary`
- `basics.email` (mailto `<a>`), `basics.url`, `basics.profiles[].url` as plain `<a>`
- `work[0]` TensorWave: name, position, dates, url, highlights
- `work[1]` Sub Zero Corp: name, position, dates, highlights
- `work[2]` Banner: name, position, dates, url, highlights

**Keep existing strings (do not “improve”):**

- `<title>Nathan Sculli</title>`
- meta description / og:description / twitter:description: `Builder-leader · 20+ years · Rust · Distributed Systems`
- og:title `Nathan Sculli — scull7.com`
- JSON-LD Person as shipped (name, Director of Engineering, TensorWave, sameAs)

---

## In scope (authorized outcomes)

1. **`robots.txt`** — allow `/`; allow `/resume.json`; no accidental block of CSS/JS needed to render (static HTML must not depend on that for crawlers).
2. **`sitemap.xml`** — at least `https://scull7.com/` and `https://scull7.com/resume.json`.
3. **Canonical** — `<link rel="canonical" href="https://scull7.com/">` (or equivalent trailing-slash policy consistent with `og:url`).
4. **Build-time inject** — a documented build step (or Vite plugin/script already in-repo) reads `public/resume.json` and writes the static fragment into `index.html` (and thus `dist/index.html`). Regenerating after resume edits must not require hand-editing HTML facts.
5. **No-JS / crawler body** — that fragment is in the HTML document (prefer `<noscript>` and/or a semantically real, non-marketing block that does not become a second homepage). Contact and job URLs are real `<a href>`.
6. **Proof** — `curl` of `/` (no JS) contains the name, a summary sentence, “TensorWave”, and at least one profile or mailto href. View-source on production/preview matches.

---

## Explicit cuts

- Headline / `basics.label` / OG / JSON-LD `jobTitle` rewrite (“AI data center engineering leader”)
- Hero buttons, cards, “focus areas”, impact snapshot chrome
- Case studies, diagrams, blog, writing surface
- Hash/path routing, full SSR, PDF / `:print` / traditional view
- Split `Main.elm`, elm-test, GitHub Actions (unless a one-file build script already fits)
- Restoring `nathansculli.com` (T-8)
- New third-party dependencies (needs a fresh human yes)
- Inventing MW/rack/GPU counts or unpublished TensorWave internals
- Changing the live Elm buffers’ visual design

---

## Current baseline (2026-08-21)

| Fact | Reality |
|---|---|
| Product | Elm + Melange vim shell; JSON Resume SoT |
| Phase 1 | Shipped PR #5; T-9 cancelled; T-6/T-7 done; T-8 in-progress |
| `index.html` body | `<div id="app"></div>` only |
| Title / OG / Person JSON-LD | Present; identity strings as above |
| `robots.txt` / `sitemap.xml` / canonical link | **Missing** |
| GPT 5.5 | Did not extract site text; proposed a different product — not this intent |

---

## Constraints for every PBI

- Career facts come from `resume.json` at **build time**. Views/HTML must not hard-code names, dates, or highlights.
- Terminal remains the product. Static HTML is for crawlers and no-JS, not a parallel branded site.
- Small PRs. No mega-diff.
- Open `notes` empty or human-accepted before final BLESS.

---

## Suggested slice shape (guidance only — Generator authors PBIs)

- Plumbing: robots + sitemap + canonical
- Inject: build step + static fragment (basics + 3 jobs + anchors)
- Verify: curl/no-JS AC; resume.json change regenerates facts

Do not emit one god-PBI. Do not emit “touch CSS” with no crawler-visible outcome.

---

## AVRIL stop condition

When every **new** active PBI has fresh PO + QA + CTO `BLESS`:

1. Write `docs/plans/phase2-discoverability-avril-blessed-backlog.md`.
2. **Stop.** Do not invoke AXEL. Do not edit `src/` except if Generator only mutates Pinto.
3. Tell the human: planning complete; authorize AXEL to execute.

---

## Explicitly unresolved (none for this slice)

Identity (keep), crawl depth (basics + 3 jobs), cuts (no executive-profile rebuild) are locked. If AVRIL needs a new public claim or a visual second homepage, **stop and ask**.
