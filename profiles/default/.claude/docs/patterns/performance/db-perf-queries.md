# Database Query Optimization

Query optimization patterns for SQL and NoSQL databases.

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

### Batch Operations

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

## Monitoring

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

## Common Pitfalls

- **SELECT ***: Wastes bandwidth, prevents covering indexes
- **No Connection Limits**: Serverless can overwhelm database
- **No Query Timeout**: Set statement timeout to prevent runaway queries
- **Missing Cache Invalidation**: Stale data served to users

## Performance Budget

- Query duration: <100ms p95, <500ms p99
- N+1 queries: Zero tolerance
- Connection pool: <80% utilization
- Cache hit rate: >80% for cacheable queries

## Related

- [Indexing Strategies](./db-perf-indexing.md)
- [Database Integration](../backend/database-integration.md)
