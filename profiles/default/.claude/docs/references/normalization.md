# Database Normalization Reference

Normalization organizes data to reduce redundancy and improve integrity. Covers 1NF, 2NF, 3NF with denormalization guidance.

## First Normal Form (1NF)

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

## Second Normal Form (2NF)

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

## Third Normal Form (3NF)

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

## Denormalization Decision

**Normalize when:**
- Write-heavy workload
- Data integrity critical
- Storage costs matter
- Minimal joins needed

**Denormalize when:**
- Read-heavy workload (10:1 read:write ratio or higher)
- Performance bottleneck proven (profile first!)
- Acceptable inconsistency (e.g., cached counts)

**Common Patterns:**

### Computed Columns
```sql
-- Normalized (compute on read)
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  subtotal DECIMAL,
  tax DECIMAL,
  shipping DECIMAL
);
-- SELECT subtotal + tax + shipping AS total

-- Denormalized (compute on write)
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  subtotal DECIMAL,
  tax DECIMAL,
  shipping DECIMAL,
  total DECIMAL GENERATED ALWAYS AS (subtotal + tax + shipping) STORED
);
```

### Cached Counts
```sql
-- Normalized (count on read)
SELECT user_id, COUNT(*) as post_count
FROM posts
GROUP BY user_id;

-- Denormalized (update on write)
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  post_count INTEGER DEFAULT 0
);

-- Update via trigger
CREATE TRIGGER update_post_count
AFTER INSERT ON posts
FOR EACH ROW
EXECUTE FUNCTION increment_user_post_count();
```

### Embedded Objects (JSON)
```sql
-- Use JSON for:
-- - Flexible schema (user preferences, metadata)
-- - Complete objects (addresses, configs)
-- - Rarely queried fields

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255),
  preferences JSONB  -- { theme: 'dark', language: 'en' }
);

CREATE INDEX idx_preferences_theme ON users USING GIN ((preferences->>'theme'));
```

## Quick Decision Tree

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

## Key Principles

1. **Start normalized** - Denormalize only when proven necessary
2. **Profile first** - Don't optimize prematurely
3. **Document deviations** - Explain why denormalized
4. **Maintain integrity** - Use triggers/constraints for denormalized data
5. **Test both** - Ensure denormalization actually improves performance

## Related
- [Database Design](../patterns/backend/database-design.md)
- [Indexing Strategies](indexing-strategies.md)
- [Database Optimization](../patterns/performance/database-optimization.md)
