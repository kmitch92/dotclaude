# DynamoDB Schema Design Patterns

## Core Principles

1. **Access Patterns First**: Design based on queries, not entities
2. **Single-Table Design**: Store multiple entity types in one table
3. **Composite Keys**: PK + SK provide flexible querying
4. **GSI Strategy**: Use Global Secondary Indexes for alternate access patterns
5. **Denormalization**: Duplicate data to avoid joins

## Single-Table Design

### Entity Modeling
```typescript
// Single table holds multiple entity types
type Entity =
  | { PK: `USER#${string}`; SK: 'PROFILE'; email: string; name: string }
  | { PK: `USER#${string}`; SK: `ORDER#${string}`; total: number; status: string }
  | { PK: `ORDER#${string}`; SK: 'METADATA'; userId: string; createdAt: string }
  | { PK: `ORDER#${string}`; SK: `ITEM#${string}`; productId: string; quantity: number };
```

### Key Patterns
```typescript
// User profile
PK: USER#user_123
SK: PROFILE

// User's orders
PK: USER#user_123
SK: ORDER#order_456

// Order metadata
PK: ORDER#order_456
SK: METADATA

// Order items
PK: ORDER#order_456
SK: ITEM#item_789
```

## Access Patterns Drive Design

```typescript
// Access Pattern 1: Get user by ID
// Query: PK = USER#user_123, SK = PROFILE

// Access Pattern 2: Get user by email
// Query: GSI1 where GSI1PK = EMAIL#user@example.com

// Access Pattern 3: List user's orders
// Query: PK = USER#user_123, SK begins_with ORDER#

// Access Pattern 4: Get order by ID
// Query: GSI1 where GSI1PK = ORDER#order_456

// Access Pattern 5: List order items
// Query: PK = ORDER#order_456, SK begins_with ITEM#
```

## Common Patterns

### Composite Sort Key for Hierarchical Data
```typescript
// Comments on posts with timestamp ordering
type CommentItem = {
  PK: `POST#${string}`;                      // POST#post_123
  SK: `COMMENT#${string}#${string}`;         // COMMENT#2025-01-15T10:30:00Z#comment_456
  commentId: string;
  userId: string;
  content: string;
  createdAt: string;
};

// Query all comments for post, ordered by time
// PK = POST#post_123, SK begins_with COMMENT#
// Results automatically sorted by timestamp in SK
```

### Sparse Index for Specific Queries
```typescript
// Only premium users have GSI2 attributes
type UserWithPremiumItem = UserItem & {
  GSI2PK?: `PREMIUM`;        // Only set for premium users
  GSI2SK?: string;           // Subscription expiration date
};

// Query only premium users via GSI2
// GSI2PK = PREMIUM
// Much smaller index than full user table
```

### One-to-Many with Query
```typescript
// User has many orders
type UserItem = {
  PK: `USER#${string}`;
  SK: 'PROFILE';
  email: string;
  name: string;
};

type OrderItem = {
  PK: `USER#${string}`;      // Same PK as user
  SK: `ORDER#${string}`;     // Different SK
  orderId: string;
  total: number;
  status: string;
  createdAt: string;
};

// Get user profile
// GetItem: PK = USER#123, SK = PROFILE

// List user's orders
// Query: PK = USER#123, SK begins_with ORDER#
```

### Many-to-Many with Bidirectional Lookups
```typescript
// Users and Groups
type UserGroupMembershipItem = {
  PK: `USER#${string}`;
  SK: `GROUP#${string}`;
  joinedAt: string;
  // GSI for reverse lookup
  GSI1PK: `GROUP#${string}`;
  GSI1SK: `USER#${string}`;
};

// Get groups for user
// Query: PK = USER#user_123, SK begins_with GROUP#

// Get members of group
// Query GSI1: GSI1PK = GROUP#group_456, GSI1SK begins_with USER#
```

### Versioning Pattern
```typescript
type DocumentItem = {
  PK: `DOC#${string}`;
  SK: `v${number}`;          // v1, v2, v3...
  content: string;
  createdAt: string;
  createdBy: string;
};

// Get latest version
// Query: PK = DOC#doc_123, SK begins_with v, ScanIndexForward = false, Limit = 1

// Get all versions
// Query: PK = DOC#doc_123, SK begins_with v
```

## GSI Design Patterns

### Inverted Index
```typescript
type OrderItem = {
  PK: `USER#${string}`;
  SK: `ORDER#${string}`;
  orderId: string;
  // GSI for order lookup
  GSI1PK: `ORDER#${string}`;
  GSI1SK: `USER#${string}`;
};

// Get order by ID (using GSI1)
// Query GSI1: GSI1PK = ORDER#order_456
```

### Filtering with GSI
```typescript
type UserItem = {
  PK: `USER#${string}`;
  SK: 'PROFILE';
  email: string;
  status: 'active' | 'suspended' | 'pending';
  // GSI for status filtering
  GSI2PK: 'USER';
  GSI2SK: `${string}#${string}`;  // status#createdAt
};

