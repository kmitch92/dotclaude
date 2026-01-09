# AWS Lambda Best Practices

Production-grade AWS Lambda patterns with TypeScript.

## Handler Pattern: Thin Handlers, Fat Services

Lambda handlers delegate to testable TypeScript services:

```typescript
// ✅ GOOD: Thin handler
// src/handlers/users/get.ts
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { getUserById } from '../../services/user-service';
import { errorResponse, successResponse } from '../../utils/responses';

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const userId = event.pathParameters?.id;
    if (!userId) return errorResponse(400, 'User ID required');

    const user = await getUserById(userId);
    if (!user) return errorResponse(404, 'User not found');

    return successResponse(200, user);
  } catch (error) {
    console.error('Error fetching user:', error);
    return errorResponse(500, 'Internal server error');
  }
};

// src/services/user-service.ts (Pure TypeScript - testable)
export async function getUserById(userId: string): Promise<User | null> {
  // Business logic here
}
```

**Why**: Business logic testable without Lambda runtime, clear separation, easier to migrate.

## Initialize Clients Outside Handler

**Most important Lambda optimization**: Initialize clients OUTSIDE handler for container reuse.

**Impact**: 200-500ms saved per warm invocation.

### AWS SDK Clients

```typescript
// ✅ GOOD: Initialize once per container
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event: APIGatewayProxyEvent) => {
  const result = await docClient.send(new GetCommand({
    TableName: 'Users',
    Key: { id: event.pathParameters?.id }
  }));
  return successResponse(200, result.Item);
};

// ❌ BAD: New client every invocation
export const handler = async (event: APIGatewayProxyEvent) => {
  const client = new DynamoDBClient({}); // Cold start penalty every time!
  // ...
};
```

### HTTP Clients

```typescript
// ✅ GOOD: HTTP client outside handler
import axios, { AxiosInstance } from 'axios';

const apiClient: AxiosInstance = axios.create({
  baseURL: 'https://api.example.com',
  timeout: 10000,
});

apiClient.interceptors.request.use((config) => {
  config.headers.Authorization = `Bearer ${process.env.API_TOKEN}`;
  return config;
});

export const handler = async (event: APIGatewayProxyEvent) => {
  const { data } = await apiClient.get('/users');
  return successResponse(200, data);
};
```

### Database Clients

```typescript
// DynamoDB
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

// Prisma (RDS)
import { PrismaClient } from '@prisma/client';

declare global {
  var prisma: PrismaClient | undefined;
}

export const prisma = global.prisma || new PrismaClient();
if (process.env.NODE_ENV !== 'production') global.prisma = prisma;
```

## Environment Variables

Load and validate at startup (global scope), fail fast if missing:

```typescript
// src/config/environment.ts
export const config = {
  tableName: process.env.TABLE_NAME!,
  region: process.env.AWS_REGION!,
  apiKey: process.env.API_KEY!,
} as const;

// Validate at startup
if (!config.tableName) throw new Error('TABLE_NAME required');
if (!config.apiKey) throw new Error('API_KEY required');
```

## Error Handling

### Custom Errors

```typescript
export class AppError extends Error {
  constructor(public statusCode: number, message: string, public details?: any) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: any) {
    super(400, message, details);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(404, `${resource} with id ${id} not found`);
  }
}
```

### Response Utilities

```typescript
export function errorResponse(
  statusCode: number,
  message: string,
  details?: any
): APIGatewayProxyResult {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ error: { code: getErrorCode(statusCode), message, details } }),
  };
}

export function successResponse<T>(statusCode: number, data: T): APIGatewayProxyResult {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ data }),
  };
}

function getErrorCode(statusCode: number): string {
  const codes: Record<number, string> = {
    400: 'BAD_REQUEST',
    401: 'UNAUTHORIZED',
    404: 'NOT_FOUND',
    500: 'INTERNAL_ERROR',
  };
  return codes[statusCode] || 'UNKNOWN_ERROR';
}
```

