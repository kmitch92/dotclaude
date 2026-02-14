---
description: Progressive sweep demanding improvement in TypeScript errors, test failures, and coverage until targets are met
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Bash(tsc:*), Read, Write, Edit, MultiEdit, Grep, Glob
---

Perform a full sweep of the project for TypeScript errors and test failures, then incrementally fix all issues.

## Phase 1: Discovery

### 1.1 Detect Package Manager
Check for lock files in priority order:
- `pnpm-lock.yaml` → use pnpm
- `yarn.lock` → use yarn
- `package-lock.json` → use npm

### 1.2 Run TypeScript Check
Execute TypeScript compiler in check mode:
```bash
# Try package.json script first
<pkg-manager> run type-check || <pkg-manager> run typecheck || npx tsc --noEmit
```

Capture ALL TypeScript errors. Parse each error to extract:
- File path
- Line number
- Error code (e.g., TS2345)
- Error message

### 1.3 Run Test Suite
Detect and run test framework:
```bash
# Check package.json for test script, then run
<pkg-manager> test
# Or detect framework: vitest, jest, etc.
```

Capture ALL test failures. Parse each failure to extract:
- Test file path
- Test name/description
- Failure reason
- Stack trace

### 1.4 Run Coverage Check
Execute test coverage measurement:
```bash
<pkg-manager> test -- --coverage
```

Capture coverage metrics:
- Statement coverage %
- Branch coverage %
- Function coverage %
- Line coverage %
- Uncovered files list

### 1.5 Build Task List
Use TodoWrite to create task list of all issues:
- Group TypeScript errors by file
- Group test failures by file
- List coverage gaps (uncovered files/functions)
- TypeScript errors MUST be listed before test failures (priority order)

## Phase 2: TypeScript Fixes (PRIORITIZED FIRST)

TypeScript errors MUST be fixed before test failures. Type errors often cause cascading test failures.

For EACH TypeScript error:

1. **Read affected file** - Understand full context around the error

2. **Analyze error** - Determine root cause:
   - Type mismatch
   - Missing type annotation
   - Incorrect generic usage
   - Null/undefined handling
   - Schema validation issue

3. **Apply fix following strict standards**:
   - NO `any` types - use `unknown` with type guards instead
   - Proper Zod schema usage where schemas exist
   - Strict mode compliance (strictNullChecks, etc.)
   - Branded types for IDs where appropriate (e.g., `UserId`, `OrderId`)
   - Import real schemas from codebase - NEVER redefine schemas
   - Use type narrowing and guards over assertions

4. **Verify fix**:
   ```bash
   npx tsc --noEmit
   ```
   Confirm the specific error is resolved

5. **Update task list** - Mark error as resolved

6. **Proceed to next error** - Do not batch fixes; verify each individually

## Phase 3: Test Fixes

After ALL TypeScript errors are resolved, address test failures.

For EACH failing test:

1. **Read test file** - Understand what behavior is being tested

2. **Diagnose failure cause**:
   - **Missing implementation**: Production code needs to be written/updated
   - **Incorrect expectation**: Test assertion needs updating
   - **Type mismatch**: Phase 2 fixes changed signatures
   - **Mock/stub issue**: Test doubles need updating
   - **Async issue**: Missing await, timing problems

3. **Apply appropriate fix**:
   - For missing implementation: Write minimum code to pass (TDD green phase)
   - For incorrect expectation: Update test to match correct behavior
   - For type issues: Update types to align with implementation
   - Maintain behavioral testing - test outcomes not implementation

4. **Verify fix** - Run specific test:
   ```bash
   <pkg-manager> test -- --testPathPattern="<test-file>" --testNamePattern="<test-name>"
   ```

5. **Update task list** - Mark test as resolved

6. **Proceed to next failure**

## Phase 3.5: Coverage Improvement

After ALL test failures are resolved, improve test coverage.

### Target: 100% Coverage

For EACH uncovered file/function:

1. **Read uncovered code** - Understand what behavior needs testing

2. **Write missing tests following TDD principles**:
   - Test behavior through public APIs
   - Cover happy paths and edge cases
   - Test error conditions
   - Use realistic test data

3. **Verify coverage improvement**:
   ```bash
   <pkg-manager> test -- --coverage
   ```
   Confirm coverage increased for that file/function

4. **Update task list** - Mark coverage gap as resolved

5. **Proceed to next uncovered area**

## Phase 4: Verification

### 4.1 Full TypeScript Check
```bash
npx tsc --noEmit
```
Confirm: **0 errors**

### 4.2 Full Test Suite
```bash
<pkg-manager> test
```
Confirm: **All tests pass**

### 4.3 Measure Improvement

Calculate deltas from start of execution:
- TypeScript errors: start → end (must decrease or reach 0)
- Test failures: start → end (must decrease or reach 0)
- Coverage: start% → end% (must increase or reach 100%)

### 4.4 Exit Criteria (MANDATORY)

**You may ONLY finish if AT LEAST ONE of:**
- TypeScript errors decreased (or already 0)
- Test failures decreased (or already 0)
- Coverage increased (or already 100%)

**If all metrics unchanged**: You have NOT completed the task. Return to Phase 2/3/3.5 and make more progress.

### 4.5 Report Summary
Provide final status:
- TypeScript errors: X → Y (delta: -N)
- Test failures: X → Y (delta: -N)
- Coverage: X% → Y% (delta: +N%)
- Files modified
- Next priority items for subsequent invocation (if not at 0/0/100%)

## Critical Rules

1. **Order matters**: TypeScript errors BEFORE test failures. Types affect tests.

2. **Incremental verification**: After EACH fix, verify before proceeding. Do not batch.

3. **Use TodoWrite**: Track all issues and progress. Update status after each fix.

4. **No `any` types**: Use `unknown` + type guards. No exceptions.

5. **Import real schemas**: Never redefine Zod schemas in fixes. Import from source.

6. **Strict mode compliance**: All fixes must satisfy TypeScript strict mode.

7. **If blocked on one issue**: Move to next item. You MUST make progress somewhere. Return to blocked items. If truly stuck on ALL items, fix something else - add a test, improve coverage, fix a different error.

8. **Ask only when necessary**: If fix approach is unclear, try the most conservative fix first. Only ask user if you've attempted fixes and failed. Default to action, not questions.

9. **Behavioral testing**: When fixing tests, ensure tests verify behavior through public APIs, not implementation details.

10. **Minimum changes**: Apply smallest fix that resolves the issue. Do not refactor unrelated code.

11. **NO "pre-existing" excuses**: Every error, every failure, every coverage gap is YOUR responsibility. "This existed before my task" is NEVER acceptable. Fix it.

12. **Progressive improvement required**: Each invocation MUST improve at least one metric. If you cannot fix a specific issue, fix a different one.

13. **Coverage is mandatory**: Uncovered code is a defect. Write tests for it.

14. **Repeated invocation guarantee**: If this command is called enough times, the codebase WILL reach:
    - 0 TypeScript compilation errors
    - 0 failing tests
    - 100% test coverage

This is not aspirational. This is a guarantee the command must fulfill through progressive improvement.
