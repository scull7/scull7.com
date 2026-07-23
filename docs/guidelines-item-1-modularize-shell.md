# Implementation Guidelines — Item 1: Modularize shell + content routing

**For:** context-free implementer  
**Repo:** `/Users/nathansculli/src/scull7.com`  
**Plan ref:** `docs/IMPROVEMENT-PLAN.md` §1  
**Architect date:** 2026-07-18

---

## 1. Goal

Split the monolithic `src/shell.mbt` (~816 lines) into focused sibling MoonBit source files within the **existing single package** (`src/moon.pkg.json`), and isolate buffer-body content routing so that opening a buffer (click or keyboard) reliably swaps main-pane content without callers outside the content-host module needing to know about DOM refs. Preserve `pub fn shell_app`, `load_resume`, and the Vite/`main.mbt` entry so the site behavior stays the same while becoming maintainable.

---

## 2. Non-goals

- Do **not** change visual design, CSS, or `public/resume.json` content (except if a bugfix requires no content change).
- Do **not** implement items 2–5 (a11y, polish, tests suite, vim cmdline redesign) except minimal hooks needed for modularization.
- Do **not** introduce TypeScript or restore the old JS shell.
- Do **not** create multiple MoonBit packages / nested `moon.pkg.json` under `src/` unless you first prove `moon build` works with that layout (today: **one package**, all `.mbt` files flat under `src/`).
- Do **not** attempt a full Luna rewrite of imperative paint if isolation is cleaner; isolation is acceptable and preferred if declarative remount remains unreliable.

---

## 3. Target file layout

MoonBit single package — **all files under `src/`** (flat). Nested dirs without their own `moon.pkg.json` are **not** assumed supported; use **filename prefixes** instead of `src/shell/` packages.

```
src/
  main.mbt                 # KEEP — boot only
  model.mbt                # KEEP — JSON Resume + load_resume
  format.mbt               # KEEP
  buffers.mbt              # KEEP
  moon.pkg.json            # KEEP (trim unused imports if safe)

  # NEW (split from shell.mbt)
  shell_app.mbt            # pub fn shell_app — chrome composition root
  shell_state.mbt          # Mode, shared helpers used by shell (optional thin)
  shell_content.mbt        # content host: body_host, paint_body, open routing API
  shell_commands.mbt       # run_command, open_by_query, palette_items, accept_palette
  shell_keyboard.mbt       # document keydown registration (or keep in shell_app if tiny)
  shell_terminal.mbt       # view_terminal + on_term logic
  shell_palette.mbt        # palette UI nodes only (optional; can stay in shell_app)

  view_home.mbt
  view_experience.mbt
  view_highlights.mbt
  view_skills.mbt
  view_opensource.mbt
  view_code.mbt
  view_relay.mbt
  view_help.mbt
  view_dispatch.mbt        # buffer_content match on BufferKind → views

  shell.mbt                # DELETE after move (or shrink to `pub fn shell_app` re-export only if needed)
```

**Minimum viable split** (if timeboxed — still satisfies plan):

```
src/
  view_*.mbt          # all views + view_dispatch.mbt
  shell_content.mbt   # body host isolation
  shell_app.mbt       # rest of chrome + keyboard + commands + shell_app
  shell.mbt           # removed
```

Prefer the **minimum viable split** first, then further split commands/keyboard if files stay &lt; ~300 lines.

---

## 4. Module boundaries

| File | Owns | Exports (pub only if needed cross-file; same package = all `fn` visible) |
|------|------|--------------------------------------------------------------------------|
| `view_*.mbt` | Pure DOM builders for one buffer kind | `fn view_home(data: ResumeView) -> @dom.DomNode`, etc. |
| `view_dispatch.mbt` | `buffer_content(...)` match | `fn buffer_content(data, buf, term_lines, on_submit) -> @dom.DomNode` |
| `shell_content.mbt` | `body_host`, `term_handler` refs, `paint_body`, wiring open→paint | See §5 API sketch |
| `shell_commands.mbt` | Parse `:cmd`, palette item lists | Called from shell_app / keyboard |
| `shell_app.mbt` | Layout chrome, sidebar, statusline, palette shell, `pub fn shell_app` | **`pub fn shell_app(data: ResumeView) -> @dom.DomNode`** |
| `shell_terminal.mbt` | Terminal view + submit handler body | Used by dispatch + content |
| `main.mbt` | load + `shell_app` only | unchanged contract |
| `model.mbt` | ResumeDoc, ResumeView, map, load | unchanged |

