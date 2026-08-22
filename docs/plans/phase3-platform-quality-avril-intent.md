# AVRIL Intent — Phase 3 Platform Quality

**Status:** Human-authorized intent. Not a backlog. Not AXEL authorization.  
**Date:** 2026-08-21  
**Workspace:** `/Users/nathansculli/src/scull7.com`  
**Live:** https://scull7.com  
**SoT:** `public/resume.json` (JSON Resume)  
**Source:** `docs/ROADMAP.md` §4 Phase 1 (platform quality) + leftover Phase 0 hygiene + §9 agent-ready tickets still undone.

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
| Board | **Pinto is source of truth.** Existing `.pinto/` (key `T`). New IDs continue (`T-14`…). `pinto automate --plan … --dry-run --json` before multi-step writes. |
| Blessed output | Pinto + `docs/plans/phase3-platform-quality-avril-blessed-backlog.md` (summary only) |
| Size | Small vertical slices. Reviewable in one short pass. |

Do not reopen Phase 1/2 items except to depend on them. **Do not touch T-8.**

---

## Intent (one paragraph)

Melange, identity, and crawlable HTML are on `main`. `Main.elm` is still a ~1176-line god-module; there is no `elm-test`, no GitHub Actions, and Playwright only covers a thin navigation path. Follow ROADMAP sequencing (Week 1–2): modularize the shell, add fixture unit tests, lock more of the keyboard contract in e2e, run CI on PRs, show a resume-load failure that is still the terminal product, and archive stale MoonBit docs so agents stop targeting the wrong stack. No new public career claims. No second visual site. No routing or print in this slice.

