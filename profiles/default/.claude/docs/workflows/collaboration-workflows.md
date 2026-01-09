# Standard Agent Collaboration Workflows

Decision trees and step-by-step workflows for common development scenarios.

## Decision Trees

### When User Requests New Feature

```
User: "Add [feature]"
  ↓
Requirements clear?
  NO → Main asks clarifying questions
  YES → Continue
  ↓
Complex feature?
  YES → Invoke Technical Architect for task breakdown
  NO → Continue
  ↓
For each task (sequential):
  ↓
  Test Writer: Write failing tests (RED)
  ↓
  Domain Agent: Implement minimum code (GREEN)
  ↓
  Test Writer: Verify tests pass and coverage
  ↓
  quality-refactoring-specialist: Assess refactoring (REFACTOR)
  ↓
  Domain Agent: Execute refactoring if recommended
  ↓
  Test Writer: Verify tests still pass
  ↓
  [Production Readiness review if needed - parallel]
  ↓
  quality-refactoring-specialist: Commit
  ↓
Next task or Done
  ↓
documentation-specialist: Capture learnings in project CLAUDE.md
```

### When User Reports Bug

```
User: "Bug in [feature]"
  ↓
Can reproduce?
  NO → Main asks for reproduction steps
  YES → Continue
  ↓
Test Writer: Write failing test reproducing bug (RED)
  ↓
Domain Agent: Fix bug (GREEN)
  ↓
Test Writer: Verify test passes + add edge case tests
  ↓
quality-refactoring-specialist: Assess if bug indicates larger issue
  ↓
If larger issue identified:
  Domain Agent: Address root cause
  Test Writer: Verify all tests pass
  ↓
quality-refactoring-specialist: Commit fix
  ↓
documentation-specialist: Document root cause and fix
```

### When User Requests Refactoring

```
User: "Refactor [code]"
  ↓
quality-refactoring-specialist: Assess current state
  ↓
Test Writer: Verify 100% test coverage exists
  ↓
Coverage < 100%?
  YES → Test Writer: Write missing tests first
  NO → Continue
  ↓
Domain Agent: Refactor maintaining public API
  ↓
Test Writer: Verify tests pass WITHOUT modification
  ↓
Tests modified?
  YES → STOP - Not true refactoring (behavior changed)
  NO → Continue
  ↓
quality-refactoring-specialist: Review refactored code (parallel)
production-readiness-specialist: Verify no regressions (parallel)
  ↓
Main synthesizes feedback
  ↓
Issues found?
  YES → Domain Agent: Address issues, repeat verification
  NO → Continue
  ↓
quality-refactoring-specialist: Commit
  ↓
documentation-specialist: Document refactoring rationale
```

### When User Requests Code Review

```
User: "Review [code/PR]"
  ↓
Security or performance critical?
  YES → Include production-readiness-specialist in parallel review
  NO → Standard review
  ↓
Main invokes in batches (max 2 parallel):
Batch 1:
  - quality-refactoring-specialist
  - TypeScript Connoisseur
Batch 2:
  - Test Writer
  - [production-readiness-specialist if needed]
  ↓
Main receives all feedback
  ↓
Main synthesizes and prioritizes:
1. Critical (security, data loss, breaks)
2. High value (performance, maintainability)
3. Nice to have (style, minor improvements)
4. Skip (bikeshedding, personal preference)
  ↓
Present prioritized feedback to user
```

## Standard Workflows

### Workflow: New Feature (Complex)

**Phases:**
1. Planning (sequential)
2. Design (parallel if multiple domains)
3. Implementation (sequential per task)
4. Quality gates (parallel)
5. Documentation (sequential)

**Step-by-Step:**

```
PLANNING PHASE
Step 1: Technical Architect - Break feature into testable tasks
Step 2: Main Agent - Review task breakdown, confirm with user

DESIGN PHASE (if needed)
Step 3: Design Specialist - Design API contracts and schema
Step 4: Main Agent - Ensure designs align

IMPLEMENTATION PHASE (repeat for each task)
Step 5: Test Writer - Write failing tests (RED)
Step 6: Domain Agent - Implement minimum code (GREEN)
Step 7: Test Writer - Verify tests pass
Step 8: quality-refactoring-specialist - Assess refactoring (REFACTOR)
Step 9: Domain Agent - Execute refactoring if recommended
Step 10: Test Writer - Verify tests still pass

QUALITY GATES (parallel if needed)
Step 11: production-readiness-specialist - Security and performance review
Step 12: Main Agent - Synthesize feedback, coordinate fixes if needed

FINALIZATION
Step 13: quality-refactoring-specialist - Commit with conventional message
Step 14: documentation-specialist - Capture learnings in project CLAUDE.md
```

### Workflow: Bug Fix

**Phases:**
1. Reproduction
2. Fix
3. Verification
4. Root cause analysis
5. Documentation

**Step-by-Step:**

```
REPRODUCTION
Step 1: Test Writer - Write failing test reproducing bug (RED)

FIX
Step 2: Domain Agent - Fix bug (GREEN)

VERIFICATION
Step 3: Test Writer - Verify test passes + add edge case tests

ROOT CAUSE ANALYSIS
Step 4: quality-refactoring-specialist - Assess if bug indicates larger issue
Step 5: Domain Agent - Address root cause if needed (after Step 4)

FINALIZATION
Step 6: quality-refactoring-specialist - Commit fix with conventional message
Step 7: documentation-specialist - Document bug, root cause, fix
```

