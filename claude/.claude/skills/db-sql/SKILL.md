---
name: db-sql
description: SQL database patterns. Schema design, normalization forms, relationships, Prisma ORM patterns, migrations, type-safe queries.
---

# SQL Database Patterns

## Core Principles

1. **Schema-First**: Design data model before application code
2. **Normalization**: Eliminate redundancy (target 3NF)
3. **Denormalization**: Strategic, only when performance requires it
4. **Referential Integrity**: Use foreign keys and constraints
5. **Index Strategy**: Index for queries, not just primary keys
6. **Migration Safety**: Never destructive without backups

## Schema Design

### Table Design with Constraints

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'admin', 'moderator')),
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending')),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMP  -- Soft delete
);

-- Indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- Trigger for automatic updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

### Primary Key Strategies

```sql
-- Option 1: UUID (distributed systems)
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
-- Pros: Globally unique, merge-friendly
-- Cons: Larger (16 bytes), non-sequential

-- Option 2: BIGINT with sequence
id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY
-- Pros: Smaller (8 bytes), sequential
-- Cons: Requires central sequence

-- Option 3: Composite (junction tables)
PRIMARY KEY (user_id, role_id)
-- Pros: Natural key, enforces uniqueness
-- Cons: Complex queries, larger FKs
```

## Relationships

### One-to-Many

```sql
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
  status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'completed', 'cancelled')),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
```

**ON DELETE options:**
- `CASCADE`: Delete orders when user deleted
- `SET NULL`: Preserve order history
- `RESTRICT`: Prevent user deletion if orders exist (safest)

### Many-to-Many with Junction Table

```sql
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE user_roles (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  granted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  granted_by UUID REFERENCES users(id),
  PRIMARY KEY (user_id, role_id)
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);
```

### One-to-One

```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  bio TEXT,
  avatar_url VARCHAR(500),
  website VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
-- UNIQUE constraint on user_id enforces one-to-one
```

## Normalization

### First Normal Form (1NF)

**Rules:**
1. Atomic values only (no arrays/repeating groups)
2. Single value per cell
3. Unique rows (primary key)

**Violations:**

```sql
-- ❌ Repeating columns
CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  phone1 VARCHAR(20),
  phone2 VARCHAR(20),
  phone3 VARCHAR(20)  -- Schema change needed for 4th phone
);

-- ❌ Comma-separated values
CREATE TABLE projects (
  name VARCHAR(100),
  team_members VARCHAR(500)  -- 'John,Jane,Bob' - can't query
);
```

**Solution:**

```sql
-- ✓ Separate table
CREATE TABLE employee_phones (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER REFERENCES employees(id),
  phone_number VARCHAR(20),
  phone_type VARCHAR(20)  -- 'mobile', 'work', 'home'
);

-- ✓ Junction table
CREATE TABLE project_members (
  project_id INTEGER REFERENCES projects(id),
  employee_id INTEGER REFERENCES employees(id),
  PRIMARY KEY (project_id, employee_id)
);
```

### Second Normal Form (2NF)

**Rule:** Must be in 1NF + no partial dependencies (non-key columns depend on entire primary key, not part of it).

**Violation:**

```sql
-- ❌ Composite key with partial dependency
CREATE TABLE order_items (
  order_id INTEGER,
  product_id INTEGER,
  quantity INTEGER,
  product_name VARCHAR(100),  -- Depends only on product_id
  product_price DECIMAL,       -- Depends only on product_id
  PRIMARY KEY (order_id, product_id)
);
```

**Solution:**

```sql
-- ✓ Separate tables
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  price DECIMAL
);

CREATE TABLE order_items (
  order_id INTEGER,
  product_id INTEGER REFERENCES products(id),
  quantity INTEGER,
  PRIMARY KEY (order_id, product_id)
);
```

### Third Normal Form (3NF)

**Rule:** Must be in 2NF + no transitive dependencies (non-key columns depend only on primary key, not other non-key columns).

**Violation:**

