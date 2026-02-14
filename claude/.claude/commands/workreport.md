---
description: Generate a structured work report summarizing task, changes, and verification steps
allowed-tools: Read, Write, Grep, Glob, Bash(git:*), Bash(find:*), Bash(ls:*), Bash(date:*)
---

Generate a structured work report summarizing work accomplished in the current session, then save it to disk.

## Phase 1: Determine Report Filename

### 1.1 Extract Job Title from Arguments
- Variable `$ARGUMENTS` contains the job title/name for the report
- If `$ARGUMENTS` is empty, derive a short descriptive slug from the conversation context (e.g., "fix-auth-bug", "add-user-dashboard", "refactor-api-layer")

### 1.2 Sanitize Job Title
Convert job title to filename-safe format:
- Lowercase all characters
- Replace spaces with hyphens
- Remove special characters (keep only alphanumeric, hyphens, underscores)
- Trim to max 50 characters
- Examples: "Fix Auth Bug" → "fix-auth-bug", "User Dashboard Feature" → "user-dashboard-feature"

### 1.3 Determine Report Path
```bash
# Get git repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPORT_DIR="${REPO_ROOT}/.reports"
REPORT_PATH="${REPORT_DIR}/{sanitized-job-title}-report.md"
```

### 1.4 Create Reports Directory
```bash
mkdir -p "${REPORT_DIR}"
```

## Phase 2: Gather Session Context

### 2.1 Get Current Branch and Date
```bash
git branch --show-current
date +%Y-%m-%d
```

### 2.2 Identify All Changed Files
```bash
git diff --name-status HEAD
git diff --name-status --cached
git status --porcelain
```

Categorize changes:
- **Added**: New files created (A status)
- **Modified**: Existing files changed (M status)
- **Deleted**: Files removed (D status)

### 2.3 Review Recent Commit History
```bash
git log --oneline --all --graph -20
git log --pretty=format:"%h - %s (%cr)" -10
```

Extract commits made during this session (since conversation started).

### 2.4 Get Detailed Diff Summary
```bash
git diff --stat HEAD
git diff --cached --stat
```

For each changed file, use Read tool to understand what was modified if the file is:
- A source code file (*.ts, *.tsx, *.js, *.jsx)
- A configuration file (package.json, tsconfig.json, etc.)
- A schema definition file
- A documentation file

### 2.5 Check for Active Plan

Claude Code stores session plans as markdown files in `~/.claude/plans/`. The most recently modified file is typically the active plan for the current session.

**Steps:**
1. Find the most recent plan file:
   ```bash
   ls -t ~/.claude/plans/*.md 2>/dev/null | head -1
   ```
2. If a plan file exists, read its contents
3. Determine whether the plan relates to the changes made in this session by comparing:
   - File paths mentioned in the plan vs files changed in git
   - Task descriptions in the plan vs commit messages
   - Step descriptions vs actual work performed
4. Extract from the plan:
   - Plan title/goal (typically the H1 heading)
   - Which steps were completed in this session
   - Which steps remain
   - Overall progress estimate

Also check these supplementary locations (lower priority):
- `WIP.md` at repository root
- `.taskmaster/tasks/tasks.json`

If no plan found or the plan is unrelated to current changes, skip this section in the report.

## Phase 3: Generate Report Content

Create report with the following structure:

```markdown
# Work Report: {Job Title}
**Date**: {YYYY-MM-DD}
**Branch**: {current git branch}
**Report line budget**: 200 lines max

## Task Summary
{Concise description of what was requested/the problem to solve. Extract from conversation context. 2-4 sentences maximum.}

## Plan Context
{If an active plan (~/.claude/plans/, WIP.md, or taskmaster) was found and relates to this work:
- **Plan source**: {filename}
- **Items addressed**: {list of plan steps/tasks completed in this session}
- **Remaining items**: {count or brief list of what's left}
- **Progress**: {X of Y tasks complete, or percentage}

If no plan found or plan is unrelated to changes, omit this section entirely.}

## Changes Made

### Added
{For each new file:}
- **{filepath}**: {brief description of what this file does and why it was added}

### Modified
{For each modified file:}
- **{filepath}**: {what was changed and why - focus on the purpose, not just the diff}

### Deleted
{For each deleted file:}
- **{filepath}**: {what was removed and why}

{If no files in a category, omit that section}

## Implementation Details
{Brief technical narrative of the approach taken. Include:
- Key architectural decisions made
- Patterns or techniques applied
- Trade-offs considered
- Any notable technical challenges overcome
- Dependencies added or removed
3-6 sentences, focused on the "how" and "why" at a high level.}

## Verification Steps
{Numbered checklist of steps to verify the changes work correctly. Derive from nature of changes:
- If tests were added: "Run test suite with `npm test` or `pnpm test`"
- If API changes: "Verify endpoint returns 200 with correct schema"
- If UI changes: "Check component renders correctly at /path"
- If config changes: "Verify application starts without errors"
- If database changes: "Run migrations and verify schema"
Minimum 3 steps, maximum 8 steps.}

1. {step with specific command or action}
2. {step with specific command or action}
3. {step with specific command or action}
...

## Notes
{Optional section - only include if relevant:
- Known limitations or caveats
- Follow-up work needed (TODOs discovered but not addressed)
- Items deferred to future sessions
- Temporary workarounds applied
- Breaking changes introduced
If none, write "None"}
```

## Phase 4: Write Report to Disk

### 4.1 Save Report
Use Write tool to save the generated markdown content to `{REPORT_PATH}`.

### 4.2 Verify File Written
```bash
ls -lh "${REPORT_PATH}"
```

Confirm file exists and show size.

## Phase 5: Output Completion

Display:
```
Work report generated successfully.

Path: {absolute path to report file}
Size: {file size}
Files documented: {count}
```

## Critical Rules

1. **HARD LIMIT: 200 lines** - The final saved report must NEVER exceed 200 lines. Achieve this by:
   - One-line descriptions per file in Changes Made (no multi-line explanations)
   - Maximum 5 verification steps
   - Implementation Details capped at 4 sentences
   - Notes capped at 3 bullet points
   - Omit empty sections entirely
   - If still over 200 lines, truncate Changes Made to top 20 files with a note: "...and N more files"
2. **Never fabricate changes** - Only document changes that actually exist in git status/diff
3. **Read files for accuracy** - Don't guess at what changed, read the actual file contents
4. **Focus on "why" not just "what"** - Explain rationale, not just list diffs
5. **Make verification actionable** - Specific commands, not vague suggestions
6. **Keep it concise** - Report should be scannable, not exhaustive
7. **Sanitize filename properly** - Prevent path traversal or invalid characters
8. **Handle empty changes gracefully** - If no changes detected, report that fact and exit
9. **Derive job title intelligently** - If $ARGUMENTS empty, analyze conversation for meaningful slug
10. **Use git as source of truth** - Trust git status/diff over memory or assumptions
11. **Group related changes** - Organize by logical units, not just alphabetically

## Examples of Good Descriptions

**Good**:
- `src/auth/jwt.ts`: Added JWT token generation with 24h expiration to support passwordless authentication
- `tests/auth.test.ts`: Added test coverage for token expiry and refresh flow edge cases
- `package.json`: Added `jsonwebtoken` dependency for token signing and verification

**Bad**:
- `src/auth/jwt.ts`: Modified file
- `tests/auth.test.ts`: Updated tests
- `package.json`: Changed

## Error Handling

**If no git repository found**:
- Use current working directory as REPO_ROOT
- Note in report: "Not a git repository - change tracking unavailable"
- Derive changes from conversation context only

**If no changes detected**:
- Create report anyway with Task Summary and Notes sections
- State in Changes Made: "No file changes detected in git status"
- Include conversation summary as primary content

**If unable to read a changed file**:
- Note in description: "{filepath}: Unable to read file contents"
- Proceed with other files

**If $ARGUMENTS and context both unclear**:
- Use fallback filename: `work-session-{YYYY-MM-DD-HHMMSS}-report.md`

Execute this process thoroughly and produce a professional, actionable work report.
