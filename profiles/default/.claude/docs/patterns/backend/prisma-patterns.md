# Prisma/RDS Integration Patterns

## Overview
Production-ready patterns for Prisma ORM with PostgreSQL/MySQL in Node.js/TypeScript applications.

## Connection Management

### Singleton Pattern
```typescript
import { PrismaClient } from '@prisma/client';

// Singleton pattern for connection reuse
declare global {
  var prisma: PrismaClient | undefined;
}

export const prisma = global.prisma || new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
});

if (process.env.NODE_ENV !== 'production') {
  global.prisma = prisma;
}

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect();
});
```

### Lambda Connection Handling
```typescript
// Create client outside handler (reused across warm invocations)
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
});

export const handler = async (event: APIGatewayEvent) => {
  try {
    // Use existing connection
    const users = await prisma.user.findMany();
    return { statusCode: 200, body: JSON.stringify(users) };
  } catch (error) {
    console.error(error);
    return { statusCode: 500, body: JSON.stringify({ error: 'Internal error' }) };
  }
  // Don't disconnect (reuse connection on next invocation)
};
```

## Repository Pattern

### Type-Safe Repository
```typescript
import { PrismaClient, User, Prisma } from '@prisma/client';

export class UserRepository {
  constructor(private prisma: PrismaClient) {}

  async create(data: Prisma.UserCreateInput): Promise<User> {
    return this.prisma.user.create({ data });
  }

  async findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async update(id: string, data: Prisma.UserUpdateInput): Promise<User> {
    return this.prisma.user.update({
      where: { id },
      data,
    });
  }

  async delete(id: string): Promise<void> {
    await this.prisma.user.delete({ where: { id } });
  }

  async findMany(params: {
    skip?: number;
    take?: number;
    where?: Prisma.UserWhereInput;
    orderBy?: Prisma.UserOrderByWithRelationInput;
  }): Promise<User[]> {
    return this.prisma.user.findMany(params);
  }
}

// Usage with dependency injection
const userRepo = new UserRepository(prisma);
const user = await userRepo.findByEmail('user@example.com');
```

## Transaction Pattern

### ACID Transactions
```typescript
// Transfer funds between accounts
async function transferFunds(fromId: string, toId: string, amount: number): Promise<void> {
  await prisma.$transaction(async (tx) => {
    // Deduct from sender
    const sender = await tx.account.update({
      where: { id: fromId },
      data: { balance: { decrement: amount } },
    });

    // Verify sufficient funds
    if (sender.balance < 0) {
      throw new Error('Insufficient funds');
    }

    // Add to recipient
    await tx.account.update({
      where: { id: toId },
      data: { balance: { increment: amount } },
    });

    // Record transaction
    await tx.transaction.create({
      data: {
        fromAccountId: fromId,
        toAccountId: toId,
        amount,
        type: 'TRANSFER',
      },
    });
  });
  // All operations succeed or all fail
}
```

## Optimistic Locking

### Version Field Pattern
```typescript
// Prevent lost updates with version field
// schema.prisma
// model Post {
//   id      String @id @default(uuid())
//   title   String
//   version Int    @default(0)
// }

async function updatePost(id: string, title: string, currentVersion: number): Promise<Post> {
  const updated = await prisma.post.updateMany({
    where: {
      id,
      version: currentVersion, // Only update if version matches
    },
    data: {
      title,
      version: { increment: 1 },
    },
  });

  if (updated.count === 0) {
    throw new Error('Post was modified by another user');
  }

  return prisma.post.findUnique({ where: { id } })!;
}
```

## Migration Strategy

### Deployment Pipeline Integration
```typescript
// Run migrations in CI/CD, not in application code

// package.json scripts
{
  "scripts": {
    "prisma:generate": "prisma generate",
    "prisma:migrate:dev": "prisma migrate dev",
    "prisma:migrate:deploy": "prisma migrate deploy",
    "prisma:studio": "prisma studio"
  }
}

// Deploy migrations in CD pipeline
// .github/workflows/deploy.yml
// - name: Run migrations
//   run: npm run prisma:migrate:deploy
```

## Error Handling

