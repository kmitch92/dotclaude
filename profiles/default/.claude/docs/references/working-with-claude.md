# Working with Claude Code - Quick Reference

## Core Expectations

1. **TDD Always** - Write failing test FIRST, then implement
2. **Think Deeply** - Understand code/dependencies before changing
3. **Full Context** - Know why code exists, requirements, constraints
4. **Ask When Unclear** - Ambiguous requirements, multiple approaches, breaking changes
5. **Delegate to Specialists** - Main agent orchestrates, never implements
6. **Track Complex Tasks** - Use TodoWrite for 3+ steps
7. **Update Docs** - Capture learnings in project CLAUDE.md after every feature

## When to Ask vs. Proceed

### Ask First

**Requirements unclear:**
- Ambiguous/conflicting requirements
- Multiple valid interpretations
- Edge cases not specified

**Approach decisions:**
- Multiple approaches with different tradeoffs
- Library/tool choice needed
- Performance vs. maintainability decision

**Breaking changes:**
- Would break existing API
- Requires migration
- Affects other systems
- Changes user-facing behavior

**User preference:**
- Subjective decisions (naming, structure)
- Configuration choices
- Feature scope

### Proceed with Delegation

- Single obvious interpretation
- Standard patterns apply
- Backwards compatible
- Follows established conventions
- No architectural decisions needed

## Code Changes Flow

### Every Change Follows This Pattern

1. **Triage** (Main Agent) - Understand requirements, identify agents, delegate to Technical Architect if complex
2. **Planning** (Technical Architect) - Break into tasks, identify dependencies, define success criteria
3. **For Each Task:**
   - **Test Writer** → Write failing test (RED)
   - **Domain Agent** → Implement minimum code (GREEN)
   - **Test Writer** → Verify coverage
   - **Quality & Refactoring** → Assess and refactor
   - **Quality & Refactoring** → Commit
4. **Documentation** (Documentation Specialist) - Update project CLAUDE.md

## Plan Requirements

### Every Plan Must Specify Agents

❌ **DON'T:**
```
1. Write tests
2. Implement feature
3. Commit
```

✅ **DO:**
```
Step 1: Test Writer - Write failing tests for user authentication
Step 2: Backend Developer - Implement auth to pass tests (after Step 1)
Step 3: Production Readiness - Security review (after Step 2)
Step 4: Quality & Refactoring - Assess refactoring (after Step 2)
Step 5: Quality & Refactoring - Commit (after Steps 3 and 4)
```

**Format:** `Step N: [Agent Name] - [Task] [execution model]`

**Execution models:**
- Sequential: "(after Step N)"
- Parallel: "(parallel with Step N)"
- Independent: no annotation

## Communication Standards

### Be Explicit About Tradeoffs

✅ **DO:**
```
Approach A: Faster, less flexible
Approach B: More work, easier to extend
Recommendation: B (requirements suggest future extensions)
```

❌ **DON'T:** Silently pick without explanation

### Explain Reasoning

✅ **DO:**
```
Using Zod here because this is a trust boundary (API input).
Ensures runtime type safety, not just compile-time.
```

❌ **DON'T:** Make changes without explaining why

### Flag Deviations

✅ **DO:**
```
Note: Using 'interface' instead of 'type' here because extending
third-party library interface that uses 'interface' pattern.
```

❌ **DON'T:** Deviate from standards without justification

### Suggest Improvements

✅ **DO:**
```
Current approach works, but consider Result type instead of exceptions.
Makes error handling more explicit and type-safe.
```

❌ **DON'T:** Miss opportunities to suggest improvements

## Providing Feedback

### When Claude Makes Mistakes

**Redirect, don't criticize:**

✅ **DO:**
```
Please delegate this to [Agent Name] instead of implementing directly.
```

or

```
The requirement is X, not Y. Please revise the approach.
```

❌ **DON'T:**
```
You did this wrong. You should have done X instead.
```

### When Claude Needs Clarification

**Provide context:**

✅ **DO:**
```
The goal is to optimize for read performance, not write performance.
Please revise to use denormalized structure.
```

❌ **DON'T:**
```
No, do it differently.
```

## Main Agent Role

**Orchestrator, NOT implementer.**

**Main Agent does:**
- Triage requests
- Delegate to specialists
- Synthesize results
- Track progress
- Ask questions

**Main Agent NEVER:**
- Writes code
- Edits files
- Creates files
- Implements features

**If main agent implements, redirect:**
```
Please delegate this to the appropriate subagent instead of implementing directly.
```

## Quality Signals

### Good Signals ✅

- Tests written BEFORE implementation
- Questions asked when unclear
- Tradeoffs explained with recommendations
- Proper delegation to specialists
- Deviations flagged and justified
- Standards followed
- Progress tracked with TodoWrite
- CLAUDE.md updated after changes

### Warning Signals ⚠️

- Code without tests
- Assumptions without asking
- Main agent implementing directly
- Standards violated without justification
- No explanation for approach
- Complex task without TodoWrite
- CLAUDE.md not updated

## Common Workflows

### New Feature

```
User: "Add user authentication"

Main Agent:
1. Ask clarifying questions (if needed)
2. Delegate to Technical Architect for breakdown
3. For each task:
   - Test Writer (failing test)
   - Backend Developer (implement)
   - Test Writer (verify)
   - Production Readiness (review)
   - Quality & Refactoring (assess and commit)
4. Documentation Specialist (update CLAUDE.md)
```

### Bug Fix

```
User: "Fix login error"

Main Agent:
1. Investigate (read files, understand context)
2. Test Writer (failing test reproducing bug)
3. Backend Developer (fix)
4. Test Writer (verify fix, edge cases)
5. Quality & Refactoring (assess and commit)
```

### Code Review

```
User: "Review this code"

Main Agent:
1. Delegate in batches (max 2 parallel):
   Batch 1: Quality & Refactoring + TypeScript Connoisseur
   Batch 2: Production Readiness + Test Writer
2. Synthesize feedback by severity
3. Present prioritized recommendations
```

## Core Principles

1. **Test-first** - No code without failing test
2. **Behavior-driven** - Test public APIs only
3. **Schema-first** - Zod at trust boundaries
4. **Immutable** - No data mutation
5. **Pure functions** - No side effects
6. **Delegate** - Main agent orchestrates
