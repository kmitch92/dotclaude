---
name: typetest
description: Check the full project for a TypeScript error, a test failure, or a hole in the coverage. Repair each one, one step at a time, until the targets are met.
disable-model-invocation: true
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Bash(tsc:*), Read, Write, Edit, Grep, Glob
---

Check the full project for a TypeScript error and a test failure, and repair each one, one step at a time. This skill checks the full project in a single run, on purpose, running the full type-check and the full test suite. The rule of "targeted tests only" has one exception here.

## 1. Discover

Find the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm).

```bash
<pkg-manager> run type-check || npx tsc --noEmit
<pkg-manager> test
<pkg-manager> test -- --coverage
```

Record each TypeScript error with its file, line, code, and message, and record each test failure with its file, name, and cause. Record each hole in the coverage as the file or function with no coverage. Show the TypeScript errors before the test failures, and always repair a TypeScript error before you repair a test failure.

## 2. Repair TypeScript errors first

A type error can cause a test to fail, so clear each type error before you touch a test.

For each error, read the file, find the root cause, and repair the error. Do not use `any`, and use `unknown` with a type check instead. Import the actual schema, and never redefine it. Stay strict-mode compliant, and confirm with `npx tsc --noEmit` after each repair, one at a time, never in a batch.

## 3. Repair test failures

For each failure, read the test and find the cause. The cause can be code not written, an incorrect expectation, a type mismatch from step 2, a stale mock, or an async bug. Apply the smallest correct repair, and confirm it by running that one test.

## 4. Improve coverage

Target 100%. For each file or function with no coverage, write a test for actual behavior: the happy path, an edge condition, or an error. Run the coverage check again, and confirm the number changed.

## 5. Make sure, and report

Run the full type-check and full test suite again, and report these changes from the start of this run.
- TypeScript errors: X → Y
- Test failures: X → Y
- Coverage: X% → Y%

**Exit only if one metric or more got better** (or the project is now at the target: 0 errors, 0 failures, 100% coverage). If nothing changed, the task is not done, so go back and repair something else.

## Rules

- Repair TypeScript before you repair a test, always, and confirm after each repair, one at a time, never in a batch.
- Do not use `any`, and use `unknown` with a type check instead. Import the schema, and never redefine it.
- When one issue stops you, repair a different one, and always keep moving.
- Apply the smallest repair that resolves the issue, and do not refactor unrelated code.
- Do not call "pre-existing" an excuse, and repair it anyway.
- Make each repeated run converge to 0 errors, 0 failures, 100% coverage.
