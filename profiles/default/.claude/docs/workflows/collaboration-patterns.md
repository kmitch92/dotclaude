# Agent Collaboration Patterns

## Core Principle

**The Main Agent orchestrates, never implements.** All code changes are delegated to specialized agents.

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

**Key Rule:** To run agents in parallel, send ONE message with MULTIPLE Task tool calls.

**Example:**
```
[SINGLE message with FOUR Task tool calls]

Task 1:
- subagent_type: "quality-refactoring-specialist"
- description: "Review code quality"
- prompt: "Review src/payment/processor.ts for: immutability violations, nested conditionals, unclear naming, functional patterns. Return prioritized feedback."

Task 2:
- subagent_type: "Test Writer"
- description: "Review test coverage"
- prompt: "Review tests for payment processor. Verify: all behaviors tested, no implementation details tested, real schemas used. Return coverage gaps."
```

## Critical Architecture: No Agent-to-Agent Invocation

**ONLY Main Agent invokes specialized agents.** Specialized agents complete their work and return to Main Agent with recommendations.

**Why this architecture:**
- **Prevents recursive invocation chains**: Agent A cannot invoke Agent B who invokes Agent C
- **Avoids heap memory errors**: Prevents JavaScript heap exhaustion
- **Maintains clear control flow**: Single orchestrator
- **Enables proper error handling**: Main Agent catches failures

**Pattern - CORRECT:**
```
Main Agent → Agent A (assign task)
Agent A completes work
Agent A → Main Agent (results + "Recommend invoking Agent B for [reason]")
Main Agent evaluates recommendation
Main Agent → Agent B (assign task based on Agent A results)
```

**Pattern - WRONG:**
```
Main Agent → Agent A → Agent B → Agent C
[System crashes: JavaScript heap out of memory]
```

### Hard Limit: Maximum 2 Agents in Parallel

**Enforced by Main Agent only.**

**When 3+ agents needed:**
- Use sequential batches of 2
- Batch 1: Invoke 2 agents (parallel)
- Wait for Batch 1 completion and review results
- Batch 2: Invoke remaining agents (sequential)

**Rationale:**
- Prevents resource contention
- Maintains focus and synthesis quality
- Avoids "too many cooks" problem

## Collaboration Patterns

### Pattern 1: Sequential Delegation

**Use when:** Tasks have dependencies

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

**Use when:** Multiple independent perspectives needed

**Flow:**
```
Main Agent → [Agent 1 + Agent 2] analyze simultaneously → Main synthesizes
```

**Example: Code Review (Batched)**
```
Batch 1 (2 agents parallel):
- quality-refactoring-specialist (style, patterns, anti-patterns)
- TypeScript Connoisseur (types, schemas, strict mode)

[Wait for Batch 1, review findings]

Batch 2 (2 agents parallel):
- production-readiness-specialist (vulnerabilities, PII handling)
- Test Writer (coverage, behavior focus, test quality)

Main synthesizes all feedback
```

### Pattern 3: Iterative Refinement

**Use when:** Complex task requires multiple rounds

**Flow:**
```
Main → Agent 1 (initial) → Main reviews → Agent 2 (feedback) → Main synthesizes → Agent 1 (refinement)
```

**Example: API Design with Security Review**
```
Design Specialist creates initial design
→ Main reviews design document
→ production-readiness-specialist reviews for security
→ Main identifies required changes
→ Design Specialist refines design
→ Main confirms design complete
```

## Domain Agent Selection

### Primary Technology Determines Agent

| Technology | Primary Agent | When to Invoke |
|------------|--------------|----------------|
| React components | React Engineer | Component implementation, hooks, SSR |
| API endpoints | Backend TypeScript Developer | Lambda, Express routes, API logic, CDK |
| Database schema | Design Specialist | Schema design, migrations, queries |
| Shell scripts | Shell Specialist | Installation scripts, git hooks, CLI |
| Type definitions | TypeScript Connoisseur | Complex types, generics, schemas |
| Tests | Test Writer | All testing activities, coverage |

### Supporting Agents for Cross-Cutting Concerns

| Concern | Agent | When to Invoke |
|---------|-------|----------------|
| Security & Performance | production-readiness-specialist | Auth, PII, payments, user input, before production |
| Code quality & Refactoring | quality-refactoring-specialist | After GREEN phase (mandatory), all commits, PRs |
| API & Database design | Design Specialist | Before implementing endpoints, contract-first |
| Documentation | documentation-specialist | After feature completion, capture learnings |

## Parallelization Decision Matrix

### Use Parallel When:

**Independent Analysis Tasks:**
- Code review from multiple perspectives
- Security + Performance + Quality assessments
- Multi-domain design (API + Database)

**Example:**
```
Batched code review (max 2 parallel):
Batch 1: [Quality & Refactoring + TypeScript] → Review
Batch 2: [Production Readiness + Test Writer] → Review
→ Synthesize all findings
```

### Use Sequential When:

**Dependency Chain:**
- TDD cycle steps (test → implement → verify)
- Design then implement
- Fix then verify

**Decision Rule:**
- Task B needs Task A output? → Sequential
- Tasks analyzing same artifact independently? → Parallel (batched if >2)
- Tasks working on different components? → Depends

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

## Summary

Agent collaboration is orchestrated through clear patterns:

1. **Sequential for dependencies** - TDD cycle, design-then-implement
2. **Parallel for independent analysis** - Code review, quality gates (max 2 at a time)
3. **Iterative for refinement** - Complex designs, user feedback
4. **Clear handoffs** - Each agent knows what to expect from previous agent
5. **Main agent synthesizes** - Never implements, always delegates

**Key principle:** The right agent for the right task at the right time. Main agent ensures this happens.

## Related

- [Collaboration Workflows](./collaboration-workflows.md) - Standard workflows for common tasks
- [TDD Cycle](./tdd-cycle.md) - Red-Green-Refactor workflow
- [Code Review Process](./code-review-process.md) - Comprehensive review workflows
