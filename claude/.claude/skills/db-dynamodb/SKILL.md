---
name: db-dynamodb
description: DynamoDB patterns with AWS SDK v3. Single-table design, access patterns, GSI design, repository pattern, pagination, testing.
---

# DynamoDB Integration Patterns

Production-ready patterns for AWS DynamoDB in Node.js/TypeScript applications using AWS SDK v3.

## Core Principles

1. **Access Patterns First**: Design based on queries, not entities
2. **Single-Table Design**: Store multiple entity types in one table
3. **Composite Keys**: PK + SK provide flexible querying
4. **GSI Strategy**: Use Global Secondary Indexes for alternate access patterns
5. **Denormalization**: Duplicate data to avoid joins

## AWS SDK v3 Client Configuration

### DocumentClient Setup

```typescript
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';

// Create base client
const client = new DynamoDBClient({
  region: process.env.AWS_REGION || 'us-east-1',
});

// Create DocumentClient with marshalling options
const dynamodb = DynamoDBDocumentClient.from(client, {
  marshallOptions: {
    removeUndefinedValues: true, // Remove undefined fields
    convertEmptyValues: false,   // Don't convert empty strings to null
  },
  unmarshallOptions: {
    wrapNumbers: false, // Return numbers as JS numbers (not BigInt)
  },
});
```

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

### Access Patterns Drive Design

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

## Repository Pattern

### Basic CRUD Operations

```typescript
class UserRepository {
  private tableName = process.env.USERS_TABLE!;

  async create(user: CreateUserInput): Promise<User> {
    const item = {
      PK: `USER#${user.id}`,
      SK: 'PROFILE',
      ...user,
      createdAt: new Date().toISOString(),
    };

    await dynamodb.send(
      new PutCommand({
        TableName: this.tableName,
        Item: item,
        ConditionExpression: 'attribute_not_exists(PK)', // Prevent overwrites
      })
    );

    return item;
  }

  async findById(userId: string): Promise<User | null> {
    const result = await dynamodb.send(
      new GetCommand({
        TableName: this.tableName,
        Key: {
          PK: `USER#${userId}`,
          SK: 'PROFILE',
        },
      })
    );

    return result.Item as User | null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const result = await dynamodb.send(
      new QueryCommand({
        TableName: this.tableName,
        IndexName: 'EmailIndex',
        KeyConditionExpression: 'email = :email',
        ExpressionAttributeValues: {
          ':email': email,
        },
        Limit: 1,
      })
    );

    return result.Items?.[0] as User | null;
  }

  async update(userId: string, updates: Partial<User>): Promise<User> {
    // Build update expression dynamically
    const updateExpression: string[] = [];
    const expressionAttributeNames: Record<string, string> = {};
    const expressionAttributeValues: Record<string, unknown> = {};

    Object.entries(updates).forEach(([key, value], index) => {
      updateExpression.push(`#${key} = :val${index}`);
      expressionAttributeNames[`#${key}`] = key;
      expressionAttributeValues[`:val${index}`] = value;
    });

    const result = await dynamodb.send(
      new UpdateCommand({
        TableName: this.tableName,
        Key: {
          PK: `USER#${userId}`,
          SK: 'PROFILE',
        },
        UpdateExpression: `SET ${updateExpression.join(', ')}`,
        ExpressionAttributeNames: expressionAttributeNames,
        ExpressionAttributeValues: expressionAttributeValues,
        ReturnValues: 'ALL_NEW',
      })
    );

    return result.Attributes as User;
  }
}
```

### One-to-Many Relationships

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

// Query all orders for user
async function getUserOrders(userId: string): Promise<Order[]> {
  const result = await dynamodb.send(
    new QueryCommand({
      TableName: 'app-table',
      KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
      ExpressionAttributeValues: {
        ':pk': `USER#${userId}`,
        ':sk': 'ORDER#',
      },
    })
  );

  return result.Items as Order[];
}

