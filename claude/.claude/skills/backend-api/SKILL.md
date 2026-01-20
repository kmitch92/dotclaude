---
name: backend-api
description: REST API design patterns. Resource naming, HTTP methods, Zod request/response schemas, versioning, pagination, error handling, status codes.
---

# Backend API Design

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
  }
}
```

### Error Responses
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

### Quick Reference

| Code | Name | Use Case |
|------|------|----------|
| **2xx Success** |
| 200 | OK | GET, PATCH successful (returns data) |
| 201 | Created | POST successful (+ Location header) |
| 204 | No Content | DELETE, PUT, PATCH (no data returned) |
| **4xx Client Errors** |
| 400 | Bad Request | Invalid input/validation error |
| 401 | Unauthorized | Missing/invalid authentication |
| 403 | Forbidden | Valid auth, insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Resource conflict (duplicate, version mismatch) |
| 422 | Unprocessable | Semantic validation error |
| 429 | Too Many Requests | Rate limit exceeded |
| **5xx Server Errors** |
| 500 | Internal Error | Unexpected server error |
| 502 | Bad Gateway | Upstream service error |
| 503 | Service Unavailable | Temporary outage/maintenance |

### Success Codes (2xx)

**200 OK** - GET requests, PUT/PATCH with response data
```typescript
app.get('/users/:id', async (req, res) => {
  const user = await db.user.findUnique({ where: { id: req.params.id } });
  if (!user) return res.status(404).json({ error: 'Not found' });
  res.status(200).json(user);
});
```

**201 Created** - POST creating resources. Include `Location` header.
```typescript
app.post('/users', async (req, res) => {
  const user = await db.user.create({ data: req.body });
  res.status(201).location(`/users/${user.id}`).json(user);
});
```

**204 No Content** - DELETE, PUT/PATCH with no response body
```typescript
app.delete('/users/:id', async (req, res) => {
  await db.user.delete({ where: { id: req.params.id } });
  res.status(204).send();
});
```

### Client Error Codes (4xx)

**400 Bad Request** - Invalid format, validation errors
```typescript
app.post('/users', async (req, res) => {
  try {
    const validated = CreateUserSchema.parse(req.body);
    const user = await db.user.create({ data: validated });
    res.status(201).json(user);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request data',
          details: error.errors,
        },
      });
    }
    throw error;
  }
});
```

**401 Unauthorized** - Missing/invalid authentication
```typescript
app.use((req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token || !verifyToken(token)) {
    return res.status(401).json({
      error: { code: 'UNAUTHORIZED', message: 'Invalid token' },
    });
  }
  next();
});
```

**403 Forbidden** - Valid auth, insufficient permissions
```typescript
app.delete('/users/:id', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin' && req.user.id !== req.params.id) {
    return res.status(403).json({
      error: { code: 'FORBIDDEN', message: 'Insufficient permissions' },
    });
  }
  await db.user.delete({ where: { id: req.params.id } });
  res.status(204).send();
});
```

**404 Not Found** - Resource doesn't exist
```typescript
app.get('/users/:id', async (req, res) => {
  const user = await db.user.findUnique({ where: { id: req.params.id } });
  if (!user) {
    return res.status(404).json({
      error: { code: 'NOT_FOUND', message: 'User not found' },
    });
  }
  res.json(user);
});
```

**409 Conflict** - Duplicate resources, version conflicts, business rule violations
```typescript
app.post('/users', async (req, res) => {
  const existing = await db.user.findUnique({ where: { email: req.body.email } });
  if (existing) {
    return res.status(409).json({
      error: { code: 'DUPLICATE_EMAIL', message: 'Email already exists' },
    });
  }
  const user = await db.user.create({ data: req.body });
  res.status(201).json(user);
});
```

**422 Unprocessable Entity** - Valid format, but semantic/business logic errors

**Difference from 400:**
- 400: Syntax error (malformed JSON, wrong types)
- 422: Semantic error (valid format, violates business rules)

```typescript
app.post('/orders', async (req, res) => {
  const order = OrderSchema.parse(req.body); // Format valid

  // Semantic validation
  if (order.quantity > product.stock) {
    return res.status(422).json({
      error: {
        code: 'INSUFFICIENT_STOCK',
        message: 'Not enough items in stock',
        details: [{ field: 'quantity', message: `Only ${product.stock} available` }],
      },
    });
  }

  const created = await db.order.create({ data: order });
  res.status(201).json(created);
});
```

**429 Too Many Requests** - Rate limit exceeded. Include `Retry-After` header.
```typescript
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 100,
  handler: (req, res) => {
    res.status(429)
      .setHeader('Retry-After', 60)
      .json({
        error: {
          code: 'RATE_LIMIT_EXCEEDED',
          message: 'Try again in 60 seconds',
          retryAfter: 60,
        },
      });
  },
}));
```

### Server Error Codes (5xx)

**500 Internal Server Error** - Unexpected server errors. Log details server-side, return generic message.
```typescript
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { error: err, requestId: req.id });

  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
      requestId: req.id,
    },
  });
});
```

**502 Bad Gateway** - Upstream service returned invalid response
```typescript
app.get('/external-data', async (req, res) => {
  try {
    const response = await fetch('https://external-api.com/data');
    if (!response.ok) {
      return res.status(502).json({
        error: { code: 'BAD_GATEWAY', message: 'Upstream service error' },
      });
    }
    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(502).json({
      error: { code: 'BAD_GATEWAY', message: 'Upstream service failed' },
    });
  }
});
```

**503 Service Unavailable** - Temporary unavailability. Include `Retry-After` header.
```typescript
app.use((req, res, next) => {
  if (isMaintenanceMode()) {
    return res.status(503)
      .setHeader('Retry-After', 3600) // 1 hour
      .json({
        error: {
          code: 'SERVICE_UNAVAILABLE',
          message: 'Maintenance in progress',
          retryAfter: 3600,
        },
      });
  }
  next();
});
```

### Status Code Decision Tree

```
Request received
  ↓
