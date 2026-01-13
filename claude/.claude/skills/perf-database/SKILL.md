---
name: perf-database
description: Database performance optimization. Indexing strategies, query optimization, N+1 prevention, explain plans, monitoring, composite indexes.
---

# Database Performance Optimization

Comprehensive guide to database performance through indexing strategies, query optimization, N+1 prevention, and monitoring.

## Indexing Strategies

### When to Create Indexes

**Always Index:**
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

**Consider Indexing:**
- **JOIN columns**
- **GROUP BY columns**
- **DISTINCT queries**
- **LIKE prefix searches** (`'John%'` - yes, `'%Doe'` - no)
- **High-cardinality columns** (many unique values)

**Don't Index:**
- ❌ **Small tables** (<1000 rows) - full scan faster
- ❌ **Frequently updated columns** - index overhead > benefit
- ❌ **Low cardinality** (few distinct values) - e.g., boolean columns
- ❌ **Columns never in WHERE/JOIN/ORDER BY**
- ❌ **Over-indexing** - each index slows writes

### Single-Column Indexes

Basic index for filtering on single column:

```sql
-- Index for filtering
CREATE INDEX idx_users_email ON users(email);

-- Query uses index
SELECT * FROM users WHERE email = 'user@example.com';
```

### Composite Indexes

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

**Left-to-Right Prefix Rule:**

Composite index `(A, B, C)` can serve queries filtering on:
- ✅ `A`
- ✅ `A, B`
- ✅ `A, B, C`

But NOT:
- ❌ `B`
- ❌ `C`
- ❌ `B, C`

**Column Order Guidelines:**

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

### Covering Indexes

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

### Partial Indexes

Index only relevant subset:

```sql
-- Only index active users
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
- Index minority case: `WHERE is_admin = true` (not all booleans)

### Functional Indexes

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

### Full-Text Indexes

For text search:

```sql
-- PostgreSQL GIN
CREATE INDEX idx_articles_content_fts ON articles
USING GIN (to_tsvector('english', content));

SELECT * FROM articles
WHERE to_tsvector('english', content) @@ to_tsquery('database & performance');

-- MySQL
CREATE FULLTEXT INDEX idx_articles_content ON articles(content);

SELECT * FROM articles
WHERE MATCH(content) AGAINST('database performance' IN NATURAL LANGUAGE MODE);
```

### GIN Indexes (PostgreSQL)

For arrays, JSONB, full-text search:

```sql
-- Array containment
CREATE INDEX idx_posts_tags ON posts USING GIN(tags);
SELECT * FROM posts WHERE tags @> ARRAY['typescript'];

-- JSONB
CREATE INDEX idx_users_prefs ON users USING GIN(preferences);
SELECT * FROM users WHERE preferences @> '{"theme": "dark"}';
```

### Unique Indexes

Enforce uniqueness + performance:

```sql
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);

-- Prevents duplicates + fast lookups
```

### Multi-Column Index Strategies

**Strategy 1: Single Composite Index**

Best when queries always use same columns together:

```sql
CREATE INDEX idx_orders_user_status ON orders(user_id, status);

-- Serves these queries well:
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';
SELECT * FROM orders WHERE user_id = 123;
```

**Strategy 2: Multiple Single-Column Indexes**

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

**Strategy 3: Overlapping Composite Indexes**

For different query patterns:

```sql
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
CREATE INDEX idx_orders_status_created ON orders(status, created_at);

-- First index serves: WHERE user_id = ? AND status = ?
-- Second index serves: WHERE status = ? ORDER BY created_at
```

## Query Optimization

### Explain Plans

```sql
-- PostgreSQL
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user@example.com';

-- Look for:
-- - Seq Scan (bad, missing index)
-- - Index Scan (good)
-- - Bitmap Heap Scan (acceptable for low selectivity)
```

**Key metrics:**
- **Seq Scan**: Full table scan (slow for large tables)
- **Index Scan**: Uses index (fast)
- **Cost**: Estimated query cost (lower is better)
- **Rows**: Estimated vs actual (large diff = outdated stats)

### SELECT Only Needed Columns

```typescript
// BAD: Fetches all columns (including large JSON/text)
const users = await db.user.findMany();

// GOOD: Fetches only needed columns
const users = await db.user.findMany({
  select: { id: true, email: true, name: true }
});
```

### Avoid Functions in WHERE Clause

```sql
-- BAD: Cannot use index (function applied to indexed column)
SELECT * FROM users WHERE LOWER(email) = 'user@example.com';

