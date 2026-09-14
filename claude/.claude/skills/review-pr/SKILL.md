---
name: review-pr
description: Review a pull request in an isolated worktree — investigate and verify the change against the code, run checks, and surface concerns before it merges
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Read, Grep, Glob, AskUserQuestion
---

Review a pull request end-to-end in an isolated **worktree**. You are a safety net, not the owner — the submitting dev stays responsible. Canvas the whole change surface; let nothing ship unseen.

Surface real errors and save time — this is not a quiz for the developer. Investigate and settle every question you can against the code yourself. Ask the developer only for what the code cannot give you: business need, intent, whether an omission was deliberate, context outside the repo.

## 1. Get the branch

If not given, ask for it. Confirm the base it targets (default `main`).

## 2. Create the worktree

```bash
ROOT=$(git rev-parse --show-toplevel)
git ls-remote --exit-code --heads origin <branch>
```

If that check fails, stop — the branch isn't on this repo's remote; don't guess another repo. Otherwise:

```bash
git fetch origin <branch>
git worktree add "$ROOT/worktrees/<branch>" origin/<branch>
```

Work exclusively inside `$ROOT/worktrees/<branch>` from here on.

## 3. Install dependencies

Detect the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm, `bun.lockb` → bun) and install. The review runs against a working, installed tree.

## 4. Map the change surface

Diff the branch against its base (`git diff <base>...HEAD`). Trace what the changed code touches and what depends on it. Done when every changed file is examined and its blast radius understood — not a file list, an understanding of what the change does and everywhere it reaches.

## 5. Investigate and verify

Work through the change and its blast radius yourself. For anything you suspect — a bug, a wipe, unbounded growth, a broken contract, a scope gap — read the code that would settle it before raising it. Never assert a claim the code can confirm or refute.

Two kinds of open question:
- **Answerable from the code** — resolve by investigation, don't ask.
- **Answerable only by the developer** — business need, why this approach, whether a scope gap was intentional, external context. Ask these one at a time, only when the answer changes your assessment, grounded in what you already found.

## 6. Run the checks

- Targeted tests covering the affected files only — never the full suite, that's CI's job.
- Typecheck with no emit (`tsc --noEmit`) and the linter.

Report every result faithfully: failures with output, skips as skips, passes as passes.

## 7. Surface everything

Canvas the whole change: correctness, edge cases, security, performance, missing tests, scope creep. Every concern raised should already be checked against the code. Offer concrete test/debug steps the dev can run now. State plainly what you couldn't verify and why. The dev decides what to act on.

When done, offer to remove the worktree: `git worktree remove $ROOT/worktrees/<branch>`.
