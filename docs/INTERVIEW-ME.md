# Interview-me v1

**Date:** 2026-08-22  
**Status:** Implementing — Pinto T-15  
**Tracker:** Pinto [T-15](../.pinto/tasks/T-15.md)  
**Decisions:** Nathan, 2026-08-22 — locked (including hold length, calendar, storage, blocklist, hold cap, required question set); do not reopen

## Job

Interview-me is a **real product** that lets **recruiter agents interview Nathan Sculli**. Agents ask questions against published career facts and, after the recruiter verifies a work email, can request a booking that creates a **tentative Google Calendar hold**.

The first user is recruiter agents interviewing Nathan Sculli — not Nathan practicing.

This product justifies OpenAPI, MCP, and webhooks. Do **not** stub those. Company OAuth is later, not v1.

Contact already public: `nathan@vegasbuckeye.com`. Site: https://scull7.com. Do **not** publish a street address.

## Users

| Actor | Role in v1 |
|-------|------------|
| Recruiter agent | Starts a named session, asks questions, may request verification and a booking |
| Recruiter (human) | Receives a magic link, clicks once; the agent never needs inbox access |
| Nathan | Calendar owner; the Google Calendar connector already exists |

## v1 loop

v1 includes **named sessions** and a **booking request**.

1. The agent **starts a session** with company, role, recruiter name, and work email.
2. The agent **asks questions**. Answers are cited from published facts (`public/resume.json` and public site pages). Refuse anything not in that corpus. No invented career facts.
3. Q&A can stay open **without** verification.
4. To book, the agent **requests a verification email**. Email verify is a human step: the recruiter receives a magic link, clicks once, the agent receives a short-lived book token. The agent never needs inbox access.
5. With that book token, the agent **creates a hold** (start/end) only if the session has **completed the required question set** and the work domain is **under the active-hold cap**. A booking request creates a **tentative Google Calendar hold**.
6. A work email must be verified **before any calendar hold**.

## Auth

- A work email is recorded on session start. Q&A does not require it to be verified.
- A work email must be verified before any calendar hold.
- Email verify is a human step: the recruiter receives a magic link, clicks once, the agent receives a short-lived book token scoped to that session.
- The agent never needs inbox access.
- Company OAuth is later, not v1.

### Work email

Reject common free providers for work email unless allowlisted. Default blocklist (locked):

- gmail
- yahoo
- hotmail
- outlook.com
- icloud

The list **must** be configurable — do not hard-code it forever.

When a hold is created, Nathan receives a hold notification email with an easy one-click way to add to the banned list. Assumption: that email offers both **ban this address** and **ban this domain**. Both links are the default.

## Calendar holds

A booking request creates a **tentative Google Calendar hold**. The Calendar connector already exists for Nathan.

Required before a hold: verified work email, a short-lived book token for that session, a completed required question set (a refusal does not count), and a work domain under the active-hold cap.

Create-hold inputs: start, end, book token. Result: a tentative GCal event. Default hold length is **1 hour**.

Holds go to the **default scull7.com Google Calendar**. Which calendar is used **must** be configurable — do not hard-code it forever.

Creating a hold also sends Nathan the hold notification email described under Auth.

### Active-hold cap

A work domain may have at most **N** active tentative holds at once. Default **N=3**. That cap **must** be configurable — do not hard-code it forever.

The work domain is the domain of the session’s work email.

### Required question set (earn the hold)

Booking / `create_hold` is allowed only after the session has completed a required question set. Refuses do not count as completion.

Default required set (locked, five items):

1. Cited answer on current work (TensorWave / Relay)
2. Cited answer on leadership scale
3. Cited answer on systems depth (Rust / distributed systems)
4. Cited answer on what Nathan wants next
5. Hiring timeline, stated by the recruiter (their fact, not a resume citation)

The required set **must** be configurable — same rule as the free-email blocklist. Do not hard-code it forever.

Items 1–4 are cited answers from the published corpus. Item 5 is the recruiter’s fact, recorded on the session; it is not cited from `resume.json` or public site pages and does not invent a career fact.

## Storage

Sessions, tokens, and holds persist in a **Turso** database. Not Netlify Blobs. Not an unspecified store.

## HTTP / MCP surfaces

Documented behavior, not an implementation. Do **not** add surfaces beyond this list.

### HTTP

| Operation | Behavior |
|-----------|----------|
| Start session | POST. Creates a named session. Inputs: company, role, recruiter name, work email. Optional `callback_url`. |
| Ask question | Cited answer from the corpus, or a refusal if the fact is not published. |
| Request verification email | Sends the magic link to the session’s work email. |
| Verify magic link | Human click. Issues a short-lived book token scoped to that session. |
| Create hold | start/end + book token → tentative GCal event. No hold without a valid token, a completed required set, and a work domain under the cap. |
| Get resume | Published resume facts from the same corpus. |
| Search experience | Search published experience facts from the same corpus. |

