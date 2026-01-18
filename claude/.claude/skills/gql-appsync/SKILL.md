---
name: gql-appsync
description: AWS AppSync GraphQL patterns. CDK constructs, Lambda resolvers, Cognito/IAM auth, multi-tenant scoping, response sanitization, Relay pagination.
---

# AWS AppSync GraphQL Patterns

Production-ready patterns for AWS AppSync with CDK and Lambda resolvers.

## Core Principles

1. **Schema-First**: Define GraphQL schema before implementation
2. **Multi-Tenant Isolation**: Extract tenant context from JWT claims, scope all queries
3. **Response Sanitization**: Never expose internal keys (PK, SK, GSI*) to clients
4. **Auth Layering**: Cognito for users, IAM for service-to-service
5. **Relay Pagination**: Use connection types for lists

## AppSync Constraints

| Constraint | Limit |
|------------|-------|
| Resolver timeout | 30 seconds |
| Response payload | 1 MB |
| Request payload | 1 MB |
| Nested depth | 10 levels |
| Subscriptions per connection | 100 |

## CDK AppSync Construct

### Basic Setup

```typescript
// ✅ GOOD: Complete AppSync construct pattern
import * as appsync from 'aws-cdk-lib/aws-appsync';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as lambda from 'aws-cdk-lib/aws-lambda-nodejs';
import { Construct } from 'constructs';

interface AppSyncConstructProps {
  readonly userPool: cognito.IUserPool;
  readonly schemaPath: string;
  readonly resolverLambda: lambda.NodejsFunction;
}

export class ServiceAppSyncConstruct extends Construct {
  public readonly api: appsync.GraphqlApi;

  constructor(scope: Construct, id: string, props: AppSyncConstructProps) {
    super(scope, id);

    this.api = new appsync.GraphqlApi(this, 'Api', {
      name: `${id}-api`,
      definition: appsync.Definition.fromFile(props.schemaPath),
      authorizationConfig: {
        defaultAuthorization: {
          authorizationType: appsync.AuthorizationType.USER_POOL,
          userPoolConfig: { userPool: props.userPool },
        },
        additionalAuthorizationModes: [
          { authorizationType: appsync.AuthorizationType.IAM },
        ],
      },
      logConfig: { fieldLogLevel: appsync.FieldLogLevel.ERROR },
      xrayEnabled: true,
    });

    const lambdaDataSource = this.api.addLambdaDataSource(
      'LambdaDataSource',
      props.resolverLambda
    );

    this.attachResolvers(lambdaDataSource);
  }

  private attachResolvers(dataSource: appsync.LambdaDataSource): void {
    dataSource.createResolver('GetItemResolver', {
      typeName: 'Query',
      fieldName: 'getItem',
    });
    dataSource.createResolver('ListItemsResolver', {
      typeName: 'Query',
      fieldName: 'listItems',
    });
    dataSource.createResolver('CreateItemResolver', {
      typeName: 'Mutation',
      fieldName: 'createItem',
    });
  }
}
```

## Lambda Resolver Pattern

### Handler Structure

```typescript
// ✅ GOOD: Lambda resolver with field routing
import { AppSyncResolverHandler } from 'aws-lambda';
import { extractTenantContext, TenantContext } from './auth';

export const handler: AppSyncResolverHandler<any, any> = async (event) => {
  const { fieldName } = event.info;
  const tenant = extractTenantContext(event);

  switch (fieldName) {
    case 'getItem':
      return getItem(event.arguments, tenant);
    case 'listItems':
      return listItems(event.arguments, tenant);
    case 'createItem':
      return createItem(event.arguments.input, tenant);
    default:
      throw new Error(`Unknown field: ${fieldName}`);
  }
};
```

### Multi-Tenant Context Extraction

```typescript
// ✅ GOOD: Extract tenant context from JWT claims
export interface TenantContext {
  companyId: string;
  userId: string;
  userGroups: string[];
}

export function extractTenantContext(event: any): TenantContext {
  const claims = event.identity?.claims;

  if (!claims) {
    throw new Error('Unauthorized: No identity claims');
  }

  const companyId = claims['custom:companyId'];
  if (!companyId) {
    throw new Error('Unauthorized: Missing companyId claim');
  }

  return {
    companyId,
    userId: claims.sub,
    userGroups: claims['cognito:groups'] || [],
  };
}

// ❌ BAD: Hardcoded tenant
export function extractTenantContextBad() {
  return { companyId: 'default-company' }; // Never hardcode!
}
```

