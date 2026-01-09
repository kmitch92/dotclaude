# Complete TDD Cycle - Order Processing Example

Full Test-Driven Development cycle demonstrating Red-Green-Refactor with schema-first design and behavioral testing.

## Iteration 1: Creating an Order

### Red: Write Failing Test

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

### Green: Minimum Code to Pass

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

### Refactor: Assess

**Analysis:** Code is simple, single responsibility, schema validates correctness.

**Decision:** No refactoring needed - already clean.

---

## Iteration 2: Validation Edge Cases

### Red: Write Failing Tests

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

---

## Iteration 3: Processing Orders

### Red: Write Failing Test

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

### Green: Minimum Code

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

### Refactor: Extract Guard Clause

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

---

## Iteration 4: Applying Discounts

### Red: Write Failing Test

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

### Green: Update Schema and Add Function

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

### Refactor: Extract Calculation

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

---

## Final Code Structure

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

## Key Lessons

1. **Schema-First**: Zod schemas catch edge cases automatically
2. **Red-Green-Refactor**: Each iteration follows strict cycle
3. **Behavioral Testing**: Tests verify outcomes, not implementation
4. **Small Steps**: Each iteration adds one behavior
5. **Refactoring Safety**: Tests ensure refactoring doesn't break behavior
6. **Immutability**: All functions return new objects (no mutation)

## Related
- [TDD Cycle](../workflows/tdd-cycle.md)
- [Schema Composition](schema-composition.md)
- [Refactoring Patterns](../patterns/refactoring/common-patterns.md)
