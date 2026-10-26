---
name: cruft
description: Find exports that nothing uses, or remove them. `delete` mode: type-check or test makes sure the result is correct, and a revert occurs automatically on failure
disable-model-invocation: true
argument-hint: [report|delete]
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Bash(git:*), Read, Write, Edit, Grep, Glob
---

Find exports that nothing uses ("cruft"). Default mode is `report` (read-only). `delete` mode ($ARGUMENTS = `delete`) removes them fully, with verification and an automatic revert.

## Discover (both modes)

1. Find exports: Grep for `export\s+(const|function|class|type|interface|default|{|\*)` across `*.ts(x)`/`*.js(x)`.
2. Examine the remaining code in the codebase for an import of each export. Count each type below as an import:
   - a named import
   - a default import
   - a namespace import
   - an aliased import
   - a type-only import
   - a dynamic import
   - a `require` call
3. Do not count these as cruft:
   - entry points (`index.ts`, `main.ts`, `_app.tsx`)
   - config files
   - API routing handlers
   - test-setup files
   - barrel re-exports (`export * from`)
   - an export tagged `@public`, `@exported`, or `@api`
   - framework special exports, for example `getServerSideProps`
4. Sort each unmatched export into HIGH, MEDIUM, or LOW confidence:
   - **HIGH**: no imports anywhere. It is a concrete `const`, `function`, or `class`, and step 3 does not name it.
   - **MEDIUM**: no imports, but type-only or plausibly used dynamically.
   - **LOW**: no imports, but the name or location suggests the code uses runtime discovery (hooks, or string-built import paths).

## Mode: report (default)

Print a report. Group it first by confidence. Group each confidence group next by directory. For each export, give the file, the line, the export name, the type, and the cause in one line.

Give the count of exports at each confidence level.

`delete` mode can remove a HIGH item. A person must examine a MEDIUM or LOW item first. Never delete a MEDIUM or LOW item.

## Mode: delete

Only act on HIGH-confidence items.

1. Check that the working tree is clean (`git status --porcelain` empty).
2. Stop if the tree is not clean. Tell the user to commit or save the changes first.
3. Make a safety branch: `git checkout -b cruft-cleanup-$(date +%Y%m%d-%H%M%S)`.
4. Delete the export statement or declaration for each HIGH item.
5. Delete the file, if it becomes empty (only white space, comments, or imports are left). Never touch a re-export (`export * from`).
6. Save the change with a commit: `chore: remove unused exports (automated cruft cleanup)`, listing counts and files.
7. Run type-check and the full test suite.
8. Revert the change (`git reset --hard HEAD~1`), if a failure names a deleted export or file.
9. Go back to the initial branch.
10. Delete the cleanup branch.
11. Give the incorrect deletions, with the cause they looked safe. Stop.
12. Give the deleted items, the removed files, and the check results, when the result is clean.
13. Give the branch name to the user, so they can examine, merge, or discard it.

## Safety rules

- Never delete a MEDIUM or LOW item.
- Never work directly on `main` or `master`. Always work on the safety branch.
- Always make sure with type-check and the full test suite before you report success.
- Always revert on a related failure, with no step from the user.
- Never continue on a working tree that is not clean.
