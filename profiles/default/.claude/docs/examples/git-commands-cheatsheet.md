# Git Commands Cheatsheet

Comprehensive reference for git version control operations following conventional commits.

## Quick Reference

| Command | Description |
|---------|-------------|
| `git status` | Show working tree status |
| `git add <file>` | Stage specific file |
| `git add .` | Stage all changes |
| `git commit -m "msg"` | Commit with message |
| `git push` | Push to remote |
| `git pull` | Fetch and merge from remote |
| `git log --oneline` | Show commit history (compact) |
| `git diff` | Show unstaged changes |
| `git diff --staged` | Show staged changes |
| `git branch` | List local branches |
| `git checkout -b <name>` | Create and switch to new branch |

## Conventional Commits

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Rules:**
- `type` is required (lowercase)
- `scope` is optional (lowercase, noun describing code section)
- `description` is required (lowercase, no period at end)
- Body and footer are optional (use for detailed explanations)

**Examples:**
```bash
git commit -m "feat(auth): add JWT token refresh mechanism"
git commit -m "fix(api): handle null response in user endpoint"
git commit -m "docs(readme): update installation instructions"
```

### Types Reference

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(payment): add Stripe integration` |
| `fix` | Bug fix | `fix(validation): prevent negative quantities` |
| `docs` | Documentation only | `docs(api): add endpoint examples` |
| `style` | Formatting, no code change | `style(header): fix indentation` |
| `refactor` | Code restructuring | `refactor(auth): extract token validation` |
| `perf` | Performance improvement | `perf(db): add index on user_id` |
| `test` | Add/update tests | `test(order): add edge case coverage` |
| `chore` | Build/tooling | `chore(deps): update dependencies` |
| `ci` | CI/CD changes | `ci(github): add deployment workflow` |

### Breaking Changes

**Using `!` suffix:**
```bash
git commit -m "feat(api)!: change response format to JSON:API spec"
```

**Using `BREAKING CHANGE` footer:**
```bash
git commit -m "$(cat <<'EOF'
feat(auth): migrate to OAuth 2.0

Replace custom auth with OAuth 2.0 standard.

BREAKING CHANGE: API endpoints now require OAuth tokens instead of API keys.
Migration guide: https://docs.example.com/oauth-migration
EOF
)"
```

## Daily Workflow

### Status and Inspection

```bash
# Show current status
git status

# Compact status
git status -s

# Show unstaged changes
git diff

# Show staged changes
git diff --staged

# Show changes for specific file
git diff path/to/file.ts

# Recent commit history (one line per commit)
git log --oneline

# Graphical commit history
git log --oneline --graph --all

# Last 5 commits with diffs
git log -5 -p

# Commits by author
git log --author="Jane Doe"

# Commits in date range
git log --since="2 weeks ago" --until="yesterday"
```

### Staging Changes

```bash
# Stage specific file
git add src/auth/login.ts

# Stage all changes in directory
git add src/auth/

# Stage all changes in project
git add .

# Stage all modified files (not new files)
git add -u

# Interactive staging (choose hunks)
git add -p src/auth/login.ts

# Stage files matching pattern
git add src/**/*.test.ts
```

### Committing

**Simple commit:**
```bash
git commit -m "feat(auth): add password reset flow"
```

**Multiline commit with HEREDOC:**
```bash
git commit -m "$(cat <<'EOF'
feat(payment): integrate Stripe checkout

- Add Stripe SDK integration
- Create checkout session endpoint
- Handle webhook events for payment confirmation

Closes #123
EOF
)"
```

**Amend last commit (message only):**
```bash
git commit --amend -m "fix(auth): handle expired tokens correctly"
```

**Amend last commit (add forgotten files):**
```bash
git add forgotten-file.ts
git commit --amend --no-edit
```

**Check authorship before amending:**
```bash
# ALWAYS verify it's YOUR commit before amending
git log -1 --format='%an %ae'
```

### Syncing with Remote

```bash
# Fetch changes from remote (doesn't merge)
git fetch

# Fetch from specific remote
git fetch origin

# Pull changes (fetch + merge)
git pull

# Pull with rebase instead of merge
git pull --rebase

# Push to remote
git push

# Push and set upstream tracking
git push -u origin feature/new-feature

