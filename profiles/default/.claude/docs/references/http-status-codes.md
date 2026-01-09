# HTTP Status Codes Reference

## Quick Reference

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

## Success Codes (2xx)

### 200 OK
**Use for:** GET requests, PUT/PATCH with response data

```typescript
app.get('/users/:id', async (req, res) => {
  const user = await db.user.findUnique({ where: { id: req.params.id } });
  if (!user) return res.status(404).json({ error: 'Not found' });
  res.status(200).json(user);
});
```

### 201 Created
**Use for:** POST creating resources. Include `Location` header.

```typescript
app.post('/users', async (req, res) => {
  const user = await db.user.create({ data: req.body });
  res.status(201).location(`/users/${user.id}`).json(user);
});
```

### 204 No Content
**Use for:** DELETE, PUT/PATCH with no response body

```typescript
app.delete('/users/:id', async (req, res) => {
  await db.user.delete({ where: { id: req.params.id } });
  res.status(204).send();
});
```

## Client Error Codes (4xx)

### 400 Bad Request
**Use for:** Invalid format, validation errors

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

### 401 Unauthorized
**Use for:** Missing/invalid authentication

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

### 403 Forbidden
**Use for:** Valid auth, insufficient permissions

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

### 404 Not Found
**Use for:** Resource doesn't exist

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

### 409 Conflict
**Use for:** Duplicate resources, version conflicts, business rule violations

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

### 422 Unprocessable Entity
**Use for:** Valid format, but semantic/business logic errors

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

### 429 Too Many Requests
**Use for:** Rate limit exceeded. Include `Retry-After` header.

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

## Server Error Codes (5xx)

### 500 Internal Server Error
**Use for:** Unexpected server errors. Log details server-side, return generic message.

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

### 502 Bad Gateway
**Use for:** Upstream service returned invalid response

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

### 503 Service Unavailable
**Use for:** Temporary unavailability. Include `Retry-After` header.

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

## Status Code Decision Tree

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

## Common Mistakes

### Using 200 for Errors
```typescript
// ❌ BAD
res.status(200).json({ success: false, error: 'User not found' });

// ✓ GOOD
res.status(404).json({ error: { code: 'NOT_FOUND', message: 'User not found' } });
```

### Using 400 for Business Logic Errors
```typescript
// ❌ BAD (use 422 for semantic errors)
res.status(400).json({ error: 'Insufficient stock' });

// ✓ GOOD
res.status(422).json({ error: { code: 'INSUFFICIENT_STOCK', message: 'Not enough items' } });
```

### Confusing 401 and 403
```typescript
// 401: Authentication problem (who are you?)
res.status(401).json({ error: 'Invalid credentials' });

// 403: Authorization problem (you can't do this)
res.status(403).json({ error: 'Insufficient permissions' });
```

## Related
- [API Design](../patterns/backend/api-design.md)
- [Security Patterns](../patterns/security/authentication.md)