### Handler with Error Handling

```typescript
export const handler = async (event: APIGatewayProxyEvent, context: Context) => {
  try {
    const body = JSON.parse(event.body || '{}');
    const validatedInput = CreateUserSchema.parse(body);
    const user = await createUser(validatedInput);
    return successResponse(201, user);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return errorResponse(400, 'Validation error', error.errors);
    }
    if (error instanceof AppError) {
      return errorResponse(error.statusCode, error.message, error.details);
    }
    console.error('Unexpected error:', error);
    return errorResponse(500, 'Internal server error');
  }
};
```

## Structured Logging

```typescript
export class Logger {
  constructor(private context: { requestId: string }) {}

  info(message: string, data?: any) {
    console.log(JSON.stringify({
      level: 'INFO',
      message,
      ...this.context,
      ...data,
      timestamp: new Date().toISOString(),
    }));
  }

  error(message: string, error: any, data?: any) {
    console.error(JSON.stringify({
      level: 'ERROR',
      message,
      error: { name: error.name, message: error.message, stack: error.stack },
      ...this.context,
      ...data,
      timestamp: new Date().toISOString(),
    }));
  }
}

// Usage
export const handler = async (event: APIGatewayProxyEvent, context: Context) => {
  const logger = new Logger({ requestId: context.requestId });
  logger.info('Request received', { path: event.path });
  // ...
};
```

## Cold Start Optimization

### Minimize Package Size

```typescript
// ❌ BAD: Entire SDK
import * as AWS from 'aws-sdk';

// ✅ GOOD: Only needed clients
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';
```

### Lazy Load Heavy Dependencies

```typescript
export const handler = async (event: APIGatewayProxyEvent) => {
  if (event.path === '/export-pdf') {
    const { generatePDF } = await import('./utils/pdf-generator');
    const pdf = await generatePDF(data);
    return successResponse(200, pdf);
  }
  // Normal path doesn't pay for PDF library
};
```

## Complete Production Example

```typescript
// src/handlers/users/create.ts
import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { z } from 'zod';
import { Logger } from '../../utils/logger';
import { errorResponse, successResponse } from '../../utils/responses';
import { config } from '../../config/environment';

// Initialize outside handler
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const CreateUserSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100),
  role: z.enum(['user', 'admin', 'moderator']),
});

type CreateUserInput = z.infer<typeof CreateUserSchema>;

export const handler = async (
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> => {
  const logger = new Logger({ requestId: context.requestId });
  logger.info('Create user request');

  try {
    const body = JSON.parse(event.body || '{}');
    const input = CreateUserSchema.parse(body);

    const existingUser = await getUserByEmail(input.email);
    if (existingUser) {
      return errorResponse(409, 'User with this email exists');
    }

    const user = await createUser(input);
    logger.info('User created', { userId: user.id });
    return successResponse(201, user);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return errorResponse(400, 'Validation error', error.errors);
    }
    logger.error('Failed to create user', error);
    return errorResponse(500, 'Internal server error');
  }
};

async function createUser(input: CreateUserInput) {
  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  const user = {
    id,
    ...input,
    status: 'active',
    createdAt: now,
    updatedAt: now,
  };

  await docClient.send(new PutCommand({
    TableName: config.tableName,
    Item: user,
    ConditionExpression: 'attribute_not_exists(id)',
  }));

  return user;
}

async function getUserByEmail(email: string) {
  // Implementation
}
```

## Key Takeaways

1. **Initialize clients outside handler** - Most important optimization
2. **Thin handlers, fat services** - Business logic in testable services
3. **Validate environment at startup** - Fail fast if config missing
4. **Structured logging** - JSON logs for CloudWatch Insights
5. **Standard error responses** - Consistent format
6. **Minimize bundle size** - Only import needed AWS SDK v3 clients
7. **Type safety end-to-end** - Zod for runtime, TypeScript for compile-time