Trigger: human asked AVRIL to plan the next ROADMAP items after T-13 merged (PR #12). ROADMAP §6 puts platform quality before remaining discovery (hash routes, print CSS).

---

## Locked human decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Identity | **Keep** dual IC + leadership. No hero/title/OG rewrite. |
| 2 | Slice | **ROADMAP Phase 1 platform quality** (+ leftover Phase 0 doc archive). Not routing. Not print. Not vim-depth. |
| 3 | Routing style | Deferred. ROADMAP still recommends hash first (`#/experience`) — **not this slice**. |
| 4 | Aesthetic | Terminal UI behavior-preserving. JSON Resume remains SoT. |
| 5 | T-8 | Out of this slice (registrar recovery). |
| 6 | New deps | **`elm-test` is authorized** (ROADMAP 1.2). Any other new npm/elm package needs a fresh human yes. |
| 7 | PDF | print CSS later (ROADMAP 2.3). Not this slice. |

**Keep existing strings (do not “improve”):**

- `<title>Nathan Sculli</title>`
- meta description / og:description / twitter:description: `Builder-leader · 20+ years · Rust · Distributed Systems`
- og:title `Nathan Sculli — scull7.com`
- JSON-LD Person as shipped (name, Director of Engineering, TensorWave, sameAs)
- Crawlable `<noscript id="crawlable-resume">` contract from T-12/T-13

---

## In scope (authorized outcomes)

ROADMAP numbering in parentheses. Generator authors the PBI split; it must not drop an outcome or add a new product direction.

1. **Split `Main.elm`** (1.1) — behavior-preserving extract into focused modules (ROADMAP names `Shell/Update.elm`, `Shell/View.elm`, `Shell/Commands.elm`, `Shell/Keyboard.elm`, `Shell/Palette.elm`; Architect may adjust names if the seam is cleaner). Target: no module in the split is a new god-file; ROADMAP exit “Main.elm < ~300 lines per module.” Existing `e2e/navigation.mjs` still PASS. Visual/keyboard contract unchanged.
2. **elm-test fixtures** (1.2) — tests for `Format`, `Resume.mapResume`, `Fuzzy`, `Highlight` from fixtures (minimal JSON, not live `resume.json` as the only case). `elm-test` package authorized. `npm test` (or documented script) runs them.
3. **Expand Playwright** (1.3) — Esc cycle, j/k after palette, terminal autofocus. **Do not** add deep-link e2e (ROADMAP: “once 2.1 exists”). Existing navigation e2e still PASS.
4. **GitHub Actions CI on PR** (1.4) — `elm make` + `dune build @site` + `npm run build` + e2e on pull_request. Must fail the PR when those fail. Bound cold-start cost; do not invent a second deploy path besides Netlify.
5. **Resume load error UX** (1.5) — when `/resume.json` fails to load, the terminal shows a failure the user can retry; not a blank `#app` and not marketing chrome. Offline banner **optional** — include only if it stays a thin terminal message; otherwise cut.
6. **Archive MoonBit docs** (0.4 / §9.8) — move or relabel `docs/IMPROVEMENT-PLAN.md` and MoonBit-era guidelines/verifications so agents do not treat MoonBit as the live stack. Leave one pointer from ROADMAP/README to Melange.

Leftover **0.2 Netlify opam cache** is in-scope only if Architect can express it as a falsifiable in-repo artifact (e.g. `netlify.toml` cache headers). If it is dashboard-only, emit a **human** PBI with a runbook, same pattern as T-6/T-7 — or cut it with an explicit note.

---

## Explicit cuts

- Hash/path routing, `Browser.application`, shareable `/#/experience` (ROADMAP 2.1)
- Print CSS / PDF / `:print` (2.3)
- Case studies, blog, writing surface, contact form (2.5, 2.6)
- Vim depth: command history, `:theme`, in-buffer `/`, tabs/marks (Phase 3)
- Light theme, richer Relay viz, tree-sitter, PWA (Phase 4)
- Headline / OG / JSON-LD rewrite
- Restoring `nathansculli.com` (T-8)
- New third-party dependencies other than `elm-test`
- Inventing MW/rack/GPU counts or unpublished TensorWave internals
- Changing the live Elm buffers’ visual design except as required to show resume-load failure in-terminal
- Deep-link e2e (blocked on 2.1)
- Re-opening T-11/T-12/T-13 inject/robots except as regression ACs (“existing crawlable + e2e still PASS”)

---

## Current baseline (2026-08-21, post PR #12)

| Fact | Reality |
|---|---|
| Product | Elm + Melange vim shell; JSON Resume SoT |
| Phase 1 (AVRIL content) | Shipped PR #5; T-9 cancelled; T-8 in-progress |
| Phase 2 (AVRIL discoverability) | T-11/T-12/T-13 done on `main` (PRs #11, #10, #12) |
| `src/elm/Main.elm` | **1176 lines** — update, view, commands, keyboard, palette colocated |
| Other Elm | Buffers 165, Format 142, Fuzzy 91, Highlight 374, Resume 540, Views 344, Ports 19 |
| elm-test | **Missing** — `elm.json` `test-dependencies` empty |
| e2e | `e2e/navigation.mjs` + T-13 crawlable proof; no Esc/jk/terminal-autofocus coverage |
| CI | **Missing** — Netlify only; no `.github/workflows` |
| Resume load failure | No dedicated retry UI (Http error currently silent/thin) |
| MoonBit docs | `docs/IMPROVEMENT-PLAN.md` + guidelines/verification-item-* still describe MoonBit/Luna |
| Identity / noscript | Locked strings + crawlable fragment on production |

---

## Constraints for every PBI

- Career facts come from `resume.json`. Views/HTML must not hard-code names, dates, or highlights.
- Terminal remains the product. Failure UX is a buffer/statusline/cmdline message, not a marketing page.
- Small PRs. No mega-diff. Split `Main.elm` may be one PBI only if AC keep it reviewable (behavior-preserving + size bound + e2e green). If the extract is a multi-thousand-line blob, split the PBI.
- Open `notes` empty or human-accepted before final BLESS.
- Identity lock and T-13 `npm run test:t13` / existing navigation e2e are regression gates on any Elm/build change.

---

## Suggested slice shape (guidance only — Generator authors PBIs)

- Modularize shell (behavior-preserving)
- elm-test fixtures for pure calculations
- Keyboard e2e (Esc, j/k after palette, terminal autofocus)
- GHA on PR
- Resume Http failure + retry (terminal)
- Archive MoonBit docs
- Optional: Netlify opam cache as human or in-repo cache config

Do not emit one god-PBI that splits Main.elm *and* adds tests *and* CI. Do not emit “touch CSS” with no user- or agent-observable outcome.

---

## AVRIL stop condition

When every **new** active PBI has fresh PO + QA + CTO `BLESS`:

1. Write `docs/plans/phase3-platform-quality-avril-blessed-backlog.md`.
2. **Stop.** Do not invoke AXEL. Do not edit `src/` except if Generator only mutates Pinto.
3. Tell the human: planning complete; authorize AXEL to execute.

---

## Explicitly unresolved (none for this slice)

Identity (keep), slice (platform quality, not routing/print), elm-test authorized, T-8 out. If AVRIL needs a new public claim, a visual second homepage, or a new npm package besides elm-test, **stop and ask**.