Authentication valid?
  NO → 401 Unauthorized
  YES → Continue
  ↓
Permissions sufficient?
  NO → 403 Forbidden
  YES → Continue
  ↓
Resource exists?
  NO → 404 Not Found
  YES → Continue
  ↓
Request format valid?
  NO → 400 Bad Request
  YES → Continue
  ↓
Business rules satisfied?
  NO → 422 Unprocessable (or 409 Conflict)
  YES → Continue
  ↓
Operation successful?
  NO → 500 Internal Error (or 502/503 if upstream)
  YES → Continue
  ↓
Response type:
  - Created resource → 201 Created
  - Updated/retrieved → 200 OK
  - Deleted/no content → 204 No Content
```

### Common Mistakes

**Using 200 for Errors**
```typescript
// ❌ BAD
res.status(200).json({ success: false, error: 'User not found' });

// ✓ GOOD
res.status(404).json({ error: { code: 'NOT_FOUND', message: 'User not found' } });
```

**Using 400 for Business Logic Errors**
```typescript
// ❌ BAD (use 422 for semantic errors)
res.status(400).json({ error: 'Insufficient stock' });

// ✓ GOOD
res.status(422).json({ error: { code: 'INSUFFICIENT_STOCK', message: 'Not enough items' } });
```

**Confusing 401 and 403**
```typescript
// 401: Authentication problem (who are you?)
res.status(401).json({ error: 'Invalid credentials' });

// 403: Authorization problem (you can't do this)
res.status(403).json({ error: 'Insufficient permissions' });
```

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

const ListUsersQuerySchema = z.object({
  sort: z.enum(["createdAt", "name"]).default("createdAt"),
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
4. **Standard errors**: Consistent error format with proper status codes
5. **Version carefully**: Breaking changes require new version
6. **Security first**: Auth, authz, rate limiting from day one
7. **Status codes matter**: Use correct codes (401 vs 403, 400 vs 422)
