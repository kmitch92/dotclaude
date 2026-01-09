# Database Indexing Strategies

Comprehensive guide to database indexing for optimal query performance.

## When to Create Indexes

### Always Index

- **Primary keys** (automatic)
- **Foreign keys** (join columns)
- **WHERE clause columns** (frequent filters)
- **ORDER BY columns** (sorting)

### Consider Indexing

- Columns in GROUP BY
- Columns in DISTINCT queries
- Columns used in search (LIKE patterns)
- High-cardinality columns (many unique values)

### Don't Index

- Low-cardinality columns (few unique values like boolean)
- Columns rarely queried
- Small tables (<1000 rows)
- Columns frequently updated (index maintenance overhead)

## Single-Column Indexes

Basic index for filtering on single column:

```sql
-- Index for filtering
CREATE INDEX idx_users_email ON users(email);

-- Query uses index
SELECT * FROM users WHERE email = 'user@example.com';
```

## Composite Indexes

Order matters! Most selective column first:

```sql
-- Index for multi-column filters
CREATE INDEX idx_orders_user_status ON orders(user_id, status);

-- Uses index (left-to-right prefix)
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';
SELECT * FROM orders WHERE user_id = 123; -- Also uses index

-- Does NOT use index (missing left prefix)
SELECT * FROM orders WHERE status = 'pending';
```

### Left-to-Right Prefix Rule

Composite index `(A, B, C)` can serve queries filtering on:
- ✅ `A`
- ✅ `A, B`
- ✅ `A, B, C`

But NOT:
- ❌ `B`
- ❌ `C`
- ❌ `B, C`

### Column Order Guidelines

1. **Equality first, range second**:
   ```sql
   -- GOOD: Equality (user_id) before range (created_at)
   CREATE INDEX idx_orders ON orders(user_id, created_at);

   SELECT * FROM orders
   WHERE user_id = 123
     AND created_at > '2024-01-01';
   ```

2. **High selectivity first**:
   ```sql
   -- user_id is more selective than status
   CREATE INDEX idx_orders ON orders(user_id, status);
   ```

3. **Most frequently queried first**:
   ```sql
   -- user_id queried more often than status
   CREATE INDEX idx_orders ON orders(user_id, status);
   ```

## Covering Indexes

Include all columns needed by query (avoid table lookup):

```sql
-- Index includes columns needed by SELECT
CREATE INDEX idx_users_email_name ON users(email, name);

-- Query satisfied entirely by index (no table access)
SELECT name FROM users WHERE email = 'user@example.com';
```

**PostgreSQL INCLUDE syntax**:
```sql
-- email is indexed, name is just included
CREATE INDEX idx_users_email_include_name
ON users(email) INCLUDE (name);
```

## Partial Indexes

Index only relevant subset:

```sql
-- Index only active users
CREATE INDEX idx_active_users_email ON users(email)
WHERE status = 'active';

-- Query uses partial index (smaller, faster)
SELECT * FROM users
WHERE email = 'user@example.com'
  AND status = 'active';
```

**Benefits**:
- Smaller index size
- Faster index scans
- Lower maintenance overhead
- Better cache hit rate

**Use cases**:
- Index only recent data: `WHERE created_at > NOW() - INTERVAL '30 days'`
- Index only non-null values: `WHERE deleted_at IS NULL`
- Index only specific status: `WHERE status IN ('active', 'pending')`

## Functional Indexes

Index computed values:

```sql
-- Index lowercase email for case-insensitive search
CREATE INDEX idx_users_email_lower ON users(LOWER(email));

-- Query uses functional index
SELECT * FROM users WHERE LOWER(email) = 'user@example.com';
```

**PostgreSQL**:
```sql
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
CREATE INDEX idx_orders_total_desc ON orders(total DESC);
```

**MySQL**:
```sql
-- MySQL 8.0+
CREATE INDEX idx_users_email_lower ON users((LOWER(email)));
```

## Full-Text Indexes

