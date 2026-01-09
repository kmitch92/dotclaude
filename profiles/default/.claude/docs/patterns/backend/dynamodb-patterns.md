# DynamoDB Integration Patterns

## Overview
Production-ready patterns for AWS DynamoDB in Node.js/TypeScript applications using AWS SDK v3.

## DocumentClient Best Practices

### Client Configuration
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

## Single-Table Design Pattern

### Entity Modeling
```typescript
// Entity types in single table
type Entity =
  | { PK: `USER#${string}`; SK: 'PROFILE'; email: string; name: string }
  | { PK: `USER#${string}`; SK: `ORDER#${string}`; total: number; status: string }
  | { PK: `ORDER#${string}`; SK: 'METADATA'; userId: string; createdAt: string };

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

## Pagination Pattern

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

## Common Pitfalls

### Forgetting Condition Expressions
```typescript
// ❌ Overwrites existing data silently
await dynamodb.send(new PutCommand({ TableName: 'users', Item: user }));

// ✓ Prevents overwrites
await dynamodb.send(
  new PutCommand({
    TableName: 'users',
    Item: user,
    ConditionExpression: 'attribute_not_exists(PK)',
  })
);
```

### Inefficient Queries
```typescript
// ❌ Scan entire table (expensive)
const result = await dynamodb.send(new ScanCommand({ TableName: 'users' }));

// ✓ Query with partition key
const result = await dynamodb.send(
  new QueryCommand({
    TableName: 'users',
    KeyConditionExpression: 'PK = :pk',
    ExpressionAttributeValues: { ':pk': 'USER#123' },
  })
);
```

## Related
- [Database Design](database-design.md)
- [Testing Patterns](database-testing.md)
- [Database Optimization](../performance/database-optimization.md)
