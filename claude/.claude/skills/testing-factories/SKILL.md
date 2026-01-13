---
name: testing-factories
description: Test data factory patterns. Partial overrides, schema validation, sequences, builder patterns, related entities, deterministic random data.
---

# Test Data Factory Patterns

Comprehensive guide to creating maintainable, type-safe test data using factory patterns.

## Core Principles

1. **Partial Overrides:** Factories accept partial objects to override defaults
2. **Schema Validation:** Factory output is validated with Zod schemas
3. **Semantic Defaults:** Default values should make semantic sense
4. **Composability:** Factories should build on other factories
5. **Type Safety:** Full TypeScript support with inference

---

## Fundamental Patterns

### Pattern 1: Simple Object Factory

Foundation pattern - accepts partial overrides, returns validated object.

```typescript
// user.ts
import { z } from 'zod';

const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  username: z.string().min(3).max(20),
  role: z.enum(['user', 'admin', 'moderator']),
  isActive: z.boolean(),
  createdAt: z.date()
});

type User = z.infer<typeof UserSchema>;

export { UserSchema };
export type { User };
```

```typescript
// user.test-factory.ts
import { type User, UserSchema } from './user';

type UserOverrides = Partial<User>;

const createTestUser = (overrides?: UserOverrides): User => {
  const user: User = {
    id: crypto.randomUUID(),
    email: 'test@example.com',
    username: 'testuser',
    role: 'user',
    isActive: true,
    createdAt: new Date(),
    ...overrides
  };

  return UserSchema.parse(user);
};

export { createTestUser };
```

```typescript
// user.test.ts
import { describe, it, expect } from 'vitest';
import { createTestUser } from './user.test-factory';

describe('User Factory', () => {
  it('should create user with defaults', () => {
    const user = createTestUser();

    expect(user.email).toBe('test@example.com');
    expect(user.role).toBe('user');
  });

  it('should create admin user with override', () => {
    const admin = createTestUser({
      email: 'admin@example.com',
      role: 'admin'
    });

    expect(admin.role).toBe('admin');
  });
});
```