For text search:

```sql
-- PostgreSQL
CREATE INDEX idx_articles_content_fts ON articles
USING GIN (to_tsvector('english', content));

SELECT * FROM articles
WHERE to_tsvector('english', content) @@ to_tsquery('database & performance');

-- MySQL
CREATE FULLTEXT INDEX idx_articles_content ON articles(content);

SELECT * FROM articles
WHERE MATCH(content) AGAINST('database performance' IN NATURAL LANGUAGE MODE);
```

## Index Monitoring

### Find Unused Indexes (PostgreSQL)

```sql
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelid NOT IN (
    SELECT indexrelid
    FROM pg_index
    WHERE indisprimary OR indisunique
  )
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Find Missing Indexes (PostgreSQL)

```sql
-- Tables with sequential scans
SELECT
  schemaname,
  tablename,
  seq_scan,
  seq_tup_read,
  idx_scan,
  seq_tup_read / seq_scan AS avg_seq_read
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC
LIMIT 25;
```

### Index Size and Bloat

```sql
-- PostgreSQL: Index sizes
SELECT
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 25;
```

## Index Maintenance

### Rebuild Bloated Indexes (PostgreSQL)

```sql
-- Rebuild index (locks table)
REINDEX INDEX idx_users_email;

-- Rebuild concurrently (no lock, but slower)
REINDEX INDEX CONCURRENTLY idx_users_email;

-- Rebuild all indexes on table
REINDEX TABLE users;
```

### Update Statistics

```sql
-- PostgreSQL
ANALYZE users;

-- MySQL
ANALYZE TABLE users;
```

## Multi-Column Index Strategies

### Strategy 1: Single Composite Index

Best when queries always use same columns together:

```sql
CREATE INDEX idx_orders_user_status ON orders(user_id, status);

-- Serves these queries well:
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';
SELECT * FROM orders WHERE user_id = 123;
```

### Strategy 2: Multiple Single-Column Indexes

PostgreSQL can combine indexes (bitmap index scan):

```sql
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);

-- PostgreSQL combines both indexes
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';
```

**Trade-offs**:
- ✅ Flexible for different query patterns
- ❌ Less efficient than single composite index
- ❌ More storage overhead

### Strategy 3: Overlapping Composite Indexes

For different query patterns:

```sql
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
CREATE INDEX idx_orders_status_created ON orders(status, created_at);

-- First index serves: WHERE user_id = ? AND status = ?
-- Second index serves: WHERE status = ? ORDER BY created_at
```

## Common Mistakes

### Over-Indexing

**Problem**: Too many indexes slow down writes and waste space

**Solution**: Monitor index usage, drop unused indexes:
```sql
DROP INDEX IF EXISTS idx_rarely_used;
```

### Wrong Column Order

**Problem**: Composite index with wrong column order

**Bad**:
```sql
CREATE INDEX idx_orders ON orders(status, user_id);
SELECT * FROM orders WHERE user_id = 123; -- Can't use index!
```

**Good**:
```sql
CREATE INDEX idx_orders ON orders(user_id, status);
SELECT * FROM orders WHERE user_id = 123; -- Uses index
```

### Indexing Low-Cardinality Columns

**Problem**: Index on column with few unique values (e.g., boolean, status with 3 values)

**Bad**:
```sql
CREATE INDEX idx_users_is_admin ON users(is_admin); -- Only 2 values!
```

**Better**: Partial index for minority case:
```sql
CREATE INDEX idx_users_admin ON users(is_admin) WHERE is_admin = true;
```

## Performance Budget

- **Index scans**: >95% of queries should use indexes
- **Index size**: <50% of table size (total for all indexes)
- **Unused indexes**: Zero (drop them)
- **Index maintenance**: REINDEX/ANALYZE scheduled regularly

## Related

- [Query Optimization](./db-perf-queries.md)
- [Database Design](../backend/database-design.md)
- [Normalization Reference](../../references/normalization.md)
