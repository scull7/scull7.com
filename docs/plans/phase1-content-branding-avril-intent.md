# AVRIL Intent — Phase 1 Content + Branding/SEO

**Status:** Shipped in-repo ([PR #5](https://github.com/scull7/scull7.com/pull/5), merged 2026-08-21). Human T-6/T-7/T-8 still open.  
**Date:** 2026-08-13 (intent); 2026-08-21 (ship)  
**Workspace:** `/Users/nathansculli/src/scull7.com`  
**Live:** https://scull7.com  
**SoT:** `public/resume.json` (JSON Resume)

Historical AVRIL lock. Do not treat as a live execution backlog — Pinto is the board.

### Ship notes (do not rewrite the lock below)

- In-repo PBIs T-1–T-5, T-9, T-10 executed via AXEL; merged in PR #5.
- **Philosophy (decision #8) superseded 2026-08-21:** human — treat as internal documentation. No `philosophy.md` buffer; no `philosophy` field on public `resume.json` (`675b2fb`).
- Remaining: T-6 GitHub website, T-7 X website, T-8 leave `nathansculli.com` NXDOMAIN.

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
| Board | **Pinto is source of truth.** Board: `.pinto/` (initialized 2026-08-13; project key `T`). Create/revise via `pinto add` / `pinto edit` / `pinto dep add`. `pinto automate --plan … --dry-run --json` before multi-step writes. |
| Blessed output | Pinto board + `docs/plans/phase1-content-branding-avril-blessed-backlog.md` (summary only; do not fork a second tracker) |
| ID scheme | Pinto-assigned (`T-1`, `T-2`, …). Stable across revise cycles. |
| Size | Small vertical slices. Reviewable in one short pass. Split mixed outcomes. |

This repo has **no harness board, no `features.json`.** Do not invent a second tracker.

---

## Intent (one paragraph)

Make scull7.com **complete and frictionless for sharing** without diluting the vim/terminal product: refresh resume content (TensorWave context, crossr-skills, ferro-wg, tightened summary, short philosophy), add in-aesthetic discoverability (last-updated, `:mail`, new buffer), and finish share/branding (OG/JSON-LD, profile URLs). `nathansculli.com` is retired, not restored. Agents execute in-repo this week after blessing; human PBIs are checklists with step-by-step instructions.

---

## Locked human decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Slice | **Content + branding/SEO only** |
| 2 | Horizon | **Agents this week** (size cap, not a calendar) |
| 3 | Aesthetic | **Terminal-first; small in-aesthetic additions OK** |
| 4 | Outside repo | **In plan.** Human PBIs must include execution instructions. |
| 5 | TensorWave | Keep role/IC/Relay lines. Add **employer context**: Series B **$350M** at **$1.55B** post-money, AMD GPU cloud. **No** 10k GPUs, site names, or “I raised this.” |
| 6 | Projects | **crossr-skills first** (marketing site primary, docs secondary) + **new buffer**. **ferro-wg** next. Keep cents / ReasonML set / Relay. **No velumobex.** |
| 7 | Summary | Draft A below. Polish wording, **not facts.** Valuation stays in **work** highlights, not summary. |
| 8 | Philosophy | Short `philosophy.md` buffer + JSON so a later PDF can reuse it. Not in summary. Not a sermon. |
| 9 | Contact | `:mail` → `mailto:nathan@vegasbuckeye.com?subject=scull7.com`. No calendar. |
| 10 | Old domain | **Retire.** Do not restore DNS. Fix GitHub + X only. |
| 11 | Education | **Out of this slice.** Keep YSU + CCNA as-is. |

---

## Authorized copy

### Summary (draft A — facts frozen)

> Director of Engineering at TensorWave and primary IC on Relay, the control plane behind the largest AMD-based GPU clouds.
>
> Twenty years as a builder-leader across AI infrastructure, financial services, data platforms, manufacturing, and SaaS. I scale orgs (100+ engineers over a career) and still ship the hard systems — Rust, OCaml, ReasonML, Haskell, JavaScript.
>
> Founder/CTO of three ventures.

`basics.label` may stay `Builder-leader · 20+ years · Rust · Distributed Systems` unless a PBI proves a one-line change is required for OG consistency.

### TensorWave work highlight (add, do not replace existing IC/leadership bullets)

Authorized public facts (company blog + WSJ, Jun 2026):

- TensorWave raised **$350M Series B** at a **$1.55B** post-money valuation
- AMD-powered / AMD-exclusive AI cloud (employer context)

Do **not** add: GPU counts, data-center locations, customer names, internal Relay architecture, or unpublished metrics.

### Philosophy (tone lock; generator may tighten)

> Industrial MES → financial HSM → GPU-cloud control planes. Same habit: isolate effects, keep the core pure, measure the line.
>
> Agents get the same treatment: AVRIL plans, AXEL executes, nothing ships unblessed. crossr-skills is that discipline made public.

Christian / Father stays on GitHub bio and crossr-skills positioning. **Not** in `basics.summary`.

### Project one-liners (public)

| Project | Primary URL | Secondary | One-liner |
|---|---|---|---|
| crossr-skills | https://scull7.github.io/crossr-skills/ | https://github.com/scull7/crossr-skills · docs `/docs/` | Agent skills + harness for long-running coding agents (“forged in the Cross”) |
| ferro-wg | https://github.com/scull7/ferro-wg | — | Rust WireGuard client with TUI and swappable backends (boringtun, neptun, gotatun) |

Bump `meta.lastModified` when resume content changes. Surface it in-aesthetic (statusline and/or home help-strip). Do not invent a last-modified if the file was not actually updated.

---

## In scope (authorized outcomes)

AVRIL must cover these outcomes. It authors the PBI split; it must not drop an outcome or add a new product direction.

**In-repo (agent-executable after AXEL is authorized):**

1. **Content sync** in `public/resume.json`: summary A, TensorWave context highlight, crossr-skills + ferro-wg projects, philosophy field, `meta.lastModified`.
2. **crossr-skills buffer** in the terminal catalog; home/OSS views pick up new projects from JSON (JSON remains SoT).
3. **`:mail`** command + palette/help listing.
4. **Last-updated** indicator tied to `meta.lastModified`.
5. **SEO / share:** schema.org `Person` JSON-LD; confirm OG/Twitter tags; OG image that scrapers accept (existing `public/og.svg` may need a PNG sibling — decide in a PBI, do not add a marketing landing page).
6. **Link audit** of URLs already on the site (LinkedIn, GitHub, crates, project URLs). Fix only what is broken or still points at `nathansculli.com`.
7. **Docs hygiene for this slice only:** this intent + blessed backlog path. Do **not** rewrite `docs/ROADMAP.md` or archive MoonBit docs unless a one-line pointer prevents agent confusion.

**Human PBIs (instructions required, not “update your profiles”):**

8. **GitHub** profile Website → `https://scull7.com` (currently `www.nathansculli.com`). Include exact settings path + suggested API command if applicable.
9. **X** `@scull7` website → `https://scull7.com`. Include exact settings path.
10. **Retire `nathansculli.com`:** explicit “do nothing / do not restore DNS.” Note NXDOMAIN is the desired end state.

Each human PBI `acceptance_criteria` must be checkable by the human in <5 minutes.

---

## Explicit cuts (do not bless these)

- Hybrid / print / `:print` / `:traditional` / PDF export
- Split `Main.elm`, elm-test, GitHub Actions, Netlify opam-cache hardening
- Hash/path routing, noscript SSR, blog / writing surface
- Live GitHub activity, calendar/booking links
- velumobex, unpublished TensorWave internals
- Restore or redirect `nathansculli.com`
- Education rewrite
- Light theme, PWA, analytics, i18n
- Internal `docs/ROADMAP.md` Phases 0.2–5 except as listed above
- New chrome that reads as a second, non-terminal site
- Third-party dependencies (needs a fresh human yes)

---

## Current baseline (do not rediscover from stale docs)

| Fact | Reality 2026-08-13 |
|---|---|
| Stack | Elm 0.19.1 + **Melange 7** + Vite. Not ReScript. Not MoonBit. |
| HEAD | `main` @ `14ca301` (PR #3 merged). Clean working tree. |
| Last OpenCode stop | AVRIL wrote `docs/ROADMAP.md`; AXEL shipped Melange; **no blessed backlog** for this slice. |
| `Main.elm` | 1135 lines — **out of scope** to split. |
| OG | `index.html` has og/twitter meta; `public/og.svg` exists. No JSON-LD. |
| Commands | `:help :ls :q :e :open :terminal :relay`. No `:mail`. |
| Buffers | README, experience, highlights, skills, opensource, cents.rs, bs_result.re, relay.rs, relay-viz, terminal, help.txt |
| GitHub `blog` | `www.nathansculli.com` |
| `nathansculli.com` | NXDOMAIN |
| `resume.json` `lastModified` | `2026-07-12T00:00:00` (stale) |

`docs/IMPROVEMENT-PLAN.md` and `docs/ROADMAP.md` describe older stacks / a larger platform roadmap. **This intent supersedes them for the authorized slice.**

---

## Constraints for every PBI

- JSON Resume stays the source of truth. Views map data; they do not hard-code career facts.
- Terminal aesthetic stays. Additions look like vim (command, buffer, statusline), not marketing widgets.
- Small PRs after execution is authorized. Planning must not assume a mega-diff.
- No new facts. If a number or URL is not in this file or already in `resume.json`, leave it out.
- Human items are first-class PBIs with runbooks, not a footnote.
- Open `notes` must be empty or human-accepted before final BLESS.

---

## Suggested slice shape (guidance only — Generator authors PBIs)

Prefer demoable vertical slices, for example:

- Content: resume.json + views that already render projects/summary
- Buffer: crossr-skills catalog entry + help/palette
- Command: `:mail` + help
- Share: JSON-LD + OG image decision + last-updated
- Human: GitHub runbook, X runbook, domain-retire note

Do not emit one god-PBI. Do not emit pure-layer tickets (“touch CSS”, “edit Elm”) with no user-visible outcome.

---

## AVRIL stop condition

When every active PBI has fresh PO `BLESS` + QA `BLESS` + CTO `BLESS`:

1. Write `docs/plans/phase1-content-branding-avril-blessed-backlog.md` (Blessed Backlog Summary + full portable PBIs).
2. **Stop.** Do not invoke AXEL. Do not edit `src/` or `public/resume.json`.
3. Tell the human: planning complete; authorize AXEL to execute.

---

## Explicitly unresolved (none)

All product questions for this slice were closed with the human (2026-08-13). If AVRIL finds a new ambiguity that changes public claims or visual identity, **stop and ask**. Do not invent strategy.
