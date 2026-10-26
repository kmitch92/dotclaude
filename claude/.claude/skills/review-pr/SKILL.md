---
name: review-pr
description: This skill examines a pull request in an isolated worktree. It runs an investigation, and it checks the change against the code. It runs checks, and it surfaces issues before the change merges.
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Read, Grep, Glob, AskUserQuestion
---

Examine a pull request end-to-end in an isolated **worktree**. You are a safety net, not the owner, and the dev who wrote the change stays responsible. Look at the full change, and let nothing ship unseen.

Surface errors, and save time. This task is not a quiz for the dev, so resolve each question you can answer against the code on your own, instead of taking it to the dev. Question the dev only for what the code cannot give you, such as why the business wants it, the intent, whether an omission was deliberate, or context external to the repo.

## 1. Get the branch

If not given, request it, and check the target branch it points to (default `main`).

## 2. Create the worktree

```bash
ROOT=$(git rev-parse --show-toplevel)
git ls-remote --exit-code --heads origin <branch>
```

If that check fails, stop, because the branch is not on the remote of this repo, and do not guess at a different repo. If the check succeeds, continue:

```bash
git fetch origin <branch>
git worktree add "$ROOT/worktrees/<branch>" origin/<branch>
```

Work exclusively in `$ROOT/worktrees/<branch>` from here on.

## 3. Install dependencies

Find the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm, `bun.lockb` → bun), and install it, because the inspection runs against a working, installed tree.

## 4. Map the change surface

Diff the branch against its target (`git diff <base>...HEAD`), and follow what the changed code touches, and what relies on it. The map is done when you examine each changed file and understand its blast radius. The goal is not a record of files, but an understanding of what the change does, and everywhere it touches.

## 5. Investigate and verify

Work through the change and its blast radius on your own, watching for a bug, a deletion, unbounded growth, a broken contract, or a partial scope. Read the code that answers it before you report an issue, and never assert a claim the code can check or disprove.

There are two types of open question.
- **Answerable from the code**:
  - Resolve it through investigation.
  - Do not put it to the dev.
- **Answerable only by the dev**:
  - Examples: why the business wants this, why this approach, if a partial scope was on purpose, or external context.
  - Question these one at a time, only when the answer changes your view.
  - Ground each question in what you found.

## 6. Run the checks

- Targeted tests for the affected files only. Never run the full suite — that job belongs to CI.
- Typecheck with `tsc --noEmit`. Run the linter too.

Report each result faithfully: a failure with output, a skip as a skip, and a success as a success.

## 7. Surface everything

Look at the full change for correctness, edge conditions, safety, performance, missing tests, and any scope creep beyond what was planned. Check each issue raised against the code before you report it, and offer concrete test and debug steps the dev can run now. State plainly what you could not check, and why, and let the dev pick what to act on.

When done, offer to remove the worktree: `git worktree remove $ROOT/worktrees/<branch>`.
