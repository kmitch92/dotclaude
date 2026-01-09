# When to Refactor - Decision Framework

## Core Principle

**Refactoring means changing the internal structure of code without changing its external behavior.** The public API remains unchanged, all tests continue to pass, but the code becomes cleaner, more maintainable, or more efficient.

**Critical**: Only refactor when it genuinely improves the code - not all code needs refactoring. If the code is already clean and expresses intent well, commit and move on.

---

## Refactoring Priority Tiers

### Tier 1: Critical - Refactor Now

**These issues actively harm the codebase and should be addressed immediately:**

**Duplication of Knowledge (Not Just Code)**
- Same business rule expressed in multiple locations
- Related concepts that should be unified
- Knowledge that will need to change together

Example:
```typescript
// Payment validation duplicated across endpoints
// BAD: Same business rule in 3 places
const createPayment = (amount: number) => {
  if (amount <= 0 || amount > 10000) throw new Error("Invalid");
  // ...
};

const updatePayment = (amount: number) => {
  if (amount <= 0 || amount > 10000) throw new Error("Invalid");
  // ...
};

const refundPayment = (amount: number) => {
  if (amount <= 0 || amount > 10000) throw new Error("Invalid");
  // ...
};

// GOOD: Single source of truth
const validatePaymentAmount = (amount: number): void => {
  if (amount <= 0 || amount > 10000) {
    throw new Error("Invalid payment amount");
  }
};

const createPayment = (amount: number) => {
  validatePaymentAmount(amount);
  // ...
};
```

**Security or Performance Issues**
- Input not validated
- Resources not properly released
- O(n²) algorithm where O(n) possible

**Broken Abstractions**
- Leaky abstractions exposing implementation details
- Violations of single responsibility principle
- Tight coupling preventing testing

---

### Tier 2: High Value - Refactor Soon

**These improvements significantly enhance maintainability:**

**Complex Structure**
- Deeply nested conditional logic (>2 levels)
- Long functions (>20 lines for complex logic)
- Mixed levels of abstraction
- Difficult to follow control flow

Example:
```typescript
// BEFORE: Complex nested logic
const processOrder = (order: Order): ProcessedOrder => {
  if (order.items.length > 0) {
    let total = 0;
    for (const item of order.items) {
      if (item.quantity > 0) {
        if (item.price > 0) {
          total += item.price * item.quantity;
        } else {
          throw new Error("Invalid price");
        }
      } else {
        throw new Error("Invalid quantity");
      }
    }
    const shippingCost = total > 50 ? 0 : order.shippingCost;
    return { ...order, shippingCost, total: total + shippingCost };
  } else {
    throw new Error("Empty order");
  }
};

// AFTER: Clear abstraction levels
const calculateItemsTotal = (items: OrderItem[]): number => {
  if (items.length === 0) {
    throw new Error("Empty order");
  }

  return items.reduce((sum, item) => {
    validateItem(item);
    return sum + item.price * item.quantity;
  }, 0);
};

const validateItem = (item: OrderItem): void => {
  if (item.quantity <= 0) throw new Error("Invalid quantity");
  if (item.price <= 0) throw new Error("Invalid price");
};

const determineShippingCost = (total: number, standardCost: number): number => {
  const FREE_SHIPPING_THRESHOLD = 50;
  return total > FREE_SHIPPING_THRESHOLD ? 0 : standardCost;
};

const processOrder = (order: Order): ProcessedOrder => {
  const itemsTotal = calculateItemsTotal(order.items);
  const shippingCost = determineShippingCost(itemsTotal, order.shippingCost);
  return { ...order, shippingCost, total: itemsTotal + shippingCost };
};
```

**Unclear Intent**
- Variable/function/type names that don't express purpose
- Code requiring comments to understand
- Magic numbers or strings without clear meaning

Example:
```typescript
// BEFORE: Unclear intent
const processUser = (u: any) => {
  if (u.s === 1) {
    return u.v > 100 ? u.v * 0.95 : u.v;
  }
  return u.v;
};

// AFTER: Clear intent
type User = {
  status: UserStatus;
  orderValue: number;
};

type UserStatus = "premium" | "regular";

const PREMIUM_STATUS = "premium" as const;
const PREMIUM_DISCOUNT_THRESHOLD = 100;
const PREMIUM_DISCOUNT_RATE = 0.95;

const calculateFinalPrice = (user: User): number => {
  if (user.status !== PREMIUM_STATUS) {
    return user.orderValue;
  }

  const qualifiesForDiscount = user.orderValue > PREMIUM_DISCOUNT_THRESHOLD;
  return qualifiesForDiscount
    ? user.orderValue * PREMIUM_DISCOUNT_RATE
    : user.orderValue;
};
```

**Emerging Patterns**
- After implementing 2-3 similar features, abstractions become apparent
- Common operations that could be extracted
- Shared behavior across components

---

### Tier 3: Nice-to-Have - Refactor If Time Permits

**These are cosmetic improvements that marginally improve readability:**

- Renaming variables for slightly better clarity
- Extracting small one-liner functions
- Reordering code for minor flow improvements
- Formatting consistency fixes

