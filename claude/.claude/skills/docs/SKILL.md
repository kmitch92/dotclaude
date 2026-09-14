---
name: docs
description: Documentation and ADR rules and preferences. Read by workers when a task brief lists this file.
disable-model-invocation: true
---

## Seven pillars (apply to any doc)

- Value-first: open with why it matters, not what it is.
- Scannable: clear heading hierarchy, bullets, code blocks, tables, whitespace.
- Progressive disclosure: overview first, details after, deep dives linked not inlined.
- Problem-oriented: organize by the reader's task ("How to...") over API reference order.
- Show-don't-tell: a runnable, copy-pasteable example with realistic data beats a paragraph of description.
- Connected: link related docs, prerequisites, source code, "see also".
- Actionable: end with a concrete next step or copy-paste command.

## Documentation hierarchy

- Project `CLAUDE.md` is the primary output for any change — update it with technical context and learnings.
- Update `README.md` only if the user-facing overview actually changed.
- Never create a new `.md` file without explicit user approval (including `NEW_FEATURES.md`, `FIXES_APPLIED.md`, `IMPLEMENTATION_NOTES.md`, `ARCHITECTURE.md`, `PATTERNS.md`).

## Code documentation

- Document why a decision was made, not what the code obviously does.
- JSDoc on public/exported functions: purpose, `@param`, `@returns`, `@throws`, `@example` — not every internal helper.
- Use a `.CLAUDE.md` suffix for AI-agent-facing docs, WIP notes, TODO tracking.
- An `ARCHITECTURE.CLAUDE.md`, if present, covers purpose, components, dependencies, patterns, constraints.

## ADRs (architecture decision records)

- Write one for a "one-way door" decision: hard to reverse, costly to undo, affects multiple systems/teams, or creates technical debt if wrong.
- Test: 3+ "yes" means write one — hard to reverse? multiple alternatives evaluated with real trade-offs? constrains future architectural decisions? a future developer would wonder why? not already covered by existing guidelines?
- Needs: context, the decision (implementable and verifiable), at least two rejected alternatives with reasons, consequences (positive/negative/neutral), an implementation note.
- Status values: Proposed, Accepted, Superseded by ADR-N, Deprecated.
- Accepted ADRs are immutable — never edit content, only status. A changed decision gets a new ADR that supersedes the old one.

## Quality bar

- Reject a doc if any pillar fails outright, if there's a Critical issue (missing value statement, no working example), or no clear next step.
- "Needs improvement": some pillar gaps but none fail outright — still shippable, flag the gaps.
