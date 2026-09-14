---
name: typetest
description: Sweep the project for TypeScript errors, test failures, and coverage gaps, then fix them incrementally until targets are met
disable-model-invocation: true
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Bash(tsc:*), Read, Write, Edit, Grep, Glob
---

Sweep the whole project for TypeScript errors and test failures, then fix them incrementally. This skill's purpose is a full-project sweep, so it deliberately runs the full type-check and full test suite — the one exception to "targeted tests only".

## 1. Discover

Detect the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm).

```bash
<pkg-manager> run type-check || npx tsc --noEmit
<pkg-manager> test
<pkg-manager> test -- --coverage
```

Record every TypeScript error (file, line, code, message), every test failure (file, name, reason), and every coverage gap (uncovered files/functions). List TypeScript errors before test failures — fix order follows this priority.

## 2. Fix TypeScript errors first

Type errors cause cascading test failures, so clear them before touching tests.

For each error: read the file, find the root cause, fix it — no `any`, use `unknown` with type guards; import real schemas, never redefine them; stay strict-mode compliant. Verify with `npx tsc --noEmit` after each fix, one at a time, not batched.

## 3. Fix test failures

For each failure: read the test, diagnose (missing implementation, wrong expectation, type mismatch from step 2, stale mock, async bug), apply the smallest correct fix, verify by running that one test.

## 4. Improve coverage

Target 100%. For each uncovered file/function, write tests for real behavior — happy path, edge cases, errors — then re-run coverage and confirm the number moved.

## 5. Verify and report

Run the full type-check and full test suite again. Report, as deltas from the start of this run:
- TypeScript errors: X → Y
- Test failures: X → Y
- Coverage: X% → Y%

**Exit only if at least one metric improved** (or is already at target: 0 errors, 0 failures, 100% coverage). If nothing moved, the task isn't done — go back and fix something.

## Rules

- TypeScript before tests, always.
- Verify after every single fix, not in batches.
- No `any` — `unknown` plus type guards.
- Import schemas, never redefine them.
- Blocked on one issue? Fix a different one — always make progress somewhere.
- Smallest fix that resolves the issue; don't refactor unrelated code.
- "Pre-existing" is not an excuse — fix it anyway.
- Repeated runs must converge toward 0 errors, 0 failures, 100% coverage.
