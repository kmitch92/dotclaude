---
name: agent-orchestration
description: Agent collaboration patterns for Claude multi-agent workflows. Sequential vs parallel delegation, code review synthesis, standard workflows for features, bugs, and refactoring.
---

# Agent Orchestration Skill

## Core Principle

**The Main Agent orchestrates, never implements.** All code changes are delegated to specialized agents.

Main Agent role:
- Triage requests
- Delegate to specialists
- Synthesize results
- Track progress
- Ask clarifying questions

Main Agent NEVER:
- Writes production code
- Edits files
- Creates files
- Implements features

**Exception**: Read-only operations (Read, Grep, Glob, read-only Bash, WebFetch, TodoWrite, AskUserQuestion)

## Critical Architecture Rules

### 1. No Agent-to-Agent Invocation

**Only Main Agent invokes specialized agents.** Specialized agents complete work and return to Main Agent with results and recommendations.

**Why**: Prevents recursive invocation chains that cause JavaScript heap memory errors and system crashes.

**CORRECT Pattern:**
```
Main Agent → Agent A (assign task)
Agent A completes work
Agent A → Main Agent (results + "Recommend invoking Agent B for [reason]")
Main Agent evaluates recommendation
Main Agent → Agent B (assign task based on Agent A results)
```

**WRONG Pattern:**
```
Main Agent → Agent A → Agent B → Agent C
[System crashes: JavaScript heap out of memory]
```

### 2. Maximum 3 Agents in Parallel (Hard Limit)

**⚠️ NEVER invoke more than 3 agents simultaneously.**

**When 3 agents needed**: Single message with three Task tool calls (parallel)
**When 4+ agents needed**: Sequential batches (max 3 parallel)
- Batch 1: 3 agents (parallel)
- [Wait and review results]
- Batch 2: Remaining agents (1-3 sequential)

**Example**: Code review needing 4 agents → Batch 1 (Quality + TypeScript + Test Writer), Batch 2 (Production Readiness)

## Agent Roster

| Agent | Primary Domain | When to Invoke |
|-------|---------------|----------------|
| **Technical Architect** | Task breakdown, planning | New features, complex changes, unclear requirements |
| **Test Writer** | TDD, behavioral testing | Writing tests, verifying coverage, test strategy |
| **TypeScript Connoisseur** | TypeScript patterns, Zod schemas | Type definitions, schema design, TypeScript questions |
| **quality-refactoring-specialist** | Code review, refactoring, git | Code review, post-green refactoring, git commits/PRs |
| **production-readiness-specialist** | Security, performance | Security review, performance optimization, pre-production |
| **Backend TypeScript Developer** | Lambda, API, database, CDK | Backend implementation, AWS services, infrastructure |
| **React Engineer** | React components, hooks, SSR | React-specific implementation |
| **Shell Specialist** | Shell scripts, automation | Installation scripts, git hooks, CLI tools |
| **documentation-specialist** | Project documentation | Update CLAUDE.md, write docs, capture learnings |

## Domain Agent Selection by Technology

| Technology | Primary Agent | Supporting Agents |
|-----------|--------------|-------------------|
| API endpoints | Backend TypeScript Developer | TypeScript Connoisseur |
| Database schema | Backend TypeScript Developer | TypeScript Connoisseur |
| React components | React Engineer | TypeScript Connoisseur, Test Writer |
| Lambda functions | Backend TypeScript Developer | production-readiness-specialist |
| Shell scripts | Shell Specialist | — |
| Type definitions | TypeScript Connoisseur | — |
| Tests | Test Writer | Domain agent for setup |
| Refactoring | quality-refactoring-specialist | Test Writer |
| Git operations | quality-refactoring-specialist | — |
| Security review | production-readiness-specialist | Test Writer, Domain Agent |
| Performance | production-readiness-specialist | Domain Agent |
| CDK infrastructure | Backend TypeScript Developer | production-readiness-specialist |

## Invocation Mechanics

### Single Agent Invocation

Use Task tool with:
- **subagent_type**: Agent name (e.g., "Test Writer", "Technical Architect")
- **description**: Short 3-5 word summary
- **prompt**: Detailed instructions, what to accomplish, what to return

**Example:**
```
[Task tool call]
- subagent_type: "Test Writer"
- description: "Write payment validation tests"
- prompt: "Write failing tests for payment validation. Cover: amount validation (positive, non-zero), card details validation (token required, CVV format), address validation (required fields). Use PaymentSchema from @/schemas/payment. Return test file path."
```

### Parallel Agent Invocation

**Key Rule**: To run agents in parallel, send ONE message with MULTIPLE Task tool calls (max 3).

