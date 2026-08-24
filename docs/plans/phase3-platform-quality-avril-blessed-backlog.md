# Blessed Backlog Summary — Phase 3 Platform Quality

**Date:** 2026-08-21  
**Remap:** 2026-08-24  
**Conductor:** AVRIL (Architect → PO → QA → CTO)  
**Status:** Planning stop. Pinto is source of truth. Hand off to AXEL only when the human authorizes execution.  
**Intent:** `docs/plans/phase3-platform-quality-avril-intent.md`

AVRIL blessed these as T-14–T-19. `main` later issued **T-14** (framework extract) and **T-15** (interview-me spec). In-flight interview-me drafts claim **T-16–T-19**. Phase 3 cards are **T-20–T-25**. Blessing is unchanged.

| Planning ID | Live ID |
|---|---|
| T-14 | T-20 Split `Main.elm` |
| T-15 | T-21 elm-test fixtures |
| T-16 | T-22 Playwright keyboard lock |
| T-17 | T-23 GitHub Actions on PR |
| T-18 | T-24 `:reload` resume retry |
| T-19 | T-25 Archive MoonBit docs |

## Intent

Melange, identity, and crawlable HTML are on `main`. `Main.elm` is still a god-module; there is no elm-test, no GitHub Actions, and Playwright is a thin navigation path. Modularize the shell, add fixture unit tests, lock Esc / j/k-after-palette / terminal autofocus in e2e, fail PRs in CI, show in-terminal resume-load retry, and archive MoonBit docs. No routing. No print. No second visual site.

## Board (source of truth)

```text
pinto list
pinto show T-20 T-21 T-22 T-23 T-24 T-25
```

Do not fork a second tracker. **T-8 remains in-progress** (registrar recovery); not in this slice.

## Blessed PBIs (ordered)

| ID | Title | Pts | Deps | Labels |
|---|---|---|---|---|
| T-20 | Split Main.elm into focused Shell modules without behavior change | 5 | — | phase3, platform |
| T-21 | Add elm-test fixtures for Format, Resume.mapResume, Fuzzy, and Highlight | 3 | — | phase3, test |
| T-25 | Archive MoonBit-era docs and leave one Melange stack pointer | 2 | — | phase3, docs |
| T-22 | Expand Playwright for Esc cycle, j/k after palette, and terminal autofocus | 3 | T-20 | phase3, test |
| T-24 | Show in-terminal retry when resume.json Http load fails | 3 | T-20 | phase3, ux |
| T-23 | Fail GitHub pull_request CI on elm make, dune, Vite build, or e2e failure | 3 | T-21, T-22 | phase3, ci |

**19 points.** All `todo`. T-20 ∥ T-21 ∥ T-25; T-22 and T-24 after T-20; T-23 after T-21 and T-22.

Suggested AXEL start: **T-20**, **T-21**, and **T-25** in parallel, then T-22 ∥ T-24, then **T-23**.

CTO notes for execution (not new PBIs): keep `Main` as the `Browser.*` root so ROADMAP 2.1 stays a later hash adapter; T-23 is a PR check only (Netlify remains deploy); `:reload` is one `runCommand` arm (GET `/resume.json`), not vim-depth.

## Explicit cuts

Hash/path routing · print CSS / PDF · vim-depth (history, `:theme`, in-buffer `/`) · light theme / blog / contact form · headline / OG / JSON-LD rewrite · T-8 · new npm besides `elm-test` · Netlify dashboard opam cache · unpublished metrics · Elm visual redesign · deep-link e2e

## Open questions for execution

None.

## Blessing log

Cycle 1 — Architect: T-20–T-25.  
PO: BLESS T-20, T-21, T-22, T-23, T-24, T-25.  
QA: REJECT T-20–T-24 (unfalsifiable behavior / tautology tests / Esc already green / GitHub-UI theater / thin load-error). BLESS T-25.  
Generator: AC-only tighten T-20–T-24 (DOM keyboard regressions, named elm-test equals, e2e/run.mjs wire-up, saboteur job fail, `:reload` + four fault kinds).

Cycle 2 — PO: BLESS T-20, T-21, T-22, T-23, T-24 (`:reload` in-slice).  
QA: BLESS T-20, T-21, T-22, T-23, T-24.

Cycle 3 — CTO: BLESS T-20, T-21, T-22, T-23, T-24, T-25.

| ID | PO | QA | CTO |
|---|---|---|---|
| T-20 | BLESS (post-AC) | BLESS (post-DOM regressions) | BLESS |
| T-21 | BLESS (post-AC) | BLESS (post-named equals) | BLESS |
| T-22 | BLESS (post-AC) | BLESS (post-DOM + run.mjs) | BLESS |
| T-23 | BLESS (post-AC) | BLESS (post-saboteur argv) | BLESS |
| T-24 | BLESS (post-`:reload`) | BLESS (post-four faults) | BLESS |
| T-25 | BLESS | BLESS | BLESS |

## Stop

Planning complete. **Do not implement from this session.** Authorize **AXEL** to execute. Pinto remains the only backlog.
