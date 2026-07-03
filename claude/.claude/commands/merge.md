---
description: Resolve git merge conflicts intelligently after pulling from main
allowed-tools: Bash(git:*), Read, Edit, Grep, Glob, AskUserQuestion
---

Resolve merge conflicts after pulling from main, attempting automatic resolution where safe and asking for user guidance on complex conflicts.

## Phase 1: Conflict Detection

### 1.1 Identify All Conflicted Files
```bash
git status --porcelain | grep '^UU'
```

Extract list of files with merge conflicts. If no conflicts found, report that merge is already clean and exit.

### 1.2 Categorize Conflicts by File Type

Group files into categories:
- **Configuration files**: package.json, tsconfig.json, .eslintrc, etc.
- **Documentation**: README.md, *.md
- **Source code**: *.ts, *.tsx, *.js, *.jsx
- **Schema definitions**: Files containing Zod schemas
- **Test files**: *.test.ts, *.spec.ts
- **Other**: Everything else

## Phase 2: Conflict Analysis & Resolution

For EACH conflicted file in priority order (config → schemas → source → tests → docs → other):

### 2.1 Read Conflicted File
Use Read tool to examine the entire file with conflict markers:
```
<<<<<<< HEAD
Current branch version
=======
Incoming changes from main
>>>>>>> main
```

### 2.2 Analyze Both Versions

For each conflict block, determine:
- **Change type**: Addition, deletion, modification, refactor
- **Scope of change**: Lines affected, logical units changed
- **Intent**: What was the purpose of each change?

### 2.3 Classify Conflict Severity

**AUTO-RESOLVABLE (Low Severity)**:
- Both sides added non-overlapping imports
- Both sides added different functions/methods
- Both sides added different properties to different objects
- Whitespace-only differences
- Comment additions in different locations
- Both sides added different test cases
- Different additions to arrays/lists (append both)

**ASK USER (High Severity - Serious Conflicts)**:
- **Same function/method modified differently** - Different logic for same operation
- **Same variable/property renamed differently** - Naming conflicts
- **Conflicting type definitions** - Same type defined with different shapes
- **Contradictory schema changes** - Same field with different validation rules
- **Breaking changes on both sides** - API signature changed in incompatible ways
- **Conflicting dependency versions** - package.json version conflicts
- **Logic conflicts** - Same conditional/business logic changed differently
- **Deletion vs modification** - One side deletes, other side modifies same code
- **Configuration conflicts** - Same setting changed to different values

### 2.4 Resolution Strategy

**For AUTO-RESOLVABLE conflicts:**
1. Preserve BOTH changes when non-overlapping
2. Merge additive changes intelligently:
   - Combine imports alphabetically
   - Include all added functions/methods
   - Merge object properties from both sides
   - Concatenate array additions
3. Apply resolution using Edit tool
4. Mark conflict as resolved

**For SERIOUS conflicts:**
1. Use AskUserQuestion to present:
   - File path and line numbers
   - Current branch version (with context)
   - Incoming version from main (with context)
   - Explanation of why automatic resolution is unsafe
   - Clear question: "Which version should be kept, or should they be manually combined?"

2. Wait for user response with options:
   - "current" - Keep current branch version
   - "incoming" - Accept incoming changes from main
   - "both" - User will manually edit (skip to next conflict)
   - "manual:[specific instruction]" - User provides merge strategy

3. Apply user's choice using Edit tool

### 2.5 Verify Resolution

After resolving all conflicts in a file:
```bash
git add <file-path>
```

Confirm file is staged and no longer in conflict status.

## Phase 3: Complete Merge Verification

### 3.1 Verify All Conflicts Resolved
```bash
git status
```

Confirm:
- No files remain with "UU" status
- All conflicted files are now staged
- Working directory is clean except for staged merge resolution

### 3.2 Detect Package Manager & Run Type Checks

