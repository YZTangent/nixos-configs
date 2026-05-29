---
name: adr
description: Create, review, and manage Architecture Decision Records that capture load-bearing design decisions with context, trade-offs, and rationale. Use when discussing architectural choices, rejecting alternatives with non-obvious reasons, or reviewing past decisions that affect the current work.
---

# Architecture Decision Records

ADRs capture decisions that are hard to reverse, surprising without context, or the result of real trade-offs. They live in `docs/adr/` with sequential numbering (`0001-slug.md`, `0002-slug.md`).

## When to offer an ADR

All three must be true:

1. **Hard to reverse** — changing your mind later costs meaningful time/money
2. **Surprising without context** — future readers will wonder "why did they do it this way?"
3. **Result of a real trade-off** — genuine alternatives existed and you picked one for specific reasons

Skip if: easy to reverse (you'll just reverse it), obvious (nobody will wonder), or no real alternative existed.

### What qualifies

- Architectural shape (monorepo, event-sourced write model)
- Integration patterns between contexts (domain events vs sync HTTP)
- Technology choices with lock-in (database, message bus, auth provider)
- Boundary and scope decisions (what each context owns)
- Deliberate deviations from the obvious path (manual SQL instead of ORM)
- Constraints invisible in code (compliance, SLAs)
- Rejected alternatives where the rejection is non-obvious

## Creating an ADR

1. Scan `docs/adr/` for the highest existing number, increment by one
2. Write using the format in [ADR-FORMAT.md](ADR-FORMAT.md)
3. Save to `docs/adr/` in the relevant project

## Reviewing ADRs before work

When starting work on a feature or bugfix, read ADRs that touch the area. If your implementation contradicts an existing ADR, surface it explicitly before overriding.

## Superseding ADRs

When a decision is revisited, update the old ADR's status frontmatter to `superseded by ADR-NNNN` and create a new ADR documenting the new decision and why the old one no longer applies.