# Force push (DANGEROUS - only for personal branches)
git push --force-with-lease

# NEVER force push to main/master
# If needed, warn user and get explicit confirmation
```

## Branch Management

### Creating and Switching

```bash
# Create new branch
git branch feature/add-search

# Switch to existing branch
git checkout feature/add-search

# Create and switch in one command
git checkout -b feature/add-search

# Modern syntax (Git 2.23+)
git switch feature/add-search
git switch -c feature/add-search

# Branch from specific commit
git checkout -b bugfix/old-issue abc1234
```

**Branch Naming Conventions:**
```
feature/description    - New features
fix/description        - Bug fixes
refactor/description   - Code refactoring
docs/description       - Documentation
test/description       - Test additions
chore/description      - Tooling/dependencies
```

### Listing and Cleaning

```bash
# List local branches
git branch

# List all branches (local + remote)
git branch -a

# List remote branches only
git branch -r

# List with last commit info
git branch -v

# Delete merged branch
git branch -d feature/completed-feature

# Force delete unmerged branch
git branch -D feature/abandoned-feature

# Delete remote branch
git push origin --delete feature/old-feature

# Prune deleted remote branches
git fetch --prune

# Clean up stale remote tracking branches
git remote prune origin
```

### Merging

```bash
# Merge branch into current branch
git merge feature/new-feature

# Merge with no fast-forward (create merge commit)
git merge --no-ff feature/new-feature

# Abort merge in progress
git merge --abort
```

**When to use each:**
- `git merge`: Fast-forward when possible (linear history)
- `git merge --no-ff`: Always create merge commit (preserve branch history)

## Merge Conflict Resolution

### Understanding Conflicts

**What causes conflicts:**
- Same line modified in both branches
- File deleted in one branch, modified in other
- File renamed differently in both branches

**Identifying conflicts:**
```bash
# After merge attempt with conflicts
git status
# Shows "Unmerged paths" with conflicted files

# List conflicted files
git diff --name-only --diff-filter=U
```

### Resolution Process

**Step-by-step:**

1. **Identify conflicts:**
```bash
git status
# Look for "both modified:" files
```

2. **Open conflicted file and edit:**
```bash
# Use your editor to resolve conflicts
code src/auth/login.ts
```

3. **Mark as resolved:**
```bash
git add src/auth/login.ts
```

4. **Complete merge:**
```bash
git commit -m "merge: resolve conflicts in auth module"
```

### Conflict Markers

**Example conflict:**
```typescript
<<<<<<< HEAD
const API_URL = "https://api.production.com";
=======
const API_URL = "https://api.staging.com";
>>>>>>> feature/new-api
```

**Markers explained:**
- `<<<<<<< HEAD`: Start of current branch changes
- `=======`: Separator between branches
- `>>>>>>> feature/new-api`: End of incoming branch changes

**Resolved version (choose one or combine):**
```typescript
const API_URL = process.env.API_URL || "https://api.production.com";
```

### Aborting a Merge

**When to abort:**
- Conflicts too complex to resolve now
- Need to consult team before deciding
- Merged wrong branch by mistake

```bash
# Abort merge and return to pre-merge state
git merge --abort

# Returns working directory to state before git merge
```

### Tools

**Built-in merge tool:**
```bash
git mergetool
# Opens configured merge tool (vimdiff, meld, etc.)
```

**Manual resolution best practices:**
1. Understand both changes before choosing
2. Test the resolved code
3. Run tests before completing merge
4. Document complex resolution decisions in commit message
5. Consider creating separate branch to test resolution

## Reverting and Undoing

### Unstaging Files

```bash
# Unstage specific file (keep changes)
git restore --staged src/auth/login.ts

# Unstage all files (keep changes)
git restore --staged .

# Legacy syntax (still works)
git reset HEAD src/auth/login.ts
```

### Discarding Local Changes

```bash
# Discard changes in specific file
git restore src/auth/login.ts

# Discard all local changes
git restore .

# Legacy syntax
git checkout -- src/auth/login.ts
```

### Reverting Commits

**Safe revert (creates new commit):**
```bash
# Revert last commit
git revert HEAD

# Revert specific commit
git revert abc1234

# Revert without auto-commit (review first)
git revert --no-commit abc1234

