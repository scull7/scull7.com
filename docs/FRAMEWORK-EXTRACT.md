# Extract the site framework as public open source

**Date:** 2026-08-22  
**Status:** Planned — do not extract or publish in this change  
**Tracker:** Pinto [T-14](../.pinto/tasks/T-14.md)

## Intent

The reusable site framework should become a **publishable open-source project** with a **public source repository**. **scull7.com** (this website: personal resume, private facts) stays **private** and consumes that framework as a dependency.

| Piece | Visibility | Role |
|-------|------------|------|
| Framework | Public source repo | Elm vim/galaxy shell, Melange ports + crawlable inject, Accept negotiation, agent-readiness surface |
| scull7.com | Private | Nathan’s content; depends on the framework |

## In this repo (now)

This note is the durable plan. Do **not** create a second GitHub repository and do **not** publish a package from this change.

## Later (T-14)

1. Extract the reusable framework (Elm shell, Melange ports/inject, Accept negotiation, agent surfaces) into a public repo.
2. Keep scull7.com private.
3. The private site consumes the public framework as a dependency.

Public source for the framework; private site for Nathan’s content.
