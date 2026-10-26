---
name: typetest
description: Check the full project for a TypeScript error, a test failure, or a hole in the coverage. Repair each one, one step at a time, until the targets are met.
disable-model-invocation: true
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Bash(tsc:*), Read, Write, Edit, Grep, Glob
---

Check the full project for a TypeScript error and a test failure. Repair each one, one step at a time. This skill checks the full project in a single run, on purpose. It runs the full type-check and the full test suite. The rule of "targeted tests only" has one exception here.

## 1. Discover

Find the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm).

```bash
<pkg-manager> run type-check || npx tsc --noEmit
<pkg-manager> test
<pkg-manager> test -- --coverage
```

Record each TypeScript error: the file, the line, the code, and the message. Record each test failure: the file, the name, and the cause. Record each hole in the coverage: the file or function with no coverage. Show the TypeScript errors before the test failures. Repair a TypeScript error before you repair a test failure, always.

## 2. Repair TypeScript errors first

A type error can cause a test to fail. Clear each type error before you touch a test.

For each error, read the file and find the root cause. Repair the error. Do not use `any`. Use `unknown` with a type check. Import the actual schema. Never redefine it. Stay strict-mode compliant. Make sure with `npx tsc --noEmit` after each repair, one at a time, never in a batch.

## 3. Repair test failures

For each failure, read the test. Find the cause. The cause can be code not written, an incorrect expectation, a type mismatch from step 2, a stale mock, or an async bug. Apply the smallest correct repair. Make sure of it: run that one test.

## 4. Improve coverage

Target 100%. For each file or function with no coverage, write a test for actual behavior: the happy path, an edge condition, or an error. Run the coverage check again. Make sure the number changed.

## 5. Make sure, and report

Run the full type-check and full test suite again. Report these changes from the start of this run.
- TypeScript errors: X → Y
- Test failures: X → Y
- Coverage: X% → Y%

**Exit only if one metric or more got better** (or the project is now at the target: 0 errors, 0 failures, 100% coverage). If nothing changed, the task is not done. Go back. Repair something else.

## Rules

- Repair TypeScript before you repair a test, always.
- Make sure after each repair, one at a time, never in a batch.
- Do not use `any`. Use `unknown` with a type check.
- Import the schema. Never redefine it.
- When one issue stops you, repair a different one. Always keep moving.
- Apply the smallest repair that resolves the issue. Do not refactor unrelated code.
- Do not call "pre-existing" an excuse. Repair it anyway.
- Make each repeated run converge to 0 errors, 0 failures, 100% coverage.
