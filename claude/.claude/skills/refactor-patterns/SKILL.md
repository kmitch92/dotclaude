---
name: refactor-patterns
description: Refactoring patterns and decisions. Extract function, guard clauses, strategy pattern, functional pipelines, DRY principle (semantic vs structural), when to refactor vs when not to.
---

# Refactoring Patterns

## Core Philosophy

**Refactoring means changing the internal structure of code without changing its external behavior.** The public API remains unchanged, all tests continue to pass, but the code becomes cleaner, more maintainable, or more efficient.

**Critical**: Only refactor when it genuinely improves the code - not all code needs refactoring. If the code is already clean and expresses intent well, commit and move on.

**"Duplicate code is cheaper than the wrong abstraction."**

---

## Common Refactoring Patterns

### Extract Function

**When to apply**: Function >20 lines, mixes abstraction levels, distinct purpose exists

```typescript
// BEFORE
const processOrder = (order: Order): ProcessedOrder => {
  const itemsTotal = order.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const shippingCost = itemsTotal > 50 ? 0 : order.shippingCost;
  return { ...order, shippingCost, total: itemsTotal + shippingCost };
};

// AFTER
const calculateItemsTotal = (items: OrderItem[]): number =>
  items.reduce((sum, item) => sum + item.price * item.quantity, 0);

const determineShippingCost = (itemsTotal: number, standardCost: number): number =>
  itemsTotal > 50 ? 0 : standardCost;

const processOrder = (order: Order): ProcessedOrder => {
  const itemsTotal = calculateItemsTotal(order.items);
  const shippingCost = determineShippingCost(itemsTotal, order.shippingCost);
  return { ...order, shippingCost, total: itemsTotal + shippingCost };
};
```

**Benefits**: Single responsibility, reusable components, self-documenting names

### Extract Constant

**When to apply**: Magic numbers, repeated strings, configuration values, business rules

```typescript
// BEFORE
const calculateShipping = (weight: number, distance: number): number => {
  if (weight > 20) return distance * 2.5;
  if (distance > 500) return 15.99;
  return 9.99;
};

// AFTER
const HEAVY_ITEM_THRESHOLD_KG = 20;
const HEAVY_ITEM_RATE_PER_KM = 2.5;
const LONG_DISTANCE_THRESHOLD_KM = 500;
const LONG_DISTANCE_FLAT_RATE = 15.99;
const STANDARD_SHIPPING_RATE = 9.99;

const calculateShipping = (weight: number, distance: number): number => {
  if (weight > HEAVY_ITEM_THRESHOLD_KG) return distance * HEAVY_ITEM_RATE_PER_KM;
  if (distance > LONG_DISTANCE_THRESHOLD_KM) return LONG_DISTANCE_FLAT_RATE;
  return STANDARD_SHIPPING_RATE;
};
```

**Benefits**: Self-documenting rules, single place to update, centralized configuration

### Replace Conditional with Strategy Pattern

**When to apply**: Type-based if/else chains, switch on type field, type-specific behavior

```typescript
// BEFORE
const calculateDiscount = (customer: Customer, amount: number): number => {
  if (customer.type === "premium") return amount * 0.2;
  if (customer.type === "regular") return amount * 0.1;
  return 0;
};

// AFTER
type CustomerStrategy = {
  calculateDiscount: (amount: number) => number;
  calculateShippingCost: (weight: number) => number;
};

const strategies: Record<CustomerType, CustomerStrategy> = {
  premium: {
    calculateDiscount: (amount) => amount * 0.2,
    calculateShippingCost: () => 0,
  },
  regular: {
    calculateDiscount: (amount) => amount * 0.1,
    calculateShippingCost: (weight) => weight * 0.5,
  },
  guest: {
    calculateDiscount: () => 0,
    calculateShippingCost: (weight) => weight * 1.0,
  },
};

const getStrategy = (type: CustomerType) => strategies[type];
```

