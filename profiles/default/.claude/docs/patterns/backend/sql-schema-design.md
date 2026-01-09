# SQL Schema Design Patterns

## Core Principles

1. **Schema-First**: Design data model before application code
2. **Normalization**: Eliminate redundancy (target 3NF)
3. **Denormalization**: Strategic, only when performance requires it
4. **Referential Integrity**: Use foreign keys and constraints
5. **Index Strategy**: Index for queries, not just primary keys
6. **Migration Safety**: Never destructive without backups

## Table Design with Constraints

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

## Primary Key Strategies

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

### Third Normal Form (3NF) - Target

```sql
-- ❌ BAD: Denormalized (redundant data)
CREATE TABLE orders_bad (
  id UUID PRIMARY KEY,
  user_email VARCHAR(255),    -- Duplicates user data
  user_name VARCHAR(100),      -- Duplicates user data
  total_amount DECIMAL(10,2)
);

-- ✅ GOOD: Normalized (3NF)
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL
);

CREATE TABLE orders (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  total_amount DECIMAL(10,2) NOT NULL
);
```

### Strategic Denormalization

```sql
-- ✅ Denormalization justified by query patterns
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
-- ❌ BAD: Over-indexing
CREATE INDEX idx_users_name ON users(name);  -- If never queried

-- ❌ BAD: Wrong column order
SELECT * FROM orders WHERE status = 'completed' AND user_id = ?;
CREATE INDEX idx_orders_wrong ON orders(status, user_id);

-- ✅ GOOD: High selectivity first
CREATE INDEX idx_orders_correct ON orders(user_id, status);

-- ❌ BAD: Redundant indexes
CREATE INDEX idx_user_id ON orders(user_id);
CREATE INDEX idx_user_status ON orders(user_id, status);  -- Makes first redundant

-- ✅ GOOD: Keep composite only
CREATE INDEX idx_user_status ON orders(user_id, status);
```

## Query Optimization

### N+1 Query Problem
```typescript
// ❌ BAD: N+1 queries
const users = await db.users.findAll();
for (const user of users) {
  user.orders = await db.orders.findByUserId(user.id);  // N queries!
}

// ✅ GOOD: Single query with join
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
-- ❌ BAD: SELECT *
SELECT * FROM orders WHERE user_id = ?;

-- ✅ GOOD: Select only needed columns
SELECT id, total_amount, status, created_at FROM orders WHERE user_id = ?;
```

## Migration Patterns

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
-- ❌ BAD: Data loss
ALTER TABLE users DROP COLUMN email;

-- ❌ BAD: Breaks running app
ALTER TABLE users RENAME COLUMN email TO new_email;

-- ❌ BAD: Fails if rows exist
ALTER TABLE users ADD COLUMN phone VARCHAR(20) NOT NULL;

-- ✅ GOOD: Add with default
ALTER TABLE users ADD COLUMN phone VARCHAR(20) DEFAULT '';
```

## Migration Implementation

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

## Schema Versioning

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

## Related
- [DynamoDB Schema Design](dynamodb-schema-design.md)
- [Database Optimization](../performance/database-optimization.md)
- [Indexing Strategies](../../references/indexing-strategies.md)