## Response Sanitization

```typescript
// ✅ GOOD: Remove DynamoDB internal keys before returning
const INTERNAL_KEYS = ['PK', 'SK', 'GSI1PK', 'GSI1SK', 'GSI2PK', 'GSI2SK'] as const;

export function sanitizeEntity<T extends Record<string, any>>(
  entity: T
): Omit<T, typeof INTERNAL_KEYS[number]> {
  const sanitized = { ...entity };
  for (const key of INTERNAL_KEYS) {
    delete sanitized[key];
  }
  return sanitized;
}

// For arrays
export function sanitizeEntities<T extends Record<string, any>>(
  entities: T[]
): Omit<T, typeof INTERNAL_KEYS[number]>[] {
  return entities.map(sanitizeEntity);
}

// ❌ BAD: Exposing internal keys
export async function getItemBad(id: string) {
  const result = await dynamodb.send(new GetCommand({ ... }));
  return result.Item; // Exposes PK, SK, GSI keys!
}
```

## Relay-Style Pagination

```typescript
// ✅ GOOD: Connection types with cursor pagination
export async function listItems(
  args: { limit?: number; nextToken?: string },
  tenant: TenantContext
): Promise<ItemConnection> {
  const limit = Math.min(args.limit || 20, 100); // Cap at 100

  const result = await dynamodb.send(
    new QueryCommand({
      TableName: process.env.TABLE_NAME!,
      KeyConditionExpression: 'PK = :pk',
      ExpressionAttributeValues: {
        ':pk': `COMPANY#${tenant.companyId}`,
      },
      Limit: limit,
      ExclusiveStartKey: args.nextToken
        ? JSON.parse(Buffer.from(args.nextToken, 'base64url').toString())
        : undefined,
    })
  );

  return {
    items: sanitizeEntities(result.Items || []),
    nextToken: result.LastEvaluatedKey
      ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64url')
      : undefined,
  };
}

// ❌ BAD: Unbounded query
export async function listItemsBad() {
  const result = await dynamodb.send(new ScanCommand({ ... }));
  return { items: result.Items }; // No limit, no tenant scoping!
}
```

## Error Handling

```typescript
// ✅ GOOD: Typed GraphQL errors
class GraphQLError extends Error {
  constructor(
    message: string,
    public readonly errorType: string,
    public readonly errorInfo?: Record<string, any>
  ) {
    super(message);
  }
}

export class NotFoundError extends GraphQLError {
  constructor(resource: string, id: string) {
    super(`${resource} with id ${id} not found`, 'NotFoundError', {
      code: 'NOT_FOUND', resource, id,
    });
  }
}

export class UnauthorizedError extends GraphQLError {
  constructor(message = 'Not authorized') {
    super(message, 'UnauthorizedError', { code: 'UNAUTHORIZED' });
  }
}
```

## Schema-Level Auth Directives

```graphql
type Query {
  # Both Cognito users and IAM roles
  getItem(id: ID!): Item @aws_cognito_user_pools @aws_iam

  # Admin group only
  listAllItems: ItemConnection! @aws_cognito_user_pools(cognito_groups: ["Admins"])
}

type Mutation {
  # Authenticated users
  createItem(input: CreateItemInput!): Item! @aws_cognito_user_pools

  # Service-to-service only
  syncItems(input: [SyncItemInput!]!): [Item!]! @aws_iam
}
```

## Design Checklist

- [ ] CDK construct with Cognito + IAM auth configured
- [ ] Lambda resolver with field routing switch
- [ ] Tenant context extracted from JWT claims
- [ ] All queries scoped to tenant companyId
- [ ] Response sanitization removes PK, SK, GSI* keys
- [ ] Relay-style pagination with Connection types
- [ ] Limits capped (max 100 per page)
- [ ] Error handling with typed GraphQL errors
- [ ] X-Ray tracing enabled

## Key Takeaways

1. **Always scope**: Every query must include tenant context
2. **Sanitize responses**: Never expose DynamoDB internal keys
3. **Dual auth**: Cognito for users, IAM for services
4. **Paginate**: Use Connection types, cap limits at 100
5. **Handle errors**: Return structured GraphQL errors
