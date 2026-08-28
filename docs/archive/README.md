# Archive — historical documents

Everything in this directory is **historical**. It is kept for provenance and is
not implementation guidance.

The live stack is **Elm 0.19.1** for the UI and **Melange 7 (OCaml → JS)** for
ports, build tooling, the crawlable-HTML CLI, and the e2e runners. See
[`README.md`](../../README.md) for how to build it and
[`docs/ROADMAP.md`](../ROADMAP.md) for where it is going.

| Document | Era | Why it is here |
|---|---|---|
| [`IMPROVEMENT-PLAN.md`](IMPROVEMENT-PLAN.md) | MoonBit + Luna | Top-5 plan written against a stack the site no longer uses |
| `guidelines-item-1…5-*.md` | MoonBit + Luna | Per-item implementation guidance for that plan |
| `verification-item-1…5.md` | MoonBit + Luna | Verification notes for that plan |

Their **intent** mostly survived — modularize the shell, a11y and focus, visual
polish, automated tests, vim UX — but it was re-planned against the current
stack and now lives on the Pinto board (`.pinto/tasks/`), where T-20 through
T-25 carried it out.

**Do not implement from anything in this directory.** If something here still
looks worth doing, raise it as a Pinto card against the current stack first.
