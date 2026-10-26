---
name: commit
description: Make atomic, conventional-format commits from pending changes.
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(~/.claude/skills/commit/preflight.sh:*), Read, Grep, Glob
---

Make atomic commits for all pending changes, putting one logical change in each commit.

## Pre-flight (mandatory)

- Run `~/.claude/skills/commit/preflight.sh` before you plan or stage files.
- Exit 0: continue. Exit 2: stop and report.
- Exit 1 or 3: check the result closely, and do not stop at the first look.
  - Exit 1 means one or more LARGE, JUNK, SECRET, or BINARY results, while exit 3 means only SUSPECT results.
  - A SUSPECT result is a low-confidence hit, such as a generic assignment of a key or a token, or a JWT block or a private-key block.
  - Each SUSPECT result sits in a test, a spec, or a fixture path.
  - For each SECRET and SUSPECT line, read the flagged line with 3 lines of context before you judge it.
  - A value is a fixture in one of five conditions: it has a repeated or sequential pattern of characters, it has a word like `fake`, `example`, or `test`, it decodes to a sample payload, a test builds it through interpolation, or the test uses it only for an assertion.
  - Record one verdict for each result, in one line, for the end report: `fixture` or `real`.
  - SUSPECT judged `fixture`: commit it.
  - SUSPECT judged `real`: apply the SECRET rule to it.
  - SECRET judged `real` on a path in the planned commits: stop, make no commit, report it, and wait for the word from the user.
  - SECRET judged `real` on a path that is not in the plan — an unrelated untracked file, or a modified file: exclude that path, report it, and continue with the plan.
  - SECRET judged `fixture`: say so, with the sign that shows it. A high-precision pattern is not always correct, since the pattern can be a changed sample, so tell the user before you commit that path.
  - LARGE, JUNK, and BINARY results: exclude them from each commit, as now, and for each one propose the correct `.gitignore` line, which can include the path. Do not add the line unless the user agrees.
- Never work around the script, with no `git add -f` and no renaming to dodge a pattern.
- `--staged` checks only the paths you stage now.

## Process

1. Run `~/.claude/skills/commit/preflight.sh` (see Pre-flight above).
2. Run `git status` and `git diff` (plus `git diff --staged`) to see everything pending.
3. Sort changes into logical commits. Draft the full plan before you touch git:
   ```
   1. feat(api): add user authentication endpoint
   2. test(api): add authentication tests
   3. docs(api): document authentication flow
   ```
4. Show the plan to the user when it holds more than 5 commits.
5. Wait for the word from the user before you continue.
6. Run one commit at a time, in the sequence of the plan, and run `~/.claude/skills/commit/preflight.sh --staged` before each commit.
   - Exit 1: unstage the flagged paths with `git restore --staged <path>`, show the results, and skip those paths, keeping staged only a SECRET path the user approved during pre-flight.
   - Exit 3: apply the verdicts from the pre-flight check, and do not check the paths a second time.
7. Give the commit SHA for each one you made. Say that each one is local-only, not pushed.

## Atomicity

One commit holds one logical change, and you break the commit apart when the message must use "and", "also", or a comma.

- Put a new file in its own commit, unless some new files add one new function together.
- Keep config, docs, tests, and code in different commits from a refactor.
- A commit that adds a new function can hold its own tests too, when the commit stays small.
- Never put unrelated changes in one commit, and never write "various improvements", or a different generic message.

## File-count limits

- 1–3 files: good to go.
- 5 files: a soft limit, so give the cause in the commit body.
- 10 files: a hard limit, so tell the user before you continue.
- Keep each commit at 10 files or fewer, and divide a larger change into more commits.

## When changes can't be split cleanly

Use `git add -p <file>` to stage chosen hunks. A commit that does not run on its own, as a middle step, is a fair trade for a clean, granular history. When patch staging cannot divide the change either, because the same line does two jobs, stop, tell the user why, and wait for the word from the user.

## Staging

Stage explicit paths only. Never `git add -A` or `git add .`.

## Commit message format

```
type(scope): imperative description

optional body — explains WHY, lines ≤72 chars
```

- The commit types are `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, and `ci`.
- Write the description in the imperative mood, and use lowercase right after the colon.
- Do not end with a period, and keep the subject at 50 characters or fewer.
- A breaking change: add `!` after the type or scope, or add a `BREAKING CHANGE:` footer.

## Never commit

The pre-flight script checks for these types: LARGE, JUNK, SECRET, BINARY, and SUSPECT results. It cannot judge two things: a file you can build again from the same source, and a lockfile change that does not come from an actual change in a dependency. Exclude those by hand.

## Never

- Never run `git push`, with or without `-u`, never set the upstream branch, and never open a PR, since the user does each of these tasks.
- `git commit --amend`, `rebase`, `reset --hard` that discards commits, or force-push.

## Report

Record each commit SHA you made, and state that each one is local-only.
Pre-flight: <N> results, <M> paths excluded, <K> SUSPECT results cleared as fixtures (or: clean).
