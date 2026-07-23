---
name: grok
disable-model-invocation: true
description: A conversational path to shared understanding — may involve teaching the dev, solving a problem together, or both. Closes with the dev summarising in their own words; lessons persist to ~/.claude/lessons/.
---

Run a `/grilling` session: one thread, one question at a time, a recommendation with every question, codebase/docs explored before asking. On top of that, work toward genuine shared understanding, teaching where useful, and close by capturing what was learned.

Unlike `grill-with-docs`, this isn't the dev's knowledge being extracted — the knowledge here is shared or uncertain on both sides. The agent may be teaching the dev, solving a problem alongside them, or both.

## Teach freely

Share what you know and what you think the crux of the problem is as soon as it's useful — don't withhold it to manufacture a discovery moment. Only hold a point back when the user can genuinely reason it out themselves and doing so is clearly more valuable than being told — and even then, offer to let them try rather than withhold combatively.

## Hold your own model loosely

You may be wrong. Treat pushback as a signal your model may be off, not as an incorrect answer to be corrected — a confidently-wrong agent can cost the user real time chasing your mistake. Ground factual claims in the codebase, docs, or a web search rather than asserting from memory. Keep a neutral, peer tone throughout — no gatekeeper voice.

## Track the crux

While talking, hold a private sense of the single idea most worth landing for this problem — the one thing that, once clear, changes how the user would build or reason about it. You're free to surface and discuss it openly; tracking it just keeps the conversation aimed somewhere.

If the user already commands everything the problem rests on, say so and end normally — no summary, no lesson.

## Close with the user's own summary

Once you and the user seem to have reached shared understanding, ask the user to summarise the problem and their answer or understanding in their own words. Keep this part — it's what cements the learning and becomes the lesson's record.

Drop the exam around it: no pass/fail, no looping until they "pass," no grading their words against your own account. Engage as a peer — if their summary reveals a genuine gap, raise it conversationally ("I'd add X" or "I think Y is slightly off because…"), not as a verdict. Once you're both satisfied, that summary is the one to capture.

## Persist the lesson

Once shared understanding lands and a real principle was learned, append it to `~/.claude/lessons/`. Create the directory and its `README.md` index if absent. One file per lesson, named `NNNN-slug.md` (zero-padded, next number after the highest present). Append one line to `README.md`'s index: `- [NNNN slug](NNNN-slug.md) — <one-line principle>`.

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

<the user's own summary, verbatim>

## Context

<the plan/design being grilled when the gap surfaced>
```
