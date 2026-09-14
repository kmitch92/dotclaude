---
name: cruft
description: Find or delete unused exports, with delete mode verified by type-check/test and auto-reverted on failure
disable-model-invocation: true
argument-hint: [report|delete]
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Bash(git:*), Read, Write, Edit, Grep, Glob
---

Find unused exports ("cruft"). Default mode is `report` (read-only). `delete` mode ($ARGUMENTS = `delete`) removes them destructively, with verification and auto-revert.

## Discover (both modes)

1. Find exports: Grep for `export\s+(const|function|class|type|interface|default|{|\*)` across `*.ts(x)`/`*.js(x)`.
2. For each, search the rest of the codebase for any import of it (named, default, namespace, aliased, type-only, dynamic, `require`).
3. Exclude from consideration: entry points (`index.ts`, `main.ts`, `_app.tsx`), config files, API route handlers, test-setup files, barrel re-exports (`export * from`), anything tagged `@public`/`@exported`/`@api`, framework special exports (e.g. `getServerSideProps`).
4. Classify each unmatched export:
   - **HIGH**: no imports anywhere, concrete implementation (const/function/class), not excluded above.
   - **MEDIUM**: no imports, but type-only or plausibly used dynamically.
   - **LOW**: no imports, but name/location suggests runtime discovery (hooks, string-built import paths).

## Mode: report (default)

Print a report grouped by confidence then directory: file:line, export name, type, one-line reason. Summarize counts per confidence level. If HIGH items exist, note that `delete` mode can remove them; MEDIUM/LOW need manual review — never delete these.

## Mode: delete

Only act on HIGH-confidence items.

1. Require a clean working tree (`git status --porcelain` empty) — otherwise stop and tell the user to commit or stash first.
2. Create a safety branch: `git checkout -b cruft-cleanup-$(date +%Y%m%d-%H%M%S)`.
3. Remove each HIGH item: delete the export statement/declaration; if the file becomes empty (only whitespace/comments/imports left), delete the file instead. Never touch re-exports (`export * from`).
4. Commit: `chore: remove unused exports (automated cruft cleanup)`, listing counts and files.
5. Run type-check and the full test suite.
6. If any failure references a deleted export/file by name, it's a false positive: revert (`git reset --hard HEAD~1`, switch back, delete the cleanup branch), report the false positives and why deletion looked safe, and stop.
7. If clean: report items deleted, files removed, verification results, and the branch name for the user to review/merge/discard.

## Safety rules

- Never delete MEDIUM/LOW items.
- Never work directly on main/master — always the safety branch.
- Always verify with type-check plus full test suite before declaring success.
- Always auto-revert on any related failure.
- Never proceed on a dirty working tree.