### Workflow: Refactoring

**Phases:**
1. Assessment
2. Coverage verification
3. Refactoring execution
4. Verification
5. Review
6. Documentation

**Step-by-Step:**

```
ASSESSMENT
Step 1: quality-refactoring-specialist - Assess current code, identify opportunities

COVERAGE VERIFICATION
Step 2: Test Writer - Verify 100% test coverage exists
Step 3: Test Writer - Write missing tests if coverage < 100% (after Step 2)

REFACTORING
Step 4: Domain Agent - Refactor maintaining public API

VERIFICATION
Step 5: Test Writer - Verify tests pass WITHOUT modification

REVIEW (parallel if needed)
Step 6: quality-refactoring-specialist - Review refactored code
Step 7: production-readiness-specialist - Verify no performance regressions (if critical)
Step 8: Main Agent - Synthesize feedback

FINALIZATION
Step 9: quality-refactoring-specialist - Commit refactoring
Step 10: documentation-specialist - Document refactoring rationale
```

### Workflow: Pre-Production Review

**Phases:**
1. Comprehensive audit (parallel batches)
2. Synthesis and prioritization
3. Issue resolution
4. Final verification

**Step-by-Step:**

```
COMPREHENSIVE AUDIT (parallel batches of 2)
Batch 1:
  Step 1a: production-readiness-specialist - Security and performance audit
  Step 1b: quality-refactoring-specialist - Code quality review

Batch 2:
  Step 1c: Test Writer - Coverage and test quality verification
  Step 1d: TypeScript Connoisseur - Type safety review (if needed)

SYNTHESIS
Step 2: Main Agent - Synthesize findings, prioritize by severity
Step 3: Main Agent - Present findings to user

ISSUE RESOLUTION (if needed)
Step 4: Domain Agent - Address critical/high priority issues
Step 5: [Production Readiness/Test Writer] - Verify fixes (parallel)

FINAL VERIFICATION
Step 6: Test Writer - Run full test suite
Step 7: quality-refactoring-specialist - Commit fixes if any
Step 8: documentation-specialist - Document readiness assessment
```

### Workflow: Security Review

**Phases:**
1. Threat identification
2. Test creation
3. Fix implementation
4. Verification
5. Documentation

**Step-by-Step:**

```
THREAT IDENTIFICATION
Step 1: production-readiness-specialist - Identify security vulnerabilities
Step 2: Main Agent - Prioritize by severity (Critical → High → Medium → Low)

TEST CREATION
Step 3: Test Writer - Write failing security tests for each vulnerability

FIX IMPLEMENTATION
Step 4: Domain Agent - Implement fixes to pass security tests
Step 5: Test Writer - Verify all security tests pass

VERIFICATION
Step 6: production-readiness-specialist - Verify fixes are complete and secure
Step 7: Main Agent - Coordinate additional fixes if needed

FINALIZATION
Step 8: quality-refactoring-specialist - Commit security fixes
Step 9: documentation-specialist - Document vulnerabilities and fixes in CHANGELOG
```

### Workflow: Performance Optimization

**Phases:**
1. Profiling
2. Benchmark creation
3. Optimization
4. Verification
5. Documentation

**Step-by-Step:**

```
PROFILING
Step 1: production-readiness-specialist - Profile application, identify bottlenecks
Step 2: Main Agent - Prioritize optimizations by impact

BENCHMARK CREATION
Step 3: Test Writer - Write performance benchmark tests (current baseline)

OPTIMIZATION
Step 4: Domain Agent - Implement performance optimizations
Step 5: Test Writer - Verify benchmarks show improvement

VERIFICATION
Step 6: production-readiness-specialist - Verify no regressions in other areas
Step 7: Test Writer - Run full test suite (regression check)

FINALIZATION
Step 8: quality-refactoring-specialist - Commit optimizations
Step 9: documentation-specialist - Document performance improvements in CHANGELOG
```

## Workflow Selection Guide

| User Request | Workflow |
|--------------|----------|
| "Add [feature]" | New Feature (Complex) |
| "Fix bug in [feature]" | Bug Fix |
| "Refactor [code]" | Refactoring |
| "Review this code" | Code Review (decision tree) |
| "Is this secure?" | Security Review |
| "This is slow" | Performance Optimization |
| "Deploy to production" | Pre-Production Review |

## Agent Invocation Quick Reference

**Sequential patterns (dependency chains):**
```
Test Writer → Domain Agent → Test Writer → quality-refactoring-specialist
```

**Parallel patterns (independent analysis, max 2):**
```
Batch 1: [Agent A + Agent B]
Batch 2: [Agent C + Agent D]
Main synthesizes all results
```

**Iterative patterns (refinement loops):**
```
Agent A → Main reviews → Agent B feedback → Main synthesizes → Agent A refines
```

## Related

- [Collaboration Patterns](./collaboration-patterns.md) - Invocation mechanics and handoff patterns
- [TDD Cycle](./tdd-cycle.md) - Red-Green-Refactor detailed workflow
- [Code Review Process](./code-review-process.md) - Comprehensive code review guidelines