**Example:**
```
[SINGLE message with THREE Task tool calls]

Task 1:
- subagent_type: "quality-refactoring-specialist"
- description: "Review code quality"
- prompt: "Review src/payment/processor.ts for: immutability violations, nested conditionals, unclear naming, functional patterns. Return prioritized feedback."

Task 2:
- subagent_type: "Test Writer"
- description: "Review test coverage"
- prompt: "Review tests for payment processor. Verify: all behaviors tested, no implementation details tested, real schemas used. Return coverage gaps."

Task 3:
- subagent_type: "TypeScript Connoisseur"
- description: "Review type safety"
- prompt: "Review TypeScript usage. Check for: any types, unnecessary assertions, schema-first violations. Return findings."
```

## Collaboration Patterns

### Pattern 1: Sequential Delegation

**Use when**: Tasks have dependencies

**Flow:**
```
Main Agent → Agent 1 → Main reviews → Agent 2 → Main reviews → Agent 3
```

**Example: New Feature Implementation**
```
Technical Architect breaks feature into tasks
→ Main reviews task breakdown
→ Test Writer writes failing tests for Task 1
→ Main verifies tests fail
→ Backend Developer implements to pass tests
→ Main verifies tests pass
→ quality-refactoring-specialist assesses code quality
→ Main coordinates any refactoring
→ quality-refactoring-specialist commits changes
```

### Pattern 2: Parallel Consultation

**Use when**: Multiple independent perspectives needed (max 3 parallel)

**Flow:**
```
Main Agent → [Agent 1 + Agent 2 + Agent 3] analyze simultaneously → Main synthesizes
```

**Example: Code Review (Batched)**
```
Batch 1 (3 agents parallel):
- quality-refactoring-specialist (style, patterns, anti-patterns)
- TypeScript Connoisseur (types, schemas, strict mode)
- Test Writer (coverage, behavior focus, test quality)

[Wait for Batch 1, review findings]

Batch 2 (1 agent):
- production-readiness-specialist (vulnerabilities, PII handling)

Main synthesizes all feedback
```

### Pattern 3: Iterative Refinement

**Use when**: Complex task requires multiple rounds

**Flow:**
```
Main → Agent 1 (initial) → Main reviews → Agent 2 (feedback) → Main synthesizes → Agent 1 (refinement)
```

**Example: API Design with Security Review**
```
Backend Developer creates initial design
→ Main reviews design document
→ production-readiness-specialist reviews for security
→ Main identifies required changes
→ Backend Developer refines design
→ Main confirms design complete
```

## Parallelization Decision Matrix

### Use Parallel When (max 3):

**Independent Analysis Tasks:**
- Code review from multiple perspectives
- Security + Performance + Quality assessments
- Multi-domain analysis

**Example:**
```
Batched code review (max 3 parallel):
Batch 1: [Quality & Refactoring + TypeScript + Test Writer] → Review
Batch 2: [Production Readiness] → Review
→ Synthesize all findings
```

### Use Sequential When:

**Dependency Chain:**
- TDD cycle steps (test → implement → verify)
- Design then implement
- Fix then verify

**Decision Rule:**
- Task B needs Task A output? → Sequential
- Tasks analyzing same artifact independently? → Parallel (batched if >3)
- Tasks working on different components? → Depends

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
  [production-readiness-specialist review if needed - parallel]
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
  YES → Include production-readiness-specialist in review
  NO → Standard review
  ↓
Main invokes in batches (max 3 parallel):
Batch 1 (3 agents):
  - quality-refactoring-specialist
  - TypeScript Connoisseur
  - Test Writer
Batch 2 (if needed):
  - production-readiness-specialist
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
2. Design (if needed)
3. Implementation (sequential per task)
4. Quality gates (parallel)
5. Documentation (sequential)

**Step-by-Step:**

```
PLANNING PHASE
Step 1: Technical Architect - Break feature into testable tasks
Step 2: Main Agent - Review task breakdown, confirm with user

DESIGN PHASE (if needed)
Step 3: Backend Developer - Design API contracts and schema
Step 4: Main Agent - Ensure designs align

IMPLEMENTATION PHASE (repeat for each task)
Step 5: Test Writer - Write failing tests (RED)
Step 6: Domain Agent - Implement minimum code (GREEN)
Step 7: Test Writer - Verify tests pass
Step 8: quality-refactoring-specialist - Assess refactoring (REFACTOR)
Step 9: Domain Agent - Execute refactoring if recommended
Step 10: Test Writer - Verify tests still pass

QUALITY GATES (parallel if needed, max 3)
Step 11: production-readiness-specialist - Security and performance review
Step 12: Main Agent - Synthesize feedback, coordinate fixes if needed

FINALIZATION
Step 13: quality-refactoring-specialist - Commit with conventional message
Step 14: documentation-specialist - Capture learnings in project CLAUDE.md
```

