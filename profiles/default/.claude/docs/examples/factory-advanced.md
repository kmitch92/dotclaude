# Test Data Factory Patterns: Advanced

Advanced factory patterns for complex object construction, builder patterns, and sophisticated composition strategies.

## Builder Pattern for Complex Objects

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

## Advanced Composition: Multi-Level Nesting

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

## Factory Traits: Reusable State Variations

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

## Factory Registry Pattern

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

## Advanced Sequences: Context-Aware Generation

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

## Summary: Advanced Factory Patterns

**Builder Pattern:**
- Use for objects with many optional fields or computed values
- Provides fluent, readable API
- Handles complex validation and dependencies

**Multi-Level Composition:**
- Compose factories for deeply nested structures
- Override at any level
- Maintain type safety throughout

**Factory Traits:**
- Reusable state transformations
- Compose multiple traits for complex states
- Clear, expressive test setup

**Factory Registry:**
- Centralized factory management
- Dynamic factory selection
- Useful for large test suites

**Advanced Sequences:**
- Context-aware, realistic data generation
- Better for demos and debugging
- Maintain uniqueness with realistic patterns

**Decision Guide:**
- Simple objects → Basic factory with partial overrides
- Nested objects → Composed factories
- Complex objects with many fields → Builder pattern
- Reusable state variations → Traits
- Large test suites → Registry pattern
- Realistic test data → Advanced sequences

See also: @~/.claude/docs/examples/factory-basics.md for fundamental patterns
