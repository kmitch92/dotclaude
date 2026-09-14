---
name: writing-great-skills
description: Reference for writing and editing skills well — the vocabulary and principles that make a skill predictable
disable-model-invocation: true
---

A skill makes a stochastic system predictable: same process every run, not necessarily the same output. Every rule below serves that.

## Body length

Every skill file body has a 500-word cap, this one included. If a skill needs more, split the extra into supporting files, read only when needed (see Information hierarchy).

## Invocation

- **Model-invoked**: keep a description. The agent fires the skill on its own, and other skills can reach it. Costs context load — the description sits in context every turn.
- **User-invoked**: set `disable-model-invocation: true`. Only typing the name invokes it — zero context load, but the user must remember it exists.

Pick model-invocation only when the agent or another skill must reach it unprompted; otherwise user-invoked. When user-invoked skills outgrow memory, add a router skill listing the rest.

For a model-invoked description: front-load the leading word; one trigger per branch, never a restated synonym; nothing but triggers plus a "used by…" reach clause — skip identity already in the body.

## Information hierarchy

Material sits at the level matching how immediately it's needed:

1. **In-skill step** — an ordered action in `SKILL.md`, ending on a completion criterion: checkable, and where it matters, exhaustive ("every file accounted for", not "make a list"). A vague criterion invites stopping early.
2. **In-skill reference** — a definition, rule, or fact consulted on demand, not in sequence. A skill can be entirely this.
3. **External reference** — a separate file, reached by a pointer, loaded only when it fires. How a skill stays under the cap without losing material it needs.

Push too little down and the top bloats past the cap; push too much and the agent misses material mid-run. Keep a concept's definition, rules, and caveats together.

## When to split into a separate skill

- **By invocation** — a new model-invoked skill, when a distinct trigger must fire independently. Costs a new always-loaded description; must earn it.
- **By sequence** — split a long run of steps so the ones still ahead don't tempt the agent to rush the current one.

## Pruning

Keep each fact in one place. Check every line still holds, then test each sentence: does it change behavior versus the default? If not, delete it — don't just trim it.

## Leading words

A leading word is a short, already-understood term (e.g. "tight loop") the agent thinks with, standing in for a longer restated idea. Repeating it anchors execution in the body, and invocation in the description, more reliably than a fresh explanation each time.

## Failure modes

- **Premature completion** — a step ends before it's genuinely done. Fix the completion criterion first; split by sequence only if that's not enough.
- **Duplication** — the same fact stated more than once.
- **Sediment** — stale content accumulating because removing feels risky.
- **Sprawl** — too long even with every line live and unique; fix via the information hierarchy.
- **No-op** — a line the agent would do by default anyway.