```sql
-- ❌ Transitive dependency
CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  department_id INTEGER,
  department_name VARCHAR(100),    -- Depends on department_id
  department_manager VARCHAR(100)  -- Depends on department_id
);
```

**Solution:**

```sql
-- ✓ Separate department table
CREATE TABLE departments (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  manager VARCHAR(100)
);

CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  department_id INTEGER REFERENCES departments(id)
);
```

### Strategic Denormalization

```sql
-- ✓ Denormalization justified by query patterns
CREATE TABLE orders_with_user_email (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  user_email VARCHAR(255) NOT NULL,  -- Denormalized
  total_amount DECIMAL(10,2) NOT NULL
);

-- When to denormalize:
-- 1. Frequent lookups (common query pattern)
-- 2. Rare updates (low overhead)
-- 3. Significant performance gain (measured)
-- 4. Consistency mechanism exists (trigger)
```

### Denormalization Decision Tree

```
Data normalized to 3NF?
  NO → Normalize first
  YES → Continue
  ↓
Performance problem?
  NO → Keep normalized
  YES → Profile to identify bottleneck
  ↓
Read:write ratio > 10:1?
  NO → Keep normalized, optimize queries/indexes
  YES → Consider denormalization
  ↓
Can tolerate inconsistency?
  NO → Keep normalized
  YES → Denormalize with update strategy (triggers, app logic)
```

**Normalize when:**
- Write-heavy workload
- Data integrity critical
- Storage costs matter
- Minimal joins needed

**Denormalize when:**
- Read-heavy workload (10:1 read:write ratio or higher)
- Performance bottleneck proven (profile first!)
- Acceptable inconsistency (e.g., cached counts)

**Common Denormalization Patterns:**

```sql
-- Computed Columns
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  subtotal DECIMAL,
  tax DECIMAL,
  shipping DECIMAL,
  total DECIMAL GENERATED ALWAYS AS (subtotal + tax + shipping) STORED
);

-- Cached Counts
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  post_count INTEGER DEFAULT 0
);

CREATE TRIGGER update_post_count
AFTER INSERT ON posts
FOR EACH ROW
EXECUTE FUNCTION increment_user_post_count();

-- Embedded Objects (JSON)
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255),
  preferences JSONB  -- { theme: 'dark', language: 'en' }
);

CREATE INDEX idx_preferences_theme ON users USING GIN ((preferences->>'theme'));
```

## Indexing Strategy

### Index Selection

```sql
-- Query: Find active users by email
SELECT * FROM users WHERE email = ? AND status = 'active';
CREATE INDEX idx_users_email_status ON users(email, status);

-- Query: List recent orders for user
SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT 20;
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at DESC);

-- Query: Find active users (partial index)
SELECT * FROM users WHERE status = 'active';
CREATE INDEX idx_active_users ON users(id, email, name) WHERE status = 'active';
```

### Covering Indexes

```sql
-- Query: Select specific columns
SELECT id, email, name FROM users WHERE status = 'active';

-- Covering index includes all queried columns
CREATE INDEX idx_users_active_covering ON users(status, id, email, name);
-- Benefit: Index-only scan (doesn't read table)
```

### Index Anti-Patterns

```sql
-- ❌ Over-indexing
CREATE INDEX idx_users_name ON users(name);  -- If never queried

-- ❌ Wrong column order
SELECT * FROM orders WHERE status = 'completed' AND user_id = ?;
CREATE INDEX idx_orders_wrong ON orders(status, user_id);

-- ✓ High selectivity first
CREATE INDEX idx_orders_correct ON orders(user_id, status);

-- ❌ Redundant indexes
CREATE INDEX idx_user_id ON orders(user_id);
CREATE INDEX idx_user_status ON orders(user_id, status);  -- Makes first redundant

-- ✓ Keep composite only
CREATE INDEX idx_user_status ON orders(user_id, status);
```

## Query Optimization

### N+1 Query Problem

