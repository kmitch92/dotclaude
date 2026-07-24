---
name: review-pr
description: Review a pull request in an isolated worktree — set it up, investigate and verify the change against the code, and surface concerns before it merges.
disable-model-invocation: true
---

Review a pull request end-to-end in an isolated **worktree**. You are a safety net, not the owner — the submitting dev stays responsible — so canvas the whole change surface and let nothing ship unseen.

**The goal is to surface real errors and concerns and to save time — not to quiz the developer.** Establishing whether the developer understands their own change is not the objective. Investigate the PR yourself and settle every question you can against the code. The developer's time is valuable: ask them only when you genuinely need information the code cannot give you (the business need, the intent behind an approach, whether an omission was deliberate, context that lives outside the repo).

## 1. Get the branch

If the branch wasn't given, ask for it before doing anything else. Confirm the base it targets (default `main`).

## 2. Create the worktree

Assume the dev is already inside the correct repo for the branch. Find the repo root, and confirm the branch exists on that repo's remote before touching anything:

```
ROOT=$(git rev-parse --show-toplevel)
git ls-remote --exit-code --heads origin <branch>   # non-zero → branch not on remote
```

If that check fails, stop and flag it to the user — the branch isn't on this repo's remote; do not guess another repo or branch. Otherwise fetch and add the worktree at the repo root:

```
git fetch origin <branch>
git worktree add "$ROOT/worktrees/<branch>" origin/<branch>
```

Work exclusively inside `$ROOT/worktrees/<branch>` for the rest of the review — never the primary checkout.

## 3. Install dependencies

Detect the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `package-lock.json` → npm, `yarn.lock` → yarn, `bun.lockb` → bun) and install. The review runs against a working, installed tree.

## 4. Map the change surface

Delegate to **git-specialist** for the full diff against the base, and to the **Explore** agent to trace what the changed code touches and what depends on it. Done when every changed file is examined and its blast radius understood — not a file list, an understanding of what the change does and everything it reaches.

## 5. Investigate and verify

Work through the change and its blast radius yourself. For anything you suspect — a bug, a wipe, unbounded growth, a broken contract, a scope gap — **read the code that would settle it before you raise it.** Trace the call, read the downstream consumer, check the guard, confirm the condition. Never assert a claim the code can confirm or refute; a concern you raise without checking wastes the developer's time and undermines the review when it turns out to be wrong. Be sure of every claim you make.

Distinguish two kinds of open question:
- **Answerable from the code** — resolve it by investigation. Do not ask the developer.
- **Answerable only by the developer** — the business need and the ticket behind it, why this approach over another, whether a scope omission was intentional, external context. Ask these, one at a time, and only when the answer actually changes your assessment.

When you do ask, ground the question in what you already found in the code, so the developer confirms or corrects a specific reading rather than re-explaining from scratch. If a `/grilling` session helps structure the developer-facing questions, use it — but it is a tool for the narrow set of questions the code cannot answer, not the default mode of the review.

## 6. Run the checks

- targeted tests covering the affected files (never the full suite — that is CI's job)
- typecheck with no emit (`tsc --noEmit`) and the linter

Report every result faithfully: failures with their output, skips as skips, passes as passes.

## 7. Surface everything

Canvas the whole change and surface every possible issue: correctness, edge cases, security, performance, missing tests, scope creep. Every concern you raise should already have been checked against the code. Offer concrete test and debug opportunities the dev can run now. State plainly what you could not verify, and why. The dev decides what to act on.

When the review is done, offer to remove the worktree (`git worktree remove /worktrees/<branch>`).