**Benefits**: Open-closed principle, isolated strategies, easy to extend

### Replace Nested Conditionals with Guard Clauses

**When to apply**: Nested if >2 levels, error conditions scattered, hard to follow control flow

```typescript
// BEFORE
const processRefund = (order: Order, reason: string): Refund => {
  if (order.status === "completed") {
    if (order.paidAmount > 0) {
      if (reason.length > 10) {
        if (order.refundable) {
          return createRefund(order, reason);
        } else {
          throw new Error("Order not refundable");
        }
      } else {
        throw new Error("Reason too short");
      }
    } else {
      throw new Error("No payment to refund");
    }
  } else {
    throw new Error("Order not completed");
  }
};

// AFTER
const processRefund = (order: Order, reason: string): Refund => {
  if (order.status !== "completed") throw new Error("Order not completed");
  if (order.paidAmount <= 0) throw new Error("No payment to refund");
  if (reason.length <= 10) throw new Error("Reason too short");
  if (!order.refundable) throw new Error("Order not refundable");

  return createRefund(order, reason);
};
```

**Benefits**: Linear control flow, explicit error conditions, happy path visible

### Replace Type Code with Discriminated Union

**When to apply**: String literals represent types, type-specific fields, runtime type checking needed

```typescript
// BEFORE
type Payment = {
  type: string;
  amount: number;
  cardNumber?: string;
  accountNumber?: string;
  walletAddress?: string;
};

// AFTER
type CreditCardPayment = {
  type: "credit_card";
  amount: number;
  cardNumber: string;
  cvv: string;
};

type BankTransferPayment = {
  type: "bank_transfer";
  amount: number;
  accountNumber: string;
  routingNumber: string;
};

type CryptoPayment = {
  type: "crypto";
  amount: number;
  walletAddress: string;
  network: string;
};

type Payment = CreditCardPayment | BankTransferPayment | CryptoPayment;

const processPayment = (payment: Payment): ProcessedPayment => {
  switch (payment.type) {
    case "credit_card":
      return processCreditCard(payment);
    case "bank_transfer":
      return processBankTransfer(payment);
    case "crypto":
      return processCrypto(payment);
    default:
      const exhaustive: never = payment;
      throw new Error(`Unknown payment type: ${exhaustive}`);
  }
};
```

**Benefits**: Type safety, exhaustiveness checking, impossible states impossible

### Introduce Parameter Object

**When to apply**: Functions with >3 parameters, same parameters passed together, cohesive concept

```typescript
// BEFORE
const createUser = (
  firstName: string,
  lastName: string,
  email: string,
  street: string,
  city: string,
  state: string,
  zipCode: string,
  country: string
): User => {
  // Implementation
};

// AFTER
type PersonalInfo = {
  firstName: string;
  lastName: string;
  email: string;
};

type Address = {
  street: string;
  city: string;
  state: string;
  zipCode: string;
  country: string;
};

type CreateUserParams = {
  personalInfo: PersonalInfo;
  address: Address;
};

const createUser = (params: CreateUserParams): User => {
  const { personalInfo, address } = params;
  // Implementation
};
```

**Benefits**: Organized parameters, reusable types, named parameters

### Replace Loop with Pipeline

**When to apply**: Loop performs transformations, temporary variables accumulate, imperative collection processing

```typescript
// BEFORE
const processOrders = (orders: Order[]): OrderSummary[] => {
  const results: OrderSummary[] = [];
  for (const order of orders) {
    if (order.status === "completed") {
      if (order.total > 100) {
        results.push({
          id: order.id,
          customerName: order.customer.name,
          total: order.total,
          discountApplied: order.total * 0.1,
        });
      }
    }
  }
  return results;
};

// AFTER
const isCompleted = (order: Order) => order.status === "completed";
const isHighValue = (order: Order) => order.total > 100;
const toSummary = (order: Order): OrderSummary => ({
  id: order.id,
  customerName: order.customer.name,
  total: order.total,
  discountApplied: order.total * 0.1,
});

const processOrders = (orders: Order[]): OrderSummary[] =>
  orders.filter(isCompleted).filter(isHighValue).map(toSummary);
```