**Key Benefits:**
- Override only what you care about in each test
- Test intent is clear (overrides highlight what's being tested)
- Schema validation catches invalid test data at setup time

---

### Pattern 2: Nested Object Factories

Factories that compose other factories for complex nested structures.

```typescript
// address.test-factory.ts
import { type Address, AddressSchema } from './address';

const createTestAddress = (overrides?: Partial<Address>): Address => {
  const address: Address = {
    street: '123 Main St',
    city: 'Springfield',
    state: 'IL',
    zipCode: '62701',
    ...overrides
  };

  return AddressSchema.parse(address);
};

export { createTestAddress };
```

```typescript
// customer.test-factory.ts
import { type Customer, CustomerSchema } from './customer';
import { createTestAddress } from './address.test-factory';

const createTestCustomer = (overrides?: Partial<Customer>): Customer => {
  const customer: Customer = {
    id: crypto.randomUUID(),
    name: 'John Doe',
    email: 'john@example.com',
    shippingAddress: createTestAddress(),
    billingAddress: createTestAddress(),
    ...overrides
  };

  return CustomerSchema.parse(customer);
};

export { createTestCustomer };
```

```typescript
// customer.test.ts
describe('Customer Factory', () => {
  it('should create customer with custom shipping address', () => {
    const customer = createTestCustomer({
      shippingAddress: createTestAddress({
        city: 'Chicago',
        zipCode: '60601'
      })
    });

    expect(customer.shippingAddress.city).toBe('Chicago');
    expect(customer.billingAddress.city).toBe('Springfield');
  });
});
```

---

### Pattern 3: Factories for Related Entities

Factories that create related entities with proper foreign key relationships.

```typescript
// blog.test-factory.ts
import { type User, type Post, type Comment } from './types';
import { createTestUser } from './user.test-factory';

type PostOverrides = Partial<Omit<Post, 'authorId'> & { author?: User }>;

const createTestPost = (overrides?: PostOverrides): { post: Post; author: User } => {
  const author = overrides?.author || createTestUser();

  const post: Post = {
    id: crypto.randomUUID(),
    authorId: author.id,
    title: 'Test Post',
    content: 'This is a test post content.',
    published: false,
    createdAt: new Date(),
    ...overrides
  };

  return { post, author };
};

export { createTestPost };
```

```typescript
// blog.test.ts
describe('Blog Factories', () => {
  it('should create post with specific author', () => {
    const specificAuthor = createTestUser({
      username: 'authorname'
    });

    const { post, author } = createTestPost({ author: specificAuthor });

    expect(post.authorId).toBe(specificAuthor.id);
    expect(author.username).toBe('authorname');
  });
});
```

**Key Benefits:**
- Automatic foreign key management
- Return all related entities for assertions
- Override relationships as needed

---

### Pattern 4: Date/Time Factories

Factories for creating consistent, testable date/time values.

```typescript
// date.test-factory.ts

const BASE_DATE = new Date('2024-01-01T00:00:00.000Z');

type DateOffset = {
  days?: number;
  hours?: number;
  minutes?: number;
};

const createTestDate = (offset?: DateOffset): Date => {
  const date = new Date(BASE_DATE);

  if (offset?.days) date.setDate(date.getDate() + offset.days);
  if (offset?.hours) date.setHours(date.getHours() + offset.hours);
  if (offset?.minutes) date.setMinutes(date.getMinutes() + offset.minutes);

  return date;
};

const createPastDate = (daysAgo: number): Date =>
  createTestDate({ days: -daysAgo });

const createFutureDate = (daysFromNow: number): Date =>
  createTestDate({ days: daysFromNow });

export { createTestDate, createPastDate, createFutureDate, BASE_DATE };
```

```typescript
// subscription.test-factory.ts
const createTestSubscription = (overrides?: Partial<Subscription>): Subscription => {
  return {
    id: crypto.randomUUID(),
    userId: 'user-default',
    startDate: createPastDate(30),
    endDate: createFutureDate(335),
    status: 'active',
    ...overrides
  };
};

const createExpiredSubscription = (overrides?: Partial<Subscription>): Subscription =>
  createTestSubscription({
    startDate: createPastDate(400),
    endDate: createPastDate(35),
    status: 'expired',
    ...overrides
  });
```

**Key Benefits:**
- Consistent, predictable dates in tests
- Easy to create relative dates (past, future, recent)
- Avoid flaky tests from current date/time
- Clear intent with named factory functions

---

### Pattern 5: Sequences and Uniqueness

Factories that generate unique values across test runs.

```typescript
// sequence.test-factory.ts

type SequenceCounters = {
  [key: string]: number;
};

const sequences: SequenceCounters = {};

const sequence = (name: string, start: number = 1): number => {
  if (!(name in sequences)) {
    sequences[name] = start;
  }
  return sequences[name]++;
};

const resetSequence = (name: string): void => {
  delete sequences[name];
};

const resetAllSequences = (): void => {
  Object.keys(sequences).forEach(key => delete sequences[key]);
};

export { sequence, resetSequence, resetAllSequences };
```

```typescript
// user.test-factory.ts (with sequences)
import { sequence } from './sequence.test-factory';

const createTestUser = (overrides?: UserOverrides): User => {
  const userNumber = sequence('user');

  const user: User = {
    id: crypto.randomUUID(),
    email: `user${userNumber}@example.com`,
    username: `user${userNumber}`,
    role: 'user',
    isActive: true,
    createdAt: new Date(),
    ...overrides
  };

  return UserSchema.parse(user);
};
```

```typescript
// user.test.ts
describe('User Factory with Sequences', () => {
  beforeEach(() => {
    resetAllSequences();
  });

  it('should create users with unique emails', () => {
    const user1 = createTestUser();
    const user2 = createTestUser();

    expect(user1.email).toBe('user1@example.com');
    expect(user2.email).toBe('user2@example.com');
  });
});
```

**Key Benefits:**
- Automatic unique values across test runs
- Avoids unique constraint violations
- Clear, predictable patterns
- Resettable for test isolation

---

## Advanced Patterns

### Builder Pattern for Complex Objects

For objects with many optional fields or complex setup requirements.

```typescript
// order.test-factory.ts
import { type Order, OrderSchema } from './order';

class TestOrderBuilder {
  private order: Partial<Order> = {
    id: crypto.randomUUID(),
    customerId: 'cust-default',
    items: [],
    subtotal: 0,
    tax: 0,
    shipping: 0,
    total: 0,
    status: 'pending',
    createdAt: new Date()
  };

  withId(id: string): this {
    this.order.id = id;
    return this;
  }

  withCustomerId(customerId: string): this {
    this.order.customerId = customerId;
    return this;
  }

  withItem(productId: string, productName: string, quantity: number, unitPrice: number): this {
    const subtotal = quantity * unitPrice;
    const item = { productId, productName, quantity, unitPrice, subtotal };
    this.order.items = [...(this.order.items || []), item];
    return this;
  }

  withStatus(status: Order['status']): this {
    this.order.status = status;
    return this;
  }

  withShipping(shipping: number): this {
    this.order.shipping = shipping;
    return this;
  }

  withTaxRate(taxRate: number): this {
    const subtotal = this.calculateSubtotal();
    this.order.subtotal = subtotal;
    this.order.tax = subtotal * taxRate;
    return this;
  }

  private calculateSubtotal(): number {
    return (this.order.items || []).reduce((sum, item) => sum + item.subtotal, 0);
  }

  private calculateTotal(): number {
    return (this.order.subtotal || 0) + (this.order.tax || 0) + (this.order.shipping || 0);
  }

  build(): Order {
    this.order.subtotal = this.calculateSubtotal();
    this.order.total = this.calculateTotal();
    return OrderSchema.parse(this.order as Order);
  }
}

const createTestOrderBuilder = (): TestOrderBuilder => new TestOrderBuilder();

const createTestOrder = (builderFn?: (builder: TestOrderBuilder) => TestOrderBuilder): Order => {
  const builder = createTestOrderBuilder()
    .withItem('prod-1', 'Default Product', 1, 10.00);
  const configured = builderFn ? builderFn(builder) : builder;
  return configured.build();
};

export { createTestOrderBuilder, createTestOrder };
```

**Usage:**
```typescript
const order = createTestOrder(builder =>
  builder
    .withItem('prod-1', 'Widget', 3, 15.00)
    .withItem('prod-2', 'Gadget', 1, 50.00)
    .withTaxRate(0.10)
    .withShipping(10.00)
    .withStatus('paid')
);
```

**When to Use Builder Pattern:**
- Objects with many optional fields (5+)
- Complex validation dependencies between fields
- Derived/calculated fields based on other fields
- Need for readable, self-documenting test setup

---

### Multi-Level Nesting

Creating factories for deeply nested structures with multiple levels of composition.

```typescript
// organization.test-factory.ts
import { type Organization, type Team, type User } from './types';
import { createTestUser } from './user.test-factory';

type TeamOverrides = Partial<Omit<Team, 'members'> & { members?: User[] }>;
type OrgOverrides = Partial<Omit<Organization, 'teams'> & { teams?: Team[] }>;

const createTestTeam = (overrides?: TeamOverrides): Team => {
  const defaultMembers = [
    createTestUser({ role: 'admin' }),
    createTestUser({ role: 'user' }),
    createTestUser({ role: 'user' })
  ];

  return {
    id: crypto.randomUUID(),
    name: 'Engineering',
    members: defaultMembers,
    createdAt: new Date(),
    ...overrides
  };
};

const createTestOrganization = (overrides?: OrgOverrides): Organization => {
  const defaultTeams = [
    createTestTeam({ name: 'Engineering' }),
    createTestTeam({ name: 'Product' })
  ];

  return {
    id: crypto.randomUUID(),
    name: 'Acme Corp',
    teams: defaultTeams,
    createdAt: new Date(),
    ...overrides
  };
};

export { createTestTeam, createTestOrganization };
```

**Usage:**
```typescript
const admin = createTestUser({ role: 'admin', username: 'cto' });
const engineers = [
  createTestUser({ username: 'dev1' }),
  createTestUser({ username: 'dev2' })
];

const org = createTestOrganization({
  name: 'Tech Startup',
  teams: [
    createTestTeam({
      name: 'Engineering',
      members: [admin, ...engineers]
    })
  ]
});
```

---

### Factory Traits: Reusable State Variations

Creating reusable state variations that can be composed.

```typescript
// user.test-factory.ts
import { type User } from './user';
import { createTestUser } from './user.test-factory';

// Trait functions - reusable state variations
const asAdmin = (user: User): User => ({
  ...user,
  role: 'admin'
});

const asInactive = (user: User): User => ({
  ...user,
  isActive: false
});

const withVerifiedEmail = (user: User): User => ({
  ...user,
  emailVerified: true,
  emailVerifiedAt: new Date()
});

// Compose traits
const createAdminUser = (overrides?: Partial<User>): User =>
  asAdmin(createTestUser(overrides));

const createInactiveUser = (overrides?: Partial<User>): User =>
  asInactive(createTestUser(overrides));

const createVerifiedAdminUser = (overrides?: Partial<User>): User =>
  withVerifiedEmail(asAdmin(createTestUser(overrides)));

export { asAdmin, asInactive, withVerifiedEmail, createAdminUser, createInactiveUser };
```

**Usage:**
```typescript
// Predefined compositions
const user = createVerifiedAdminUser({ username: 'superadmin' });

// Manual composition
const customUser = withVerifiedEmail(
  asAdmin(
    createTestUser({ username: 'custom' })
  )
);
```

**Key Benefits:**
- Reusable state transformations
- Compose multiple traits
- Clear, expressive test setup
- Avoid duplication across tests

---

### Factory Registry Pattern

Centralized factory management for large test suites.

```typescript
// factory-registry.ts
type FactoryFn<T> = (overrides?: Partial<T>) => T;
type FactoryMap = Map<string, FactoryFn<any>>;

class FactoryRegistry {
  private factories: FactoryMap = new Map();

  register<T>(name: string, factory: FactoryFn<T>): void {
    this.factories.set(name, factory);
  }

  create<T>(name: string, overrides?: Partial<T>): T {
    const factory = this.factories.get(name);
    if (!factory) {
      throw new Error(`Factory "${name}" not registered`);
    }
    return factory(overrides);
  }

  has(name: string): boolean {
    return this.factories.has(name);
  }
}

const registry = new FactoryRegistry();

export { registry };
```

```typescript
// factories/index.ts
import { registry } from './factory-registry';
import { createTestUser } from './user.test-factory';
import { createTestPost } from './post.test-factory';

registry.register('user', createTestUser);
registry.register('post', createTestPost);

export { registry as factories };
```

**Usage:**
```typescript
import { factories } from './factories';

const user = factories.create('user', { username: 'testuser' });
const post = factories.create('post', { title: 'Test Post' });
```

**When to Use Registry:**
- Large test suites with many factories
- Dynamic factory selection
- Centralized factory configuration
- Plugin-based testing systems

---

### Advanced Sequences: Context-Aware Generation

Sequences that generate contextual, realistic data.

```typescript
// advanced-sequence.test-factory.ts

const emailDomains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'company.com'];
const firstNames = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'];
const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones'];

let userCounter = 0;

const generateRealisticEmail = (): string => {
  const firstName = firstNames[userCounter % firstNames.length];
  const lastName = lastNames[userCounter % lastNames.length];
  const domain = emailDomains[userCounter % emailDomains.length];
  const number = Math.floor(userCounter / firstNames.length) + 1;

  userCounter++;

  return `${firstName.toLowerCase()}.${lastName.toLowerCase()}${number > 1 ? number : ''}@${domain}`;
};

const generateUsername = (): string => {
  const firstName = firstNames[userCounter % firstNames.length];
  const number = Math.floor(userCounter / firstNames.length) + 1;
  return `${firstName.toLowerCase()}${number > 1 ? number : ''}`;
};

const resetRealisticGenerators = (): void => {
  userCounter = 0;
};

export { generateRealisticEmail, generateUsername, resetRealisticGenerators };
```

**Use cases:**
- More realistic test data for demos
- Testing uniqueness constraints with realistic patterns
- Debugging with identifiable test data

---

## Pattern Selection Guide

| Scenario | Pattern |
|----------|---------|
| Simple objects with few fields | Simple Object Factory |
| Nested structures | Nested Object Factories |
| Related entities with foreign keys | Related Entities Factory |
| Time-dependent testing | Date/Time Factories |
| Unique constraint handling | Sequences |
| Objects with 5+ optional fields | Builder Pattern |
| Deeply nested structures | Multi-Level Nesting |
| Reusable state variations | Factory Traits |
| Large test suites | Factory Registry |
| Realistic test data | Advanced Sequences |

---

## Best Practices Summary

1. **Start Simple:** Use Partial overrides for most factories
2. **Compose Factories:** Build complex objects from simpler factories
3. **Maintain Relationships:** Handle foreign keys automatically
4. **Consistent Dates:** Use date factories for predictable, testable dates
5. **Ensure Uniqueness:** Use sequences when uniqueness matters
6. **Validate Output:** Always validate factory output with schemas
7. **Override What Matters:** Test intent should be clear from overrides
8. **Semantic Defaults:** Choose defaults that make sense in context
9. **Type Safety:** Use TypeScript types and Zod schemas throughout
10. **Builder for Complex:** Use builder pattern when objects have many optional fields
11. **Traits for Variants:** Use trait functions for reusable state transformations
12. **Registry for Scale:** Centralize factory management in large test suites
