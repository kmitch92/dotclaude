---
name: security-auth
description: Authentication patterns. JWT access/refresh tokens, OAuth 2.0 flows, OIDC, server-side session management, secure token storage.
---

# Authentication Patterns

Production-ready authentication patterns for TypeScript applications covering JWT tokens, OAuth 2.0/OIDC, and server-side sessions.

## JWT Tokens

### Access + Refresh Token Strategy

Best practice: short-lived access tokens + long-lived refresh tokens stored in database for revocation.

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

res.json({
  accessToken,
  refreshToken,
  expiresIn: 900, // 15 minutes in seconds
});
```

**Why two tokens:**
- **Access token**: Stateless, fast validation, expires quickly
- **Refresh token**: Stored in DB, allows revocation, long-lived

### Token Refresh Flow

```typescript
app.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;

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

### JWT Claims Best Practices

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

### Token Storage

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

2. **localStorage** (vulnerable to XSS) - ❌ Avoid
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

### JWT Verification Middleware

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

app.get('/api/profile', authenticate, (req, res) => {
  res.json({ user: req.user });
});
```

### Token Revocation

```typescript
// Logout: Delete refresh token
app.post('/logout', authenticate, async (req, res) => {
  await db.refreshToken.deleteMany({
    where: { userId: req.user.userId },
  });
  res.json({ success: true });
});

// Logout all sessions
app.post('/logout-all', authenticate, async (req, res) => {
  await db.refreshToken.deleteMany({
    where: { userId: req.user.userId },
  });
  res.json({ success: true });
});
```

### Security Best Practices

**Timing Attacks Prevention:**

```typescript
// ❌ Vulnerable: Different response times reveal valid usernames
const user = await db.user.findUnique({ where: { email } });
if (!user) {
  return res.status(401).json({ error: 'User not found' });
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

**Brute Force Protection:**

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

## OAuth 2.0 and OIDC

- **OAuth 2.0**: Authorization framework (grants access to resources)
- **OIDC**: Identity layer on top of OAuth 2.0 (authentication)

### Authorization Code Flow (Recommended)

Most secure flow for web applications with backend.

```typescript
import { AuthorizationCode } from 'simple-oauth2';

const oauth2 = new AuthorizationCode({
  client: {
    id: GOOGLE_CLIENT_ID,
    secret: GOOGLE_CLIENT_SECRET,
  },
  auth: {
    tokenHost: 'https://oauth2.googleapis.com',
    tokenPath: '/token',
    authorizePath: 'https://accounts.google.com/o/oauth2/v2/auth',
  },
});

// Step 1: Redirect to OAuth provider
app.get('/auth/google', (req, res) => {
  const authorizationUri = oauth2.authorizeURL({
    redirect_uri: 'https://myapp.com/auth/google/callback',
    scope: 'openid email profile',
    state: crypto.randomBytes(16).toString('hex'), // CSRF protection
  });

  req.session.oauthState = authorizationUri.state;
  res.redirect(authorizationUri);
});

// Step 2: Handle callback
app.get('/auth/google/callback', async (req, res) => {
  const { code, state } = req.query;

  // Validate state (CSRF protection)
  if (state !== req.session.oauthState) {
    return res.status(403).json({ error: 'Invalid state' });
  }

  // Exchange code for tokens
  const result = await oauth2.getToken({
    code,
    redirect_uri: 'https://myapp.com/auth/google/callback',
  });

  const { access_token, id_token } = result.token;
  const userInfo = jwt.decode(id_token);

  // Create or update user
  const user = await db.user.upsert({
    where: { email: userInfo.email },
    create: {
      email: userInfo.email,
      name: userInfo.name,
      oauthProvider: 'google',
      oauthId: userInfo.sub,
    },
    update: { name: userInfo.name },
  });

  req.session.userId = user.id;
  res.redirect('/dashboard');
});
```

### PKCE for Public Clients

Use PKCE (Proof Key for Code Exchange) for mobile/SPA apps without client secret.

```typescript
// Generate code verifier and challenge
const codeVerifier = crypto.randomBytes(32).toString('base64url');
const codeChallenge = crypto
  .createHash('sha256')
  .update(codeVerifier)
  .digest('base64url');

// Authorization request with PKCE
const authUrl = oauth2.authorizeURL({
  redirect_uri: 'myapp://callback',
  code_challenge: codeChallenge,
  code_challenge_method: 'S256',
  scope: 'openid email profile',
});

// Store code_verifier securely
sessionStorage.setItem('code_verifier', codeVerifier);

// Token request with code verifier
const result = await oauth2.getToken({
  code,
  redirect_uri: 'myapp://callback',
  code_verifier: codeVerifier,
});
```

**Why PKCE:**
- Prevents authorization code interception attacks
- Required for public clients (SPAs, mobile apps)

### Multi-Provider OAuth

```typescript
interface OAuthProvider {
  name: string;
  client: AuthorizationCode;
  scopes: string[];
  getUserInfo: (accessToken: string) => Promise<UserInfo>;
}

const providers: Record<string, OAuthProvider> = {
  google: {
    name: 'Google',
    client: new AuthorizationCode({
      client: { id: GOOGLE_CLIENT_ID, secret: GOOGLE_CLIENT_SECRET },
      auth: {
        tokenHost: 'https://oauth2.googleapis.com',
        tokenPath: '/token',
        authorizePath: 'https://accounts.google.com/o/oauth2/v2/auth',
      },
    }),
    scopes: ['openid', 'email', 'profile'],
    getUserInfo: async (accessToken) => {
      const response = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      return response.json();
    },
  },
  github: {
    name: 'GitHub',
    client: new AuthorizationCode({
      client: { id: GITHUB_CLIENT_ID, secret: GITHUB_CLIENT_SECRET },
      auth: {
        tokenHost: 'https://github.com',
        tokenPath: '/login/oauth/access_token',
        authorizePath: '/login/oauth/authorize',
      },
    }),
    scopes: ['user:email'],
    getUserInfo: async (accessToken) => {
      const response = await fetch('https://api.github.com/user', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      return response.json();
    },
  },
};

// Generic OAuth handler
app.get('/auth/:provider', (req, res) => {
  const { provider } = req.params;
  const oauthProvider = providers[provider];

  if (!oauthProvider) {
    return res.status(404).json({ error: 'Provider not found' });
  }

  const state = crypto.randomBytes(16).toString('hex');
  req.session.oauthState = state;
  req.session.oauthProvider = provider;

  const authUri = oauthProvider.client.authorizeURL({
    redirect_uri: `https://myapp.com/auth/${provider}/callback`,
    scope: oauthProvider.scopes.join(' '),
    state,
  });

  res.redirect(authUri);
});
```

### ID Token Verification

```typescript
import { JwksClient } from 'jwks-rsa';
import jwt from 'jsonwebtoken';

