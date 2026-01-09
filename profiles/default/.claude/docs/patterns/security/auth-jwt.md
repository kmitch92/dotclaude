# JWT Authentication Patterns

Production-ready JWT implementation with access and refresh tokens for TypeScript applications.

## Overview

JWT (JSON Web Tokens) provide stateless authentication. Best practice: short-lived access tokens + long-lived refresh tokens stored in database for revocation.

## Access + Refresh Token Strategy

```typescript
// Access token: Short-lived, contains user claims
const accessToken = jwt.sign(
  {
    userId: user.id,
    email: user.email,
    role: user.role,
  },
  ACCESS_TOKEN_SECRET,
  { expiresIn: '15m' } // Short expiry
);

// Refresh token: Long-lived, opaque, stored in database
const refreshToken = crypto.randomBytes(32).toString('hex');
await db.refreshToken.create({
  data: {
    token: refreshToken,
    userId: user.id,
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
  },
});

// Return both tokens
res.json({
  accessToken,
  refreshToken,
  expiresIn: 900, // 15 minutes in seconds
});
```

**Why two tokens:**
- **Access token**: Stateless, fast validation, expires quickly
- **Refresh token**: Stored in DB, allows revocation, long-lived

## Token Refresh Flow

```typescript
app.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;

  // Validate refresh token from database
  const storedToken = await db.refreshToken.findUnique({
    where: { token: refreshToken },
    include: { user: true },
  });

  if (!storedToken) {
    return res.status(401).json({ error: 'Invalid refresh token' });
  }

  if (storedToken.expiresAt < new Date()) {
    await db.refreshToken.delete({ where: { id: storedToken.id } });
    return res.status(401).json({ error: 'Refresh token expired' });
  }

  // Issue new access token
  const accessToken = jwt.sign(
    {
      userId: storedToken.user.id,
      email: storedToken.user.email,
      role: storedToken.user.role,
    },
    ACCESS_TOKEN_SECRET,
    { expiresIn: '15m' }
  );

  res.json({ accessToken, expiresIn: 900 });
});
```

## JWT Claims Best Practices

```typescript
// GOOD: Minimal claims, short expiry
{
  sub: "user-id-123",           // Subject (user ID)
  email: "user@example.com",
  role: "user",                 // High-level role only
  iat: 1699564800,              // Issued at
  exp: 1699565700,              // Expires at (15 min)
  iss: "myapp.com",             // Issuer
  aud: "myapp-api"              // Audience
}

// BAD: Too many claims, sensitive data, long expiry
{
  sub: "user-id-123",
  email: "user@example.com",
  firstName: "John",            // ❌ Unnecessary claims
  lastName: "Doe",              // ❌ Increases token size
  permissions: [...100 items],  // ❌ Huge token
  creditCard: "****1234",       // ❌ Sensitive data
  exp: 1699999999               // ❌ 30 day expiry
}
```

**Guidelines:**
- Keep tokens small (<1KB)
- No sensitive data (PII, secrets)
- Short expiry (5-15 minutes)
- Include only essential claims
- Use refresh tokens for long sessions

## Token Storage

**Client-side storage options:**

1. **httpOnly Cookie** (recommended for web apps)
```typescript
res.cookie('accessToken', token, {
  httpOnly: true,    // Not accessible via JavaScript
  secure: true,      // HTTPS only
  sameSite: 'strict', // CSRF protection
  maxAge: 15 * 60 * 1000, // 15 minutes
});
```

2. **localStorage** (vulnerable to XSS)
```typescript
// ❌ Avoid: Accessible to any script
localStorage.setItem('accessToken', token);
```

3. **Memory only** (secure but lost on refresh)
```typescript
// ✓ Best for SPAs with refresh token in httpOnly cookie
let accessToken = null; // In-memory variable
```

**Best practice**: Store refresh token in httpOnly cookie, keep access token in memory.

## JWT Verification Middleware