-- GOOD: Store normalized data, use index
SELECT * FROM users WHERE email = 'user@example.com';

-- Alternative: Functional index
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
```

## N+1 Query Prevention

### Problem

```typescript
// BAD: N+1 pattern (1 + N queries)
const users = await db.user.findMany(); // 1 query

for (const user of users) {
  user.posts = await db.post.findMany({
    where: { userId: user.id } // N queries
  });
}
// Total: 1 + 100 users = 101 queries
```

### Solution: Eager Loading

```typescript
// GOOD: Single query with join
const users = await db.user.findMany({
  include: {
    posts: true // Joined in single query
  }
});
// Total: 1-2 queries regardless of user count
```

### DataLoader Pattern (GraphQL/Node.js)

Batches and caches database calls within single request:

```typescript
import DataLoader from 'dataloader';

const postLoader = new DataLoader(async (userIds) => {
  const posts = await db.post.findMany({
    where: { userId: { in: userIds } }
  });

  // Group posts by userId
  const postsByUserId = new Map();
  for (const post of posts) {
    if (!postsByUserId.has(post.userId)) {
      postsByUserId.set(post.userId, []);
    }
    postsByUserId.get(post.userId).push(post);
  }

  // Return in same order as userIds
  return userIds.map(id => postsByUserId.get(id) || []);
});

// Usage: Automatically batches calls
const user1Posts = await postLoader.load(user1.id);
const user2Posts = await postLoader.load(user2.id);
// Results in single query: SELECT * FROM posts WHERE userId IN (1, 2)
```

## Connection Pooling

### Problem

Creating database connections is expensive (100-300ms):

```typescript
// BAD: New connection every request
app.get('/users', async (req, res) => {
  const client = await createConnection(); // Slow!
  const users = await client.query('SELECT * FROM users');
  await client.close();
  res.json(users);
});
```

### Solution: Connection Pool

```typescript
import { Pool } from 'pg';