async function verifyGoogleIdToken(idToken: string): Promise<any> {
  const client = new JwksClient({
    jwksUri: 'https://www.googleapis.com/oauth2/v3/certs',
  });

  const decoded = jwt.decode(idToken, { complete: true });
  if (!decoded) throw new Error('Invalid token');

  const key = await client.getSigningKey(decoded.header.kid);
  const publicKey = key.getPublicKey();

  const payload = jwt.verify(idToken, publicKey, {
    audience: GOOGLE_CLIENT_ID,
    issuer: ['https://accounts.google.com', 'accounts.google.com'],
  });

  return payload;
}
```

### OAuth Token Storage and Refresh

```typescript
interface OAuthToken {
  userId: string;
  provider: string;
  accessToken: string;
  refreshToken?: string;
  expiresAt: Date;
}

await db.oauthToken.create({
  data: {
    userId: user.id,
    provider: 'google',
    accessToken: result.token.access_token,
    refreshToken: result.token.refresh_token,
    expiresAt: new Date(Date.now() + result.token.expires_in * 1000),
  },
});

// Refresh access token when expired
async function getValidAccessToken(userId: string, provider: string): Promise<string> {
  const token = await db.oauthToken.findUnique({
    where: { userId_provider: { userId, provider } },
  });

  if (!token) throw new Error('No token found');

  if (token.expiresAt > new Date()) {
    return token.accessToken;
  }

  if (!token.refreshToken) throw new Error('No refresh token');

  const oauthProvider = providers[provider];
  const result = await oauthProvider.client.createToken({
    access_token: token.accessToken,
    refresh_token: token.refreshToken,
  }).refresh();

  await db.oauthToken.update({
    where: { id: token.id },
    data: {
      accessToken: result.token.access_token,
      expiresAt: new Date(Date.now() + result.token.expires_in * 1000),
    },
  });

  return result.token.access_token;
}
```

### OAuth Security

**State Parameter (CSRF Protection):**

```typescript
// Always use state parameter
const state = crypto.randomBytes(16).toString('hex');
req.session.oauthState = state;

// Validate on callback
if (state !== req.session.oauthState) {
  return res.status(403).json({ error: 'Invalid state parameter' });
}

delete req.session.oauthState;
```

**Redirect URI Validation:**

```typescript
const ALLOWED_REDIRECT_URIS = [
  'https://myapp.com/auth/google/callback',
  'https://myapp.com/auth/github/callback',
];

