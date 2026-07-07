---
name: grok
disable-model-invocation: true
description: Grill to shared understanding, then gate on a teach-back of the missing principle before ending; passing lessons persist to ~/.claude/lessons/.
---

Run a `/grilling` session with one hard gate: it does not end until the user can explain, in their own words, the core principle they were missing — then the lesson is written to `~/.claude/lessons/`.

## Track the gap

While grilling, hold onto the single principle whose absence most weakens the user's thinking — the one concept that, once truly grokked, changes how they'd build. Keep it private for now: surfacing it early lets the user nod along instead of earning it.

If the user already commands every concept the plan rests on, say so and end the session normally — no teach-back, no lesson.

## The teach-back gate

Once grilling would otherwise reach shared understanding, gate it before declaring it reached:

1. Name the principle, then ask the user to explain it back in their own words as if teaching a novice. Do not supply the explanation first — a teach-back only proves understanding if the words are theirs.
2. Judge the answer against a correct account. It passes only when accurate, complete on the points that matter, and phrased in the user's own words — not when the user merely agrees it's important or echoes the agent's phrasing.
3. On a miss, name exactly what is wrong or missing — no more — and ask again. Loop until they pass. Never accept fatigue, agreement, or "makes sense" as a pass.

Shared understanding is reached only after a pass.

## Persist the lesson

The moment the user passes, append the lesson to `~/.claude/lessons/`. Create the directory and its `README.md` index if absent. One file per lesson, named `NNNN-slug.md` (zero-padded, next number after the highest present). Append one line to `README.md`'s index: `- [NNNN slug](NNNN-slug.md) — <one-line principle>`.

Lesson file format:

```markdown
---
principle: <one-line principle>
date: YYYY-MM-DD
project: <repo or path the session was about>
tags: [<retrieval keywords>]
---

## The principle

<correct account, tightened>

## Why it matters

<the gap it filled — what the user would have got wrong without it>

## In my own words

<the user's passing teach-back, verbatim>

## Context

<the plan/design being grilled when the gap surfaced>
```
