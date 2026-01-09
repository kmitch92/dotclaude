# DRY: Semantic vs Structural Duplication

## Core Principle

**"DRY addresses duplicated knowledge, not duplicated code."**

The DRY (Don't Repeat Yourself) principle is fundamentally about **semantic duplication** - duplicated knowledge, business rules, or concepts - NOT about eliminating all similar-looking code.

---

## The Critical Distinction

### Semantic Duplication (Refactor This)

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

// REFACTOR: They share semantic meaning, not just structure
const formatPersonDisplayName = (firstName: string, lastName: string): string => {
  return `${firstName} ${lastName}`.trim();
};

// Replace all call sites
const userLabel = formatPersonDisplayName(user.firstName, user.lastName);
const customerName = formatPersonDisplayName(customer.firstName, customer.lastName);
const employeeTag = formatPersonDisplayName(employee.firstName, employee.lastName);
```

**Why refactor**: If the business decides names should be formatted as "LAST, First", you only change ONE place.

---

### Structural Duplication (Keep Separate)

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

// DO NOT ABSTRACT - Here's why:

// These represent DIFFERENT business rules:
// - Payment validation: Fraud prevention limit
// - Transfer validation: Daily account limit

// They will evolve INDEPENDENTLY:
// - Payment limits might change based on:
//   * Merchant fraud patterns
//   * Card issuer requirements
//   * Geographic regulations
//
// - Transfer limits might change based on:
//   * Account tier (basic, premium, business)
//   * Account age
//   * Verification status

// If you abstract them:
const validateAmount = (amount: number): boolean => {
  return amount > 0 && amount <= 10000;
};

// Now when payment limits need to change, you're forced to:
// 1. Change shared function (affects both)
// 2. Add parameters to distinguish cases (complexity grows)
// 3. Eventually split them back apart (wasted effort)
```

**Why keep separate**: These are DIFFERENT pieces of business knowledge that happen to have the same implementation today.

---

## "Duplicate Code is Cheaper Than the Wrong Abstraction"

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
  const max = type === "payment" ? 5000 : 10000; // Complexity starts
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
    max = accountTier === "premium" ? 50000 : 10000; // More complexity
  }
  return amount > 0 && amount <= max;
};

// Day 90: Payment rules need merchant verification
const validateAmount = (
  amount: number,
  type: "payment" | "transfer",
  accountTier?: "basic" | "premium",
  merchantVerified?: boolean
): boolean => {
  let max: number;
  if (type === "payment") {
    max = merchantVerified ? 10000 : 5000; // Even more complexity
  } else {
    max = accountTier === "premium" ? 50000 : 10000;
  }
  return amount > 0 && amount <= max;
};

// Day 120: Give up and split back to separate functions
const validatePaymentAmount = (
  amount: number,
  merchantVerified: boolean
): boolean => {
  const max = merchantVerified ? 10000 : 5000;
  return amount > 0 && amount <= max;
};

const validateTransferAmount = (amount: number, accountTier: string): boolean => {
  const max = accountTier === "premium" ? 50000 : 10000;
  return amount > 0 && amount <= max;
};

// We're back where we started, but lost 120 days fighting the abstraction
```

**Cost comparison**:
- **Duplicate code**: 2 simple functions, easy to change independently
- **Wrong abstraction**: Complex shared function, hard to understand, hard to change, eventually split anyway

---

## Decision Framework: When to Abstract

### Step 1: Identify the Type of Duplication

Ask: **"What knowledge does this code represent?"**

- Same business concept? → Semantic duplication
- Different business concepts? → Structural duplication

### Step 2: Test for Semantic Unity

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

### Step 3: Apply the Decision

**If semantic duplication** → Extract to single source of truth
**If structural duplication** → Keep separate, document why if needed

---

## Real-World Examples

### Example 1: Order Processing (Different Concepts)

```typescript
// DO NOT ABSTRACT - Different business concepts

const calculatePaymentProcessingFee = (amount: number): number => {
  return amount * 0.029 + 0.30; // Stripe's fee structure
};

