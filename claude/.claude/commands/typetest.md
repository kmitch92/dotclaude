---
description: Full TypeScript error and test suite sweep with incremental fixes
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

### 1.4 Build Task List
Use TodoWrite to create task list of all issues:
- Group TypeScript errors by file
- Group test failures by file
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

### 4.3 Report Summary
Provide final status:
- Total TypeScript errors found → fixed
- Total test failures found → fixed
- Any issues that could not be resolved (with explanation)
- Files modified

## Critical Rules

1. **Order matters**: TypeScript errors BEFORE test failures. Types affect tests.

2. **Incremental verification**: After EACH fix, verify before proceeding. Do not batch.

3. **Use TodoWrite**: Track all issues and progress. Update status after each fix.

4. **No `any` types**: Use `unknown` + type guards. No exceptions.

5. **Import real schemas**: Never redefine Zod schemas in fixes. Import from source.

6. **Strict mode compliance**: All fixes must satisfy TypeScript strict mode.

7. **If blocked**: Document the issue, move to next item, return to blocked items after completing others.

8. **Ask for clarification**: If fix approach is unclear or multiple valid approaches exist, ask user before proceeding.

9. **Behavioral testing**: When fixing tests, ensure tests verify behavior through public APIs, not implementation details.

10. **Minimum changes**: Apply smallest fix that resolves the issue. Do not refactor unrelated code.