```typescript
// ❌ N+1 queries
const users = await db.users.findAll();
for (const user of users) {
  user.orders = await db.orders.findByUserId(user.id);  // N queries!
}

// ✓ Single query with join
const users = await db.query(`
  SELECT
    u.id,
    u.email,
    u.name,
    json_agg(
      json_build_object(
        'id', o.id,
        'totalAmount', o.total_amount,
        'status', o.status
      )
    ) as orders
  FROM users u
  LEFT JOIN orders o ON o.user_id = u.id
  GROUP BY u.id, u.email, u.name
`);
```

### SELECT Optimization

```sql
-- ❌ SELECT *
SELECT * FROM orders WHERE user_id = ?;

-- ✓ Select only needed columns
SELECT id, total_amount, status, created_at FROM orders WHERE user_id = ?;
```

## Migrations

### Safe Migration Strategy

```sql
-- Step 1: Add new column (optional, nullable)
ALTER TABLE users ADD COLUMN new_email VARCHAR(255);

-- Step 2: Backfill data (batches)
UPDATE users SET new_email = email WHERE new_email IS NULL;

-- Step 3: Make NOT NULL
ALTER TABLE users ALTER COLUMN new_email SET NOT NULL;

-- Step 4: Add unique constraint
ALTER TABLE users ADD CONSTRAINT users_new_email_unique UNIQUE (new_email);

-- Step 5: Create index
CREATE INDEX idx_users_new_email ON users(new_email);

-- Step 6: Drop old column (next release)
ALTER TABLE users DROP COLUMN email;
```

### Migration Anti-Patterns

```sql
-- ❌ Data loss
ALTER TABLE users DROP COLUMN email;

-- ❌ Breaks running app
ALTER TABLE users RENAME COLUMN email TO new_email;

-- ❌ Fails if rows exist
ALTER TABLE users ADD COLUMN phone VARCHAR(20) NOT NULL;

-- ✓ Add with default
ALTER TABLE users ADD COLUMN phone VARCHAR(20) DEFAULT '';
```

### Migration Implementation

```typescript
// migrations/001_create_users_table.ts
import { Kysely, sql } from "kysely";

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable("users")
    .addColumn("id", "uuid", (col) =>
      col.primaryKey().defaultTo(sql`gen_random_uuid()`)
    )
    .addColumn("email", "varchar(255)", (col) => col.notNull().unique())
    .addColumn("name", "varchar(100)", (col) => col.notNull())
    .addColumn("created_at", "timestamp", (col) =>
      col.notNull().defaultTo(sql`now()`)
    )
    .execute();

  await db.schema
    .createIndex("idx_users_email")
    .on("users")
    .column("email")
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable("users").cascade().execute();
}
```

### Schema Versioning

```sql
CREATE TABLE schema_migrations (
  version VARCHAR(255) PRIMARY KEY,
  applied_at TIMESTAMP NOT NULL DEFAULT NOW(),
  description TEXT
);

INSERT INTO schema_migrations (version, description)
VALUES ('20250115_001', 'Create users table');
```

```typescript
const requiredVersion = "20250115_001";
const currentVersion = await db.getCurrentSchemaVersion();

if (currentVersion !== requiredVersion) {
  throw new Error(`Schema version mismatch. Run migrations.`);
}
```

## Prisma ORM Patterns

### Connection Management

**Singleton Pattern:**

```typescript
import { PrismaClient } from '@prisma/client';

// Singleton pattern for connection reuse
declare global {
  var prisma: PrismaClient | undefined;
}

export const prisma = global.prisma || new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
});

if (process.env.NODE_ENV !== 'production') {
  global.prisma = prisma;
}

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect();
});
```

**Lambda Connection Handling:**

```typescript
// Create client outside handler (reused across warm invocations)
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
});

export const handler = async (event: APIGatewayEvent) => {
  try {
    // Use existing connection
    const users = await prisma.user.findMany();
    return { statusCode: 200, body: JSON.stringify(users) };
  } catch (error) {
    console.error(error);
    return { statusCode: 500, body: JSON.stringify({ error: 'Internal error' }) };
  }
  // Don't disconnect (reuse connection on next invocation)
};
```

