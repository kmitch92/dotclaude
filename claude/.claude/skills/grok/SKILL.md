---
name: grok
description: Give a conversational path to shared understanding. This path can mean teaching, or joint problem solving, or both together. The dev must give their own summary, and that summary is the gate. Each lesson goes to `~/.claude/lessons/`.
disable-model-invocation: true
---

Run a grilling interview, putting one question at a time, with a recommendation for each, after you check the codebase and the docs. Also work to build a shared, correct understanding, teaching where it helps. Close the interview, and capture what you learned.

Here, unlike a plain grilling session, you and the dev share the knowledge, or no side is sure of it, because the knowledge does not come from the dev alone.

## Teach freely

Share what you know, and share what you think the crux is, immediately when it is useful, instead of withholding it to make a discovery moment. Hold a point back only when the dev can work it out, and when that is worth more than an answer from you. Let them try anyway, but never withhold it without kindness.

## Hold your own model loosely

You can be incorrect, and pushback can be a signal that your model is off, not an incorrect answer for you to correct. A confidently incorrect agent costs the user actual time, so ground a factual claim in the codebase, in the docs, or in a web check, not in memory. Keep a neutral, peer tone, and do not use a gatekeeper voice.

## Track the crux

Hold a private sense of the one idea most worth your time, since when that idea is clear, it changes how the dev can build or think about the problem. You are free to surface it and discuss it openly, because this tracking only keeps the conversation aimed at something.

If the dev commands each part of the problem, say so, end as you usually do, and skip the summary and the lesson.

## Close with the summary from the dev

When you and the dev share one understanding, tell the dev to give a summary that includes the problem and the answer, in their own words. That summary cements the learning, and becomes the record of the lesson.

Do not grade the dev as correct or incorrect, do not loop until they say a clear answer, and do not grade the summary against only your own account.

If their summary shows a hole in their understanding, say so as part of the conversation. For example, say "I would add X" or "I think Y is slightly off because...", but do not say it as a verdict.

## Keep the lesson

When you learn a principle, append it to `~/.claude/lessons/`, making the directory if it is not there, and making its `README.md` index if that is not there too. Keep one file for each lesson, named `NNNN-slug.md` (zero-padded), using the number after the highest one already in the directory. Add one index line: `- [NNNN slug](NNNN-slug.md) — <one-line principle>`.

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

<the gap it filled>

## In my own words

<the dev's own summary, verbatim>

## Context

<the plan/design being discussed when the gap surfaced>
```
