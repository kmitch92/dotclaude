# DRY Principle: Semantic vs Structural Duplication

## Core Principle

**Semantic duplication** (doing different things that happen to look similar) should NOT be extracted.

**Structural duplication** (doing the same thing multiple times) SHOULD be extracted.

## Example: Over-Abstraction Trap

### Poor Abstraction (Over-DRY)

```typescript
// BEFORE - Structural duplication extracted (BAD)
function processData(
  data: unknown[],
  validator: (item: unknown) => boolean,
  transformer: (item: unknown) => unknown,
  aggregator: (acc: unknown, item: unknown) => unknown,
  initialValue: unknown
): unknown {
  return data
    .filter(validator)
    .map(transformer)
    .reduce(aggregator, initialValue);
}

// Usage is confusing - what does this do?
const result1 = processData(
  orders,
  (o: any) => o.status === 'paid',
  (o: any) => o.total,
  (sum: number, total: number) => sum + total,
  0
);

const result2 = processData(
  users,
  (u: any) => u.isActive,
  (u: any) => u.email,
  (emails: string[], email: string) => [...emails, email],
  []
);
```

**Problems:**
- Abstraction hides intent
- Generic names provide no meaning
- Hard to understand what's happening
- Types are lost (using `unknown`)
- Need to read all callback implementations to understand behavior

### Good Semantic Separation (AFTER)

```typescript
// AFTER - Semantic functions (GOOD)
const OrderSchema = z.object({
  id: z.string(),
  status: z.enum(['pending', 'paid', 'shipped']),
  total: z.number()
});

const UserSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  isActive: z.boolean()
});

type Order = z.infer<typeof OrderSchema>;
type User = z.infer<typeof UserSchema>;

// Each function has semantic meaning
function calculatePaidOrdersTotal(orders: Order[]): number {
  return orders
    .filter(order => order.status === 'paid')
    .reduce((sum, order) => sum + order.total, 0);
}

function getActiveUserEmails(users: User[]): string[] {
  return users
    .filter(user => user.isActive)
    .map(user => user.email);
}

// Usage is clear - intent is obvious
const totalRevenue = calculatePaidOrdersTotal(orders);
const activeEmails = getActiveUserEmails(users);
```

**Improvements:**
- Function names describe business intent
- Types are preserved and specific
- Self-documenting code
- Easy to test and modify
- Intent is immediately clear from function name

**Why better:**
The two functions serve different business purposes (revenue calculation vs email collection). Even though they have similar structure (filter + transform/reduce), they represent different semantic operations and should remain separate.

## When to Extract

### Extract Structural Duplication (SAME LOGIC)

```typescript
// BEFORE - Same logic repeated
function getUserById(id: string): User | null {
  const response = await fetch(`/api/users/${id}`);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response.json();
}

function getOrderById(id: string): Order | null {
  const response = await fetch(`/api/orders/${id}`);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response.json();
}

// AFTER - Extract structural duplication
async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response.json();
}

function getUserById(id: string): Promise<User> {
  return fetchJson<User>(`/api/users/${id}`);
}

function getOrderById(id: string): Promise<Order> {
  return fetchJson<Order>(`/api/orders/${id}`);
}
```

**Why extract:**
Identical fetch-and-error-check logic. Same structural pattern serving same purpose.

### Keep Semantic Duplication (DIFFERENT PURPOSES)

```typescript
// KEEP SEPARATE - Different semantic meanings
function calculateShippingCost(weight: number, distance: number): number {
  if (weight <= 0 || distance <= 0) {
    throw new Error('Invalid shipping parameters');
  }
  return weight * 0.5 + distance * 0.2;
}

function calculateTaxAmount(subtotal: number, taxRate: number): number {
  if (subtotal < 0 || taxRate < 0) {
    throw new Error('Invalid tax parameters');
  }
  return subtotal * taxRate;
}
```

**Why keep separate:**
Different business logic (shipping vs tax), different validation rules (what constitutes "invalid"), different future evolution paths. Similar structure is coincidental.

## Decision Framework

Ask these questions:

1. **Do they represent the same business concept?**
   - YES → Consider extracting
   - NO → Keep separate

2. **Would they evolve together?**
   - YES → Extract
   - NO → Keep separate

3. **Does extraction make intent clearer or more obscure?**
   - Clearer → Extract
   - Obscure → Keep separate

4. **Are the types compatible without type erasure (`unknown`/`any`)?**
   - YES → Safe to extract
   - NO → Keep separate

## Anti-Patterns to Avoid

### Generic "Util" Functions

```typescript
// ❌ BAD - Generic util hiding business logic
function processItems<T>(
  items: T[],
  condition: (item: T) => boolean,
  transform: (item: T) => T
): T[] {
  return items.filter(condition).map(transform);
}

// ✓ GOOD - Specific business functions
function getEligibleOrdersForDiscount(orders: Order[]): Order[] {
  return orders.filter(order => order.total > 100);
}

function applyDiscountToOrders(orders: Order[]): Order[] {
  return orders.map(order => ({
    ...order,
    total: order.total * 0.9
  }));
}
```

### Premature Abstraction

```typescript
// ❌ BAD - Abstracting after seeing pattern ONCE
function handleApiCall(endpoint: string, method: string, body?: unknown) {
  // Complex generic handler
}

// ✓ GOOD - Wait for third occurrence (Rule of Three)
// First occurrence: write it
// Second occurrence: tolerate duplication
// Third occurrence: NOW extract
```

## Summary

**Extract when:**
- Same logic appears multiple times (structural duplication)
- Code represents same business concept
- Changes would need to happen in lockstep
- Extraction preserves or improves clarity
- Types remain specific

**Keep separate when:**
- Different business purposes (semantic duplication)
- Similar structure is coincidental
- Different evolution paths expected
- Extraction requires type erasure or generic parameters
- Function names would become less meaningful

**Remember:** Clarity > Brevity. Duplication is cheaper than wrong abstraction.

## Related
- [Refactoring Stepwise Example](refactoring-stepwise-example.md)
- [Common Refactoring Patterns](../patterns/refactoring/common-patterns.md)
- [When to Refactor](../patterns/refactoring/when-to-refactor.md)
