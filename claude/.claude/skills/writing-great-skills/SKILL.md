---
name: writing-great-skills
description: Give the vocabulary and the principles that make a skill predictable. Workers use this file when they write or edit a skill.
disable-model-invocation: true
---

A skill makes a stochastic system predictable, and each rule below serves that goal, since each run follows the same process, though not always the same output.

## Body length

Each skill file body has a limit: 500 words, and this file counts too. A skill can use a supporting file for more words, but read that file only when it is necessary (see Information hierarchy).

## Invocation

- **Model-invoked**: keep a description, since the agent fires the skill on its own, and a different skill can also use it, with no prompt.
- Model-invocation costs a context load: the description sits in context on each turn.
- **User-invoked**: set `disable-model-invocation: true`, so only typing the name invokes it.
- User-invocation has no cost in context load, but the user must remember the skill.

Pick model-invocation only when the agent or a different skill must use it with no prompt, and otherwise pick user-invoked. When there are too many user-invoked skills for memory, add a router skill that shows the remaining skills.

For a model-invoked description, put the leading word first, give one cue for each branch, and never restate a synonym. Give only cues, plus a clause that names who else uses the skill, and skip identity, since the body gives it elsewhere.

## Information hierarchy

Material sits at the level that fits when the agent must use it:

1. `In-skill step`: a step, in sequence, in `SKILL.md`, that ends on a clear stopping point.
2. `In-skill reference`: a definition, a rule, or a fact, read only when the agent uses it.
3. `External reference`: a file apart from `SKILL.md`, reached by a pointer, read only when it fires.

A stopping point must be checkable, and where this applies, it also names each condition explicitly, for example "each file accounted for," not "make a list." A stopping point with no clear meaning invites the agent to stop before the work is done.

The second type does not follow a sequence, and a skill can have only this type.

The third type keeps a skill in its limit, without the loss of material the agent must have.

Do not push too small a part down, or the top becomes too large for the limit. Do not push too much down, or the agent misses material in the middle of the run. Keep the definition, the rules, and the caveats of a concept together.

## When to split into a separate skill

- **By invocation**: make a new model-invoked skill when a clear cue must fire on its own.
- That type of skill costs a new, always-loaded description, and it must earn that cost.
- **By sequence**: break a long run of steps in two, so the steps after it do not tempt the agent to rush the current one.

## Pruning

Keep each fact in one location, and check each line: does it hold now? Test each sentence: does it change behavior, against the default? When the answer is no, delete the line, and do not only cut part of it.

## Leading words

A leading word is a short term the agent understands, for example "tight loop," and the agent thinks with this word, not a longer, restated idea. The word, when repeated, attaches the execution to the body, and the invocation to the description, more reliably than a new explanation each time.

## Failure modes

- `Premature completion`: a step ends before the work is done.
- `Duplication`: the same fact, stated more than one time.
- `Sediment`: stale content that builds up, because removing it feels risky.
- `Sprawl`: the content is too long, with each line live and unique.
- `No-op`: a line the agent does by default anyway.

Repair the stopping point of a `Premature completion` first, and only after that, break the step by sequence, if the stopping point is not sufficient. Repair `Sprawl` with the information hierarchy.
