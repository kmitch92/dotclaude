# Common Refactoring Patterns

Essential refactoring patterns for improving code quality.

## Extract Function

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

## Extract Constant

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

## Replace Conditional with Strategy Pattern

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

## Replace Nested Conditionals with Guard Clauses

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

## Replace Type Code with Discriminated Union

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
      return processCreditCard(payment); // TypeScript knows all fields available
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

## Introduce Parameter Object

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

## Replace Loop with Pipeline

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

## Summary

**Seven essential patterns:**

1. **Extract Function** - Break long functions into focused pieces
2. **Extract Constant** - Name magic numbers and strings
3. **Replace Conditional with Strategy** - Type-based behavior becomes data
4. **Replace Nested Conditionals** - Flatten with guard clauses
5. **Discriminated Union** - Type-safe polymorphism
6. **Parameter Object** - Group related parameters
7. **Replace Loop with Pipeline** - Functional transformations

**Apply when they improve clarity, not for their own sake.**
