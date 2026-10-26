---
name: merge
description: Resolve git disagreements after you pull from `main`. Resolve safe conditions on your own. Question the user about important disagreements after that.
disable-model-invocation: true
allowed-tools: Bash(git:*), Read, Edit, Grep, Glob, AskUserQuestion
---

Resolve merge disagreements after you pull from `main`, handling safe disagreements on your own and questioning the user about important disagreements.

## 1. Find disagreements

```bash
git status --porcelain | grep '^UU'
```

If there are none, state that the merge is clean, and stop.

## 2. Put files in sequence

Resolve files in this order: config files, then schema files, then source files, then test files, then doc files, then other files last.

## 3. Read and classify each disagreement

Read the full file, not only the disagreement markers, and check the context around each one carefully.

You can resolve some disagreements on your own by combining both sides, for example an import, a function, or an object property added on one side and not on the other, a difference made only of whitespace, a comment added in different positions, or different test conditions added on each side.

Question the user about other disagreements, and never guess. Examples include the same function or variable changed differently on each side, type definitions or schema definitions that disagree with each other, and API changes that break on one side. Other examples are dependency versions that disagree with each other, the same business logic changed differently, and one side removing a file while the other side changes it. A disagreement about a binary file, or about a file name change, also needs the user's judgment.

## 4. Resolve

For a disagreement you can resolve on your own, combine both changes with Edit, remove duplicate imports, sort them, and include each new part. Run `git add <file>`.

For an important disagreement, use AskUserQuestion, and state the file, both versions with their context, and why you must not resolve it automatically. Offer to keep the current version, keep the incoming version, or give a manual instruction, then apply the answer. Run `git add <file>`.

## 5. Make sure each file is resolved

```bash
git status
```

No file can show `UU`, and you must stage each file that had a disagreement.

## 6. Run the type-check and the tests

Find the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm).

```bash
<pkg-manager> run type-check || npx tsc --noEmit
<pkg-manager> test <test files covering files touched by the merge>
```

Run the test files for the files touched by the merge, one time only, and never in `watch mode`. Never run the full suite unless the user tells you to.

If one run fails, report the failures, and question the user about whether to continue or repair the problem first.

## 7. Complete the merge

```bash
git commit --no-edit
```

## 8. Report

State: the disagreements you resolved (on your own, compared with the user), the files you changed, the type-check result, and the test result.

## Rules

1. Do not resolve an important disagreement on your own, and question the user instead.
2. Keep the function of both sides, above removing one of them.
3. Read the full file for context around each disagreement, not only the markers.
4. Always send config disagreements and schema disagreements to the user.
5. Make sure the type-check and the tests for the changed files succeed, before you finish.