// Create pool once at startup
const pool = new Pool({
  host: 'localhost',
  database: 'myapp',
  max: 20, // Max connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Reuse connections from pool
app.get('/users', async (req, res) => {
  const client = await pool.connect(); // Fast (reuses existing)
  try {
    const result = await client.query('SELECT * FROM users');
    res.json(result.rows);
  } finally {
    client.release(); // Return to pool
  }
});
```

**Pool sizing:**
- **Web apps**: `connections = ((core_count * 2) + effective_spindle_count)`
- **Typical**: 10-20 connections per app instance
- **Lambda/serverless**: Use connection pooler (RDS Proxy, PgBouncer)

### Prisma Connection Pooling

```typescript
// Recommended: Prisma Accelerate for serverless
import { PrismaClient } from '@prisma/client/edge';
import { withAccelerate } from '@prisma/extension-accelerate';

const prisma = new PrismaClient().$extends(withAccelerate());
```

## Caching Strategies

### Application-Level Cache (Redis)

```typescript
import { Redis } from 'ioredis';

const redis = new Redis();

async function getUser(userId: string) {
  // Try cache first
  const cached = await redis.get(`user:${userId}`);
  if (cached) return JSON.parse(cached);

  // Cache miss: query database
  const user = await db.user.findUnique({ where: { id: userId } });

  // Store in cache (TTL: 5 minutes)
  await redis.setex(`user:${userId}`, 300, JSON.stringify(user));

  return user;
}

// Invalidate cache on update
async function updateUser(userId: string, data: UpdateUserInput) {
  const user = await db.user.update({ where: { id: userId }, data });
  await redis.del(`user:${userId}`); // Invalidate cache
  return user;
}
```

**When to cache:**
- Expensive queries (joins, aggregations)
- Frequently accessed data (user profiles, config)
- Relatively static data (categories, tags)

**When NOT to cache:**
- Rapidly changing data (real-time feeds)
- User-specific data with low reuse
- Data where stale reads cause issues

### HTTP Cache Headers

```typescript
app.get('/api/users/:id', async (req, res) => {
  const user = await getUser(req.params.id);

  // Cache in browser/CDN for 5 minutes
  res.setHeader('Cache-Control', 'public, max-age=300');
  res.json(user);
});
```

## Batch Operations

### Bulk Inserts

```typescript
// BAD: Individual inserts (N queries)
for (const user of users) {
  await db.user.create({ data: user });
}

// GOOD: Bulk insert (1 query)
await db.user.createMany({
  data: users,
  skipDuplicates: true,
});
```

### Transactions for Consistency

```typescript
// Atomic multi-table update
await db.$transaction(async (tx) => {
  // Deduct from sender
  await tx.account.update({
    where: { id: senderId },
    data: { balance: { decrement: amount } },
  });

  // Add to recipient
  await tx.account.update({
    where: { id: recipientId },
    data: { balance: { increment: amount } },
  });

  // Record transaction
  await tx.transaction.create({
    data: { from: senderId, to: recipientId, amount },
  });
});
// All succeed or all fail (no partial updates)
```

## NoSQL Optimization (DynamoDB)

### Single-Table Design

```typescript
// Store multiple entity types in one table
// PK: USER#123, SK: PROFILE
// PK: USER#123, SK: ORDER#456
// PK: USER#123, SK: ORDER#789

// Fetch user and all orders in single query
const result = await dynamodb.query({
  TableName: 'app-data',
  KeyConditionExpression: 'PK = :pk',
  ExpressionAttributeValues: { ':pk': 'USER#123' },
});
```

### GSI for Alternative Access Patterns

```typescript
// GSI: email-index (PK: email, SK: timestamp)
const user = await dynamodb.query({
  TableName: 'app-data',
  IndexName: 'email-index',
  KeyConditionExpression: 'email = :email',
  ExpressionAttributeValues: { ':email': 'user@example.com' },
});
```

### DynamoDB Batch Operations

```typescript
// Batch get (up to 100 items)
const result = await dynamodb.batchGet({
  RequestItems: {
    'app-data': {
      Keys: [
        { PK: 'USER#123', SK: 'PROFILE' },
        { PK: 'USER#456', SK: 'PROFILE' },
      ],
    },
  },
});

// Batch write (up to 25 items)
await dynamodb.batchWrite({
  RequestItems: {
    'app-data': [
      { PutRequest: { Item: { PK: 'USER#123', SK: 'ORDER#789', ... } } },
      { DeleteRequest: { Key: { PK: 'USER#456', SK: 'ORDER#012' } } },
    ],
  },
});
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

-- Check slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
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

## Query Monitoring

### Key Metrics

- **Query duration**: p50, p95, p99 latency
- **Slow query log**: Queries >1s
- **Connection pool usage**: Active vs idle connections
- **Cache hit rate**: >80% for cached queries

### PostgreSQL Monitoring

```sql
-- Long-running queries
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '5 seconds'
ORDER BY duration DESC;
```

### Application-Level Monitoring

```typescript
// Log slow queries
const start = Date.now();
const result = await db.query('SELECT ...');
const duration = Date.now() - start;

if (duration > 1000) {
  logger.warn('Slow query detected', { query, duration });
}
```

## Common Mistakes

### Over-Indexing

**Problem**: Too many indexes slow down writes and waste space

**Solution**: Monitor index usage, drop unused indexes:
```sql
DROP INDEX IF EXISTS idx_rarely_used;
```

### Wrong Column Order

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

**Bad**:
```sql
CREATE INDEX idx_users_is_admin ON users(is_admin); -- Only 2 values!
```

**Better**: Partial index for minority case:
```sql
CREATE INDEX idx_users_admin ON users(is_admin) WHERE is_admin = true;
```

### Other Common Pitfalls

- **SELECT ***: Wastes bandwidth, prevents covering indexes
- **No Connection Limits**: Serverless can overwhelm database
- **No Query Timeout**: Set statement timeout to prevent runaway queries
- **Missing Cache Invalidation**: Stale data served to users

## Performance Budget

- **Query duration**: <100ms p95, <500ms p99
- **Index scans**: >95% of queries should use indexes
- **Index size**: <50% of table size (total for all indexes)
- **Unused indexes**: Zero (drop them)
- **N+1 queries**: Zero tolerance
- **Connection pool**: <80% utilization
- **Cache hit rate**: >80% for cacheable queries

## Decision Tree: When to Index

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

## Best Practices

1. **Profile before indexing** - Use EXPLAIN ANALYZE
2. **Index foreign keys** - Always create these manually
3. **Composite index order matters** - Most selective first
4. **Partial indexes for subsets** - Smaller, faster
5. **Monitor unused indexes** - Drop or justify
6. **Regular maintenance** - REINDEX bloated indexes, ANALYZE statistics
7. **Trade-off** - Indexes speed reads, slow writes
8. **SELECT only needed columns** - Prevents table access, enables covering indexes
9. **Use connection pooling** - Essential for performance
10. **Eliminate N+1 queries** - Use eager loading or DataLoader