Example:
```typescript
// Slightly better but not critical
// BEFORE
const x = calculateTotal(items);
const y = applyDiscount(x, discount);

// AFTER
const subtotal = calculateTotal(items);
const finalTotal = applyDiscount(subtotal, discount);
```

---

### Tier 4: Skip - Don't Refactor

**These should NOT be refactored:**

**Structurally Similar, Semantically Different**
- Code that looks similar but represents different business concepts
- Rules that may evolve independently
- "Duplicate code is cheaper than wrong abstraction"

Example:
```typescript
// DO NOT ABSTRACT - Different business concepts
const validatePaymentAmount = (amount: number): boolean => {
  return amount > 0 && amount <= 10000; // Fraud prevention limit
};

const validateTransferAmount = (amount: number): boolean => {
  return amount > 0 && amount <= 10000; // Daily transfer limit
};

// These will evolve independently:
// - Payment limits might change based on fraud patterns
// - Transfer limits might change based on account tier
// Abstracting them couples unrelated business rules
```

**Speculative Abstractions**
- "We might need this someday"
- Abstracting before patterns are clear (need 2-3 examples minimum)
- Creating flexibility without current need

**Already Clean Code**
- Intent is clear from names and structure
- Functions are focused and small
- No obvious improvements to make

---

## The TDD Refactoring Cycle

Refactoring is the **mandatory third step** in Red-Green-Refactor:

1. **Red**: Write a failing test
2. **Green**: Write minimum code to pass
3. **Refactor**: Assess if improvements would add value, then refactor OR move on

### Refactoring Process

**1. Commit Before Refactoring**

ALWAYS commit your working code before starting refactoring:

```bash
git add .
git commit -m "feat: add payment validation"
# Now safe to refactor
```

**2. Look for Useful Abstractions**

Create abstractions only when code shares the same **semantic meaning and purpose** (see dry-semantics.md for detailed guidance).

**3. Maintain External APIs**

Refactoring must NEVER break existing consumers:

```typescript
// Original implementation
export const processPayment = (payment: Payment): ProcessedPayment => {
  // 50 lines of complex logic all in one function
  if (payment.amount <= 0) throw new Error("Invalid amount");
  if (payment.amount > 10000) throw new Error("Amount too large");
  // ... more validation and processing
  return result;
};

// Refactored - external API UNCHANGED, internals improved
export const processPayment = (payment: Payment): ProcessedPayment => {
  validatePaymentAmount(payment.amount);
  validatePaymentMethod(payment.method);

  const authorizedPayment = authorizePayment(payment);
  const capturedPayment = capturePayment(authorizedPayment);

  return generateReceipt(capturedPayment);
};

// New internal functions - NOT exported
const validatePaymentAmount = (amount: number): void => {
  if (amount <= 0) throw new Error("Invalid amount");
  if (amount > 10000) throw new Error("Amount too large");
};

// Tests continue to pass WITHOUT MODIFICATION
```

**4. Verify and Commit**

After every refactoring:

```bash
npm test          # All tests must pass WITHOUT changes
npm run lint      # All linting must pass
npm run typecheck # TypeScript must be happy

# Only then commit
git add .
git commit -m "refactor: extract payment validation helpers"
```

---

## Decision Tree

```
Code is working (tests pass)
    ↓
    Does refactoring add value?
    ├─ YES → Identify tier:
    │        ├─ Tier 1 (Critical)? → Refactor NOW
    │        ├─ Tier 2 (High Value)? → Refactor SOON
    │        ├─ Tier 3 (Nice-to-Have)? → Refactor IF TIME
    │        └─ Tier 4 (Skip)? → DON'T refactor
    │
    └─ NO → Commit and move on
```

---

## When NOT to Refactor

### No Tests

Never refactor code without test coverage. Write tests first:

```typescript
// DON'T refactor this without tests:
const calculateDiscount = (customer: any) => {
  // Complex logic without tests
};

// DO: Write tests first, THEN refactor
```

### Unclear Requirements

Don't refactor when you don't understand what the code does:

```typescript
// Mysterious legacy code - understand it first
const processWidget = (w: any) => {
  // What is this doing? Why?
};

// First: Add characterization tests
// Then: Refactor with confidence
```

### During Feature Development

Finish the feature first (green), THEN assess refactoring:

```
❌ WRONG: Write test → Start feature → Refactor mid-implementation
✓ RIGHT: Write test → Finish feature → Commit → Assess refactoring
```

---

## Refactoring Checklist

Before considering refactoring complete:

- [ ] The refactoring actually improves the code (if not, don't refactor)
- [ ] All tests still pass without modification
- [ ] All static analysis tools pass (linting, type checking)
- [ ] No new public APIs were added (only internal ones)
- [ ] Code is more readable than before
- [ ] Any duplication removed was duplication of knowledge, not just code
- [ ] No speculative abstractions were created
- [ ] The refactoring is committed separately from feature changes

---

## Remember

**Not all code needs refactoring.** The question is not "can I refactor this?" but "would refactoring this add value?"

If the code is already clean, expressive, and well-structured:
1. Commit it
2. Move on to the next test
3. Don't refactor for refactoring's sake

**"Duplicate code is far cheaper than the wrong abstraction."**
