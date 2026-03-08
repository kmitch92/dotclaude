---
name: tdd-workflow
description: Test-driven development using Red-Green-Refactor cycle. Behavioral testing, failing tests first, minimum implementation, refactoring assessment.
---

# TDD Workflow: Red-Green-Refactor

## Core Mandate

**TEST-DRIVEN DEVELOPMENT IS NON-NEGOTIABLE.**

Every single line of production code must be written in response to a failing test. No exceptions.

If you're typing production code without a failing test, you're not doing TDD. Stop. Write the test first.

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

Full workflow demonstrating Red-Green-Refactor with schema-first design and behavioral testing.

### Iteration 1: Creating an Order

#### Red: Write Failing Test

```typescript
// order.test.ts
import { describe, it, expect } from 'vitest';
import { createOrder, type Order } from './order';

describe('Order Processing', () => {
  it('should create valid order with items', () => {
    const order = createOrder({
      customerId: 'cust-123',
      items: [{ productId: 'prod-1', quantity: 2, unitPrice: 10.00 }]
    });

    expect(order.id).toBeDefined();
    expect(order.customerId).toBe('cust-123');
    expect(order.items).toHaveLength(1);
    expect(order.status).toBe('pending');
    expect(order.total).toBe(20.00);
    expect(order.createdAt).toBeInstanceOf(Date);
  });
});
```

**Run test:** ❌ Fails - `createOrder` doesn't exist

#### Green: Minimum Code to Pass

```typescript
// order.ts
import { z } from 'zod';

// Schema first
const OrderItemSchema = z.object({
  productId: z.string().min(1),
  quantity: z.number().int().positive(),
  unitPrice: z.number().positive()
});

const OrderSchema = z.object({
  id: z.string(),
  customerId: z.string().min(1),
  items: z.array(OrderItemSchema).min(1),
  status: z.enum(['pending', 'processing', 'completed', 'cancelled']),
  total: z.number().nonnegative(),
  createdAt: z.date()
});

type OrderItem = z.infer<typeof OrderItemSchema>;
type Order = z.infer<typeof OrderSchema>;

type CreateOrderInput = {
  customerId: string;
  items: OrderItem[];
};

const createOrder = (input: CreateOrderInput): Order => {
  const total = input.items.reduce(
    (sum, item) => sum + (item.quantity * item.unitPrice), 0
  );

  return OrderSchema.parse({
    id: `order-${Date.now()}`,
    customerId: input.customerId,
    items: input.items,
    status: 'pending' as const,
    total,
    createdAt: new Date()
  });
};

export { createOrder, OrderSchema, OrderItemSchema };
export type { Order, OrderItem };
```

**Run test:** ✅ Passes

#### Refactor: Assess

**Analysis:** Code is simple, single responsibility, schema validates correctness.

**Decision:** No refactoring needed - already clean.

### Iteration 2: Validation Edge Cases

#### Red: Write Failing Tests

```typescript
it('should throw for empty items', () => {
  expect(() => createOrder({ customerId: 'cust-123', items: [] })).toThrow();
});

it('should throw for negative quantities', () => {
  expect(() =>
    createOrder({
      customerId: 'cust-123',
      items: [{ productId: 'prod-1', quantity: -1, unitPrice: 10.00 }]
    })
  ).toThrow();
});

it('should throw for invalid customer ID', () => {
  expect(() =>
    createOrder({
      customerId: '',
      items: [{ productId: 'prod-1', quantity: 1, unitPrice: 10.00 }]
    })
  ).toThrow();
});
```

**Run tests:** ✅ All pass - Schema already validates these!

**Learning:** Schema-first design caught edge cases automatically. No code changes needed.

### Iteration 3: Processing Orders

#### Red: Write Failing Test

