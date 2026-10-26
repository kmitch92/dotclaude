---
name: docs
description: Documentation and ADR rules and preferences. Workers read this file when a task brief names it.
disable-model-invocation: true
---

## Seven pillars (apply to any doc)

- Value-first: open with why it is material, not what it is.
- Scannable: a clear heading hierarchy and bullets, code blocks and tables, and whitespace.
- Disclosure in layers: show the overview first, then the instruction, then connect to deep dives, but never mark a deep dive inline.
- Problem-oriented: organize by what the reader wants to do ("How to..."), not by the method sequence of an API manual.
- Show not tell: a runnable, copy-paste example with realistic data beats a paragraph of description.
- Connected: connect to related docs and prerequisites, to source code, and to "see also" notes.
- Actionable: end with a concrete next step or copy-paste command.

## Documentation hierarchy

- Project `CLAUDE.md` is the primary output for each change — update it with technical context and learnings.
- Update `README.md` only if the user-facing overview changed.
- Never make a new `.md` file without explicit user approval (including `NEW_FEATURES.md`, `FIXES_APPLIED.md`, `IMPLEMENTATION_NOTES.md`, `ARCHITECTURE.md`, `PATTERNS.md`).

## Code documentation

- Document why someone made a decision, not what the code does.
- JSDoc on public/exported functions: purpose, `@param`, `@returns`, `@throws`, `@example` — not each internal helper.
- Use a `.CLAUDE.md` suffix for AI-agent-facing docs, WIP notes, TODO tracking.
- An `ARCHITECTURE.CLAUDE.md`, if one is there, includes the purpose and the components, the dependencies and the patterns, and the constraints.

## ADRs (architecture decision records)

- Write one for a "one-way door" decision: hard to back out of, costly to redo, with an effect on many systems or teams, or likely to cause technical debt if incorrect.
- Test: three or more answers of "yes" mean write one.
  - Is it hard to back out of?
  - Did the team weigh many alternatives, with their own trade-offs?
  - Does it limit a future decision?
  - Will a future teammate want to know why?
  - Is it covered by a guideline now?
- State the context first.
  - Write the decision so a team can both build and check it.
  - State two or more rejected alternatives, with the cause for each.
  - State the result of each, good, bad, or neutral, and state how to build it.
- Status values: Proposed, Accepted, Superseded by ADR-N, Deprecated.
- An accepted ADR cannot change: never edit the content, only the status, since a new decision gets a new ADR that supersedes the first one.

## Quality bar

- Reject a doc if one pillar fails outright, for example a careful issue with no value statement, no working example, or no clear next step.
- "Needs improvement": it has some pillar weak points but none fail outright, so this doc can ship, but flag the weak points.