### Prisma-Specific Errors
```typescript
import { Prisma } from '@prisma/client';

try {
  await prisma.user.create({ data: { email: 'user@example.com' } });
} catch (error) {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    // Unique constraint violation
    if (error.code === 'P2002') {
      throw new Error('Email already exists');
    }
    // Record not found
    if (error.code === 'P2025') {
      throw new Error('User not found');
    }
  }
  throw error;
}
```

## Performance Monitoring

### Query Logging
```typescript
// Prisma query logging
const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'query' },
    { emit: 'event', level: 'error' },
  ],
});

prisma.$on('query', (e) => {
  if (e.duration > 1000) {
    logger.warn('Slow query detected', {
      query: e.query,
      duration: e.duration,
      params: e.params,
    });
  }
});
```

### Connection Pool Monitoring
```typescript
// Monitor Prisma connection pool
setInterval(() => {
  const metrics = prisma.$metrics.json();
  logger.info('Database metrics', {
    activeConnections: metrics.counters.find(c => c.key === 'prisma_client_queries_active')?.value,
    totalConnections: metrics.counters.find(c => c.key === 'prisma_client_queries_total')?.value,
  });
}, 60000); // Every minute
```

## Common Pitfalls

### N+1 Queries
```typescript
// ❌ N+1 query problem
const users = await prisma.user.findMany();
for (const user of users) {
  user.posts = await prisma.post.findMany({ where: { authorId: user.id } });
}

// ✓ Eager loading
const users = await prisma.user.findMany({
  include: { posts: true },
});
```

### Connection Leaks
```typescript
// ❌ Creates new connection every time
export const handler = async () => {
  const prisma = new PrismaClient(); // Leak!
  const users = await prisma.user.findMany();
  return { statusCode: 200, body: JSON.stringify(users) };
};

// ✓ Reuse connection across invocations
const prisma = new PrismaClient();

export const handler = async () => {
  const users = await prisma.user.findMany();
  return { statusCode: 200, body: JSON.stringify(users) };
};
```

### Missing Error Handling
```typescript
// ❌ Unhandled database errors crash application
const user = await prisma.user.create({ data: { email } });

// ✓ Handle specific errors
try {
  const user = await prisma.user.create({ data: { email } });
} catch (error) {
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
    throw new ConflictError('Email already exists');
  }
  throw new InternalServerError('Database error');
}
```

## Testing

### In-Memory Database
```typescript
// Use SQLite in-memory for tests
// prisma/schema.test.prisma
datasource db {
  provider = "sqlite"
  url      = "file::memory:?cache=shared"
}

// Test setup
import { PrismaClient } from '@prisma/client';

let prisma: PrismaClient;

beforeAll(async () => {
  prisma = new PrismaClient();
  await prisma.$executeRaw`PRAGMA foreign_keys = ON`;
});

afterAll(async () => {
  await prisma.$disconnect();
});

beforeEach(async () => {
  // Clear all tables
  const tables = await prisma.$queryRaw<{ name: string }[]>`
    SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
  `;

  for (const { name } of tables) {
    await prisma.$executeRawUnsafe(`DELETE FROM ${name}`);
  }
});
```

### Integration Tests with Testcontainers
```typescript
import { GenericContainer, StartedTestContainer } from 'testcontainers';
import { PrismaClient } from '@prisma/client';

let container: StartedTestContainer;
let prisma: PrismaClient;

beforeAll(async () => {
  // Start PostgreSQL container
  container = await new GenericContainer('postgres:15')
    .withEnvironment({
      POSTGRES_USER: 'test',
      POSTGRES_PASSWORD: 'test',
      POSTGRES_DB: 'test',
    })
    .withExposedPorts(5432)
    .start();

  const connectionString = `postgresql://test:test@${container.getHost()}:${container.getMappedPort(5432)}/test`;

  prisma = new PrismaClient({
    datasources: { db: { url: connectionString } },
  });

  // Run migrations
  await exec(`DATABASE_URL="${connectionString}" npx prisma migrate deploy`);
}, 60000);

afterAll(async () => {
  await prisma.$disconnect();
  await container.stop();
});
```

## Related
- [Database Design](database-design.md)
- [Testing Patterns](database-testing.md)
- [Database Optimization](../performance/database-optimization.md)