OpenAPI at `/openapi.json`. That document is a real contract, not a stub.

### MCP

MCP at `/mcp`. Tools:

| Tool | Behavior |
|------|----------|
| `start_interview` | Same as start session |
| `ask_nathan` | Same as ask question |
| `request_verification` | Same as request verification email |
| `create_hold` | Same as create hold (requires the book token, completed required set, and domain under the cap) |
| `get_resume` | Same as get resume |

No other MCP tools in v1. Verify stays a human magic-link click.

### llms.txt

v1 updates the `/llms.txt` when-to-use copy for this product so agents can tell interview-me (OpenAPI / MCP / webhooks) from the static resume site.

## Webhooks

Optional `callback_url` on the session. Events:

- `interview.completed`
- `booking.requested`

No other event names in v1.

## Out of scope

- Implementing the product in the same change as this spec
- Practice mode
- Live audio / video
- Company OAuth
- Framework extract ([T-14](../.pinto/tasks/T-14.md))
- A second repository
- Publishing a street address
- Invented career facts or answers outside `resume.json` and public site pages
- Stub OpenAPI, stub MCP, or stub webhooks
- Hard-coding the hold cap or the required question set with no configuration

## Open decisions

None remaining from the 2026-08-22 list. Hold length, calendar, storage, the free-email blocklist, the active-hold cap, and the required question set are locked in Auth and Calendar holds.

## In this repo (now)

This note is the durable v1 spec. Implementation is T-15 (Melange Netlify function, Turso, cited Q&A, magic-link verify, tentative GCal hold). Locked decisions stay locked.

Netlify deploy: `emit_artifacts` esbuild-bundles the interview function so Lambda does not import `melange.js` as a package (the edge negotiate re-export is fine on Deno). `netlify.toml` rewrites `/openapi.json`, `/mcp`, and `/interview/*` onto `/.netlify/functions/interview` and keeps those pretty paths in `config.path`.

## Environment

Do not commit secrets. Config fails closed when a required secret is missing (HTTP 503 `missing_env` + the variable name).

| Variable | Role | Default / notes |
|----------|------|-----------------|
| `TURSO_DATABASE_URL` | libSQL / Turso database | Required for sessions, tokens, holds. `libsql://` is rewritten to HTTPS. Set on Netlify site `cv-scull7` for production + deploy-preview (database `interview-me` in org/group `scull7`). |
| `TURSO_AUTH_TOKEN` | Turso auth | Required with the URL. Set on Netlify site `cv-scull7` for production + deploy-preview. |
| `INTERVIEW_MAGIC_LINK_SECRET` | HMAC for magic-link / book / ban tokens | Required before verify or hold. |
| `INTERVIEW_HOLD_CAP` | Active tentative holds per work domain | `3` |
| `INTERVIEW_REQUIRED_QUESTIONS` | Required set (CSV ids or JSON array) | The five locked items |
| `INTERVIEW_FREE_EMAIL_BLOCKLIST` | Comma list | `gmail,yahoo,hotmail,outlook.com,icloud` |
| `INTERVIEW_EMAIL_ALLOWLIST` | Comma list that bypasses the blocklist | empty |
| `INTERVIEW_CALENDAR_ID` | Google Calendar id | `scull7.com` |
| `INTERVIEW_HOLD_DEFAULT_SECONDS` | Default hold length | `3600` (1 hour) |
| `INTERVIEW_MAIL_FROM` / `INTERVIEW_MAIL_TO` | Magic-link From; hold notification To | `nathan@vegasbuckeye.com` |
| `RESEND_API_KEY` (or `INTERVIEW_RESEND_API_KEY`) | Send mail | Required to actually send. This repo had no mail path; Resend HTTP is the smallest real sender. |
| `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET` / `GOOGLE_OAUTH_REFRESH_TOKEN` | Calendar (and optional Gmail later) | Preferred Calendar connector. |
| `GOOGLE_SERVICE_ACCOUNT_JSON` or `GOOGLE_CLIENT_EMAIL` + `GOOGLE_PRIVATE_KEY` | Alternate Calendar auth | Used if OAuth refresh is unset. |
| `INTERVIEW_SITE_URL` | Public origin for magic/ban links | `https://scull7.com` (deploy uses the request/site URL when present) |

Sessions, tokens, and holds use Turso via `TURSO_DATABASE_URL` + `TURSO_AUTH_TOKEN` only. No other store backend. `INTERVIEW_STORE=memory` is not a production switch — deploy-preview and production fail closed to Turso. If either Turso variable is missing, session/verify/hold operations fail closed. A Turso HTTP 401 (invalid JWT) means the token configured on the site is not a valid key for that database — re-issue the token in the Turso UI/CLI and set `TURSO_AUTH_TOKEN` on the Netlify site (do not put the token in git). `/openapi.json` and MCP `initialize` / `tools/list` still load.

## Later

Keep locked decisions. Framework extract remains T-14.
