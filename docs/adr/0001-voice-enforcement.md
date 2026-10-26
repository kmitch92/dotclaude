# ADR 0001: Voice enforcement keeps the STE discipline and drops its dictionary

- Status: accepted, on trial
- Date: 2026-10-26
- Supersedes: the original ASD-STE100 enforcement plan from the same week

This file sits in `docs/adr/` on purpose. Nothing under `docs/` is stowed into
`~/.claude`, so Claude Code cannot load this record as a skill, an agent, an
output style or a lesson. Read it when you want to change how the voice rules
work, or when you want to remove them.

## Context

The repo first adopted ASD-STE100 Issue 9 in full, including its controlled
vocabulary. That vocabulary holds 846 approved words and 1313 unapproved ones,
drawn from aircraft maintenance manuals.

Measurement killed that approach. On 8133 words of this repo's own prose the
dictionary check produced 1032 hits, one for every 8 words, and 807 of those
came from the vocabulary rule across 246 distinct words. The words it objected
to most were `pass`, `list`, `order`, `every`, `under`, `fix`, `final`, `still`
and `true`. Each one is ordinary technical English, and the replacement the
standard offered read worse. The standard wanted `GO` for pass and `RECORD` for
list.

Two further faults appeared. The hook refused a reply and forced a rewrite,
which cost a second full reply for no gain in clarity. A pass that rewrote every
markdown file to satisfy the 20-word sentence limit cut flowing prose into runs
of one-line bullets, and 24 files fell to 8 or 9 words per sentence. That
staccato reads worse than the text it replaced.

The goal was always legible output. The dictionary worked against the goal.

## Decision

ASD-STE100 contributes its writing discipline and none of its vocabulary.

Keep: one meaning for each word, one instruction in each sentence, active voice
with the actor named, a sentence limit of 25 words, a paragraph limit of six
sentences, no contractions, no semicolons, no Latin abbreviations, an article
before each noun, and one clear referent for every pronoun.

Drop: the approved word list, the unapproved word list, the verb-form table, the
recurring-errors table, the extraction script that built them, the glossary, the
British spelling map and the banned-word file.

Add three checks for the habits that cost the reader most, each driven by a
phrase file this repo owns and can defend entry by entry:

| Check | Catches |
| --- | --- |
| NARRATION | "Let me check", "I will now", "I am going to" |
| FILLER-OPEN | a reply opening with "Great", "Perfect", "You are right" |
| SLOP | hedging and empty adjectives such as "robust" and "it is worth noting" |

Every rule is class `warn`. No hook ever refuses a reply.

## Consequences

| Measure | Before | After |
| --- | --- | --- |
| Checks | 23 | 13 |
| Linter lines | 1565 | 924 |
| Data files | 11 | 2 |
| Hit rate on repo prose | 1 per 8 words | 1 per 134 words |
| Context injected each turn | about 120 words | 15 to 40 words |
| Reply ever regenerated | yes, once | never |

Deleting the four extracted word files also removed a copyright problem. Those
files copied the substance of a copyrighted dictionary into a repo with a public
remote.

The subagent gate still lints the report of a worker or a scout, but nothing
reads the result. The gate keys its state file by agent identifier while the
reminder looks up by session identifier. Those results feed the report script
and nothing else. Treat them as measurement, not steering.

## How to adjust this later

Each lever is one file.

| To change | Edit |
| --- | --- |
| Which checks run, and their class and scope | `claude/.claude/ste/rules.tsv` |
| Which phrases count as narration, filler or slop | `claude/.claude/ste/phrases.tsv` |
| The rules the model reads before it writes | `claude/.claude/output-styles/terse.md` |
| The one static line injected each turn | `claude/.claude/bin/claude-terse-reminder.sh` |
| Check logic | `claude/.claude/bin/claude-ste-lint.py` |

A check stops firing when you delete its row from `rules.tsv`. The linter skips
an identifier with no row and writes one line to standard error.

To see which checks fire in practice, run `claude/.claude/bin/claude-ste-report.sh`
against `claude/.claude/ste/lint.log.jsonl`. The report gives a hit rate, the
most frequent identifiers, the most frequent slop words, and a count for each of
the three register checks. Tune `phrases.tsv` from that evidence, not from
taste.

Keep the admission rule for `phrases.tsv`. A phrase enters the file only when it
is wrong in every context and carries no technical meaning. An ordinary
programming word must never enter it. That rule is what stopped the first
attempt from working.

## How to remove it

Three steps, in this order.

1. Delete the `Stop` and `SubagentStop` hook entries from
   `claude/.claude/settings.json`, which stops the linting.
2. Delete the `UserPromptSubmit` entry for `claude-terse-reminder.sh`, which
   stops the context injection.
3. Delete `claude/.claude/ste/` and the four scripts named
   `claude-ste-*` in `claude/.claude/bin/`.

The output style survives all three steps and keeps working on its own, because
the model reads it directly. Prompt text needs no mechanism.

## Open caveat

This record is on trial. The design rests on one measurement of one repo's prose
and on a single session of live use. If replies still read badly, suspect the
output style first, because the model reads that text before it writes, and the
hook only reports after the fact.
