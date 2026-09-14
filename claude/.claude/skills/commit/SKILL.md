---
name: commit
description: Create atomic, conventional-format commits from pending changes
disable-model-invocation: true
allowed-tools: Bash(git:*), Read, Grep, Glob
---

Create atomic commits for all pending changes. One logical change per commit.

## Process

1. Run `git status` and `git diff` (plus `git diff --staged`) to see everything pending.
2. Group changes into logical commits. Draft the full plan before touching git:
   ```
   1. feat(api): add user authentication endpoint
   2. test(api): add authentication tests
   3. docs(api): document authentication flow
   ```
3. If the plan has more than 5 commits, show it and wait for confirmation before executing.
4. Execute one commit at a time, in order.
5. Report every commit SHA created and state they are local-only (not pushed).

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

Secrets, credentials, API keys, `node_modules`, `package-lock.json` (unless the dependency bump is intentional), generated files, logs, large binaries without justification.

## Never

- `git push` (with or without `-u`), setting upstream, or opening a PR — the user does both.
- `git commit --amend`, `rebase`, `reset --hard` that discards commits, or force-push.

## Report

List every commit SHA created and state they are local-only.
