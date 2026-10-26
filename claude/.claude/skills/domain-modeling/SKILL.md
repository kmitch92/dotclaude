---
name: domain-modeling
description: This skill builds and sharpens the domain model of a project: the glossary terms and the architecture decision records (ADRs)
disable-model-invocation: true
---

# Domain Modeling

Actively build and sharpen the domain model of the project. Do this while you build the system. Domain modeling is an active discipline. You challenge terms. You invent edge-case scenarios. You write the glossary and decisions down the moment they crystallise. To read `CONTEXT.md` for vocabulary is not this skill. This habit is small. Each skill could follow it. This skill applies when you change the model. It does not apply when you only read the model.

## File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` is there at the root, the repo has many contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Make files only when you have something to write. If `CONTEXT.md` is not there, make one when you resolve the first term. If `docs/adr/` is not there, make it when the first ADR is necessary.

## During the session

### Challenge against the glossary

When the user uses a term that is different from the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose an accurate canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When the user speaks about domain relationships, stress-test them with specified scenarios. Invent scenarios that find edge conditions and push the user to be accurate about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check if the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When you resolve a term, update `CONTEXT.md` right there. Do not batch these up. Capture them as they occur. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

`CONTEXT.md` must be totally without instructions on how you do things. Do not apply `CONTEXT.md` as a spec or a scratch pad. Do not apply it as a position for decisions on how you do things. `CONTEXT.md` is a glossary and nothing else.

### Offer ADRs sparingly

Only offer to make an ADR when all three are correct:

1. **Hard to change back** — the cost of a subsequent change is meaningful
2. **A surprise without context** — a future reader will wonder "why did they do it this way?"
3. **The result of an actual trade-off** — there were actual alternatives and you picked one for specified causes

If one of the three is not there, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).