### Workflow: Bug Fix

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

### Workflow: Security Review

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

### Workflow: Pre-Production Review

```
COMPREHENSIVE AUDIT (parallel batches of max 3)
Batch 1:
  Step 1a: quality-refactoring-specialist - Code quality review
  Step 1b: TypeScript Connoisseur - Type safety review
  Step 1c: Test Writer - Coverage and test quality verification

Batch 2:
  Step 1d: production-readiness-specialist - Security and performance audit

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

## Code Review Process

### Review Types

**Standard Code Review:**
- **Scope**: Code quality, patterns, maintainability
- **Agents (max 3 parallel)**: Quality & Refactoring, Test Writer, TypeScript Connoisseur
- **Use when**: PR review, refactoring assessment, general health check

**Security/Performance Review:**
- **Scope**: Auth, PII, payments, user input, API endpoints, data processing
- **Agents (batches)**: Batch 1 (Quality + TypeScript + Test Writer), Batch 2 (Production Readiness)
- **Use when**: Auth flows, payment processing, data handling, API endpoints with SLA

**Pre-Production Review:**
- **Scope**: Comprehensive readiness
- **Agents (batches)**: Batch 1 (Quality + TypeScript + Test Writer), Batch 2 (Production Readiness)
- **Use when**: Before production deployment, major feature release, compliance review

### Agent Responsibilities in Reviews

**quality-refactoring-specialist:**
- Immutability violations
- Nested conditionals
- Functional patterns
- Naming clarity
- Anti-patterns
- Refactoring opportunities

**Test Writer:**
- Coverage gaps
- Implementation detail testing
- Schema usage (real vs redefined)
- Test organization
- Missing edge cases

**TypeScript Connoisseur:**
- Strict mode compliance
- `any` types
- Type assertions
- Schema-first violations
- Type narrowing opportunities

**production-readiness-specialist:**
- **Security**: Input validation, injection, auth/authz, PII, secrets
- **Performance**: Database queries, algorithms, memory, network, rendering

### Severity Levels

🔴 **CRITICAL** - Must fix before merge
- Security vulnerabilities
- Performance causing user problems
- Data loss risks
- Breaking changes without migration
- Broken functionality

⚠️ **HIGH VALUE** - Fix now
- Moderate performance issues
- Maintainability problems
- Missing coverage for critical paths
- Type safety risks

💡 **NICE TO HAVE** - Consider
- Minor improvements
- Additional edge cases
- Type narrowing
- Documentation

✅ **SKIP** - Not worth addressing
- Bikeshedding
- Premature optimization
- Over-engineering

### TypeScript-Specific Severity Levels

**🔴 CRITICAL**
- `any` types (loses all type safety)
- Missing schemas at trust boundaries (external data unvalidated)
- Unjustified type assertions (bypassing type safety)
- `@ts-ignore` / `@ts-expect-error` without explanation

**⚠️ HIGH PRIORITY**
- Multiple function parameters without options object (refactor-hostile)
- Data mutations (should use immutable patterns)
- `interface` for data structures (use `type` for consistency)
- Redefining types in tests (import real schemas)
- Non-strict tsconfig (missing strict mode flags)

**💡 NICE-TO-HAVE**
- Naming convention inconsistencies
- Types scattered across files
- Missing utility type usage
- Excessive optional chaining (may indicate poor null handling design)

### Synthesis and Presentation

**Format:**
```
Code Review: [Feature/PR Name]

🔴 CRITICAL:
1. [Agent] Issue description
   - Impact: What could happen
   - Location: file:line
   - Fix: Specific action

⚠️ HIGH VALUE:
2. [Agent] Issue description
   - Impact: Effect on maintainability/performance
   - Location: file:line
   - Fix: Specific action

💡 NICE TO HAVE:
3. [Agent] Suggestion
   - Benefit: Why consider
   - Note: Context or conditions

✅ SKIP:
4. [Agent] Suggestion not recommended
   - Reason: Why skipping
```

### Prioritization Framework

**Critical Assignment:**
- Security vulnerability (any)
- Performance causing user issues (>500ms delay)
- Data loss risk
- Production outage risk
- Broken core functionality

**High Value Assignment:**
- Moderate performance (>100ms delay)
- Code quality preventing changes
- Test gaps for critical paths
- Type safety risking runtime errors

**Nice to Have Assignment:**
- Minor optimization (<50ms)
- Unlikely edge cases
- Type narrowing improving DX
- Clear style improvements

**Skip Assignment:**
- Subjective preferences
- Premature optimization
- Over-engineering
- Clarity-reducing suggestions

## Agent Handoff Patterns

### Pattern: Test Writer → Domain Agent

**Test Writer completes RED phase:**
```
Test Writer: "Failing tests written for payment validation.
Tests verify: positive amounts, required card details, address validation.
Test file: src/payment/payment-processor.test.ts
All tests fail as expected. Ready for implementation."