**Benefits**: Declarative, independently testable steps, immutable, composable

---

## DRY Principle: Semantic vs Structural Duplication

### Core Principle

**"DRY addresses duplicated knowledge, not duplicated code."**

The DRY (Don't Repeat Yourself) principle is fundamentally about **semantic duplication** - duplicated knowledge, business rules, or concepts - NOT about eliminating all similar-looking code.

### The Critical Distinction

#### Semantic Duplication (Refactor This)

**Definition**: Code that represents the **same business concept** or **same knowledge** in multiple places.

**Key question**: "If this business rule changes, would I need to change both places?"

If YES → Semantic duplication → Refactor to single source of truth

**Example: Same Semantic Meaning**

```typescript
// Three functions representing THE SAME CONCEPT: "how to format a person's name"
const formatUserDisplayName = (firstName: string, lastName: string): string => {
  return `${firstName} ${lastName}`.trim();
};

const formatCustomerDisplayName = (firstName: string, lastName: string): string => {
  return `${firstName} ${lastName}`.trim();
};

const formatEmployeeDisplayName = (firstName: string, lastName: string): string => {
  return `${firstName} ${lastName}`.trim();
};

// REFACTOR: They share semantic meaning
const formatPersonDisplayName = (firstName: string, lastName: string): string => {
  return `${firstName} ${lastName}`.trim();
};
```

**Why refactor**: If the business decides names should be formatted as "LAST, First", you only change ONE place.

#### Structural Duplication (Keep Separate)

**Definition**: Code that **looks similar** but represents **different business concepts** or **different knowledge**.

**Key question**: "Would these evolve independently based on different business requirements?"

If YES → Structural duplication → Keep separate

**Example: Different Semantic Meaning**

```typescript
// Similar structure, DIFFERENT business concepts
const validatePaymentAmount = (amount: number): boolean => {
  return amount > 0 && amount <= 10000;
};

const validateTransferAmount = (amount: number): boolean => {
  return amount > 0 && amount <= 10000;
};

// DO NOT ABSTRACT - These represent DIFFERENT business rules:
// - Payment validation: Fraud prevention limit
// - Transfer validation: Daily account limit

// They will evolve INDEPENDENTLY:
// - Payment limits might change based on merchant fraud patterns
// - Transfer limits might change based on account tier
```

**Why keep separate**: These are DIFFERENT pieces of business knowledge that happen to have the same implementation today.

### The Cost of Wrong Abstractions

**Scenario**: You abstract structurally similar code that has different semantic meaning.

**What happens**:

1. **Initial coupling**: Unrelated business concepts now coupled through shared abstraction
2. **Divergence pain**: When concepts evolve differently, abstraction becomes parameterized
3. **Complexity explosion**: Parameters, flags, conditionals added to handle differences
4. **Eventual split**: Eventually you split the abstraction back apart (wasted effort)

**Example: Wrong Abstraction Evolution**

```typescript
// Day 1: Abstract similar-looking code
const validateAmount = (amount: number): boolean => {
  return amount > 0 && amount <= 10000;
};

// Day 30: Payment rules change
const validateAmount = (amount: number, type: "payment" | "transfer"): boolean => {
  const max = type === "payment" ? 5000 : 10000;
  return amount > 0 && amount <= max;
};

// Day 60: Transfer rules change based on account type
const validateAmount = (
  amount: number,
  type: "payment" | "transfer",
  accountTier?: "basic" | "premium"
): boolean => {
  let max: number;
  if (type === "payment") {
    max = 5000;
  } else {
    max = accountTier === "premium" ? 50000 : 10000;
  }
  return amount > 0 && amount <= max;
};

// Day 120: Give up and split back to separate functions
// We're back where we started, but lost 120 days fighting the abstraction
```

### Decision Framework: When to Abstract

**Step 1: Identify the Type of Duplication**

Ask: **"What knowledge does this code represent?"**

- Same business concept? → Semantic duplication
- Different business concepts? → Structural duplication

**Step 2: Test for Semantic Unity**

Ask these questions:

1. **"If requirements change, would both pieces need to change together?"**
   - YES → Semantic duplication → Safe to abstract
   - NO → Structural duplication → Keep separate

2. **"Do these represent the same business rule or concept?"**
   - YES → Semantic duplication → Safe to abstract
   - NO → Structural duplication → Keep separate

3. **"Would a domain expert consider these the same thing?"**
   - YES → Semantic duplication → Safe to abstract
   - NO → Structural duplication → Keep separate

**Step 3: Apply the Decision**

- If semantic duplication → Extract to single source of truth
- If structural duplication → Keep separate, document why if needed

### Real-World Examples

**Example 1: Data Validation (Same Concept - Should Abstract)**

```typescript
// These represent THE SAME CONCEPT: "what constitutes a valid email"
const validateUserEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validateCustomerEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

// REFACTOR to single source of truth:
const isValidEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};
```

**Example 2: Feature Flags (Different Concepts - Keep Separate)**

```typescript
// Structure is identical, but these are DIFFERENT business features
const isPaymentFeatureEnabled = (): boolean => {
  return process.env.ENABLE_PAYMENTS === "true";
};

const isDarkModeEnabled = (): boolean => {
  return process.env.ENABLE_DARK_MODE === "true";
};

// Don't abstract because:
// 1. Payment might need user permission checks
// 2. Dark mode might need user preference storage
// 3. They'll diverge, and you'll fight the abstraction
```

**Example 3: Over-Abstraction Trap**

```typescript
// BAD - Generic abstraction hides intent
function processData(
  data: unknown[],
  validator: (item: unknown) => boolean,
  transformer: (item: unknown) => unknown,
  aggregator: (acc: unknown, item: unknown) => unknown,
  initialValue: unknown
): unknown {
  return data.filter(validator).map(transformer).reduce(aggregator, initialValue);
}

// GOOD - Specific business functions
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
```

### Detection Guide

**Signs of Semantic Duplication (Refactor)**

- Same business rule expressed multiple times
- Changing requirement would need same change in multiple places
- Domain expert would call these "the same thing"
- Duplicated **knowledge** about how system should behave
- Code serves identical purpose in different contexts

**Signs of Structural Duplication (Keep Separate)**

- Code looks similar but represents different business concepts
- Changes would be driven by different business reasons
- Domain expert would call these "different things"
- Duplicated **implementation** that happens to match today
- Code serves different purposes in different contexts

---

## When to Refactor - Decision Framework

### Refactoring Priority Tiers

#### Tier 1: Critical - Refactor Now

**Duplication of Knowledge**
- Same business rule expressed in multiple locations
- Related concepts that should be unified
- Knowledge that will need to change together

**Security or Performance Issues**
- Input not validated
- Resources not properly released
- O(n²) algorithm where O(n) possible

**Broken Abstractions**
- Leaky abstractions exposing implementation details
- Violations of single responsibility principle
- Tight coupling preventing testing

#### Tier 2: High Value - Refactor Soon

**Complex Structure**
- Deeply nested conditional logic (>2 levels)
- Long functions (>20 lines for complex logic)
- Mixed levels of abstraction
- Difficult to follow control flow

**Unclear Intent**
- Variable/function/type names that don't express purpose
- Code requiring comments to understand
- Magic numbers or strings without clear meaning

**Emerging Patterns**
- After implementing 2-3 similar features, abstractions become apparent
- Common operations that could be extracted
- Shared behavior across components

#### Tier 3: Nice-to-Have - Refactor If Time Permits

- Renaming variables for slightly better clarity
- Extracting small one-liner functions
- Reordering code for minor flow improvements
- Formatting consistency fixes

#### Tier 4: Skip - Don't Refactor

**Structurally Similar, Semantically Different**
- Code that looks similar but represents different business concepts
- Rules that may evolve independently
- "Duplicate code is cheaper than wrong abstraction"

**Speculative Abstractions**
- "We might need this someday"
- Abstracting before patterns are clear (need 2-3 examples minimum)
- Creating flexibility without current need

**Already Clean Code**
- Intent is clear from names and structure
- Functions are focused and small
- No obvious improvements to make

### The TDD Refactoring Cycle

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

Create abstractions only when code shares the same **semantic meaning and purpose**.

**3. Maintain External APIs**

Refactoring must NEVER break existing consumers:

```typescript
// Original implementation
export const processPayment = (payment: Payment): ProcessedPayment => {
  // 50 lines of complex logic
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

### Decision Tree

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

### When NOT to Refactor

**No Tests**

Never refactor code without test coverage. Write tests first.

**Unclear Requirements**

Don't refactor when you don't understand what the code does. First add characterization tests, then refactor with confidence.

**During Feature Development**

Finish the feature first (green), THEN assess refactoring:

```
❌ WRONG: Write test → Start feature → Refactor mid-implementation
✓ RIGHT: Write test → Finish feature → Commit → Assess refactoring
```

### Refactoring Checklist

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

## Complete Example: User Registration Refactoring

### Step 0: Poor Code (Starting Point)

```typescript
function registerUser(email: string, username: string, password: string) {
  // Manual validation (15+ lines)
  if (!email || email.length === 0) throw new Error('Email required');
  if (!email.includes('@')) throw new Error('Invalid email');
  if (!username || username.length < 3) throw new Error('Username too short');
  if (username.length > 20) throw new Error('Username too long');
  if (!password || password.length < 8) throw new Error('Password too short');
  if (!/[A-Z]/.test(password)) throw new Error('Need uppercase');
  if (!/[a-z]/.test(password)) throw new Error('Need lowercase');
  if (!/[0-9]/.test(password)) throw new Error('Need number');

  const normalizedEmail = email.toLowerCase().trim();
  const existing = findUserByEmail(normalizedEmail);
  if (existing !== null) throw new Error('User exists');

  const hashedPassword = hashPassword(password);
  const user = {
    id: generateId(),
    email: normalizedEmail,
    username: username.trim(),
    password: hashedPassword,
    isActive: true,
    createdAt: new Date()
  };

  saveUser(user);
  sendEmail(user.email, 'Welcome!', 'Thanks for registering');
  return user;
}
```

**Problems:**
- Manual validation instead of schemas
- Multiple responsibilities (validation, persistence, email)
- Side effects mixed with logic
- Hard to test

### Step 1: Use Schema for Validation

```typescript
import { z } from 'zod';

const RegisterUserInputSchema = z.object({
  email: z.string().email(),
  username: z.string().min(3).max(20),
  password: z.string()
    .min(8)
    .regex(/[A-Z]/, 'Password must contain uppercase')
    .regex(/[a-z]/, 'Password must contain lowercase')
    .regex(/[0-9]/, 'Password must contain number')
});

type RegisterUserInput = z.infer<typeof RegisterUserInputSchema>;

function registerUser(input: RegisterUserInput) {
  const validated = RegisterUserInputSchema.parse(input);
  const normalizedEmail = validated.email.toLowerCase().trim();

  const existing = findUserByEmail(normalizedEmail);
  if (existing !== null) throw new Error('User exists');

  const hashedPassword = hashPassword(validated.password);
  const user = {
    id: generateId(),
    email: normalizedEmail,
    username: validated.username.trim(),
    password: hashedPassword,
    isActive: true,
    createdAt: new Date()
  };

  saveUser(user);
  sendEmail(user.email, 'Welcome!', 'Thanks for registering');
  return user;
}
```

**Improvements:**
- Removed 15+ lines of manual validation
- Single source of truth for validation
- Consistent error messages

### Step 2: Extract Functions (Single Responsibility)

```typescript
// Pure function: validate uniqueness
function ensureEmailUnique(email: string): void {
  const existing = findUserByEmail(email);
  if (existing !== null) throw new Error('User exists');
}

// Pure function: create user entity
function createUserEntity(input: RegisterUserInput, hashedPassword: string): User {
  return {
    id: generateId(),
    email: input.email.toLowerCase().trim(),
    username: input.username.trim(),
    password: hashedPassword,
    isActive: true,
    createdAt: new Date()
  };
}

// Pure function: send notification
function sendWelcomeNotification(email: string): void {
  sendEmail(email, 'Welcome!', 'Thanks for registering');
}

// Orchestrator: coordinates flow
function registerUser(input: RegisterUserInput): User {
  const validated = RegisterUserInputSchema.parse(input);
  const normalizedEmail = validated.email.toLowerCase().trim();

  ensureEmailUnique(normalizedEmail);
  const hashedPassword = hashPassword(validated.password);
  const user = createUserEntity(validated, hashedPassword);

  saveUser(user);
  sendWelcomeNotification(user.email);
  return user;
}
```

**Improvements:**
- Each function has single responsibility
- `registerUser` is readable orchestrator
- Functions testable independently

### Step 3: Dependency Injection (Final)

```typescript
// Dependencies interfaces
type UserRepository = {
  findByEmail: (email: string) => User | null;
  save: (user: User) => void;
};

type PasswordHasher = {
  hash: (password: string) => string;
};

type EmailService = {
  send: (to: string, subject: string, body: string) => void;
};

type IdGenerator = {
  generate: () => string;
};

// Factory: returns configured function
function createRegisterUser(
  repository: UserRepository,
  hasher: PasswordHasher,
  emailService: EmailService,
  idGenerator: IdGenerator
) {
  return (input: RegisterUserInput): User => {
    const validated = RegisterUserInputSchema.parse(input);
    const normalizedEmail = validated.email.toLowerCase().trim();

    const existing = repository.findByEmail(normalizedEmail);
    if (existing !== null) throw new Error('User exists');

    const hashedPassword = hasher.hash(validated.password);
    const user = {
      id: idGenerator.generate(),
      email: normalizedEmail,
      username: validated.username.trim(),
      password: hashedPassword,
      isActive: true,
      createdAt: new Date()
    };

    repository.save(user);
    emailService.send(user.email, 'Welcome!', 'Thanks');
    return user;
  };
}

// Production configuration
const registerUser = createRegisterUser(
  productionRepository,
  productionHasher,
  productionEmailService,
  productionIdGenerator
);
```

**Improvements:**
- Fully testable without real services
- Dependencies explicit and replaceable
- Easy to mock in tests

---

## Summary

**Seven Essential Patterns:**

1. **Extract Function** - Break long functions into focused pieces
2. **Extract Constant** - Name magic numbers and strings
3. **Replace Conditional with Strategy** - Type-based behavior becomes data
4. **Replace Nested Conditionals** - Flatten with guard clauses
5. **Discriminated Union** - Type-safe polymorphism
6. **Parameter Object** - Group related parameters
7. **Replace Loop with Pipeline** - Functional transformations

**DRY Decision Rule:**

```
Same business concept + will evolve together = ABSTRACT
Different business concepts + will evolve independently = KEEP SEPARATE
```

**Key Principles:**

- **Not all code needs refactoring** - Only refactor when it adds value
- **DRY is about knowledge, not code** - Eliminate duplicated knowledge, not structure
- **Wrong abstraction is costly** - Duplicate code is cheaper than fighting a bad abstraction
- **Refactor in small steps** - Commit before and after, tests pass throughout
- **Maintain external APIs** - Refactoring must not break existing consumers
- **Apply when they improve clarity** - Not for their own sake

**Remember**: "The question is not 'can I refactor this?' but 'would refactoring this add value?'"
