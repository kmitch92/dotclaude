---
description: Create granular atomic commits with conventional commit format
allowed-tools: Bash(git:*), Read, Grep, Glob
---

Create granular, atomic commits for all pending changes following conventional commits best practices.

## Process

1. **Analyze pending changes:**
   ```bash
   git status
   git diff --stat
   git diff
   ```

2. **Group changes by logical unit:**
   - Single feature, fix, or refactor per commit
   - File/module scope where appropriate
   - Conventional commit type: feat, fix, docs, refactor, test, chore, style, perf, ci, build

3. **For each logical group, create an atomic commit:**
   - Stage only relevant files: `git add <specific files>`
   - Commit with conventional format: `type(scope): description`
   - Message explains "why" not just "what"
   - Use imperative mood ("add feature" not "added feature")

4. **Continue until all changes committed**

5. **Verify and summarize:**
   ```bash
   git status
   git log --oneline -n <number of commits created>
   ```

## Commit Guidelines

**Atomic commits:**
- Each commit could be reverted independently
- Each commit represents one logical change
- Never combine unrelated changes
- Prefer many small commits over few large ones

**Conventional commit format:**
```
type(scope): short description

[optional body explaining why]

[optional footer for breaking changes]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code change that neither fixes bug nor adds feature
- `test`: Adding or correcting tests
- `chore`: Maintenance tasks, dependencies
- `style`: Formatting, whitespace (no code change)
- `perf`: Performance improvement
- `ci`: CI/CD changes
- `build`: Build system or external dependencies

**Breaking changes:**
- Use `!` suffix: `feat(api)!: change response format`
- Or add footer: `BREAKING CHANGE: description`

**Never commit:**
- Secrets, credentials, API keys
- node_modules, vendor directories
- Generated files (.js from .ts, build output)
- Large binary files
- IDE/editor config (unless shared)

## Edge Cases

**If changes are intermingled and cannot be cleanly separated:**
1. Explain why separation is difficult
2. Propose alternatives:
   - Use `git add -p` for partial staging
   - Accept a slightly larger commit with clear explanation
   - Suggest refactoring approach for future

**If only one logical change exists:**
- Create single commit (that's fine)
- Don't artificially split coherent changes

**If changes include both staged and unstaged:**
- Handle staged changes first
- Then process unstaged changes