function validateRedirectUri(uri: string): boolean {
  return ALLOWED_REDIRECT_URIS.includes(uri);
}
```

**Nonce for ID Tokens (OIDC):**

```typescript
const nonce = crypto.randomBytes(16).toString('hex');
req.session.oidcNonce = nonce;

const authUri = oauth2.authorizeURL({
  redirect_uri: 'https://myapp.com/auth/callback',
  scope: 'openid email profile',
  state,
  nonce,
});

// Validate nonce in ID token
const payload = await verifyIdToken(idToken);
if (payload.nonce !== req.session.oidcNonce) {
  throw new Error('Invalid nonce');
}
```

## Session Management

Session vs JWT:
- **Sessions**: Stateful, easy revocation, server memory/storage required
- **JWT**: Stateless, scalable, harder to revoke
- **Hybrid**: JWT with refresh tokens in database (recommended)

### Server-Side Sessions with Redis

```typescript
import session from 'express-session';
import RedisStore from 'connect-redis';
import { createClient } from 'redis';

const redisClient = createClient();
await redisClient.connect();

app.use(
  session({
    store: new RedisStore({ client: redisClient }),
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      secure: true,
      sameSite: 'strict',
      maxAge: 24 * 60 * 60 * 1000, // 24 hours
    },
  })
);
```

**Session configuration:**
- `secret`: Sign session ID cookie (use strong random value)
- `resave`: false (don't save unchanged sessions)
- `saveUninitialized`: false (don't create session until something stored)
- `store`: Redis for production (in-memory for development)

### Session Lifecycle

```typescript
// Login
app.post('/login', async (req, res) => {
  const user = await authenticateUser(req.body);
  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  // Regenerate session ID (prevent fixation)
  req.session.regenerate(err => {
    if (err) return res.status(500).json({ error: 'Login failed' });
    req.session.userId = user.id;
    req.session.role = user.role;
    res.json({ success: true });
  });
});

// Access session data
app.get('/profile', (req, res) => {
  if (!req.session.userId) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  const userId = req.session.userId;
  // Fetch and return user data
});

// Logout
app.post('/logout', (req, res) => {
  req.session.destroy(err => {
    if (err) return res.status(500).json({ error: 'Logout failed' });
    res.clearCookie('connect.sid');
    res.json({ success: true });
  });
});
```

### Session Security

**Prevent Session Fixation:**

```typescript
// ALWAYS regenerate session ID after login
app.post('/login', async (req, res) => {
  const user = await authenticateUser(req.body);

  req.session.regenerate(err => {
    if (err) return res.status(500).json({ error: 'Login failed' });
    req.session.userId = user.id;
    res.json({ success: true });
  });
});
```

**Session Timeout and Renewal:**

```typescript
const SESSION_TIMEOUT = 30 * 60 * 1000; // 30 minutes

function checkSessionExpiry(req: Request, res: Response, next: NextFunction) {
  if (!req.session.userId) {
    return next();
  }

  const lastActivity = req.session.lastActivity || Date.now();
  const now = Date.now();

  if (now - lastActivity > SESSION_TIMEOUT) {
    req.session.destroy(() => {
      res.status(401).json({ error: 'Session expired' });
    });
    return;
  }

  req.session.lastActivity = now;
  next();
}

app.use(checkSessionExpiry);
```

**Concurrent Session Limits:**

```typescript
app.post('/login', async (req, res) => {
  const user = await authenticateUser(req.body);

  // Get existing sessions for user
  const sessions = await db.session.findMany({
    where: { userId: user.id },
    orderBy: { createdAt: 'desc' },
  });

  // Delete oldest sessions if limit exceeded (max 3)
  if (sessions.length >= 3) {
    const sessionsToDelete = sessions.slice(2);
    await db.session.deleteMany({
      where: { id: { in: sessionsToDelete.map(s => s.id) } },
    });
  }

  req.session.regenerate(err => {
    if (err) return res.status(500).json({ error: 'Login failed' });
    req.session.userId = user.id;
    res.json({ success: true });
  });
});
```

### Database Session Store

```typescript
import connectPg from 'connect-pg-simple';
import session from 'express-session';

const PgSession = connectPg(session);

app.use(
  session({
    store: new PgSession({
      pool: pgPool,
      tableName: 'sessions',
    }),
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
  })
);
```

**Database schema:**
```sql
CREATE TABLE sessions (
  sid VARCHAR NOT NULL PRIMARY KEY,
  sess JSON NOT NULL,
  expire TIMESTAMP(6) NOT NULL
);

CREATE INDEX idx_sessions_expire ON sessions (expire);
```

### Type-Safe Sessions

```typescript
import 'express-session';

