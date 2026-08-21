# Blessed Backlog Summary — Phase 1 Content + Branding/SEO

**Date:** 2026-08-13 (bless); 2026-08-21 (ship)  
**Conductor:** AVRIL (Architect → PO → QA → CTO) → AXEL  
**Status:** In-repo slice **shipped** in [PR #5](https://github.com/scull7/scull7.com/pull/5) (`e8a6030`). Pinto is source of truth.  
**Intent:** `docs/plans/phase1-content-branding-avril-intent.md`

## Intent

Make scull7.com complete and frictionless for sharing without diluting the vim/terminal product: authorized career facts, crossr-skills + ferro-wg, `:mail`, last-updated, scraper card, URL hygiene, and human identity (GitHub/X). `nathansculli.com` stays retired. Philosophy is **internal** (not a public buffer or JSON field).

## Board (source of truth)

```text
pinto list
pinto show T-<n>
```

Project key `T`. DoD in `.pinto/dod.md`.  
This file is a summary + blessing log. **Do not fork a second tracker.**

## Execution outcome (2026-08-21)

| ID | Board | Outcome |
|---|---|---|
| T-1 | done | Resume facts + ROADMAP pointer. Philosophy JSON later removed as internal. |
| T-2 | done | `crossr-skills.md` buffer from JSON. |
| T-3 | done | `:mail` → public mailto. |
| T-4 | done | Person JSON-LD + `og.png`. |
| T-5 | done | URL audit no-op (already clean). |
| T-9 | **cancelled** (archived) | Buffer shipped then unpublished (`675b2fb`); human cancelled 2026-08-21. Not on live catalog or `/resume.json`. |
| T-10 | done | Statusline `updated YYYY-MM-DD`. |
| T-6 | done | GitHub profile website → `scull7.com`. |
| T-7 | done | X @Scull7 website → `scull7.com`. |
| T-8 | in-progress | Human recovering registrar access; keep NXDOMAIN; no redirect. |

## Blessed PBIs (ordered)

| ID | Title | Pts | Deps | Labels |
|---|---|---|---|---|
| T-1 | Refresh resume.json career facts and existing views | 3 | — | content, phase1 |
| T-2 | Add crossr-skills.md terminal buffer from JSON project | 2 | T-1 | content, ux, phase1 |
| T-9 | Add philosophy.md terminal buffer from JSON philosophy | 2 | T-1 | content, ux, phase1 |
| T-3 | Add :mail command that opens the public mailto | 2 | — | ux, phase1 |
| T-10 | Surface last-updated date from meta.lastModified | 2 | T-1 | ux, phase1 |
| T-4 | Ship Person JSON-LD and scraper-safe OG PNG | 2 | T-1 | seo, branding, phase1 |
| T-5 | Fix broken or retired-domain URLs already on the site | 2 | T-1 | content, seo, phase1 |
| T-6 | Point GitHub profile website at https://scull7.com | 1 | — | human, phase1 |
| T-7 | Point X @scull7 website at https://scull7.com | 1 | — | human, phase1 |
| T-8 | Leave nathansculli.com retired at NXDOMAIN | 1 | — | human, phase1 |

**19 points.** T-6, T-7, T-8 are human runbooks (execution instructions on the Pinto bodies).

Suggested AXEL start: **T-1**, then fan-out T-2 / T-9 / T-10 / T-4 / T-5. T-3 and humans can run in parallel with T-1.

## Explicit cuts

Hybrid/print/` :print`/PDF · split `Main.elm` / elm-test / GHA · routing/SSR/blog · live GitHub activity / calendar · velumobex · unpublished TensorWave internals / 10k GPUs · restore or redirect `nathansculli.com` · education rewrite · light theme / PWA / analytics / i18n · non-terminal chrome · new third-party deps

## Open questions for execution

None. Human-accepted product lock is in the intent file.

## Blessing log

Cycle 1 — PO: BLESS T-1, T-3, T-5, T-6, T-7, T-8 · REJECT T-2 (bundled buffers) · REJECT T-4 (bundled last-updated + share).  
Generator: split T-2→T-2+T-9, T-4→T-4+T-10.

Cycle 2 — PO: BLESS T-2, T-4, T-9, T-10.

Cycle 3 — QA: BLESS T-1, T-3, T-6, T-7, T-8 · REJECT T-2, T-4, T-5, T-9, T-10 (unfalsifiable ACs).  
Generator: AC-only fixtures.

Cycle 4 — PO: BLESS T-2, T-4, T-5, T-9, T-10.  
QA: BLESS T-4, T-5, T-9, T-10 · REJECT T-2 (empty-description).  
Generator: T-2 empty-description + missing-project tighten.

Cycle 5 — PO: BLESS T-2. QA: BLESS T-2.

Cycle 6 — CTO: BLESS T-1 … T-10. No REJECT.

| ID | PO | QA | CTO |
|---|---|---|---|
| T-1 | BLESS | BLESS | BLESS |
| T-2 | BLESS (post-split + AC) | BLESS (post-empty-desc) | BLESS |
| T-3 | BLESS | BLESS | BLESS |
| T-4 | BLESS (post-split + AC) | BLESS (post-AC) | BLESS |
| T-5 | BLESS (reaffirmed post-AC) | BLESS (post-AC) | BLESS |
| T-6 | BLESS | BLESS | BLESS |
| T-7 | BLESS | BLESS | BLESS |
| T-8 | BLESS | BLESS | BLESS |
| T-9 | BLESS (post-split + AC) | BLESS (post-AC) | BLESS |
| T-10 | BLESS (post-split + AC) | BLESS (post-AC) | BLESS |

## Stop

In-repo execution complete (PR #5). Remaining work is human T-6, T-7, T-8. Pinto remains the only backlog.