```typescript
import jwt from 'jsonwebtoken';

interface JWTPayload {
  userId: string;
  email: string;
  role: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: JWTPayload;
    }
  }
}

const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = authHeader.substring(7);

  try {
    const payload = jwt.verify(token, ACCESS_TOKEN_SECRET) as JWTPayload;
    req.user = payload;
    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Usage
app.get('/api/profile', authenticate, (req, res) => {
  res.json({ user: req.user });
});
```

## Token Revocation

```typescript
// Logout: Delete refresh token
app.post('/logout', authenticate, async (req, res) => {
  await db.refreshToken.deleteMany({
    where: { userId: req.user.userId },
  });
  res.json({ success: true });
});

// Logout all sessions: Delete all refresh tokens for user
app.post('/logout-all', authenticate, async (req, res) => {
  await db.refreshToken.deleteMany({
    where: { userId: req.user.userId },
  });
  res.json({ success: true });
});

// Admin: Revoke specific user's tokens
app.post('/admin/revoke-user/:userId', adminOnly, async (req, res) => {
  await db.refreshToken.deleteMany({
    where: { userId: req.params.userId },
  });
  res.json({ success: true });
});
```

## Security Best Practices

### Timing Attacks Prevention

```typescript
// ❌ Vulnerable: Different response times reveal valid usernames
const user = await db.user.findUnique({ where: { email } });
if (!user) {
  return res.status(401).json({ error: 'User not found' });
}

const isValid = await bcrypt.compare(password, user.passwordHash);
if (!isValid) {
  return res.status(401).json({ error: 'Invalid password' });
}

// ✓ Secure: Constant-time comparison
const user = await db.user.findUnique({ where: { email } });
const dummyHash = '$2b$12$dummyhashforinvalidusers';
const hashToCompare = user ? user.passwordHash : dummyHash;

const isValid = await bcrypt.compare(password, hashToCompare);

if (!user || !isValid) {
  return res.status(401).json({ error: 'Invalid credentials' });
}
```

### Brute Force Protection

```typescript
import rateLimit from 'express-rate-limit';

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts
  message: 'Too many login attempts, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});

app.post('/login', loginLimiter, async (req, res) => {
  // Login logic
});
```

## Testing JWT Authentication

```typescript
describe('JWT Authentication', () => {
  test('issues JWT on valid credentials', async () => {
    const response = await request(app)
      .post('/login')
      .send({ email: 'user@example.com', password: 'password123' });

    expect(response.status).toBe(200);
    expect(response.body.accessToken).toBeDefined();
    expect(response.body.refreshToken).toBeDefined();

    // Verify token is valid
    const decoded = jwt.verify(response.body.accessToken, ACCESS_TOKEN_SECRET);
    expect(decoded.userId).toBe(user.id);
  });

  test('rejects invalid credentials', async () => {
    const response = await request(app)
      .post('/login')
      .send({ email: 'user@example.com', password: 'wrong' });

    expect(response.status).toBe(401);
    expect(response.body.accessToken).toBeUndefined();
  });

  test('refresh token flow works', async () => {
    const { refreshToken } = await loginUser();

    const response = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken });

    expect(response.status).toBe(200);
    expect(response.body.accessToken).toBeDefined();
  });

  test('expired tokens are rejected', async () => {
    const expiredToken = jwt.sign(
      { userId: user.id },
      ACCESS_TOKEN_SECRET,
      { expiresIn: '0s' }
    );

    const response = await request(app)
      .get('/api/profile')
      .set('Authorization', `Bearer ${expiredToken}`);

    expect(response.status).toBe(401);
    expect(response.body.error).toBe('Token expired');
  });
});
```

## Related

- [OAuth Patterns](./auth-oauth.md) - OAuth 2.0 and OIDC flows
- [Session Management](./auth-sessions.md) - Server-side session patterns
- [OWASP Authentication](./owasp-auth.md) - Authentication security risks
