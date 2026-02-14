---
description: Delete unused exports (cruft) with typetest verification and auto-revert
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Bash(git:*), Read, Write, Edit, MultiEdit, Grep, Glob, Skill
model: sonnet
---

Delete unused exports (cruft) with automated verification and safety rollback. This is DESTRUCTIVE and will modify/delete code.

## Prerequisites Check

### 1. Verify Clean Working Tree

```bash
git status --porcelain
```

**If output is not empty:**
- Print error: "Working directory has uncommitted changes. Commit or stash changes before running /crufthard."
- STOP execution - do NOT proceed

### 2. Detect Package Manager

Check for lock files in order:
- `pnpm-lock.yaml` → use `pnpm`
- `yarn.lock` → use `yarn`
- `package-lock.json` → use `npm`

Store detected package manager for typetest execution.

## Phase 1: Discover & Analyze (Same as cruftsoft)

Execute identical export discovery and import checking as `/cruftsoft`:

1. **Find all exports** using Grep with pattern: `export\s+(const|function|class|type|interface|default|{|\*)`
2. **Check for imports** for each export using comprehensive regex patterns
3. **Evaluate confidence** level (HIGH/MEDIUM/LOW)
4. **Filter to HIGH confidence only** - discard MEDIUM and LOW from deletion list

**Store in memory:**
- List of HIGH confidence cruft items with: file path, line number, export name, export type
- List of MEDIUM/LOW confidence items (for reporting only, not deletion)

If NO HIGH confidence items found:
- Print: "No HIGH confidence cruft found. MEDIUM/LOW confidence items require manual review."
- Output MEDIUM/LOW items as report
- STOP execution

## Phase 2: Create Safety Branch

Delegate to git-specialist agent or execute directly:

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
git checkout -b cruft-cleanup-$TIMESTAMP
```

Store branch name for later reference.

## Phase 3: Delete Cruft

For each HIGH confidence cruft item:

### 3.1 Read Source File

Use Read tool to get current file content.

### 3.2 Remove Export Statement

**Handle different export types:**

**Single-line exports:**
- `export const NAME = ...;` → Delete entire line
- `export function NAME() { ... }` → Delete function declaration
- `export class NAME { ... }` → Delete class declaration
- `export type NAME = ...;` → Delete entire line
- `export interface NAME { ... }` → Delete interface declaration
- `export default NAME;` → Delete entire line

**Multi-line exports:**
- For function/class exports, delete from `export` keyword to closing brace
- Use Edit tool with precise old_string/new_string match

**Named export lists:**
- `export { NAME1, NAME2 };` → If removing NAME1, edit to `export { NAME2 };`
- `export { NAME };` → If only export in list, delete entire line
- `export { NAME as ALIAS };` → Handle aliased exports

**Re-exports (DO NOT DELETE):**
- `export * from './module'` → Skip (these are barrel files, not cruft)
- `export * as namespace from './module'` → Skip

### 3.3 Check If File Now Empty

After removing export:
1. Read file again
2. Check if file contains only whitespace/comments
3. If empty or only comments/imports remain:
   - Delete entire file using Bash: `rm file_path`
   - Track as "file deleted" rather than "export deleted"

### 3.4 Track Deletion

Store in deletion log:
- File path
- Line number (original)
- Export name
- Export type
- Action: "export removed" or "file deleted"

## Phase 4: Commit Changes

Delegate to git-specialist or execute directly:

```bash
git add -A
git commit -m "chore: remove unused exports (automated cruft cleanup)

Deleted X unused exports across Y files using /crufthard.
All items were HIGH confidence (no imports found in codebase).

Files modified: Z
Files deleted: W

This commit will be reverted if typetest finds issues."
```

## Phase 5: Verification with Typetest

### 5.1 Run Typetest

Execute `/typetest` using Skill tool:

```
Skill: typetest
```

This will:
- Run TypeScript type checking
- Run full test suite
- Return errors and failures

### 5.2 Capture Output

Store ALL output from typetest:
- TypeScript errors: file paths, line numbers, error messages, error codes
- Test failures: test file paths, test names, failure reasons

## Phase 6: False Positive Detection

### 6.1 Parse Errors for Deleted Exports

For EACH TypeScript error and test failure:

**Check if error references deleted export:**
- Error message contains deleted export name (exact word boundary match)
- Error file path matches deleted file path
- Import statement error mentioning deleted export
- "Cannot find module" error for deleted file

**If match found:**
- Mark as FALSE POSITIVE
- Add to false positive list with:
  - Deleted export name
  - Error message
  - Error file path
  - Error type (TypeScript or test)

### 6.2 Evaluate Results

**If false positives found:**
- Proceed to Phase 7 (Revert)

**If NO false positives found:**
- Proceed to Phase 8 (Success Report)

## Phase 7: Revert on False Positives

### 7.1 Revert Commit

Delegate to git-specialist or execute directly:

```bash
git reset --hard HEAD~1
git checkout main  # or original branch
git branch -D cruft-cleanup-$TIMESTAMP
```

### 7.2 Generate False Positive Report

```
# Cruft Cleanup REVERTED - False Positives Detected

## Summary
- HIGH confidence items analyzed: N
- Items deleted: M
- False positives found: X
- Changes REVERTED

## False Positives

The following exports appeared unused but caused errors when deleted:

### src/utils/helper.ts:15 - helperFunction
  Error: TS2304: Cannot find name 'helperFunction'
  Location: src/app/main.ts:42
  Reason: Likely dynamic import or indirect usage

### src/types/models.ts:8 - UserModel
  Error: Test failure in user.test.ts
  Location: src/__tests__/user.test.ts:12
  Reason: Used in test file not detected by import search

## Root Cause Analysis

False positives likely due to:
- Dynamic imports using string concatenation
- Framework-specific usage patterns
- Test framework implicit imports
- Type-only imports not detected

## Recommendation

Manually review the false positive items to determine if they are truly needed.
Consider adding JSDoc @public tag to intentionally exported items.
```

**Print report and STOP**

## Phase 8: Success Report

### 8.1 Generate Success Report

```
# Cruft Cleanup SUCCESS

## Summary
- HIGH confidence items deleted: N
- Exports removed: X
- Files modified: Y
- Files deleted: Z
- TypeScript errors: 0
- Test failures: 0
- False positives: 0

## Deleted Items

### src/utils/
✓ src/utils/deprecated.ts:15 - calculateLegacy (const)
  Reason: No imports found

✓ src/utils/old-helpers.ts:8 - formatOldWay (function)
  Reason: No imports found

✓ src/utils/unused.ts (ENTIRE FILE DELETED)
  Reason: All exports were unused

### src/components/
✓ src/components/OldButton.tsx:5 - OldButton (const)
  Reason: No imports found

## Skipped Items (MEDIUM/LOW Confidence)

Review these manually if desired:

### src/types/
[MEDIUM] src/types/legacy.ts:12 - OldUserType (interface)
  Reason: No imports found, but type-only export

[LOW] src/hooks/experimental.ts:7 - useExperimental (function)
  Reason: No imports found, but name suggests framework usage

## Verification Results

✓ TypeScript compilation: PASSED
✓ Test suite: PASSED
✓ No references to deleted exports found

## Next Steps

Changes are on branch: cruft-cleanup-$TIMESTAMP

To merge:
  git checkout main
  git merge cruft-cleanup-$TIMESTAMP

To review first:
  git diff main..cruft-cleanup-$TIMESTAMP

To discard:
  git checkout main
  git branch -D cruft-cleanup-$TIMESTAMP
```

### 8.2 Print Report

Output the complete success report to user.

## Critical Safety Rules

1. **NEVER delete MEDIUM or LOW confidence items** - only HIGH confidence
2. **ALWAYS create safety branch** - never work on main/master
3. **ALWAYS run typetest** - verify deletions don't break build
4. **ALWAYS auto-revert** - if typetest fails with related errors, revert immediately
5. **NEVER proceed if working tree is dirty** - require clean state
6. **Track ALL deletions** - comprehensive log for debugging
7. **Provide both reports** - deleted items AND skipped items (MEDIUM/LOW)

## Edge Cases to Handle

**Multi-export files:**
- If file has 5 exports and 3 are unused, only remove the 3 unused ones
- Do NOT delete file unless ALL exports are removed

**Exported then re-exported:**
- `export { NAME } from './other'` in barrel file - do NOT delete from barrel
- Only delete from original source if not re-exported anywhere

**Default exports:**
- `export default function Component() {}` - delete entire function
- `const X = ...; export default X;` - delete both const and export

**Type-only exports:**
- Even if HIGH confidence, be extra careful with pure type exports
- TypeScript may use types implicitly without import statements

**Test utilities:**
- Exports in `test-utils.ts`, `setupTests.ts` should be LOW confidence
- Test frameworks may import without explicit import statements

## Performance Considerations

- Use Edit tool for single-line deletions (faster than rewriting entire file)
- Use Write tool for multi-line deletions or file rewrites
- Batch file operations where possible
- Limit to reasonable number of deletions per run (<100 items)

## Reporting Format Requirements

**Comprehensive Skipped Items Section REQUIRED:**

Every run MUST include "Skipped Items" section showing MEDIUM and LOW confidence exports that were NOT deleted:

```
## Skipped Items (MEDIUM/LOW Confidence)

These exports appear unused but were not deleted due to lower confidence.
Review manually if desired:

### src/types/ (MEDIUM Confidence)
[MEDIUM] src/types/legacy.ts:12 - OldUserType (interface)
  Reason: No imports found, but type-only export may have indirect usage
  Analysis: Types can be used implicitly by TypeScript without explicit imports

[MEDIUM] src/schemas/old.ts:5 - oldSchema (const)
  Reason: No imports found, but exported from schema file
  Analysis: May be used for runtime validation in ways not detected by static analysis

### src/hooks/ (LOW Confidence)
[LOW] src/hooks/experimental.ts:7 - useExperimental (function)
  Reason: No imports found, but name pattern suggests framework usage
  Analysis: React hooks may be dynamically discovered by build tools

[LOW] src/utils/dynamic.ts:15 - dynamicHelper (function)
  Reason: Possible dynamic import patterns detected in codebase
  Analysis: String concatenation in import statements suggests runtime usage
```

**Purpose:**
- Enables user to follow up on MEDIUM/LOW items if desired
- Provides analysis explaining WHY each item was skipped
- Groups by confidence level and directory for easy review
- Shows comprehensive view of all potential cruft, not just deleted items

This ensures transparency and helps users make informed decisions about manual cleanup.

Execute this process with extreme care. Automated deletion requires robust verification to avoid breaking changes.