# Revert multiple commits
git revert HEAD~3..HEAD
```

**Dangerous reset (rewrites history):**
```bash
# Only use on unpushed commits or personal branches
git reset abc1234
```

### Reset Types

```bash
# Soft: Move HEAD, keep staged changes and working directory
git reset --soft HEAD~1
# Use case: Undo commit, keep changes staged for re-commit

# Mixed (default): Move HEAD, unstage changes, keep working directory
git reset --mixed HEAD~1
# Use case: Undo commit, keep changes but unstage them

# Hard: Move HEAD, discard all changes (DANGEROUS)
git reset --hard HEAD~1
# Use case: Completely undo commit and all changes
```

**Dangers:**
- `--hard` permanently deletes uncommitted work
- Never reset commits already pushed to shared branches
- Use `git revert` for public branches instead

### Recovering Lost Commits

```bash
# View reflog (local history of HEAD)
git reflog

# Example output:
# abc1234 HEAD@{0}: reset: moving to HEAD~1
# def5678 HEAD@{1}: commit: feat(auth): add login
# 9gh0123 HEAD@{2}: commit: fix(api): handle errors

# Restore lost commit
git checkout def5678

# Or create branch from it
git checkout -b recovery/lost-work def5678

# Or reset to it
git reset --hard def5678
```

## History and Inspection

### Viewing History

```bash
# One line per commit
git log --oneline

# Graphical branch visualization
git log --oneline --graph --all

# With file change stats
git log --stat

# With full diffs
git log -p

# Last N commits
git log -5

# Commits affecting specific file
git log -- path/to/file.ts

# Commits with specific message pattern
git log --grep="feat(auth)"

# Pretty format
git log --pretty=format:"%h - %an, %ar : %s"
```

### Finding Changes

**Git blame (who changed what):**
```bash
# Show who last modified each line
git blame src/auth/login.ts

# Ignore whitespace changes
git blame -w src/auth/login.ts

# Show lines 10-20
git blame -L 10,20 src/auth/login.ts

# With commit messages
git blame -s src/auth/login.ts
```

**Git bisect (binary search for bugs):**
```bash
# Start bisect session
git bisect start

# Mark current commit as bad
git bisect bad

# Mark known good commit
git bisect good abc1234

# Git checks out middle commit, test it
npm test

# If tests pass
git bisect good

# If tests fail
git bisect bad

# Repeat until git finds first bad commit
# When done
git bisect reset
```

### Comparing

```bash
# Compare working directory to last commit
git diff HEAD

# Compare two commits
git diff abc1234 def5678

# Compare branches
git diff main feature/new-feature

# Compare specific file between branches
git diff main feature/new-feature -- src/auth/login.ts

# Show files changed between commits
git diff --name-only abc1234 def5678

# Show stats
git diff --stat main feature/new-feature
```

## Stashing

### Basic Stash

```bash
# Stash all changes
git stash

# Stash with message
git stash push -m "WIP: refactoring auth module"

# List stashes
git stash list
# Output:
# stash@{0}: WIP: refactoring auth module
# stash@{1}: On main: emergency fix

# Apply most recent stash (keeps stash)
git stash apply

# Apply specific stash
git stash apply stash@{1}

# Apply and remove stash
git stash pop

# Remove stash without applying
git stash drop stash@{0}

# Clear all stashes
git stash clear
```

### Named Stashes

```bash
# Stash with descriptive message
git stash push -m "half-finished payment integration"

# Stash only staged changes
git stash push --staged

# Stash including untracked files
git stash push -u

# Stash everything including ignored files
git stash push -a
```

### Applying vs Popping

**`git stash apply`:**
- Applies stash to working directory
- Keeps stash in stash list
- Use when you want to apply same stash to multiple branches

**`git stash pop`:**
- Applies stash to working directory
- Removes stash from stash list
- Use for normal "save work, switch branches, restore work" workflow

## Rebasing

### Interactive Rebase

```bash
# Rebase last 3 commits
git rebase -i HEAD~3

# Rebase from specific commit
git rebase -i abc1234

# Rebase onto another branch
git rebase -i main
```

**Interactive rebase commands:**
```
pick abc1234 feat(auth): add login
pick def5678 fix(auth): typo
pick ghi9012 test(auth): add tests