Main Agent → Domain Agent: "Implement payment validation to pass tests.
Tests are in src/payment/payment-processor.test.ts.
Minimum code to make tests pass. No premature abstraction.
Return implementation file path when complete."
```

### Pattern: Domain Agent → quality-refactoring-specialist

**Domain Agent completes GREEN phase:**
```
Domain Agent: "Payment validation implemented.
All tests passing. Implementation in src/payment/payment-processor.ts.
Simple conditional logic, no abstractions yet."

Main Agent → quality-refactoring-specialist: "Assess refactoring opportunities.
Code: src/payment/payment-processor.ts
Tests: src/payment/payment-processor.test.ts
Check for: duplication, complex conditionals, unclear naming.
Return: recommendations or confirmation code is clean."
```

### Pattern: Multiple Specialists → Main Agent (Parallel)

**Parallel review completion:**
```
quality-refactoring-specialist: "Found: 2 immutability violations, 1 nested conditional. Priority: High."
Test Writer: "Coverage: 95%. Missing: error boundary tests. Priority: Critical."
TypeScript Connoisseur: "Found: 1 'any' type, 2 unneeded assertions. Priority: High."
production-readiness-specialist: "Found: Unvalidated user input in /api/payment. Priority: Critical."

Main Agent synthesizes:
"Critical issues (fix first):
1. Security: Unvalidated user input in /api/payment
2. Test coverage: Missing error boundary tests

High priority (fix next):
3. Code quality: 2 immutability violations, 1 nested conditional
4. TypeScript: 1 'any' type, 2 unneeded assertions"
```

## Quality Gates

### Pre-Merge Gate

- [ ] 🔴 Zero critical issues
- [ ] ⚠️ High value issues addressed or tracked with justification
- [ ] Test Writer: 100% behavior coverage, no implementation tests
- [ ] All tests passing
- [ ] TypeScript: No errors, strict mode compliant

### Pre-Production Gate

- [ ] All Pre-Merge criteria met
- [ ] Production Readiness approval for security/performance-sensitive features
- [ ] quality-refactoring-specialist: No critical maintainability issues
- [ ] documentation-specialist: Learnings captured in project CLAUDE.md

## When to Ask vs. Proceed

### Ask First

- Requirements unclear or conflicting
- Multiple valid approaches with different tradeoffs
- Breaking changes required
- User preference needed (library choice, architectural pattern)

### Proceed with Delegation

- Clear requirements and single obvious approach
- Standard patterns apply
- No breaking changes
- Follows established conventions

## Plan Requirements

Every plan must specify which agent performs each step.

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
Step 3: production-readiness-specialist - Security review (after Step 2)
Step 4: quality-refactoring-specialist - Assess refactoring (after Step 2)
Step 5: quality-refactoring-specialist - Commit (after Steps 3 and 4)
```

**Format**: `Step N: [Agent Name] - [Task] [execution model]`

**Execution models**:
- Sequential: "(after Step N)"
- Parallel: "(parallel with Step N)"
- Independent: no annotation

## Common Parallel Patterns

**Pattern 1: Comprehensive Code Review (Batched)**
- **Batch 1**: Quality & Refactoring + TypeScript Connoisseur + Test Writer
- **Batch 2**: Production Readiness
- **When**: Pre-merge, pre-production, significant refactoring

**Pattern 2: Post-Implementation Verification**
- **Agents**: Test Writer + production-readiness-specialist (parallel)
- **When**: After feature implementation, before complete

**Pattern 3: Security + Performance Audit**
- **Agents**: production-readiness-specialist (handles both)
- **When**: Pre-production readiness, critical features

**Pattern 4: Parallel Investigation (Batched if 3+ agents)**
- **Agents**: Varies (Production Readiness + Domain Agent + Test Writer)
- **When**: Complex bugs requiring multiple analysis angles
- **Note**: If 3+ agents needed, use batches (max 3 parallel)

## Summary

Agent collaboration follows clear patterns:

1. **Sequential for dependencies** - TDD cycle, design-then-implement
2. **Parallel for independent analysis** - Code review, quality gates (max 3 at a time)
3. **Iterative for refinement** - Complex designs, user feedback
4. **Clear handoffs** - Each agent knows what to expect from previous agent
5. **Main agent synthesizes** - Never implements, always delegates
6. **Severity-based prioritization** - Critical → High → Nice → Skip

**Key principle**: The right agent for the right task at the right time. Main agent ensures this happens.
