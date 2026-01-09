# Database Indexing Strategies

Indexes improve query performance but add write overhead. Practical guide for creating and optimizing indexes.

## When to Index

### Always Index
- **Primary keys** (automatic)
- **Foreign keys** (NOT automatic - must create manually)
- **WHERE clause columns** (frequent filters)
- **ORDER BY columns** (sorting)

```sql
-- Foreign key index (critical!)
CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  author_id INTEGER REFERENCES users(id)
);
CREATE INDEX idx_posts_author_id ON posts(author_id);

-- WHERE clause
CREATE INDEX idx_users_email ON users(email);

-- ORDER BY
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
```

### Consider Indexing
- **JOIN columns**
- **GROUP BY columns**
- **LIKE prefix searches** (`'John%'` - yes, `'%Doe'` - no)

## Index Types

### B-Tree (Default)
Use for: Equality, ranges, sorting

```sql
CREATE INDEX idx_users_email ON users(email);

-- Efficient
SELECT * FROM users WHERE email = 'user@example.com';
SELECT * FROM users WHERE created_at > '2024-01-01';
SELECT * FROM users ORDER BY name;
```

### Composite (Multi-Column)
Use for: Queries filtering on multiple columns

```sql
-- Query: WHERE status = 'active' AND created_at > '2024-01-01'
CREATE INDEX idx_orders_status_created ON orders(status, created_at);

-- Order matters!
-- ✓ Uses index: WHERE status = 'active'
-- ✓ Uses index: WHERE status = 'active' AND created_at > '2024-01-01'
-- ✗ Doesn't use: WHERE created_at > '2024-01-01' (only)
```

**Rule:** Most selective column first (status before created_at if status filters more).

### Partial (Filtered)
Use for: Subset of rows

```sql
-- Only index active users
CREATE INDEX idx_active_users ON users(email) WHERE status = 'active';

-- Efficient
SELECT * FROM users WHERE status = 'active' AND email = 'user@example.com';

-- Smaller index = faster + less storage
```

### GIN (Inverted)
Use for: Arrays, JSONB, full-text search

```sql
-- Array containment
CREATE INDEX idx_posts_tags ON posts USING GIN(tags);
SELECT * FROM posts WHERE tags @> ARRAY['typescript'];

-- JSONB
CREATE INDEX idx_users_prefs ON users USING GIN(preferences);
SELECT * FROM users WHERE preferences @> '{"theme": "dark"}';

-- Full-text
CREATE INDEX idx_posts_search ON posts USING GIN(to_tsvector('english', content));
SELECT * FROM posts WHERE to_tsvector('english', content) @@ to_tsquery('postgresql');
```

### Unique
Use for: Enforce uniqueness + performance

```sql
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);

-- Prevents duplicates + fast lookups
```

## When NOT to Index

❌ **Small tables** (<1000 rows) - full scan faster
❌ **Frequently updated columns** - index overhead > benefit
❌ **Low cardinality** (few distinct values) - e.g., boolean columns
❌ **Columns never in WHERE/JOIN/ORDER BY**
❌ **Over-indexing** - each index slows writes

## Index Maintenance

### Find Missing Indexes

```sql
-- PostgreSQL: Queries with seq scans
SELECT schemaname, tablename, seq_scan, seq_tup_read
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC
LIMIT 10;

-- Check slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Find Unused Indexes

```sql
-- PostgreSQL: Indexes never used
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE 'pg_toast%';

-- Drop unused indexes
DROP INDEX idx_unused_column;
```

### Monitor Index Size

```sql
-- Index size
SELECT
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Rebuild Bloated Indexes

```sql
-- Rebuild index
REINDEX INDEX idx_users_email;

-- Rebuild all indexes on table
REINDEX TABLE users;
```

## Best Practices

1. **Profile before indexing** - Use EXPLAIN ANALYZE
2. **Index foreign keys** - Always create these manually
3. **Composite index order matters** - Most selective first
4. **Partial indexes for subsets** - Smaller, faster
5. **Monitor unused indexes** - Drop or justify
6. **Regular maintenance** - REINDEX bloated indexes
7. **Trade-off** - Indexes speed reads, slow writes

## Decision Tree

```
Query slow?
  NO → No index needed
  YES → Profile with EXPLAIN ANALYZE
  ↓
Seq scan on large table?
  NO → Optimize query, not index
  YES → Continue
  ↓
Column in WHERE/JOIN/ORDER BY?
  NO → Can't index effectively
  YES → Continue
  ↓
Multiple columns filtered?
  YES → Create composite index
  NO → Create single-column index
  ↓
Only querying subset of rows?
  YES → Create partial index
  NO → Create full index
  ↓
Test performance improvement
  <10% → Remove index
  >10% → Keep index
```

## Related
- [Database Design](../patterns/backend/database-design.md)
- [Database Optimization](../patterns/performance/database-optimization.md)
- [Normalization](normalization.md)