**Shared types** already in `buffers.mbt` (`BufferDef`, `BufferKind`) and `model.mbt` (`ResumeView`). Do not duplicate.

**Helpers** currently in shell (`attr_s`, `pills`, `split_paragraphs`, `mode_label`, `is_mobile`) → move to `shell_app.mbt` or small `shell_util.mbt`.

---

## 5. Content routing strategy (CHOSEN)

### Choice: **Isolated imperative content host** (`shell_content.mbt`)

Keep the working pattern from current `shell.mbt`:

- `body_host: Ref[Element?]` set via Luna `ref_` on `#buffer-body`
- `paint_body()` calls `@dom.render_to(el, node)`
- `open_buffer` updates `active_id` / `focus_idx` then calls `paint_body()`
- `term_handler: Ref[(String) -> Unit]` avoids forward-reference issues with `on_term`

Do **not** reintroduce dual-`show`/epoch hacks unless you prove they work in Playwright first.

### Sketch (MoonBit)

```moonbit
// shell_content.mbt — conceptual

struct ContentHost {
  body_host : Ref[@js_dom.Element?]
  term_handler : Ref[(String) -> Unit]
  active_id : @resource.Signal[String]
  // ... other signals passed in or stored
}

fn paint_body(host : ContentHost, data : ResumeView, term_lines : ...) -> Unit {
  match host.body_host.val {
    None => ()
    Some(el) => {
      let node = match find_buffer(host.active_id.get()) {
        Some(buf) => buffer_content(data, buf, term_lines, fn(s) { (host.term_handler.val)(s) })
        None => @dom.div() <| [@dom.text("Empty buffer")]
      }
      @dom.render_to(el, node)
    }
  }
}

fn body_element(host : ContentHost, data : ResumeView, ...) -> @dom.DomNode {
  @dom.div(
    class="buffer-body",
    id="buffer-body",
    ref_=fn(el) {
      host.body_host.val = Some(el)
      paint_body(host, data, ...)
    },
  ) <| []
}
```

`shell_app` owns signals; either:

- pass signals into content helpers, or  
- keep signals in `shell_app` and only extract `paint_body` + `body_element` + open_buffer’s paint call path into `shell_content.mbt`.

**Important:** After extract, **no** `paint_body` calls from view files. Only `open_buffer` / terminal refresh / initial ref.

### Alternative rejected for this iteration

Declarative keyed remount via dual `show` + epoch — previously flaky in practice for this codebase; only revisit after e2e exists (plan item 4).

---

## 6. Migration steps (ordered)

1. **Baseline verify**
   ```bash
   cd /Users/nathansculli/src/scull7.com
   export PATH="$HOME/.moon/bin:$PATH"
   moon build --target js --release
   npm run build
   ```
   Manually note: click `experience.md` changes body (already fixed on main).

2. **Extract views (behavior-identical)**
   - Create `view_home.mbt` … `view_help.mbt` by cutting `fn view_*` from `shell.mbt`.
   - Create `view_dispatch.mbt` with `buffer_content`.
   - Create `view_terminal` in `shell_terminal.mbt` or `view_terminal.mbt`.
   - Build after each file or after all views.

3. **Extract content host**
   - Move `body_host`, `term_handler`, `paint_body`, and buffer-body `ref_` node builder into `shell_content.mbt`.
   - `open_buffer` stays next to signals (in `shell_app.mbt`) but calls `paint_body`.
   - Build + quick click test.

