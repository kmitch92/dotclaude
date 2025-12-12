---
description: Create granular atomic commits with conventional commit format
allowed-tools: Bash(git:*), Read, Grep, Glob
---

DELEGATE THIS TASK TO git-specialist USING THE TASK TOOL.

Do NOT perform this task directly. Invoke git-specialist with the following prompt:

---

Create granular, atomic commits for all pending changes following conventional commits best practices.

Guidelines:
- Analyze all pending changes (staged and unstaged)
- Group changes by logical unit (single feature, fix, or refactor per commit)
- Stage only relevant files for each commit
- Use conventional commit format: type(scope): description
- Message explains why not just what
- Use imperative mood

Commit types: feat, fix, docs, refactor, test, chore, style, perf, ci, build

Breaking changes: Add ! after scope. Example: feat(api)!: change response format

Never commit: Secrets, credentials, node_modules, generated files, large binaries

If changes cannot be cleanly separated, explain why and propose alternatives.