```typescript
it('should process pending order', () => {
  const order = createOrder({
    customerId: 'cust-123',
    items: [{ productId: 'prod-1', quantity: 1, unitPrice: 10.00 }]
  });

  const processed = processOrder(order);

  expect(processed.status).toBe('processing');
  expect(processed.id).toBe(order.id);
});

it('should reject non-pending orders', () => {
  const order = createOrder({
    customerId: 'cust-123',
    items: [{ productId: 'prod-1', quantity: 1, unitPrice: 10.00 }]
  });
  const processed = processOrder(order);

  expect(() => processOrder(processed)).toThrow('Can only process pending orders');
});
```

**Run tests:** ❌ Fails - `processOrder` doesn't exist

#### Green: Minimum Code

```typescript
const processOrder = (order: Order): Order => {
  if (order.status !== 'pending') {
    throw new Error('Can only process pending orders');
  }

  return OrderSchema.parse({
    ...order,
    status: 'processing' as const
  });
};

export { processOrder };
```

**Run tests:** ✅ Passes

#### Refactor: Extract Guard Clause

```typescript
// Better: explicit guard function
const ensurePendingStatus = (order: Order): void => {
  if (order.status !== 'pending') {
    throw new Error('Can only process pending orders');
  }
};

const processOrder = (order: Order): Order => {
  ensurePendingStatus(order);
  return OrderSchema.parse({ ...order, status: 'processing' as const });
};
```

