scull7.com — STATUS DASHBOARD CONTRACT (in-harness UI)

You are the agent doing the work in this project. This file tells you how to keep
its status view honest while you work. It is machine-facing: it assumes you already
know the project, and it never explains what a dashboard is.

PARAMETERS (resolved for this project)
  PROJECT_NAME     = scull7.com
  REPO             = scull7.com (git root)
  REFRESH          = `just status`
  PUBLISH          = `just status-html`
  DASHBOARD_FILE   = docs/status-dashboard.html
  CONFIG           = dashboard.config.json
  SOURCES          = see SOURCES below
  CHECKPOINTS      = see CHECKPOINTS below

SOURCES OF TRUTH (read-only; the dashboard renders these, it never replaces them)
  Board          : `pinto list --json` — a JSON array of PBIs with id, title, status.
                   Installed CLI: pinto-cli 0.4.3 (`pinto --version`).
                   Shared `.pinto/config.toml` must not contain `[tui.key_bindings]`
                   (personal bindings belong in $XDG_CONFIG_HOME/pinto/config.toml).
  Tracking file  : none
  Narrative log  : none (no progress.md)
  Status words   : done   = done
                   active = in-progress, review
                   everything else counts as todo
  If pinto is missing or `pinto list --json` fails, REFRESH exits 2. Do not fall
  back to features.json or to hand-parsing `.pinto/tasks/*.md`. Never invent PBIs.
  Never hand-edit `.pinto/tasks/*.md` — all board writes go through the pinto CLI.

CHECKPOINTS (refresh at each; never batch them to the end)
  After the pre-flight read of `pinto list --json`.
  After every `pinto move` (todo → in-progress → review → done).
  After `pinto add` / `pinto edit` / `pinto dep add` when the user authorized writes.
  At the acceptance-criteria evidence gate, before allowing done.
  At a PBI completion record, before advancing to the next PBI.
  The rule behind the list: refresh immediately after the underlying state changes,
  because the window between the change and the refresh is the window in which the
  dashboard is lying.

RULES
  - Generated, never hand-written. Run REFRESH or PUBLISH. Do not hand-author
    DASHBOARD_FILE, and do not edit it to say something the sources do not.
  - The dashboard is a view, not a record. When it disagrees with the board, the
    board wins and the disagreement is itself a finding worth reporting.
  - Never show work as complete before its completion evidence exists.
  - A stale dashboard is worse than none. If you cannot refresh it, say so in the
    same place you record progress, and say why.
  - Commit DASHBOARD_FILE only at phase or PBI boundaries, not on
    every refresh, so the diff stays meaningful.
  - Report counts you read, never counts you expect. If REFRESH shows zeros where
    you believed there was work, that is a defect in the sources or the config —
    investigate it, do not narrate around it.
  - Leave T-8 (nathansculli.com NXDOMAIN) as the CLI reports it. Do not change
    T-25 / #38 product scope from this harness wiring.

WHEN THE NUMBERS LOOK WRONG
  A dashboard reporting "0 in progress" during active work usually means the status
  vocabulary does not match the tracker's. Check CONFIG's status words against the
  literal strings the board emits before concluding the work is untracked.
  Pinto emits `in-progress` (hyphen). The config maps that string, and classify()
  also folds `-` / `_` / space so a missed hyphen still matches. `review` is an
  in-flight column with zero items on the board that proved this contract; it is
  mapped active on purpose, not left to become todo by omission.

FIRST ACTION
  Run REFRESH now and state the current counts before doing anything else. That is
  your baseline, and every later claim of progress is measured against it.

PROOF (2026-08-28, against live `pinto list --json`)
  board says:      done=23   in-progress=1   todo=2
  dashboard says:  ✔ completed 23   ▶ in progress 1   ○ todo 2
  reconciles: 23 == 23, and 1 + 2 == 3
  T-8 left in-progress as the CLI reported. T-25 left todo.

## Unresolved questions

- none
