# Implementation Guidelines — Item 4: Automated tests

> **ARCHIVED — historical, not live guidance.**
> This document is from the MoonBit/Luna era of scull7.com and describes a stack the
> site no longer uses. The live stack is **Elm 0.19.1 for the UI and Melange 7
> (OCaml → JS) for ports, build tooling, and e2e** — see [`README.md`](../../README.md)
> and [`docs/ROADMAP.md`](../ROADMAP.md). Kept for provenance only; do not implement
> from it.

**Repo:** `/Users/nathansculli/src/scull7.com`  
**Plan:** `docs/archive/IMPROVEMENT-PLAN.md` §4

---

## 1. Goal

Add unit tests (`moon test`) for pure format/map helpers and a plain-JS Playwright e2e suite that fails if buffer body does not change on sidebar click. Document scripts in `package.json` + README. No TypeScript.

---

## 2. Non-goals

- Full axe suite / visual regression CI
- Testing every buffer demo
- Item 5 vim cmdline redesign
- GitHub Actions required (optional thin workflow OK)

---

## 3. Files

| File | Role |
|------|------|
| `src/format_wbtest.mbt` | whitebox: `format_date`, `slugify`, … |
| `src/model_wbtest.mbt` | whitebox: minimal `ResumeDoc` → `map_resume` |
| `src/buffers_wbtest.mbt` | whitebox: `find_buffer`, `code_sample` |
| `e2e/navigation.mjs` | Playwright: home, click experience, palette `:` |
| `e2e/run.mjs` or npm scripts | start preview, run tests, exit code |
| `package.json` | `test`, `test:unit`, `test:e2e` |
| `README.md` | How to run tests |
| `docs/archive/verification-item-4.md` | After implement |

**Fixture approach:** Prefer constructing `ResumeDoc` structs in MoonBit (no filesystem in JS tests) rather than loading `src/testdata/*.json` unless `@json.parse` of a string literal is clean. Optional: embed a small JSON string and `@json.from_json(@json.parse(...))` if that API is available.

---

## 4. Unit tests

```moonbit
// format_test.mbt
test "format_date month year" {
  assert_eq(format_date("2024-04"), "April 2024")
}
test "format_date_range present" {
  assert_eq(format_date_range("2024-04", ""), "April 2024 – Present")
}
test "slugify company" {
  assert_eq(slugify("TensorWave Inc."), "tensorwave-inc")
}
```

```moonbit
// model_test.mbt
test "map_resume maps name and work" {
  let doc : ResumeDoc = { /* minimal fields */ }
  let v = map_resume(doc)
  assert_eq(v.profile.name, "Test User")
  assert_eq(v.experience.length(), 1)
  assert_eq(v.experience[0].role, "Engineer")
}
```

Run: `moon test --target js`

---

## 5. E2E (plain JS)

`e2e/navigation.mjs`:

1. Launch chromium
2. `page.goto(BASE_URL)` default `http://127.0.0.1:4173`
3. Wait `#vim-root`, assert hero name "Nathan Sculli"
4. Click buffer item `experience.md` → body contains "WORK EXPERIENCE" or "TensorWave"
5. Click `skills.md` → body changes (not still only experience)
6. Press `:` → `#palette-input` is activeElement; Esc closes
7. Exit 1 on failure

`package.json`:

```json
"test:unit": "moon test --target js",
"test:e2e": "node e2e/navigation.mjs",
"test": "npm run test:unit && npm run build && npx vite preview --host 127.0.0.1 --port 4173 & sleep 1 && npm run test:e2e; code=$?; pkill -f 'vite preview.*4173' || true; exit $code"
```

Prefer a small `e2e/run.mjs` that spawns preview, waits for ready, runs tests, kills preview — cleaner than shell `&`.

---

## 6. Acceptance

- [ ] `moon test --target js` green
- [ ] E2E fails if body does not change on experience click (assert deliberately)
- [ ] README has Testing section
- [ ] `npm test` (or documented two-step) works
- [ ] Build still green

---

## 7. Risks

| Risk | Mitigation |
|------|------------|
| `is-main` package complicates tests | Tests colocated in same package usually work |
| Playwright browsers missing | `npx playwright install chromium` once; document |
| Preview race | poll `/` until 200 |
