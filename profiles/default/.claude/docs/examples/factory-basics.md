# Test Data Factory Patterns: Basics

Fundamental factory patterns for creating maintainable, type-safe test data. Based on proven patterns from citypaul's factory guidance.

## Core Principles

1. **Partial Overrides:** Factories accept partial objects to override defaults
2. **Schema Validation:** Factory output is validated with Zod schemas
3. **Semantic Defaults:** Default values should make semantic sense
4. **Composability:** Factories should build on other factories
5. **Type Safety:** Full TypeScript support with inference

---

## Pattern 1: Simple Object Factory

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

## Pattern 2: Nested Object Factories

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

## Pattern 3: Factories for Related Entities

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

## Pattern 4: Date/Time Factories

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

## Pattern 5: Sequences and Uniqueness

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

## Summary: Basic Factory Patterns

1. **Start Simple:** Use Partial overrides for most factories
2. **Compose Factories:** Build complex objects from simpler factories
3. **Maintain Relationships:** Handle foreign keys automatically
4. **Consistent Dates:** Use date factories for predictable, testable dates
5. **Ensure Uniqueness:** Use sequences when uniqueness matters
6. **Validate Output:** Always validate factory output with schemas
7. **Override What Matters:** Test intent should be clear from overrides
8. **Semantic Defaults:** Choose defaults that make sense in context
9. **Type Safety:** Use TypeScript types and Zod schemas throughout

For advanced patterns (builders, complex composition), see @~/.claude/docs/examples/factory-advanced.md