**Tests:** ✅ Still pass (refactoring doesn't change behavior)

### Iteration 4: Applying Discounts

#### Red: Write Failing Test

```typescript
it('should apply discount to order total', () => {
  const order = createOrder({
    customerId: 'cust-123',
    items: [{ productId: 'prod-1', quantity: 2, unitPrice: 50.00 }]
  });

  const discounted = applyDiscount(order, 0.10); // 10% discount

  expect(discounted.total).toBe(90.00);
  expect(discounted.discount).toBe(10.00);
});

it('should reject invalid discount percentages', () => {
  const order = createOrder({
    customerId: 'cust-123',
    items: [{ productId: 'prod-1', quantity: 1, unitPrice: 100.00 }]
  });

  expect(() => applyDiscount(order, -0.1)).toThrow();
  expect(() => applyDiscount(order, 1.1)).toThrow();
});
```

**Run tests:** ❌ Fails - `applyDiscount` doesn't exist, schema missing `discount` field

#### Green: Update Schema and Add Function

```typescript
// Update OrderSchema
const OrderSchema = z.object({
  id: z.string(),
  customerId: z.string().min(1),
  items: z.array(OrderItemSchema).min(1),
  status: z.enum(['pending', 'processing', 'completed', 'cancelled']),
  total: z.number().nonnegative(),
  discount: z.number().nonnegative().default(0),
  createdAt: z.date()
});

// Add discount validation
const DiscountSchema = z.number().min(0).max(1);

// Implement applyDiscount
const applyDiscount = (order: Order, discountPercent: number): Order => {
  const validated = DiscountSchema.parse(discountPercent);
  const discountAmount = order.total * validated;
  const newTotal = order.total - discountAmount;

  return OrderSchema.parse({
    ...order,
    discount: discountAmount,
    total: newTotal
  });
};

export { applyDiscount };
```

**Run tests:** ✅ Passes

#### Refactor: Extract Calculation

```typescript
const calculateDiscount = (total: number, percent: number): number => {
  const validated = DiscountSchema.parse(percent);
  return total * validated;
};

const applyDiscount = (order: Order, discountPercent: number): Order => {
  const discountAmount = calculateDiscount(order.total, discountPercent);

  return OrderSchema.parse({
    ...order,
    discount: discountAmount,
    total: order.total - discountAmount
  });
};
```

**Tests:** ✅ Still pass

### Final Code Structure

```typescript
// order.ts
import { z } from 'zod';

// Schemas
const OrderItemSchema = z.object({
  productId: z.string().min(1),
  quantity: z.number().int().positive(),
  unitPrice: z.number().positive()
});

const OrderSchema = z.object({
  id: z.string(),
  customerId: z.string().min(1),
  items: z.array(OrderItemSchema).min(1),
  status: z.enum(['pending', 'processing', 'completed', 'cancelled']),
  total: z.number().nonnegative(),
  discount: z.number().nonnegative().default(0),
  createdAt: z.date()
});

const DiscountSchema = z.number().min(0).max(1);

// Types
type OrderItem = z.infer<typeof OrderItemSchema>;
type Order = z.infer<typeof OrderSchema>;

// Functions
const createOrder = (input: { customerId: string; items: OrderItem[] }): Order => {
  const total = input.items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
  return OrderSchema.parse({
    id: `order-${Date.now()}`,
    customerId: input.customerId,
    items: input.items,
    status: 'pending',
    total,
    discount: 0,
    createdAt: new Date()
  });
};

const ensurePendingStatus = (order: Order): void => {
  if (order.status !== 'pending') throw new Error('Can only process pending orders');
};

const processOrder = (order: Order): Order => {
  ensurePendingStatus(order);
  return OrderSchema.parse({ ...order, status: 'processing' });
};

const calculateDiscount = (total: number, percent: number): number => {
  return total * DiscountSchema.parse(percent);
};

const applyDiscount = (order: Order, discountPercent: number): Order => {
  const discountAmount = calculateDiscount(order.total, discountPercent);
  return OrderSchema.parse({
    ...order,
    discount: discountAmount,
    total: order.total - discountAmount
  });
};

export { createOrder, processOrder, applyDiscount, OrderSchema, OrderItemSchema };
export type { Order, OrderItem };
```

**Key Lessons:**
1. **Schema-First**: Zod schemas catch edge cases automatically
2. **Red-Green-Refactor**: Each iteration follows strict cycle
3. **Behavioral Testing**: Tests verify outcomes, not implementation
4. **Small Steps**: Each iteration adds one behavior
5. **Refactoring Safety**: Tests ensure refactoring doesn't break behavior
6. **Immutability**: All functions return new objects (no mutation)

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

### Sequential Flow (ENFORCED — Token-Gated)

```
Main Agent
  → Test Writer (RED: write failing test)
      ↳ outputs [RED COMPLETE] — gates Domain Agent
  → Domain Agent (GREEN: implement to pass test)
      ↳ checks for [RED COMPLETE] in prompt, outputs [GREEN COMPLETE]
  → Test Writer (verify coverage, tests pass)
      ↳ outputs [GREEN VERIFIED] — gates Quality & Refactoring
  → Quality & Refactoring (REFACTOR: assess opportunities)
      ↳ outputs [REFACTOR COMPLETE] — gates Git Specialist commit
  → Domain Agent (implement refactoring if needed)
      ↳ outputs [GREEN COMPLETE]
  → Test Writer (verify tests still pass)
      ↳ outputs [POST-REFACTOR VERIFIED]
  → Git Specialist (commit — checks for [REFACTOR COMPLETE])
  → Documentation Specialist (capture learnings)
```

**Skipping any step = RULE VIOLATION equivalent to Main Agent writing code directly.**

Each arrow represents a mandatory sequential handoff. Tokens at each step form an evidence chain. Domain agents REFUSE implementation if their prompt lacks test references or `[RED COMPLETE]`.

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

## Quality Gates Before Commit

Verify ALL criteria met:

- [ ] Every production code line written in response to failing test
- [ ] RED phase: Test written first and verified to fail
- [ ] GREEN phase: Minimum code to pass written
- [ ] REFACTOR phase: quality-refactoring-specialist consulted
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
- [ ] All tests pass

## Summary

TDD is a discipline, not a suggestion. The RED-GREEN-REFACTOR cycle ensures:

1. **Clear requirements** - Tests are specifications
2. **Working code** - Every line proven by passing test
3. **Clean design** - Refactoring with safety net of tests
4. **High coverage** - Natural side effect of testing behaviors
5. **Maintainability** - Tests document intended behavior

**Remember:** The goal is not to write tests. The goal is to write working, clean code. Tests are the tool that makes this possible.

When in doubt, return to the cycle: RED (test first) → GREEN (make it work) → REFACTOR (make it clean).
