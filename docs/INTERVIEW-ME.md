# Interview-me v1

**Date:** 2026-08-22  
**Status:** Planned — do not implement the product in this change  
**Tracker:** Pinto [T-15](../.pinto/tasks/T-15.md)  
**Decisions:** Nathan, 2026-08-22 — locked; do not reopen

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
5. With that book token, the agent **creates a hold** (start/end). A booking request creates a **tentative Google Calendar hold**.
6. A work email must be verified **before any calendar hold**.

## Auth

- A work email is recorded on session start. Q&A does not require it to be verified.
- A work email must be verified before any calendar hold.
- Email verify is a human step: the recruiter receives a magic link, clicks once, the agent receives a short-lived book token scoped to that session.
- The agent never needs inbox access.
- Company OAuth is later, not v1.

### Work email

Reject common free providers for work email unless allowlisted. Default blocklist (open list Nathan can edit):

- gmail
- yahoo
- hotmail
- outlook.com
- icloud

## Calendar holds

A booking request creates a **tentative Google Calendar hold**. The Calendar connector already exists for Nathan.

Required before a hold: verified work email and a short-lived book token for that session.

Create-hold inputs: start, end, book token. Result: a tentative GCal event.

Hold duration, which calendar, and storage are unset — see Open decisions.

## HTTP / MCP surfaces

Documented behavior, not an implementation. Do **not** add surfaces beyond this list.

### HTTP

| Operation | Behavior |
|-----------|----------|
| Start session | POST. Creates a named session. Inputs: company, role, recruiter name, work email. Optional `callback_url`. |
| Ask question | Cited answer from the corpus, or a refusal if the fact is not published. |
| Request verification email | Sends the magic link to the session’s work email. |
| Verify magic link | Human click. Issues a short-lived book token scoped to that session. |
| Create hold | start/end + book token → tentative GCal event. No hold without a valid token. |
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
| `create_hold` | Same as create hold (requires the book token) |
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

## Open decisions

Unset. Do not treat a guess as locked.

| Decision | Notes |
|----------|--------|
| Hold duration | How long a tentative hold lasts / default meeting length |
| Which calendar | Which of Nathan’s Google calendars receives the hold |
| Storage | Where sessions, tokens, and holds persist |
| Free-email blocklist | Default reject list above; Nathan can edit the list and the allowlist |

## In this repo (now)

This note is the durable v1 spec. Do **not** implement interview-me in this change.

## Later (T-15)

Implement interview-me v1 against this spec. Keep the locked decisions. Leave the open decisions for Nathan.
