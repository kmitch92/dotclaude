---
name: merge
description: Resolve git merge conflicts after pulling from main, auto-resolving safe cases and asking on serious ones
disable-model-invocation: true
allowed-tools: Bash(git:*), Read, Edit, Grep, Glob, AskUserQuestion
---

Resolve merge conflicts after pulling from main. Auto-resolve safe conflicts, ask on serious ones.

## 1. Detect conflicts

```bash
git status --porcelain | grep '^UU'
```

If none, report the merge is already clean and stop.

## 2. Order files

Resolve in this order: config → schemas → source → tests → docs → other.

## 3. Read and classify each conflict

Read the full file, not just the conflict markers — understand the surrounding context.

**Auto-resolvable** (merge both sides):
- Non-overlapping imports, functions, or object properties added on each side
- Whitespace-only differences
- Comments added in different places
- Different test cases added on each side

**Ask the user** (never guess):
- Same function or variable modified differently on each side
- Conflicting type or schema definitions
- Breaking API changes on either side
- Conflicting dependency versions
- Same business logic changed differently
- One side deletes, the other modifies
- Binary-file or file-rename conflicts

## 4. Resolve

For auto-resolvable conflicts, combine both changes (dedupe/alphabetise imports, include every addition) with Edit, then `git add <file>`.

For serious conflicts, use AskUserQuestion: state the file, both versions with context, and why auto-resolution is unsafe. Offer: keep current, keep incoming, or a manual instruction. Apply the answer, then `git add <file>`.

## 5. Verify all resolved

```bash
git status
```

No file may show `UU`; every conflicted file must be staged.

## 6. Type-check and test

Detect the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm).

```bash
<pkg-manager> run type-check || npx tsc --noEmit
<pkg-manager> test <test files covering files touched by the merge>
```

Run only the test files covering files touched by the merge, once, never in watch mode. Never the full suite unless the user asks.

If either fails, report the failures and ask whether to proceed or fix first.

## 7. Complete the merge

```bash
git commit --no-edit
```

## 8. Report

State: conflicts resolved (auto vs. user-guided), files modified, type-check result, test result.

## Rules

1. Never auto-resolve a serious conflict — ask.
2. Favor keeping both sides' functionality over deleting either.
3. Read full file context, not just the markers.
4. Config and schema conflicts always go to the user.
5. Verify with type-check and the tests covering merged files before finishing.
