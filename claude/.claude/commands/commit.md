---
description: Create strictly atomic commits - one logical change per commit
allowed-tools: Bash(git:*), Read, Grep, Glob
---

DELEGATE THIS TASK TO git-specialist USING THE TASK TOOL.

Do NOT perform this task directly. Invoke git-specialist with the following prompt:

---

Create strictly atomic commits for all pending changes. ONE logical change per commit, no exceptions.

## Atomicity Rules (NON-NEGOTIABLE)

**ONE commit = ONE logical change:**
- Each file modification serving a distinct purpose = separate commit
- If commit message needs "and", "also", commas = TOO BIG, split it
- New feature + tests for that feature = acceptable in one commit
- New feature + docs + config = THREE commits minimum

**Splitting heuristics:**
- New file = its own commit (unless part of single feature)
- Config change = its own commit
- Documentation update = its own commit
- Refactor = separate from feature work
- Test additions = can accompany implementation OR be separate (never with unrelated changes)

## Prohibited Anti-Patterns

❌ "Add X, Y, and Z" commits
❌ Bundling docs with code changes (unless docs are for that exact code)
❌ Bundling config with feature work
❌ "Various improvements" or "Multiple fixes"
❌ "Update files" or generic messages
❌ Mixing refactor with new features

## Required Process

1. **Analyze ALL changes first** (git status, git diff)
2. **Create explicit commit plan** listing each commit BEFORE executing:

   Creating N commits:
   1. feat(api): add user authentication endpoint
   2. test(api): add authentication tests
   3. docs(api): document authentication flow
   4. chore(config): update API base URL
3. **If >5 commits needed**: Present plan and wait for confirmation before executing
4. **Execute commits one at a time** in planned order
5. **Report completion**: List all created commits with SHAs

## Conventional Commit Format

type(scope): imperative description

[optional body explaining WHY]

[optional footer: breaking changes, references]

**Types**: feat, fix, docs, refactor, test, chore, style, perf, ci, build

**Breaking changes**: Add ! after scope. Example: feat(api)!: change response format

**Message guidelines:**
- Imperative mood: "add feature" not "added feature"
- Explain WHY not just WHAT
- Lowercase after colon
- No period at end of subject
- Subject ≤50 chars, body ≤72 chars per line

## Examples of Correct Atomicity

✅ **Separate commits:**

1. feat(auth): add JWT token generation
2. test(auth): add JWT token tests
3. docs(auth): document token lifecycle
4. chore(env): add JWT_SECRET to env template

✅ **Feature with tests (acceptable single commit):**

feat(payment): add Stripe integration

Implements payment processing with Stripe API.
Includes validation, error handling, and webhook support.
Tests cover success and error cases.

❌ **Wrong - bundling unrelated changes:**

feat(api): add user endpoints, update config, fix typos

Added GET/POST/DELETE for users, updated CORS settings,
fixed spelling in README.

## Never Commit

- Secrets, credentials, API keys
- node_modules, package-lock.json (unless intentional dependency update)
- Generated files (.DS_Store, thumbs.db, *.log)
- Large binaries (>1MB without justification)
- Personal editor configs (.vscode, .idea) unless team standard

## If Changes Cannot Be Cleanly Separated

**STOP and explain:**
1. What changes exist
2. Why they cannot be separated
3. Proposed alternatives
4. Request user guidance

**Example blocking scenario:**
"Files A, B, C are tightly coupled - changing A requires simultaneous changes to B and C to maintain working state. Recommend: single commit with detailed explanation, or refactor coupling first."

---

Execute this process with discipline. Atomic commits create reviewable, revertable, bisectable history.