Check for lock files in priority order:
- `pnpm-lock.yaml` → use pnpm
- `yarn.lock` → use yarn
- `package-lock.json` → use npm

Run type check:
```bash
<pkg-manager> run type-check || <pkg-manager> run typecheck || npx tsc --noEmit
```

If type errors found:
- Report count and sample errors
- Ask user if they want to proceed with merge or fix types first

### 3.3 Run Test Suite (if available)

Detect test script in package.json:
```bash
<pkg-manager> test
```

If tests fail:
- Report count of failures
- Show first few failing test names
- Ask user if they want to proceed with merge or fix tests first

### 3.4 Final Merge Completion

If types pass and tests pass (or user approves proceeding despite failures):
```bash
git commit --no-edit
```

Complete the merge with default merge commit message.

Report final status:
- Total conflicts resolved: X
- Auto-resolved: Y
- User-guided: Z
- Files modified: [list]
- Type check: PASS/FAIL
- Tests: PASS/FAIL/SKIPPED

## Critical Rules

1. **Never auto-resolve serious conflicts** - When in doubt, ask the user

2. **Preserve functionality from BOTH sides when possible** - Favor inclusive merges over deletions

3. **Read full file context** - Don't just look at conflict markers, understand surrounding code

4. **Respect configuration files** - Package.json, tsconfig, etc. always require user input for version conflicts

5. **Schema conflicts are serious** - Different validation rules must be user-resolved

6. **Test file conflicts usually safe** - Different test additions can typically be merged

7. **Import conflicts usually safe** - Combine imports from both sides, deduplicate

8. **Breaking changes require user input** - API signature changes, public interface modifications

9. **Document decisions** - When asking user, explain why automatic resolution is unsafe

10. **Verify before completing** - Always run type check and tests after resolution

## Examples of Conflict Types

### AUTO-RESOLVABLE: Non-overlapping imports
```typescript
<<<<<<< HEAD
import { foo } from './foo';
import { bar } from './bar';
=======
import { baz } from './baz';
import { qux } from './qux';
>>>>>>> main
```
**Resolution**: Combine all imports alphabetically

### AUTO-RESOLVABLE: Different function additions
```typescript
<<<<<<< HEAD
export const calculateTotal = (items: Item[]) => { /* ... */ };
=======
export const validateOrder = (order: Order) => { /* ... */ };
>>>>>>> main
```
**Resolution**: Include both functions

### SERIOUS: Same function modified differently
```typescript
<<<<<<< HEAD
export const processPayment = (amount: number) => {
  if (amount <= 0) throw new Error('Invalid amount');
  return chargeCard(amount);
};
=======
export const processPayment = (amount: number, currency: string) => {
  if (amount < 0) throw new Error('Negative amount');
  return chargeCard(amount, currency);
};
>>>>>>> main
```
**Resolution**: ASK USER - Different signatures and validation logic

### SERIOUS: Schema conflict
```typescript
<<<<<<< HEAD
const UserSchema = z.object({
  email: z.string().email(),
  age: z.number().min(0)
});
=======
const UserSchema = z.object({
  email: z.string().email(),
  age: z.number().min(18)
});
>>>>>>> main
```
**Resolution**: ASK USER - Different validation rules for age field

### AUTO-RESOLVABLE: Test additions
```typescript
<<<<<<< HEAD
it('should validate email format', () => { /* ... */ });
=======
it('should reject invalid age', () => { /* ... */ });
>>>>>>> main
```
**Resolution**: Include both test cases

## Edge Cases

**Empty conflict (whitespace only)**: Choose either side, they're equivalent

**Deleted file vs modified file**: ASK USER - One branch deleted, other modified

**Binary file conflict**: ASK USER - Cannot auto-merge, must choose version

**Renamed file conflict**: ASK USER - Same file renamed differently on both branches

**Large conflicts (>50 lines)**: ASK USER - Too complex for automatic resolution

**Multiple conflicts in same function**: ASK USER - Interleaved changes require careful review