// List active users sorted by creation
// Query GSI2: GSI2PK = USER, GSI2SK begins_with active#
```

## Query Optimization

### Reduce Item Size
```typescript
// ❌ BAD: Large items increase cost
type OrderItem = {
  PK: string;
  SK: string;
  itemDetails: { /* huge nested object */ };
};

// ✅ GOOD: Store large attributes separately
type OrderMetadata = {
  PK: `ORDER#${string}`;
  SK: 'METADATA';
  id: string;
  total: number;
  status: string;
};

type OrderDetails = {
  PK: `ORDER#${string}`;
  SK: 'DETAILS';
  items: OrderItem[];
  notes: string;
};

// Fetch metadata frequently (small)
// Fetch details only when needed (large)
```

### Batch Operations
```typescript
// ❌ BAD: Individual GetItem calls
for (const id of userIds) {
  const user = await dynamodb.get({ PK: `USER#${id}`, SK: 'PROFILE' });
}

// ✅ GOOD: BatchGetItem (up to 100 items)
const users = await dynamodb.batchGet({
  RequestItems: {
    'users-table': {
      Keys: userIds.map(id => ({ PK: `USER#${id}`, SK: 'PROFILE' })),
    },
  },
});
```

### Pagination with LastEvaluatedKey
```typescript
type PaginationResult<T> = {
  items: T[];
  lastKey?: Record<string, any>;
};

async function listOrders(userId: string, lastKey?: Record<string, any>): Promise<PaginationResult<Order>> {
  const result = await dynamodb.query({
    KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
    ExpressionAttributeValues: {
      ':pk': `USER#${userId}`,
      ':sk': 'ORDER#',
    },
    Limit: 20,
    ExclusiveStartKey: lastKey,
  });

  return {
    items: result.Items as Order[],
    lastKey: result.LastEvaluatedKey,
  };
}
```

## Anti-Patterns to Avoid

### Scans Instead of Queries
```typescript
// ❌ BAD: Scan entire table
const result = await dynamodb.scan({
  FilterExpression: 'email = :email',
  ExpressionAttributeValues: { ':email': 'user@example.com' },
});

// ✅ GOOD: Query with GSI
const result = await dynamodb.query({
  IndexName: 'EmailIndex',
  KeyConditionExpression: 'GSI1PK = :email',
  ExpressionAttributeValues: { ':email': 'EMAIL#user@example.com' },
});
```

### Hot Partitions
```typescript
// ❌ BAD: All items share same PK
PK: 'GLOBAL'
SK: `USER#${userId}`

// ✅ GOOD: Distribute across partitions
PK: `SHARD#${hash(userId) % 10}`  // 10 shards
SK: `USER#${userId}`
```

### Large Items
```typescript
// ❌ BAD: Item > 400KB (DynamoDB limit)
type LargeItem = {
  PK: string;
  SK: string;
  largeBlob: string;  // Huge data
};

// ✅ GOOD: Store large data in S3
type ItemWithS3 = {
  PK: string;
  SK: string;
  dataUrl: string;  // s3://bucket/key
};
```

## Conditional Writes

### Optimistic Locking
```typescript
type VersionedItem = {
  PK: string;
  SK: string;
  version: number;
  data: unknown;
};

await dynamodb.update({
  Key: { PK: 'USER#123', SK: 'PROFILE' },
  UpdateExpression: 'SET #data = :data, #version = #version + 1',
  ConditionExpression: '#version = :currentVersion',
  ExpressionAttributeNames: {
    '#data': 'data',
    '#version': 'version',
  },
  ExpressionAttributeValues: {
    ':data': newData,
    ':currentVersion': currentVersion,
  },
});
// Throws ConditionalCheckFailedException if version changed
```

### Prevent Duplicates
```typescript
await dynamodb.put({
  Item: { PK: 'USER#123', SK: 'PROFILE', email: 'user@example.com' },
  ConditionExpression: 'attribute_not_exists(PK)',
});
// Throws ConditionalCheckFailedException if item exists
```

## Design Checklist

- [ ] All access patterns identified and documented
- [ ] PK and SK designed to support primary access patterns
- [ ] GSIs designed for alternate access patterns
- [ ] No scans required for common queries
- [ ] Items < 400KB (consider S3 for large data)
- [ ] Hot partitions avoided (distribute load)
- [ ] Batch operations used where possible
- [ ] Pagination implemented for list operations
- [ ] Conditional writes for concurrent updates
- [ ] TTL configured for time-limited data

## When to Choose DynamoDB

✅ Horizontal scaling (massive scale)
✅ Flexible schema (evolving data)
✅ Simple access patterns (key-value)
✅ High write throughput
✅ Eventual consistency acceptable
✅ Predictable low latency
✅ Serverless, fully managed

**Examples**: Session storage, logs, time-series, IoT, caching

## Related
- [SQL Schema Design](sql-schema-design.md)
- [DynamoDB Patterns](dynamodb-patterns.md)
- [Database Optimization](../performance/database-optimization.md)
