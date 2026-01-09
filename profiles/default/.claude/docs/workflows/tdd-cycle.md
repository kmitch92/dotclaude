# TDD Cycle: Red-Green-Refactor

## Core Mandate

**TEST-DRIVEN DEVELOPMENT IS NON-NEGOTIABLE.**

If you're typing production code without a failing test, you're not doing TDD. Stop. Write the test first.

Every single line of production code must be written in response to a failing test. No exceptions.

## The Three Phases

### RED: Write a Failing Test

**Goal:** Define expected behavior before implementation exists.

**Process:**
1. Identify ONE specific user behavior to test
2. Write test describing that behavior
3. Run test and VERIFY it fails for the right reason
4. If test passes unexpectedly → behavior already implemented or test is wrong

**Key Questions:**
- Who is the user? (human, API consumer, system component)
- What action are they taking?
- What outcome do they expect?
- What edge cases exist?

**Critical Rules:**
- Test through public API only (no implementation details)
- Use real schemas imported from codebase (never redefine)
- Test must fail before proceeding to green

### GREEN: Write Minimum Code to Pass

**Goal:** Make the test pass with simplest possible implementation.

**Process:**
1. Write ONLY enough code to pass the failing test
2. Run tests and verify they pass
3. Resist urge to add features, abstractions, or optimizations
4. Accept duplication and simplicity at this stage

**Key Principle:**
The green phase is not about perfect code. It's about proving the behavior works. Improvement comes in refactor phase.

**Critical Rules:**
- No premature abstraction
- No feature creep
- Simplest thing that could possibly work
- Tests must pass before proceeding to refactor

### REFACTOR: Assess and Improve

**Goal:** Improve code quality while preserving behavior.

**Process:**
1. Invoke quality-refactoring-specialist agent to assess opportunities
2. If improvements identified → implement refactoring
3. Run tests continuously during refactoring
4. If any test fails → revert and try different approach
5. Commit when tests pass and code is clean

**Key Principle:**
Refactoring is OPTIONAL. If code is already clean, skip this phase. The quality-refactoring-specialist will confirm when code is good as-is.

**Critical Rules:**
- Tests must not change (behavior remains constant)
- All tests must pass throughout refactoring
- Refactor in small steps with frequent test runs
- If unsure whether to refactor → consult quality-refactoring-specialist

## Complete Example: Order Processing

See @~/.claude/docs/examples/tdd-complete-cycle.md for full workflow example with order processing and free shipping.

## Quality Gates Before Commit

Verify ALL criteria met:

- [ ] All tests verify user-observable behaviors only
- [ ] No tests examine implementation details
- [ ] All tests use real schemas imported from codebase
- [ ] Test names clearly describe expected behavior
- [ ] Tests would remain valid if implementation changes
- [ ] TypeScript strict mode requirements met
- [ ] All code follows immutable, functional patterns
- [ ] Tests organized by feature/behavior, not code structure
- [ ] No comments (code is self-documenting)
- [ ] Red-Green-Refactor cycle followed for ALL changes
- [ ] 100% coverage achieved as side effect of testing behaviors
- [ ] quality-refactoring-specialist consulted after green phase
- [ ] All tests pass

## Common Pitfalls

### Writing Tests After Code

**Wrong:**
```
1. Write production code
2. Write tests to verify it works
```

**Why wrong:** Tests become implementation verification, not behavior specification. You've already committed to an implementation approach.

**Right:**
```
1. Write failing test describing behavior
2. Write minimum code to pass
3. Assess refactoring opportunities
```

### Testing Implementation Details

**Wrong:**
```typescript
it("should call checkBalance method", () => {
  const spy = jest.spyOn(processor, 'checkBalance');
  processor.processPayment(payment);
  expect(spy).toHaveBeenCalled();
});
```

**Why wrong:** Test breaks if you refactor to not use `checkBalance`, even if behavior is still correct.

**Right:**
```typescript
it("should decline payment when insufficient funds", () => {
  const payment = getMockPayment({ Amount: 1000 });
  const account = getMockAccount({ Balance: 500 });

  const result = processPayment(payment, account);

  expect(result.success).toBe(false);
  expect(result.error.message).toBe("Insufficient funds");
});
```