# Commands:
# p, pick = use commit
# r, reword = use commit, edit message
# e, edit = use commit, stop to amend
# s, squash = merge with previous commit
# f, fixup = like squash, discard message
# d, drop = remove commit
```

**Example - squashing commits:**
```
pick abc1234 feat(auth): add login
fixup def5678 fix(auth): typo
fixup ghi9012 test(auth): add tests
```

### Rebase vs Merge

**Use merge when:**
- Working on shared/public branches
- Want to preserve complete history
- Multiple people collaborating on feature branch

**Use rebase when:**
- Cleaning up personal feature branch
- Want linear history
- Before merging feature to main

**Golden Rule of Rebasing:**
Never rebase commits that have been pushed to shared branches and others may have based work on.

### Fixing Up Commits

```bash
# Create fixup commit for specific commit
git commit --fixup abc1234

# Auto-squash during rebase
git rebase -i --autosquash main
```

## Troubleshooting

### Common Issues

#### "Detached HEAD"

**What it means:**
HEAD points to specific commit instead of branch. Changes made here are easily lost.

**How to fix:**
```bash
# If you want to keep changes, create branch
git checkout -b new-branch-name

# If you want to discard and return to branch
git checkout main
```

#### "Your branch is behind"

**What it means:**
Remote branch has commits you don't have locally.

**How to fix:**
```bash
# Pull changes
git pull

# Or rebase your changes on top
git pull --rebase
```

#### "Cannot push - rejected"

**What it means:**
Remote has commits you don't have. You need to integrate them first.

**How to fix:**
```bash
# Fetch and see what's different
git fetch
git log HEAD..origin/main

# Pull changes
git pull

# Resolve conflicts if any, then push
git push
```

#### "Untracked files would be overwritten"

**What it means:**
Checkout/merge would overwrite files not tracked by git.

**How to fix:**
```bash
# Stash untracked files
git stash -u

# Or commit them
git add .
git commit -m "chore: add untracked files"

# Or discard them
rm -f untracked-file.txt
```

### Recovery Scenarios

#### Accidentally Committed to Wrong Branch

```bash
# You're on main, should have been on feature branch
git log -1  # Note commit hash abc1234

# Create feature branch from current state
git checkout -b feature/correct-branch

# Go back to main and reset
git checkout main
git reset --hard HEAD~1

# Now feature/correct-branch has your commit, main doesn't
```

**Alternative using cherry-pick:**
```bash
# On wrong branch (main)
git log -1  # Note commit hash abc1234

# Switch to correct branch
git checkout feature/correct-branch

# Cherry-pick the commit
git cherry-pick abc1234

# Go back to main and undo commit
git checkout main
git reset --hard HEAD~1
```

#### Need to Undo a Push

**For shared branches (safe):**
```bash
# Create revert commit
git revert HEAD
git push
```

**For personal branches (only if nobody else has pulled):**
```bash
# Reset locally
git reset --hard HEAD~1

# Force push with lease (safer than --force)
git push --force-with-lease
```

**NEVER force push to main/master:**
If you must undo a push to main, use `git revert` to create a new commit that undoes changes.

#### Lost Work After Reset

```bash
# View reflog to find lost commit
git reflog

# Example output:
# abc1234 HEAD@{0}: reset: moving to HEAD~1
# def5678 HEAD@{1}: commit: feat(auth): important work

# Recover lost commit
git cherry-pick def5678

# Or reset to it
git reset --hard def5678

# Or create branch from it
git checkout -b recovery/important-work def5678
```

## Best Practices

### Commit Hygiene

**Atomic commits:**
- One logical change per commit
- Each commit should build and pass tests
- Makes bisecting bugs easier
- Simplifies code review

**Example - good:**
```bash
git commit -m "feat(auth): add JWT token generation"
git commit -m "feat(auth): add token validation middleware"
git commit -m "test(auth): add token lifecycle tests"
```

**Example - bad:**
```bash
git commit -m "feat(auth): add JWT stuff, fix login bug, update docs"
```

**Clear messages:**
- Use conventional commits format
- Describe "why" not "what" (code shows what)
- Reference issue numbers when applicable
- Keep first line under 72 characters

**Test before commit:**
```bash
# Always run tests before committing
npm test

