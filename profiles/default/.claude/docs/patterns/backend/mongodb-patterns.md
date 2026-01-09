# MongoDB Integration Patterns

## Overview
Production-ready patterns for MongoDB in Node.js/TypeScript applications using native driver.

## Connection Pooling

### Lambda Connection Reuse
```typescript
import { MongoClient, Db } from 'mongodb';

let cachedDb: Db | null = null;

async function connectToDatabase(): Promise<Db> {
  if (cachedDb) {
    return cachedDb;
  }

  const client = await MongoClient.connect(process.env.MONGODB_URI!, {
    maxPoolSize: 10,
    minPoolSize: 2,
    maxIdleTimeMS: 30000,
    serverSelectionTimeoutMS: 5000,
  });

  cachedDb = client.db('myapp');
  return cachedDb;
}

// Usage in Lambda
export const handler = async (event: APIGatewayEvent) => {
  const db = await connectToDatabase(); // Reuses connection
  const users = await db.collection('users').find().toArray();
  return { statusCode: 200, body: JSON.stringify(users) };
};
```

## Type-Safe Collections

### Repository Pattern
```typescript
import { Collection, ObjectId } from 'mongodb';

interface User {
  _id?: ObjectId;
  email: string;
  name: string;
  createdAt: Date;
}

class UserRepository {
  private collection: Collection<User>;

  constructor(db: Db) {
    this.collection = db.collection<User>('users');
  }

  async create(user: Omit<User, '_id'>): Promise<User> {
    const result = await this.collection.insertOne(user);
    return { ...user, _id: result.insertedId };
  }

  async findById(id: string): Promise<User | null> {
    return this.collection.findOne({ _id: new ObjectId(id) });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.collection.findOne({ email });
  }

  async update(id: string, updates: Partial<User>): Promise<void> {
    await this.collection.updateOne(
      { _id: new ObjectId(id) },
      { $set: updates }
    );
  }

  async delete(id: string): Promise<void> {
    await this.collection.deleteOne({ _id: new ObjectId(id) });
  }
}
```

## Index Management

### Idempotent Index Creation
```typescript
// Create indexes at startup (idempotent)
async function ensureIndexes(db: Db): Promise<void> {
  const users = db.collection('users');

  await users.createIndex({ email: 1 }, { unique: true });
  await users.createIndex({ createdAt: -1 });
  await users.createIndex({ 'profile.location': 1 }, { sparse: true });

  // Compound index
  await users.createIndex({ status: 1, createdAt: -1 });

  // Text search index
  await users.createIndex({ name: 'text', bio: 'text' });
}
```

## Error Handling

### Duplicate Key Errors
```typescript
import { MongoError } from 'mongodb';

try {
  await collection.insertOne(user);
} catch (error) {
  if (error instanceof MongoError) {
    // Duplicate key error
    if (error.code === 11000) {
      throw new Error('Email already exists');
    }
  }
  throw error;
}
```

## Common Pitfalls

### ObjectId Conversion
```typescript
// ❌ String comparison doesn't work
const user = await collection.findOne({ _id: '507f1f77bcf86cd799439011' });

// ✓ Convert to ObjectId
const user = await collection.findOne({ _id: new ObjectId('507f1f77bcf86cd799439011') });
```

### Missing Indexes
```typescript
// ❌ Slow query without index
const users = await collection.find({ email: 'user@example.com' }).toArray();

// ✓ Create index first
await collection.createIndex({ email: 1 }, { unique: true });
const users = await collection.find({ email: 'user@example.com' }).toArray();
```

## Related
- [Database Design](database-design.md)
- [Testing Patterns](database-testing.md)
- [Database Optimization](../performance/database-optimization.md)