declare module 'express-session' {
  interface SessionData {
    userId: string;
    role: 'user' | 'admin';
    createdAt: number;
    lastActivity: number;
    ipAddress: string;
  }
}

// Now session data is type-safe
app.get('/profile', (req, res) => {
  const userId: string = req.session.userId; // Type-safe
});
```

### Session Authentication Middleware

```typescript
function requireAuth(req: Request, res: Response, next: NextFunction) {
  if (!req.session.userId) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  next();
}

function requireRole(role: 'user' | 'admin') {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.session.userId) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (req.session.role !== role && req.session.role !== 'admin') {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }

    next();
  };
}

// Usage
app.get('/api/profile', requireAuth, (req, res) => { /* ... */ });
app.delete('/api/users/:id', requireRole('admin'), (req, res) => { /* ... */ });
```

### Multi-Factor Authentication with Sessions

```typescript
app.post('/login', async (req, res) => {
  const user = await authenticateUser(req.body);

  if (user.mfaEnabled) {
    req.session.regenerate(err => {
      if (err) return res.status(500).json({ error: 'Login failed' });
      req.session.pendingUserId = user.id;
      req.session.mfaRequired = true;
      res.json({ mfaRequired: true });
    });
  } else {
    req.session.regenerate(err => {
      if (err) return res.status(500).json({ error: 'Login failed' });
      req.session.userId = user.id;
      res.json({ success: true });
    });
  }
});

app.post('/mfa/verify', async (req, res) => {
  if (!req.session.pendingUserId || !req.session.mfaRequired) {
    return res.status(400).json({ error: 'MFA verification not in progress' });
  }

  const { code } = req.body;
  const verified = await verifyMFACode(req.session.pendingUserId, code);

  if (!verified) {
    return res.status(401).json({ error: 'Invalid MFA code' });
  }

  // Complete authentication
  req.session.userId = req.session.pendingUserId;
  delete req.session.pendingUserId;
  delete req.session.mfaRequired;

  res.json({ success: true });
});
```

## Testing Authentication

### JWT Testing

```typescript
describe('JWT Authentication', () => {
  test('issues JWT on valid credentials', async () => {
    const response = await request(app)
      .post('/login')
      .send({ email: 'user@example.com', password: 'password123' });

    expect(response.status).toBe(200);
    expect(response.body.accessToken).toBeDefined();
    expect(response.body.refreshToken).toBeDefined();

    const decoded = jwt.verify(response.body.accessToken, ACCESS_TOKEN_SECRET);
    expect(decoded.userId).toBe(user.id);
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

### OAuth Testing

```typescript
describe('OAuth Authentication', () => {
  test('redirects to OAuth provider', async () => {
    const response = await request(app)
      .get('/auth/google')
      .expect(302);

    expect(response.headers.location).toContain('accounts.google.com');
    expect(response.headers.location).toContain('state=');
  });

  test('handles callback with valid code', async () => {
    mockOAuthTokenExchange({ access_token: 'mock-token' });

    const response = await request(app)
      .get('/auth/google/callback')
      .query({ code: 'auth-code', state: validState })
      .expect(302);

    expect(response.headers.location).toBe('/dashboard');
  });

  test('rejects callback with invalid state', async () => {
    const response = await request(app)
      .get('/auth/google/callback')
      .query({ code: 'auth-code', state: 'invalid-state' })
      .expect(403);

    expect(response.body.error).toBe('Invalid state');
  });
});
```

### Session Testing

```typescript
describe('Session Authentication', () => {
  test('creates session on login', async () => {
    const agent = request.agent(app);

    const response = await agent
      .post('/login')
      .send({ email: 'user@example.com', password: 'password' });

    expect(response.status).toBe(200);
    expect(response.headers['set-cookie']).toBeDefined();

    // Session persists across requests
    const profileResponse = await agent.get('/profile');
    expect(profileResponse.status).toBe(200);
  });

  test('destroys session on logout', async () => {
    const agent = request.agent(app);
    await agent.post('/login').send(credentials);
    await agent.post('/logout');

    const response = await agent.get('/profile');
    expect(response.status).toBe(401);
  });

  test('regenerates session ID on login', async () => {
    const agent = request.agent(app);
    const initialResponse = await agent.get('/');
    const initialSessionId = getCookie(initialResponse, 'connect.sid');

    await agent.post('/login').send(credentials);

    const afterLoginResponse = await agent.get('/profile');
    const afterLoginSessionId = getCookie(afterLoginResponse, 'connect.sid');

    expect(afterLoginSessionId).not.toBe(initialSessionId);
  });
});
```
