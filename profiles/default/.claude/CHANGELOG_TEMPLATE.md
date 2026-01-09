# CHANGELOG Entry Template

This template provides guidance for creating consistent CHANGELOG entries following the Keep A Changelog format.

## Format: Keep A Changelog

**Reference**: https://keepachangelog.com

### Entry Structure

```markdown
## [Version] - YYYY-MM-DD

### [Category]
- **Summary**: Brief description of the change
- **Motivation**: Why this change was made
- **Breaking**: Yes/No
- **Files Modified**: List of changed files (relative paths)
- **Migration**: (If breaking) Steps to migrate from old behavior
```

### Categories

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features marked for removal
- **Removed**: Features removed
- **Fixed**: Bug fixes
- **Security**: Security-related changes

## Entry Requirements

### Required Fields
- **Date format**: YYYY-MM-DD (e.g., 2025-11-03)
- **Summary**: Brief description of what changed
- **Motivation**: Why this change was made
- **Breaking**: Yes/No flag
- **Files Modified**: List of changed files

### Conditional Fields
- **Migration**: ONLY include if Breaking: Yes
- **Root Cause**: For bug fixes, explain what caused the issue
- **Impact**: For bug fixes, describe user/system impact

### Version Numbering

**Semantic Versioning**: MAJOR.MINOR.PATCH

- **MAJOR** (X.0.0): Breaking changes, API changes requiring user action
- **MINOR** (x.X.0): New features, backwards compatible additions
- **PATCH** (x.x.X): Bug fixes, internal improvements, no new features

## When to Create New Version Section

- After significant milestone completion
- Before release/deployment
- When accumulating multiple related changes
- User explicitly requests version bump

## Unreleased Section

If changes accumulate before version decision, use:

```markdown
## [Unreleased]

### Added
- Feature pending release

### Fixed
- Bug fix pending release
```

Then move to versioned section when ready.

## Examples

### Example 1: New Feature (Non-Breaking)

```markdown
## [2.1.0] - 2025-11-03

### Added
- **Summary**: CHANGELOG documentation procedure with Keep A Changelog format
- **Motivation**: Prevent ad-hoc markdown file creation that clutters codebase; establish single source of truth for change history
- **Breaking**: No
- **Files Modified**: `~/.claude/agents/documentation-agent.md`, `~/.claude/CLAUDE.md`, `~/.claude/CHANGELOG_TEMPLATE.md`
```

### Example 2: Bug Fix

```markdown
## [2.0.1] - 2025-10-28

### Fixed
- **Summary**: Neovim AppImage download URL pointing to dev build
- **Motivation**: Latest tag was pointing to v0.12.0-dev which had broken Lua loader
- **Breaking**: No
- **Root Cause**: Using `/releases/latest/` instead of specific version tag
- **Impact**: Neovim would not start, LazyVim completely unusable
- **Files Modified**: `scripts/linux/install-dev-tools.sh`
```

### Example 3: Breaking Change

```markdown
## [3.0.0] - 2025-12-01

### Changed
- **Summary**: Authentication API now requires JWT tokens instead of session cookies
- **Motivation**: Improve security and enable stateless architecture for horizontal scaling
- **Breaking**: Yes
- **Migration**:
  1. Update client code to store JWT token from `/auth/login` response
  2. Include token in `Authorization: Bearer <token>` header for all requests
  3. Remove cookie-based session handling from client code
- **Files Modified**: `src/auth/middleware.ts`, `src/auth/login.ts`, `src/types/auth.ts`
```

### Example 4: Security Fix

```markdown
## [2.0.2] - 2025-11-01

### Security
- **Summary**: Fixed SQL injection vulnerability in user search endpoint
- **Motivation**: User-provided search terms were concatenated directly into SQL query
- **Breaking**: No
- **Root Cause**: Missing parameterized query for search functionality
- **Impact**: Attackers could execute arbitrary SQL commands with database privileges
- **Files Modified**: `src/api/users/search.ts`
```

### Example 5: Multiple Changes in One Version

```markdown
## [2.2.0] - 2025-11-05

### Added
- **Summary**: Dark mode support for admin dashboard
- **Motivation**: User feedback requested dark mode for reduced eye strain
- **Breaking**: No
- **Files Modified**: `src/components/Dashboard.tsx`, `src/styles/theme.ts`

### Fixed
- **Summary**: Race condition in concurrent file uploads
- **Motivation**: Multiple simultaneous uploads could corrupt file metadata
- **Breaking**: No
- **Root Cause**: Shared upload state without proper locking
- **Impact**: File uploads would silently fail or create duplicate entries
- **Files Modified**: `src/services/upload.ts`

### Deprecated
- **Summary**: Legacy v1 API endpoints marked for removal
- **Motivation**: Consolidate on v2 API with improved error handling and performance
- **Breaking**: No (removal scheduled for v3.0.0)
- **Migration**: Update client code to use `/api/v2/` endpoints instead of `/api/v1/`
- **Files Modified**: `src/api/v1/index.ts` (added deprecation warnings)
```

## Best Practices

### DO
- ✓ Write entries immediately after completing work (while context is fresh)
- ✓ Include all modified files (helps reviewers understand scope)
- ✓ Explain WHY changes were made (motivation)
- ✓ Flag breaking changes clearly
- ✓ Provide migration steps for breaking changes
- ✓ Use consistent date format (YYYY-MM-DD)
- ✓ Group related changes under same version

### DON'T
- ✗ Create entries after commit (documentation should be part of commit)
- ✗ Write vague summaries ("fixed bug", "updated code")
- ✗ Omit breaking changes flag
- ✗ Skip motivation/reasoning
- ✗ Create separate documentation files instead (use CHANGELOG)
- ✗ Use inconsistent date formats
- ✗ Mix unrelated changes in same entry

## Integration with Workflow

**Standard flow:**
1. Complete feature/fix
2. Update CHANGELOG.md (this file)
3. Update project CLAUDE.md if technical context discovered
4. Commit with both documentation updates

**NEVER:**
- Document after commit
- Create separate documentation files (NEW_FEATURES.md, FIXES_APPLIED.md, etc)
- Skip CHANGELOG updates

## File Location

**CHANGELOG.md location:**
- Project root: `<project-root>/CHANGELOG.md`
- Example: `/home/user/myproject/CHANGELOG.md`

**DO NOT:**
- Place CHANGELOG in subdirectories
- Create multiple CHANGELOG files
- Use different filenames (CHANGES.md, HISTORY.md, etc)

One project = One CHANGELOG.md in root directory.