const calculateRefundProcessingFee = (amount: number): number => {
  return amount * 0.029 + 0.30; // Happens to be same now
};

const calculateTaxAmount = (amount: number): number => {
  return amount * 0.029 + 0.30; // Coincidentally same calculation
};

// These are DIFFERENT knowledge:
// - Payment fees: Set by payment processor contract
// - Refund fees: May have different structure (often no fee)
// - Tax calculation: Set by government regulations
//
// If you abstract them, when Stripe changes fees or tax rate changes,
// you're forced to parameterize or split them apart
```

### Example 2: Data Validation (Same Concept)

```typescript
// SHOULD ABSTRACT - Same business concept

const validateUserEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validateCustomerEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validateAdminEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

// These represent THE SAME CONCEPT: "what constitutes a valid email"
// REFACTOR to single source of truth:

const isValidEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

// If email validation rules change, only one place to update
```

### Example 3: Feature Flags (Same Implementation, Different Concepts)

```typescript
// DO NOT ABSTRACT - Implementation happens to match

const isPaymentFeatureEnabled = (): boolean => {
  return process.env.ENABLE_PAYMENTS === "true";
};

const isDarkModeEnabled = (): boolean => {
  return process.env.ENABLE_DARK_MODE === "true";
};

const isAnalyticsEnabled = (): boolean => {
  return process.env.ENABLE_ANALYTICS === "true";
};

// Structure is identical, but these are DIFFERENT business features
// Don't create:
const isFeatureEnabled = (featureName: string): boolean => {
  return process.env[`ENABLE_${featureName.toUpperCase()}`] === "true";
};

// Because:
// 1. Payment might need user permission checks
// 2. Dark mode might need user preference storage
// 3. Analytics might need consent management
//
// They'll diverge, and you'll fight the abstraction
```

### Example 4: Error Messages (Same Concept)

```typescript
// SHOULD ABSTRACT - Same business concept

const handleUserNotFound = (userId: string): never => {
  throw new Error(`User with ID ${userId} not found`);
};

const handleCustomerNotFound = (customerId: string): never => {
  throw new Error(`Customer with ID ${customerId} not found`);
};

const handleProductNotFound = (productId: string): never => {
  throw new Error(`Product with ID ${productId} not found`);
};

// These represent THE SAME CONCEPT: "entity not found error pattern"
// REFACTOR:

const notFoundError = (entityType: string, id: string): never => {
  throw new Error(`${entityType} with ID ${id} not found`);
};

// Usage
notFoundError("User", userId);
notFoundError("Customer", customerId);
notFoundError("Product", productId);

// If we decide to change error format (add error codes, i18n, etc.),
// single place to update
```

---

## Detection Guide

### Signs of Semantic Duplication (Refactor)

✓ Same business rule expressed multiple times
✓ Changing requirement would need same change in multiple places
✓ Domain expert would call these "the same thing"
✓ Duplicated **knowledge** about how system should behave
✓ Code serves identical purpose in different contexts

### Signs of Structural Duplication (Keep Separate)

✓ Code looks similar but represents different business concepts
✓ Changes would be driven by different business reasons
✓ Domain expert would call these "different things"
✓ Duplicated **implementation** that happens to match today
✓ Code serves different purposes in different contexts

---

## Summary

**Key Principles:**

1. **DRY is about knowledge, not code** - Eliminate duplicated knowledge, not duplicated structure
2. **Semantic vs Structural** - Abstract when meaning is same, keep separate when concepts differ
3. **Wrong abstraction is costly** - Duplicate code is cheaper than fighting a bad abstraction
4. **Test for semantic unity** - "Would these change together?" is the key question
5. **Wait for patterns** - Need 2-3 examples before abstractions become clear

**Decision Rule:**

```
Same business concept + will evolve together = ABSTRACT
Different business concepts + will evolve independently = KEEP SEPARATE
```

**Remember**: "Don't Repeat Yourself" means "Don't Repeat Your Knowledge" - not "Don't Repeat Your Code Structure."
