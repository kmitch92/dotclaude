---
name: merge
description: Resolve git disagreements after you pull from `main`. Resolve safe conditions on your own. Question the user about important disagreements after that.
disable-model-invocation: true
allowed-tools: Bash(git:*), Read, Edit, Grep, Glob, AskUserQuestion
---

Resolve merge disagreements after you pull from `main`. Resolve safe disagreements on your own. Question the user about important disagreements.

## 1. Find disagreements

```bash
git status --porcelain | grep '^UU'
```

If there are none, state that the merge is clean, and stop.

## 2. Put files in sequence

The sequence to resolve files is: config files first. Next come schema files. Source files come next. Test files come next. Doc files come next. Other files come last.

## 3. Read and classify each disagreement

Read the full file, not only the disagreement markers. Check the context around each one carefully.

You can resolve some disagreements on your own: put the two sides together. One example: an import, a function, or an object property, added on one side and not on the other. One more example: differences made only of whitespace. One more: comments added in different positions. One more: different test conditions added on each side.

Question the user about other disagreements. Never guess. Examples: the same function or variable, changed differently on each side. Type definitions or schema definitions that disagree with each other. API changes that break on one side. Dependency versions that disagree with each other. The same business logic, changed differently. One side removes a file, and the other side changes it. A disagreement about a binary file, or about a file name change.

## 4. Resolve

For a disagreement you can resolve on your own, put together the two changes with Edit. Remove duplicate imports. Sort them. Include each new part. Run `git add <file>`.

For an important disagreement, use AskUserQuestion. State the file, the two versions with their context, and why you must not resolve it automatically. Offer: keep the current version, keep the incoming version, or give a manual instruction. Apply the answer. Run `git add <file>`.

## 5. Make sure each file is resolved

```bash
git status
```

No file can show `UU`. You must stage each file that had a disagreement.

## 6. Run the type-check and the tests

Find the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm).

```bash
<pkg-manager> run type-check || npx tsc --noEmit
<pkg-manager> test <test files covering files touched by the merge>
```

Run the test files for the files touched by the merge. Run them one time, never in `watch mode`. Never run the full suite unless the user tells you to.

If one run fails, report the failures. Question the user: continue, or repair the problem first?

## 7. Complete the merge

```bash
git commit --no-edit
```

## 8. Report

State: the disagreements you resolved (on your own, compared with the user), the files you changed, the type-check result, and the test result.

## Rules

1. Do not resolve an important disagreement on your own. Question the user.
2. Keep the function of the two sides, above removing one of them.
3. Read the full file for context, not only the markers.
4. Send config disagreements and schema disagreements to the user, always.
5. Make sure the type-check and the tests for the changed files succeed, before you finish.