### Repository Pattern

```typescript
import { PrismaClient, User, Prisma } from '@prisma/client';

export class UserRepository {
  constructor(private prisma: PrismaClient) {}

  async create(data: Prisma.UserCreateInput): Promise<User> {
    return this.prisma.user.create({ data });
  }

  async findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async update(id: string, data: Prisma.UserUpdateInput): Promise<User> {
    return this.prisma.user.update({
      where: { id },
      data,
    });
  }

  async delete(id: string): Promise<void> {
    await this.prisma.user.delete({ where: { id } });
  }

  async findMany(params: {
    skip?: number;
    take?: number;
    where?: Prisma.UserWhereInput;
    orderBy?: Prisma.UserOrderByWithRelationInput;
  }): Promise<User[]> {
    return this.prisma.user.findMany(params);
  }
}

// Usage with dependency injection
const userRepo = new UserRepository(prisma);
const user = await userRepo.findByEmail('user@example.com');
```

### Transaction Pattern

```typescript
// Transfer funds between accounts
async function transferFunds(fromId: string, toId: string, amount: number): Promise<void> {
  await prisma.$transaction(async (tx) => {
    // Deduct from sender
    const sender = await tx.account.update({
      where: { id: fromId },
      data: { balance: { decrement: amount } },
    });

    // Verify sufficient funds
    if (sender.balance < 0) {
      throw new Error('Insufficient funds');
    }

    // Add to recipient
    await tx.account.update({
      where: { id: toId },
      data: { balance: { increment: amount } },
    });

    // Record transaction
    await tx.transaction.create({
      data: {
        fromAccountId: fromId,
        toAccountId: toId,
        amount,
        type: 'TRANSFER',
      },
    });
  });
  // All operations succeed or all fail
}
```

### Optimistic Locking

```typescript
// Prevent lost updates with version field
// schema.prisma
// model Post {
//   id      String @id @default(uuid())
//   title   String
//   version Int    @default(0)
// }

async function updatePost(id: string, title: string, currentVersion: number): Promise<Post> {
  const updated = await prisma.post.updateMany({
    where: {
      id,
      version: currentVersion, // Only update if version matches
    },
    data: {
      title,
      version: { increment: 1 },
    },
  });

  if (updated.count === 0) {
    throw new Error('Post was modified by another user');
  }

  return prisma.post.findUnique({ where: { id } })!;
}
```

### Error Handling

```typescript
import { Prisma } from '@prisma/client';

try {
  await prisma.user.create({ data: { email: 'user@example.com' } });
} catch (error) {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    // Unique constraint violation
    if (error.code === 'P2002') {
      throw new Error('Email already exists');
    }
    // Record not found
    if (error.code === 'P2025') {
      throw new Error('User not found');
    }
  }
  throw error;
}
```

### Performance Monitoring

**Query Logging:**

```typescript
const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'query' },
    { emit: 'event', level: 'error' },
  ],
});

prisma.$on('query', (e) => {
  if (e.duration > 1000) {
    logger.warn('Slow query detected', {
      query: e.query,
      duration: e.duration,
      params: e.params,
    });
  }
});
```

**Connection Pool Monitoring:**

```typescript
setInterval(() => {
  const metrics = prisma.$metrics.json();
  logger.info('Database metrics', {
    activeConnections: metrics.counters.find(c => c.key === 'prisma_client_queries_active')?.value,
    totalConnections: metrics.counters.find(c => c.key === 'prisma_client_queries_total')?.value,
  });
}, 60000); // Every minute
```

### Common Pitfalls

**N+1 Queries:**

```typescript
// ❌ N+1 query problem
const users = await prisma.user.findMany();
for (const user of users) {
  user.posts = await prisma.post.findMany({ where: { authorId: user.id } });
}

// ✓ Eager loading
const users = await prisma.user.findMany({
  include: { posts: true },
});
```

**Connection Leaks:**

