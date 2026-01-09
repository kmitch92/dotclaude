---
description: Reduce project CLAUDE.md size by removing outdated or low-priority information
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob"]
---

# /forget - Reduce Project CLAUDE.md Size

Drastically reduce the size of the local project CLAUDE.md file by removing outdated, low-priority, or redundant information while preserving essential context.

## Instructions

**CRITICAL: This command operates on the project's CLAUDE.md file in the current working directory, NOT the global ~/.claude/CLAUDE.md file.**

### Step 1: Locate and Read Project CLAUDE.md

1. Find the project CLAUDE.md file in the current working directory
2. Read the entire file to understand current content
3. Note the current file size and line count

### Step 2: Analyze Content Categories

Categorize all content into:

**KEEP (High Priority):**
- Recent architectural decisions (last 3 months)
- Active patterns and conventions currently in use
- Current system constraints and technical debt
- Unresolved issues or blockers
- Critical context that would be painful to rediscover
- Active feature flags or configuration notes
- Security considerations
- Performance bottlenecks or optimization notes

**CONSOLIDATE (Medium Priority):**
- Redundant explanations of same concept
- Multiple examples showing same pattern (keep best 1-2)
- Overlapping sections that can be merged
- Verbose descriptions that can be made concise

**REMOVE (Low Priority):**
- Completed task notes and checkboxes
- Resolved issues with clear outcomes
- Obsolete patterns no longer in use
- Historical context no longer relevant to current work
- Outdated dependency information
- Temporary workarounds that are now fixed
- Meeting notes or discussion summaries older than 3 months
- Duplicate information
- Implementation details now obvious from code
- Notes about decisions that were reversed or superseded

### Step 3: Content Reduction Strategy

Apply these techniques:

**Aggressive Pruning:**
- Remove entire sections for completed/obsolete topics
- Delete verbose prose, keep bullet points
- Remove redundant examples (keep one representative example)
- Delete historical "how we got here" narratives

**Consolidation:**
- Merge related sections into single concise section
- Combine similar patterns into one pattern with variations noted
- Collapse verbose explanations into terse bullet points

**Preservation:**
- Keep recent dates/timestamps (useful for staleness detection)
- Preserve all "gotchas" and "lessons learned" (high value)
- Maintain all links to external resources
- Keep all security warnings and constraints

### Step 4: Execute Reduction

1. Create a NEW reduced version of the CLAUDE.md file
2. Structure should follow this template:

```markdown
# [Project Name] - Local Context

Last updated: [DATE]

## Current Architecture

[Active architectural decisions and patterns - concise bullets]

## Active Constraints

[Technical limitations, dependencies, gotchas - one-liners]

## Unresolved Issues

[Open problems, blockers, technical debt - with dates]

## Key Patterns

[Patterns actively in use - example per pattern only if essential]

## Security & Performance

[Critical notes only]

## Historical Notes

[Only if essential for understanding current decisions - very brief]
```

3. Line count targets:
   - If document is <150 lines: No specific line target, only remove clearly useless/obsolete content
   - If document is 150+ lines: HARD TARGET is 150 lines maximum
   - This means making hard decisions about what's truly important
   - Aggressive editing required: reduce fluff, consolidate heavily, cut redundant explanations

### Step 5: Report Changes

Provide summary:
```
CLAUDE.md Reduction Summary:
- Original size: [lines/characters]
- New size: [lines/characters]
- Reduction: [percentage]%

Removed:
- [X] completed tasks
- [Y] resolved issues
- [Z] obsolete patterns
- [Other categories]

Preserved:
- [Key architectural decisions]
- [Active constraints]
- [Unresolved issues]
- [Critical patterns]

High-value content retained: [brief description]
```

## Guiding Principles

**When in doubt, REMOVE:**
- If you'd need to read code to verify if it's still true → REMOVE (code is source of truth)
- If it's older than 3 months and not a key decision → REMOVE
- If it duplicates something in code comments → REMOVE
- If it's a "note to self" that's now resolved → REMOVE

**Always KEEP:**
- Anything marked "CRITICAL", "GOTCHA", "WARNING"
- Active unresolved issues with dates
- Security considerations
- Performance constraints
- Breaking changes in recent dependencies
- Anything that would take >30min to rediscover

**Never KEEP:**
- Completed TODO lists
- Resolved bugs/issues
- Old meeting notes
- Historical narrative ("we tried X then Y then Z")
- Obsolete workarounds

## Example Transformations

**BEFORE (verbose, historical):**
```
## Database Migration Strategy

We initially tried using raw SQL migrations but ran into versioning issues.
Then we switched to Prisma migrations which worked better. However, we had
problems with team members running migrations out of order. After a team
discussion on 2024-03-15, we decided to use a linear migration strategy
where each migration explicitly depends on the previous one.

Current status: All migrations up to 2024-06-20 are deployed to production.

TODO:
- [x] Complete user table migration
- [x] Add indexes for performance
- [ ] Migrate legacy data from old system
```

**AFTER (concise, current):**
```
## Database

- Using Prisma with linear migrations (each depends on previous)
- Legacy data migration to new schema: IN PROGRESS
```

---

**BEFORE (redundant examples):**
```
## Error Handling Pattern

Example 1: API Route
[10 lines of code]

Example 2: Database Query
[10 lines of code]

Example 3: External Service Call
[10 lines of code]

All follow same pattern: try/catch with custom error types.
```

**AFTER (essential only):**
```
## Error Handling

- Use custom error types with try/catch
- See: src/lib/errors.ts
```

## Success Criteria

File should be:
- Maximum 150 lines if original was 150+ lines (HARD CAP)
- If original was <150 lines: only clearly obsolete content removed
- Focused on current, actionable information
- Free of historical narrative and completed tasks
- Easy to scan in <2 minutes
- Containing only high-value context

If final file exceeds 150 lines and original was 150+, you have failed the task. Be ruthless in cutting content.
