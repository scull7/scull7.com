# Blessed Backlog Summary — Phase 3 Platform Quality

**Date:** 2026-08-21  
**Conductor:** AVRIL (Architect → PO → QA → CTO)  
**Status:** Planning stop. Pinto is source of truth. Hand off to AXEL only when the human authorizes execution.  
**Intent:** `docs/plans/phase3-platform-quality-avril-intent.md`

## Intent

Melange, identity, and crawlable HTML are on `main`. `Main.elm` is still a god-module; there is no elm-test, no GitHub Actions, and Playwright is a thin navigation path. Modularize the shell, add fixture unit tests, lock Esc / j/k-after-palette / terminal autofocus in e2e, fail PRs in CI, show in-terminal resume-load retry, and archive MoonBit docs. No routing. No print. No second visual site.

## Board (source of truth)

```text
pinto list
pinto show T-14 T-15 T-16 T-17 T-18 T-19
```

Do not fork a second tracker. **T-8 remains in-progress** (registrar recovery); not in this slice.

## Blessed PBIs (ordered)

| ID | Title | Pts | Deps | Labels |
|---|---|---|---|---|
| T-14 | Split Main.elm into focused Shell modules without behavior change | 5 | — | phase3, platform |
| T-15 | Add elm-test fixtures for Format, Resume.mapResume, Fuzzy, and Highlight | 3 | — | phase3, test |
| T-19 | Archive MoonBit-era docs and leave one Melange stack pointer | 2 | — | phase3, docs |
| T-16 | Expand Playwright for Esc cycle, j/k after palette, and terminal autofocus | 3 | T-14 | phase3, test |
| T-18 | Show in-terminal retry when resume.json Http load fails | 3 | T-14 | phase3, ux |
| T-17 | Fail GitHub pull_request CI on elm make, dune, Vite build, or e2e failure | 3 | T-15, T-16 | phase3, ci |

**19 points.** All `todo`. T-14 ∥ T-15 ∥ T-19; T-16 and T-18 after T-14; T-17 after T-15 and T-16.

Suggested AXEL start: **T-14**, **T-15**, and **T-19** in parallel, then T-16 ∥ T-18, then **T-17**.

CTO notes for execution (not new PBIs): keep `Main` as the `Browser.*` root so ROADMAP 2.1 stays a later hash adapter; T-17 is a PR check only (Netlify remains deploy); `:reload` is one `runCommand` arm (GET `/resume.json`), not vim-depth.

## Explicit cuts

Hash/path routing · print CSS / PDF · vim-depth (history, `:theme`, in-buffer `/`) · light theme / blog / contact form · headline / OG / JSON-LD rewrite · T-8 · new npm besides `elm-test` · Netlify dashboard opam cache · unpublished metrics · Elm visual redesign · deep-link e2e

## Open questions for execution

None.

## Blessing log

Cycle 1 — Architect: T-14–T-19.  
PO: BLESS T-14, T-15, T-16, T-17, T-18, T-19.  
QA: REJECT T-14–T-18 (unfalsifiable behavior / tautology tests / Esc already green / GitHub-UI theater / thin load-error). BLESS T-19.  
Generator: AC-only tighten T-14–T-18 (DOM keyboard regressions, named elm-test equals, e2e/run.mjs wire-up, saboteur job fail, `:reload` + four fault kinds).

Cycle 2 — PO: BLESS T-14, T-15, T-16, T-17, T-18 (`:reload` in-slice).  
QA: BLESS T-14, T-15, T-16, T-17, T-18.

Cycle 3 — CTO: BLESS T-14, T-15, T-16, T-17, T-18, T-19.

| ID | PO | QA | CTO |
|---|---|---|---|
| T-14 | BLESS (post-AC) | BLESS (post-DOM regressions) | BLESS |
| T-15 | BLESS (post-AC) | BLESS (post-named equals) | BLESS |
| T-16 | BLESS (post-AC) | BLESS (post-DOM + run.mjs) | BLESS |
| T-17 | BLESS (post-AC) | BLESS (post-saboteur argv) | BLESS |
| T-18 | BLESS (post-`:reload`) | BLESS (post-four faults) | BLESS |
| T-19 | BLESS | BLESS | BLESS |

## Stop

Planning complete. **Do not implement from this session.** Authorize **AXEL** to execute. Pinto remains the only backlog.
