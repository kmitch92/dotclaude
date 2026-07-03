---
name: review-pr
description: Review a pull request in an isolated worktree — set it up, grill the developer, and stress-test the change before it merges.
disable-model-invocation: true
---

Review a pull request end-to-end in an isolated **worktree**, then **grill** the submitting developer until you and they share a complete understanding of the change. You are a safety net, not the owner — the submitting dev stays responsible — so canvas the whole change surface and let nothing ship unseen.

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

## 5. Grill the developer

Run a `/grilling` session on the PR. Interrogate, one question at a time:

- the business need and the ticket behind it
- what was actually changed, and why this approach
- whether the scope matches the need — nothing missing, nothing extra
- code quality and suitability for purpose

Do not conclude until you and the dev reach shared understanding of all of these. Resolve questions against the code wherever the code can answer them, rather than asking.

## 6. Run the checks

- targeted tests covering the affected files (never the full suite — that is CI's job)
- typecheck with no emit (`tsc --noEmit`) and the linter

Report every result faithfully: failures with their output, skips as skips, passes as passes.

## 7. Surface everything

Canvas the whole change and surface every possible issue: correctness, edge cases, security, performance, missing tests, scope creep. Offer concrete test and debug opportunities the dev can run now. State plainly what you could not verify. The dev decides what to act on.

When the review is done, offer to remove the worktree (`git worktree remove /worktrees/<branch>`).
