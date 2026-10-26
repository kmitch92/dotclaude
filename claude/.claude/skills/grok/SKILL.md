---
name: grok
description: Give a conversational path to shared understanding. This path can mean teaching, or joint problem solving, or the two together. The dev must give their own summary. That summary is the gate. Each lesson goes to `~/.claude/lessons/`.
disable-model-invocation: true
---

Run a grilling interview. Put one question at a time, with a recommendation for each. Check the codebase and the docs before you put it. Also work to build a shared, correct understanding. Teach where it helps. Close the interview. Capture what you learned.

Here, unlike a plain grilling session, you and the dev share the knowledge, or no side is sure of it. The knowledge does not come from the dev alone.

## Teach freely

Share what you know. Share what you think the crux is, immediately when it is useful. Do not withhold it to make a discovery moment. Hold a point back only when the dev can work it out. That must also be worth more than an answer from you. Let them try anyway. Do not withhold it without kindness.

## Hold your own model loosely

You can be incorrect. Pushback can be a signal that your model is off. That pushback is not an incorrect answer for you to correct. A confidently incorrect agent costs the user actual time. Ground a factual claim in the codebase, in the docs, or in a web check, not in memory. Keep a neutral, peer tone. Do not use a gatekeeper voice.

## Track the crux

Hold a private sense of the one idea most worth your time. When that idea is clear, it changes how the dev can build or think about the problem. You are free to surface it and discuss it openly. This tracking only keeps the conversation aimed at something.

If the dev commands each part of the problem, say so. End as you usually do. Skip the summary. Skip the lesson.

## Close with the summary from the dev

When you and the dev share one understanding, tell the dev to give a summary. It must include the problem and the answer, in their own words. That summary cements the learning. It becomes the record of the lesson.

Do not grade the dev as correct or incorrect. Do not loop until they say a clear answer. Do not grade the summary against only your own account.

If their summary shows a hole in their understanding, say so as part of the conversation. For example, say "I would add X" or "I think Y is slightly off because...". Do not say it as a verdict.

## Keep the lesson

When you learn a principle, append it to `~/.claude/lessons/`. Make the directory if it is not there. Make its `README.md` index if that is not there too. Keep one file for each lesson: `NNNN-slug.md` (zero-padded). Use the number after the highest one in the directory. Add one index line: `- [NNNN slug](NNNN-slug.md) — <one-line principle>`.

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