4. **Extract commands (optional in same PR if clean)**
   - `run_command`, `open_by_query`, `palette_items`, `accept_palette`, `open_palette` → `shell_commands.mbt`.
   - These need access to signals — pass as parameters or keep a `ShellCtx` struct in `shell_app.mbt` / `shell_state.mbt`.

5. **Delete empty `shell.mbt`**
   - Ensure `pub fn shell_app` lives in `shell_app.mbt`.
   - `main.mbt` still calls `shell_app(data)`.

6. **Cleanup**
   - Remove unused `Insert` variant or use it.
   - Remove unused package aliases (`signal`, `event`) from `moon.pkg.json` if still unused.
   - `moon build --target js --release` with 0 errors.

7. **Functional verify** (before handoff)
   ```bash
   npm run build
   npm run preview -- --host 127.0.0.1 --port 4173
   # Playwright or manual:
   # - load /
   # - click experience.md → body contains work experience / TensorWave role bullets
   # - click skills.md → languages (active)
   # - press j/k/Enter if possible
   # - :help via palette if time
   ```

---

## 7. Public API that must not break

| Symbol / entry | Location | Contract |
|----------------|----------|----------|
| `pub fn shell_app(data : ResumeView) -> @dom.DomNode` | was `shell.mbt`, move to `shell_app.mbt` | Same signature |
| `pub async fn load_resume(url : String) -> Result[ResumeView, String] raise` | `model.mbt` | Unchanged |
| `pub fn map_resume` / types `ResumeView`, … | `model.mbt` | Unchanged |
| `main` in `main.mbt` | boot | Still loads `/resume.json` and renders `shell_app` |
| `main.js` | `import "mbt:scull7/site"` | Unchanged |
| `public/resume.json` | data | Unchanged schema |
| CSS classes | `public/styles/*` | Keep class names used by shell (`.buffer-item`, `.buffer-body`, etc.) |

---

## 8. Build / verify commands

```bash
export PATH="$HOME/.moon/bin:$PATH"
cd /Users/nathansculli/src/scull7.com

moon check --target js
moon build --target js --release
npm run build

# optional runtime
npm run preview -- --host 127.0.0.1 --port 4173
# Playwright (playwright may already be devDependency):
# node e2e smoke or manual browser
```

---

## 9. Acceptance checklist

- [ ] `shell.mbt` deleted or ≤ ~150 lines
- [ ] No single new god-file without clear name; prefer files &lt; ~300 lines
- [ ] Views live in separate `view_*.mbt` files
- [ ] Content host / `paint_body` isolated; views never call `paint_body`
- [ ] Click sidebar buffer changes **main body text**, not only tab/status
- [ ] Keyboard open (focus + Enter) still works
- [ ] `moon build --target js --release` succeeds (0 errors)
- [ ] `npm run build` succeeds
- [ ] Site loads: name, summary, buffers list, statusline visible
- [ ] `main.mbt` / `load_resume` / `shell_app` signatures unchanged

---

## 10. Risks and how to avoid them

| Risk | Avoidance |
|------|-----------|
| Forward reference (`on_term` before definition) | Keep `term_handler` Ref pattern from current code |
| Nested package layout breaks build | Stay flat under `src/`; one `moon.pkg.json` |
| Accidental behavior change while moving | Move functions literally first; no refactors in same step |
| `paint_body` forgotten after open | Single `open_buffer` path only paints; grep for `active_id.set` |
| Luna remount regressions | Do not remove imperative host in this item |
| Package-level `using` collisions | Prefer `@dom.` / `@resource.` prefixes like current shell |
| Build cache stale | `touch` changed files; confirm new symbols in `_build/js/release/build/site.js` |

---

## Current code anchors (implementer map)

- Content host today: `shell.mbt` — search `body_host`, `paint_body`, `term_handler`, `ref_=fn(el)`
- Views: `view_home` … `view_help`, `view_terminal`, `buffer_content`
- Public entry: `pub fn shell_app` ~line 319
- Boot: `main.mbt` calls `shell_app(data)`

---

## Definition of done

Guidelines implemented, build green, buffer body swaps on click, architecture matches §3–§5. Hand off to architect verification and QA.