# Type check
npm run type-check

# Lint
npm run lint

# Format
npm run format

# Then commit
git add .
git commit -m "feat(api): add user endpoint"
```

### Branch Strategy

**Feature branches:**
```bash
# Create feature branch from main
git checkout main
git pull
git checkout -b feature/new-feature

# Work on feature, commit often
git commit -m "feat(feature): implement X"
git commit -m "feat(feature): implement Y"

# Before merging, update from main
git checkout main
git pull
git checkout feature/new-feature
git rebase main

# Merge to main
git checkout main
git merge feature/new-feature

# Delete merged branch
git branch -d feature/new-feature
```

**Keep main clean:**
- Only merge completed, tested features
- All tests must pass before merge
- Code review before merge
- Never commit directly to main

**Delete merged branches:**
```bash
# Locally
git branch -d feature/old-feature

# Remote
git push origin --delete feature/old-feature
```

### Collaboration

**Pull before push:**
```bash
# Always pull before starting work
git pull

# Before pushing
git pull
git push
```

**Communicate about force pushes:**
```bash
# If you must force push (personal branch only)
# Warn team first: "Rebasing feature/X, don't pull for 10 minutes"

git push --force-with-lease
```

**Review before merge:**
```bash
# View changes before merging
git diff main feature/new-feature

# Check commit history
git log main..feature/new-feature

# Run tests
npm test

# Then merge
git merge feature/new-feature
```

## Pre-commit Checklist

Before every commit, verify:

- [ ] **Tests pass**: `npm test` succeeds
- [ ] **Linting passes**: `npm run lint` succeeds
- [ ] **Type check passes**: `npm run type-check` succeeds
- [ ] **Code formatted**: `npm run format` applied
- [ ] **No debugging code**: No `console.log`, debugger statements
- [ ] **No secrets**: No API keys, passwords, tokens
- [ ] **Commit message**: Follows conventional commits format
- [ ] **Atomic change**: Single logical change per commit
- [ ] **Related files staged**: All files needed for this change
- [ ] **No unintended changes**: Review `git diff --staged`

**Quick verification script:**
```bash
#!/bin/bash
# pre-commit-check.sh

echo "Running pre-commit checks..."

echo "1. Type checking..."
npm run type-check || exit 1

echo "2. Linting..."
npm run lint || exit 1

echo "3. Tests..."
npm test || exit 1

echo "4. Checking for secrets..."
git diff --staged | grep -E 'API_KEY|PASSWORD|SECRET' && exit 1

echo "✓ All checks passed!"
```

## Advanced Tips

### Useful Aliases

Add to `~/.gitconfig`:
```ini
[alias]
  st = status -s
  co = checkout
  br = branch
  ci = commit
  unstage = restore --staged
  last = log -1 HEAD
  visual = log --oneline --graph --all
  amend = commit --amend --no-edit
  undo = reset HEAD~1
  tree = log --graph --pretty=format:'%C(yellow)%h%Creset -%C(cyan)%d%Creset %s %C(green)(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
```

Usage:
```bash
git st          # Instead of git status -s
git visual      # Pretty branch visualization
git tree        # Detailed history tree
```

### Search Commit History

```bash
# Find commits that added/removed specific text
git log -S "API_KEY" --source --all

# Find commits with message matching pattern
git log --grep="auth" --oneline

# Find commits touching specific function
git log -L :functionName:path/to/file.ts
```

### Clean Working Directory

```bash
# Remove untracked files (dry run first)
git clean -n

# Remove untracked files
git clean -f

# Remove untracked files and directories
git clean -fd

# Remove ignored files too
git clean -fdx
```

### Work with Remote Repositories

```bash
# List remotes
git remote -v

# Add remote
git remote add upstream https://github.com/original/repo.git

# Rename remote
git remote rename origin old-origin

# Remove remote
git remote remove old-origin

# Fetch from specific remote
git fetch upstream

# Merge upstream changes
git merge upstream/main
```

## Related Documentation

- **Conventional Commits**: https://www.conventionalcommits.org/
- **Git Documentation**: https://git-scm.com/doc
- **TDD Cycle**: @~/.claude/docs/workflows/tdd-cycle.md
- **Code Review Process**: @~/.claude/docs/workflows/code-review-process.md