```typescript
// ❌ Creates new connection every time
export const handler = async () => {
  const prisma = new PrismaClient(); // Leak!
  const users = await prisma.user.findMany();
  return { statusCode: 200, body: JSON.stringify(users) };
};

// ✓ Reuse connection across invocations
const prisma = new PrismaClient();

export const handler = async () => {
  const users = await prisma.user.findMany();
  return { statusCode: 200, body: JSON.stringify(users) };
};
```

**Missing Error Handling:**

```typescript
// ❌ Unhandled database errors crash application
const user = await prisma.user.create({ data: { email } });

// ✓ Handle specific errors
try {
  const user = await prisma.user.create({ data: { email } });
} catch (error) {
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
    throw new ConflictError('Email already exists');
  }
  throw new InternalServerError('Database error');
}
```

### Deployment Pipeline Integration

```typescript
// Run migrations in CI/CD, not in application code

// package.json scripts
{
  "scripts": {
    "prisma:generate": "prisma generate",
    "prisma:migrate:dev": "prisma migrate dev",
    "prisma:migrate:deploy": "prisma migrate deploy",
    "prisma:studio": "prisma studio"
  }
}

// Deploy migrations in CD pipeline
// .github/workflows/deploy.yml
// - name: Run migrations
//   run: npm run prisma:migrate:deploy
```

### Testing with Prisma

**In-Memory Database:**

```typescript
// Use SQLite in-memory for tests
// prisma/schema.test.prisma
datasource db {
  provider = "sqlite"
  url      = "file::memory:?cache=shared"
}

// Test setup
import { PrismaClient } from '@prisma/client';

let prisma: PrismaClient;

beforeAll(async () => {
  prisma = new PrismaClient();
  await prisma.$executeRaw`PRAGMA foreign_keys = ON`;
});

afterAll(async () => {
  await prisma.$disconnect();
});

beforeEach(async () => {
  // Clear all tables
  const tables = await prisma.$queryRaw<{ name: string }[]>`
    SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
  `;

  for (const { name } of tables) {
    await prisma.$executeRawUnsafe(`DELETE FROM ${name}`);
  }
});
```

**Integration Tests with Testcontainers:**

```typescript
import { GenericContainer, StartedTestContainer } from 'testcontainers';
import { PrismaClient } from '@prisma/client';

let container: StartedTestContainer;
let prisma: PrismaClient;

beforeAll(async () => {
  // Start PostgreSQL container
  container = await new GenericContainer('postgres:15')
    .withEnvironment({
      POSTGRES_USER: 'test',
      POSTGRES_PASSWORD: 'test',
      POSTGRES_DB: 'test',
    })
    .withExposedPorts(5432)
    .start();

  const connectionString = `postgresql://test:test@${container.getHost()}:${container.getMappedPort(5432)}/test`;

  prisma = new PrismaClient({
    datasources: { db: { url: connectionString } },
  });

  // Run migrations
  await exec(`DATABASE_URL="${connectionString}" npx prisma migrate deploy`);
}, 60000);

afterAll(async () => {
  await prisma.$disconnect();
  await container.stop();
});
```

## Design Checklist

- [ ] All tables have primary keys (UUID or BIGINT)
- [ ] Foreign key constraints with appropriate ON DELETE
- [ ] Indexes for all common query patterns
- [ ] Check constraints for validation
- [ ] NOT NULL constraints where appropriate
- [ ] Unique constraints for unique data
- [ ] Default values where sensible
- [ ] Normalized to 3NF (unless denormalization justified)
- [ ] Migration strategy defined
- [ ] Rollback plan tested
- [ ] No over-indexing
- [ ] Soft delete pattern (deleted_at)
- [ ] Audit fields (created_at, updated_at)

## When to Choose SQL

✅ Complex relationships (many joins)
✅ Strong consistency (ACID)
✅ Complex queries (aggregations, joins)
✅ Ad-hoc reporting
✅ Well-defined, stable schema
✅ Referential integrity needed

**Examples**: User management, orders, financial transactions, CRM
