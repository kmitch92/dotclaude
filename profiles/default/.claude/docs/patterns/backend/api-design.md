# REST API Design Patterns

## Core Principles

1. **Contract-First**: Design API contract before implementation
2. **Consistency**: Uniform patterns across endpoints
3. **Resource-Oriented**: Model domain entities as resources
4. **Versioning**: Plan for evolution from start
5. **Self-Documenting**: Clear, predictable structure

## Resource Naming

```
✅ GOOD: Plural nouns, clean structure
GET    /api/users
GET    /api/users/:id
POST   /api/users
PATCH  /api/users/:id
DELETE /api/users/:id
GET    /api/users/:userId/orders

❌ BAD: Verbs in URLs
GET    /api/getUsers
POST   /api/createUser

❌ BAD: Deep nesting (max 2 levels)
GET    /api/users/:userId/orders/:orderId/items/:itemId/reviews
```

**Rule**: Resources are nouns (plural), actions are HTTP methods.

## HTTP Methods

| Method | Purpose | Idempotent | Returns |
|--------|---------|------------|---------|
| GET | Retrieve | Yes | Resource(s) |
| POST | Create | No | 201 + resource |
| PUT | Full replace | Yes | Updated resource |
| PATCH | Partial update | Yes | Updated resource |
| DELETE | Remove | Yes | 204 No Content |

## Request Schemas

```typescript
import { z } from "zod";

// GET /api/users - Query parameters
const ListUsersQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  sort: z.enum(["createdAt", "name"]).default("createdAt"),
  order: z.enum(["asc", "desc"]).default("desc"),
  status: z.enum(["active", "suspended"]).optional(),
  search: z.string().max(100).optional(),
});

// POST /api/users - Request body
const CreateUserRequestSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100),
  role: z.enum(["user", "admin"]),
});

// PATCH /api/users/:id - Partial update
const UpdateUserRequestSchema = CreateUserRequestSchema.partial();
```

## Response Schemas

### Single Resource
```typescript
type UserResponse = {
  id: string;
  email: string;
  name: string;
  role: "user" | "admin";
  createdAt: string;  // ISO 8601
  updatedAt: string;
};

// Example
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "user",
    "createdAt": "2025-01-15T10:30:00Z",
    "updatedAt": "2025-01-15T10:30:00Z"
};
```

### Examples
```javascript
// 400 Bad Request - Validation error
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ],
    "timestamp": "2025-01-15T10:30:00Z"
  }
}

// 409 Conflict
{
  "error": {
    "code": "RESOURCE_CONFLICT",
    "message": "User with this email already exists",
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

## HTTP Status Codes

### Success
```
200 OK              GET, PATCH successful
201 Created         POST successful + Location header
204 No Content      DELETE successful
```

### Client Errors
```
400 Bad Request     Invalid input, validation failed
401 Unauthorized    Missing/invalid auth token
403 Forbidden       Valid auth, insufficient permissions
404 Not Found       Resource doesn't exist
409 Conflict        Resource conflict (duplicate, version)
422 Unprocessable   Semantic validation error
429 Too Many Requests Rate limit exceeded
```

### Server Errors
```
500 Internal Error  Unexpected server error
502 Bad Gateway     Upstream service error
503 Service Unavailable Temporary outage
```

See [HTTP Status Codes](../../references/http-status-codes.md) for detailed guide.

## Versioning

### URL Versioning (Recommended)
```
GET /api/v1/users
GET /api/v2/users

Pros: Clear, easy to route/test
Cons: Multiple codebases
```

### Breaking vs Non-Breaking

**Non-Breaking (same version):**
- Adding optional fields
- Adding response fields
- Adding new endpoints

**Breaking (new version):**
- Removing fields
- Renaming fields
- Changing field types
- Making optional fields required

## Pagination

### Offset-Based (Simpler)
```typescript
type OffsetPaginationQuery = {
  page?: number;    // 1-indexed
  limit?: number;
};

  order: z.enum(["asc", "desc"]).default("desc"),
  search: z.string().max(100).optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});
```

## Authentication

### Bearer Token (Recommended)
```
GET /api/users
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

401 Unauthorized    No/invalid token
403 Forbidden       Valid token, insufficient permissions
```

### API Key (Service-to-Service)
```
GET /api/users
X-API-Key: sk_live_abc123...
```

## Rate Limiting

### Headers
```
HTTP/1.1 200 OK
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 998
X-RateLimit-Reset: 1642435200
```

### Exceeded Response
```
HTTP/1.1 429 Too Many Requests
Retry-After: 60

{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Try again in 60 seconds",
    "retryAfter": 60
  }
}
```

## Complete Handler Example
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Request validation failed',
            details: error.errors,
          },
        }),
      };
    }

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: {
          code: 'INTERNAL_ERROR',
          message: 'An unexpected error occurred',
        },
      }),
    };
  }
};
```

## Design Checklist

- [ ] Plural noun resources
- [ ] HTTP methods used correctly
- [ ] Request/response schemas with Zod
- [ ] Standard error responses
- [ ] Appropriate status codes
- [ ] Pagination implemented
- [ ] Filtering, sorting, search
- [ ] Versioning strategy
- [ ] Auth/authz requirements
- [ ] Rate limiting configured
- [ ] Backward compatibility considered

## Key Takeaways

1. **Resource-oriented**: Plural nouns, HTTP methods for actions
2. **Validate everything**: Use Zod for request validation
3. **Consistent structure**: Same patterns across endpoints
4. **Standard errors**: Consistent error format
5. **Version carefully**: Breaking changes require new version
6. **Security first**: Auth, authz, rate limiting from day one

## Related
- [Database Design](database-design.md)
- [Lambda Patterns](lambda-patterns.md)
- [Security Patterns](../security/authentication.md)
- [HTTP Status Codes](../../references/http-status-codes.md)
