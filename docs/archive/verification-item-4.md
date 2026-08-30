# Verification Report — Item 4 Automated tests

> **ARCHIVED — historical, not live guidance.**
> This document is from the MoonBit/Luna era of scull7.com and describes a stack the
> site no longer uses. The live stack is **Elm 0.19.1 for the UI and Melange 7
> (OCaml → JS) for ports, build tooling, and e2e** — see [`README.md`](../../README.md)
> and [`docs/ROADMAP.md`](../ROADMAP.md). Kept for provenance only; do not implement
> from it.

**Date:** 2026-07-18  
**Guidelines:** `docs/archive/guidelines-item-4-automated-tests.md`

## Architect checklist

| Criterion | Result |
|-----------|--------|
| `moon test --target js` passes | **PASS** — 29/29 |
| E2E fails if body does not change on sidebar click | **PASS** (asserts body ≠ previous + TensorWave/skills content) |
| Code highlight regression covered in e2e | **PASS** (`.kw` count > 0) |
| Palette `:` focus covered | **PASS** |
| README documents how to run tests | **PASS** |
| `npm test` = unit + build + e2e | **PASS** |
| No TypeScript | **PASS** (plain `.mjs`) |
| Whitebox tests (`*_wbtest.mbt`) for map_resume construction | **PASS** |

## Verdict: **PASS**

## Layout

```
src/format_wbtest.mbt    # dates, slugify, labels
src/model_wbtest.mbt     # map_resume fixture
src/buffers_wbtest.mbt   # catalog + samples
e2e/navigation.mjs       # Playwright assertions
e2e/run.mjs              # build + preview + navigate
```

## Commands

```bash
npm test                 # full
npm run test:unit
npm run test:e2e
```

## Notes

- Main package warns that blackbox `_test.mbt` will stop generating tests later — whitebox `*_wbtest.mbt` is the correct choice for constructing `ResumeDoc`.
- Optional CI not added (plan said optional).

## Product owner

Navigation regressions (tab-only body switch) are now caught automatically. Ready for Item 5 (vim command UX authenticity).