// GSI for reverse lookup (find user by order)
async function findUserByOrder(orderId: string): Promise<User | null> {
  const result = await dynamodb.send(
    new QueryCommand({
      TableName: 'app-table',
      IndexName: 'GSI1', // GSI1PK = ORDER#123, GSI1SK = USER#456
      KeyConditionExpression: 'GSI1PK = :pk',
      ExpressionAttributeValues: {
        ':pk': `ORDER#${orderId}`,
      },
    })
  );

  return result.Items?.[0] as User | null;
}
```

## Common Design Patterns

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

## Pagination

### Cursor-Based Pagination

```typescript
interface PaginatedResponse<T> {
  items: T[];
  nextToken?: string;
}

async function listUsers(limit = 20, nextToken?: string): Promise<PaginatedResponse<User>> {
  const result = await dynamodb.send(
    new QueryCommand({
      TableName: 'users-table',
      KeyConditionExpression: 'PK = :pk',
      ExpressionAttributeValues: { ':pk': 'USERS' },
      Limit: limit,
      ExclusiveStartKey: nextToken ? JSON.parse(Buffer.from(nextToken, 'base64').toString()) : undefined,
    })
  );

  return {
    items: result.Items as User[],
    nextToken: result.LastEvaluatedKey
      ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
      : undefined,
  };
}
```

### Pagination with LastEvaluatedKey

```typescript
type PaginationResult<T> = {
  items: T[];
  lastKey?: Record<string, any>;
};

async function listOrders(userId: string, lastKey?: Record<string, any>): Promise<PaginationResult<Order>> {
  const result = await dynamodb.send(
    new QueryCommand({
      TableName: 'app-table',
      KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
      ExpressionAttributeValues: {
        ':pk': `USER#${userId}`,
        ':sk': 'ORDER#',
      },
      Limit: 20,
      ExclusiveStartKey: lastKey,
    })
  );

  return {
    items: result.Items as Order[],
    lastKey: result.LastEvaluatedKey,
  };
}
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

## Conditional Writes

### Prevent Overwrites

```typescript
// ✅ Prevents overwrites
await dynamodb.send(
  new PutCommand({
    TableName: 'users',
    Item: user,
    ConditionExpression: 'attribute_not_exists(PK)',
  })
);
// Throws ConditionalCheckFailedException if item exists
```

### Optimistic Locking

```typescript
type VersionedItem = {
  PK: string;
  SK: string;
  version: number;
  data: unknown;
};

await dynamodb.send(
  new UpdateCommand({
    TableName: 'users',
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
  })
);
// Throws ConditionalCheckFailedException if version changed
```

## Error Handling

### Conditional Check Failures

```typescript
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb';

try {
  await dynamodb.send(
    new PutCommand({
      TableName: 'users',
      Item: user,
      ConditionExpression: 'attribute_not_exists(PK)',
    })
  );
} catch (error) {
  if (error instanceof ConditionalCheckFailedException) {
    throw new Error('User already exists');
  }
  throw error;
}
```

## Testing

### Mocking DynamoDB Client

```typescript
import { mockClient } from 'aws-sdk-client-mock';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

const dynamoMock = mockClient(DynamoDBDocumentClient);

beforeEach(() => {
  dynamoMock.reset();
});

test('fetches user by id', async () => {
  dynamoMock.on(GetCommand).resolves({
    Item: { PK: 'USER#123', SK: 'PROFILE', email: 'user@example.com' },
  });

  const user = await userRepo.findById('123');
  expect(user?.email).toBe('user@example.com');
});
```

## Anti-Patterns to Avoid

### Scans Instead of Queries

```typescript
// ❌ BAD: Scan entire table (expensive)
const result = await dynamodb.send(new ScanCommand({ TableName: 'users' }));

// ✅ GOOD: Query with partition key
const result = await dynamodb.send(
  new QueryCommand({
    TableName: 'users',
    KeyConditionExpression: 'PK = :pk',
    ExpressionAttributeValues: { ':pk': 'USER#123' },
  })
);

// ❌ BAD: Scan with filter
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

### Forgetting Condition Expressions

```typescript
// ❌ Overwrites existing data silently
await dynamodb.send(new PutCommand({ TableName: 'users', Item: user }));

// ✅ Prevents overwrites
await dynamodb.send(
  new PutCommand({
    TableName: 'users',
    Item: user,
    ConditionExpression: 'attribute_not_exists(PK)',
  })
);
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
