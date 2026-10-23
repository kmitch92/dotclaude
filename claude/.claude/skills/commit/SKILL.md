---
name: commit
description: Create atomic, conventional-format commits from pending changes
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(~/.claude/skills/commit/preflight.sh:*), Read, Grep, Glob
---

Create atomic commits for all pending changes. One logical change per commit.

## Pre-flight (mandatory)

- Run `~/.claude/skills/commit/preflight.sh` first, before any planning or staging.
- Exit 0: continue.
- Exit 2: stop and report.
- Exit 1 or 3: investigate, don't stop on sight.
  - Exit 1 means at least one LARGE / JUNK / SECRET / BINARY finding. Exit 3 means only SUSPECT findings — low-confidence hits (generic key/token assignment, or a JWT/private-key block) found in a test, spec, or fixture path.
  - For every SECRET and SUSPECT line, read the flagged line with 3 lines of context before deciding.
  - A value is a fixture when it is obviously synthetic (repeated or sequential characters, words like fake/example/test, decodes to a sample payload), is built by interpolation, or lives in a test/fixture file and is used only to drive assertions.
  - Record a one-line verdict per finding for the final report: `fixture` or `real`.
  - SUSPECT judged fixture: commit it. SUSPECT judged real: treat it as SECRET.
  - SECRET judged real on a path in the planned commits: stop, create no commit, report, wait for the user.
  - SECRET judged real on a path NOT in the plan (an unrelated untracked or modified file): exclude that path, report it, continue with the plan.
  - SECRET judged fixture: say so with the evidence — a high-precision pattern can still be a doctored sample — and ask the user before committing that path.
  - LARGE / JUNK / BINARY: excluded from every commit as now. For each, propose the exact `.gitignore` line that would cover the path (do not add it unless the user agrees).
- Never work around the script (no `git add -f`, no renaming to dodge a pattern).
- `--staged` checks only what is currently staged.

## Process

1. Run `~/.claude/skills/commit/preflight.sh` (see Pre-flight above).
2. Run `git status` and `git diff` (plus `git diff --staged`) to see everything pending.
3. Group changes into logical commits. Draft the full plan before touching git:
   ```
   1. feat(api): add user authentication endpoint
   2. test(api): add authentication tests
   3. docs(api): document authentication flow
   ```
4. If the plan has more than 5 commits, show it and wait for confirmation before executing.
5. Execute one commit at a time, in order. Before each commit, run `~/.claude/skills/commit/preflight.sh --staged`.
   - Exit 1: unstage the flagged paths with `git restore --staged <path>`, show the findings, and skip them — except a SECRET path the user explicitly approved during pre-flight, which stays staged.
   - Exit 3: apply the verdicts already recorded during pre-flight investigation — no re-investigation needed.
6. Report every commit SHA created and state they are local-only (not pushed).

## Atomicity

One commit = one logical change. If the message needs "and", "also", or a comma, split it.

- New file → its own commit, unless it's part of one feature.
- Config, docs, tests, implementation, refactor → separate commits.
- Feature + its own tests → acceptable together if it stays small.
- Never bundle unrelated changes, "various improvements", or generic messages.

## File-count limits

- 1–3 files: ideal.
- 5 files: soft cap — justify in the commit body.
- 10 files: hard cap — ask the user before proceeding.
- Never exceed 10 without splitting further.

## When changes can't be split cleanly

Use `git add -p <file>` to stage specific hunks. A non-working intermediate commit is an acceptable trade for granular history. If even patch staging can't separate the change (the same line serves two purposes), stop, explain why, and ask the user.

## Staging

Stage explicit paths only. Never `git add -A` or `git add .`.

## Commit message format

```
type(scope): imperative description

optional body — explains WHY, lines ≤72 chars
```

- Types: feat, fix, docs, style, refactor, perf, test, chore, ci.
- Imperative mood, lowercase after the colon, no period, subject ≤50 chars.
- Breaking changes: `!` after type/scope, or a `BREAKING CHANGE:` footer.

## Never commit

The pre-flight script is the enforced list: LARGE, JUNK, SECRET, BINARY, and SUSPECT findings. It cannot judge two things: generated files you can regenerate, and a lockfile change that was not an intentional dependency bump — exclude those by hand.

## Never

- `git push` (with or without `-u`), setting upstream, or opening a PR — the user does both.
- `git commit --amend`, `rebase`, `reset --hard` that discards commits, or force-push.

## Report

List every commit SHA created and state they are local-only.
Pre-flight: <N> findings, <M> paths excluded, <K> suspects cleared as fixtures (or: clean).