### Skipping the Refactor Phase Assessment

**Wrong:**
```
1. Write test (RED)
2. Make test pass (GREEN)
3. Move to next test immediately
```

**Why wrong:** Accumulates technical debt. Code quality degrades over time.

**Right:**
```
1. Write test (RED)
2. Make test pass (GREEN)
3. Invoke quality-refactoring-specialist to assess
4. Refactor if valuable improvements identified
5. Commit when clean
```

### Premature Abstraction in Green Phase

**Wrong:**
```typescript
// GREEN phase - writing generic framework before simple solution
const processOrder = <T extends Order>(
  order: T,
  rules: ProcessingRule<T>[]
): ProcessedOrder<T> => {
  return rules.reduce((acc, rule) => rule.apply(acc), order);
};
```

**Why wrong:** Over-engineering before understanding actual needs. Abstractions should emerge from concrete examples.

**Right:**
```typescript
// GREEN phase - simple solution first
const processOrder = (order: Order): ProcessedOrder => {
  const itemsTotal = order.items.reduce(
    (sum, item) => sum + item.price * item.quantity,
    0
  );
  const shippingCost = itemsTotal > 50 ? 0 : order.shippingCost;
  return { ...order, shippingCost, total: itemsTotal + shippingCost };
};
```

After multiple similar patterns emerge → THEN consider abstraction in refactor phase.

### Redefining Schemas in Tests

❌ Test file redefines schema → schemas drift
✓ Import real schemas from codebase

### 1:1 Test File to Implementation File Mapping

❌ payment-validator.test.ts mirrors payment-validator.ts → encourages testing internals
✓ Organize by feature/behavior, test through public API

## Agent Collaboration in TDD Cycle

### Sequential Flow (Standard Pattern)

```
Main Agent
  → Test Writer (RED: write failing test)
  → Domain Agent (GREEN: implement to pass test)
  → Test Writer (verify coverage, tests pass)
  → quality-refactoring-specialist (REFACTOR: assess opportunities)
  → Domain Agent (implement refactoring if needed)
  → Test Writer (verify tests still pass)
  → quality-refactoring-specialist (commit)
  → documentation-specialist (capture learnings)
```

### Key Agent Responsibilities

**Test Writer:**
- Write failing tests (RED phase)
- Verify coverage and test passage
- Confirm tests unchanged during refactoring
- MANDATORY: Invoke quality-refactoring-specialist after GREEN

**Domain Agent (React Engineer, Backend Developer, etc):**
- Implement minimum code to pass (GREEN phase)
- Execute refactoring if quality-refactoring-specialist recommends
- Never write production code without failing test first

**quality-refactoring-specialist:**
- Assess code quality after GREEN phase
- Identify refactoring opportunities
- Confirm when code is clean as-is
- Guide refactoring execution
- Handle all git operations (commits, branching, PRs)

**Main Agent:**
- Orchestrate TDD cycle (never implement directly)
- Ensure RED-GREEN-REFACTOR sequence followed
- Synthesize results and track progress

## TDD Non-Negotiable Checklist

Before considering ANY task complete:

- [ ] Every production code line written in response to failing test
- [ ] RED phase: Test written first and verified to fail
- [ ] GREEN phase: Minimum code to pass written
- [ ] REFACTOR phase: quality-refactoring-specialist consulted
- [ ] Tests verify behaviors through public API only
- [ ] No implementation details tested
- [ ] Real schemas imported from codebase (not redefined)
- [ ] All tests pass
- [ ] 100% coverage as side effect of behavior testing
- [ ] Code follows immutable, functional patterns
- [ ] Committed with conventional commit message

## Summary

TDD is a discipline, not a suggestion. The RED-GREEN-REFACTOR cycle ensures:

1. **Clear requirements** - Tests are specifications
2. **Working code** - Every line proven by passing test
3. **Clean design** - Refactoring with safety net of tests
4. **High coverage** - Natural side effect of testing behaviors
5. **Maintainability** - Tests document intended behavior

**Remember:** The goal is not to write tests. The goal is to write working, clean code. Tests are the tool that makes this possible.

When in doubt, return to the cycle: RED (test first) → GREEN (make it work) → REFACTOR (make it clean).
