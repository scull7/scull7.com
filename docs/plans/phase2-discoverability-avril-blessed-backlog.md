# Blessed Backlog Summary — Phase 2 Discoverability

**Date:** 2026-08-21  
**Conductor:** AVRIL (Architect → PO → QA → CTO)  
**Status:** Planning stop. Pinto is source of truth. Hand off to AXEL only when the human authorizes execution.  
**Intent:** `docs/plans/phase2-discoverability-avril-intent.md`

## Intent

Crawlers and no-JS clients currently see an empty `#app`. Keep the vim/terminal product and dual IC + leadership identity. Add robots/sitemap/canonical and build-time static HTML of basics + TensorWave + Sub Zero + Banner from `resume.json`. No headline rewrite. No second visual site.

## Board (source of truth)

```text
pinto list
pinto show T-11 T-12 T-13
```

Do not fork a second tracker. **T-8 remains in-progress** (registrar recovery); not in this slice.

## Blessed PBIs (ordered)

| ID | Title | Pts | Deps | Labels |
|---|---|---|---|---|
| T-11 | Ship robots.txt, sitemap.xml, and a canonical link | 2 | T-4 | seo, discoverability, phase2 |
| T-12 | Inject crawlable static HTML from resume.json at build | 3 | T-1, T-4 | seo, discoverability, phase2 |
| T-13 | Regenerate crawlable facts from resume.json and prove no-JS curl | 2 | T-12 | seo, discoverability, phase2 |

**7 points.** All `todo`. T-11 ∥ T-12; T-13 after T-12.

Suggested AXEL start: **T-11** and **T-12** in parallel (or T-11 first if smaller), then **T-13**.

CTO note for execution (not a new PBI): generate the fragment at build into `dist/`; do not commit filled career HTML as a second SoT.

## Explicit cuts

Headline / OG / JSON-LD rewrite · executive homepage · case studies / blog · routing / SSR / PDF · `Main.elm` split · T-8 · new third-party deps · unpublished metrics · Elm visual redesign

## Open questions for execution

None.

## Blessing log

Cycle 1 — Architect: T-11, T-12, T-13.  
PO: BLESS T-11, T-12, T-13.  
QA: REJECT all three (unfalsifiable GET/head/JSON-LD theater).  
Generator: AC-only (fragment region, GET body, well-formed sitemap, overwrite, fixtures).

Cycle 2 — PO: BLESS T-11, T-12, T-13.  
QA: BLESS T-11, T-12 · REJECT T-13 (mutation appearance-only).  
Generator: T-13 replace-not-append mutation.

Cycle 3 — PO: BLESS T-13. QA: BLESS T-13.

Cycle 4 — CTO: BLESS T-11, T-12, T-13.

| ID | PO | QA | CTO |
|---|---|---|---|
| T-11 | BLESS | BLESS | BLESS |
| T-12 | BLESS | BLESS | BLESS |
| T-13 | BLESS | BLESS (post-mutation tighten) | BLESS |

## Stop

Planning complete. **Do not implement from this session.** Authorize **AXEL** to execute. Pinto remains the only backlog.
