# Session Management Patterns

Server-side session management patterns for TypeScript applications with security best practices.

## Overview

Session vs JWT:
- **Sessions**: Stateful, easy revocation, server memory/storage required
- **JWT**: Stateless, scalable, harder to revoke
- **Hybrid**: JWT with refresh tokens in database (recommended)

## Server-Side Sessions with Redis

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

## Session Lifecycle

```typescript
// Set session data (login)
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

// Destroy session (logout)
app.post('/logout', (req, res) => {
  req.session.destroy(err => {
    if (err) return res.status(500).json({ error: 'Logout failed' });
    res.clearCookie('connect.sid');
    res.json({ success: true });
  });
});
```

## Session Security

### Prevent Session Fixation

```typescript
// ALWAYS regenerate session ID after login
app.post('/login', async (req, res) => {
  const user = await authenticateUser(req.body);

  // Regenerate session (new session ID)
  req.session.regenerate(err => {
    if (err) return res.status(500).json({ error: 'Login failed' });
    req.session.userId = user.id;
    res.json({ success: true });
  });
});
```

### Session Timeout and Renewal

```typescript
// Middleware to check session expiry
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

### Concurrent Session Limits

```typescript
// Limit to 3 concurrent sessions per user
app.post('/login', async (req, res) => {
  const user = await authenticateUser(req.body);

  // Get existing sessions for user
  const sessions = await db.session.findMany({
    where: { userId: user.id },
    orderBy: { createdAt: 'desc' },
  });

  // Delete oldest sessions if limit exceeded
  if (sessions.length >= 3) {
    const sessionsToDelete = sessions.slice(2);
    await db.session.deleteMany({
      where: { id: { in: sessionsToDelete.map(s => s.id) } },
    });
  }

  // Create new session
  req.session.regenerate(err => {
    if (err) return res.status(500).json({ error: 'Login failed' });
    req.session.userId = user.id;
    res.json({ success: true });
  });
});
```

## Session Store Patterns

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

### Custom Session Store

```typescript
import { SessionStore } from 'express-session';

class CustomSessionStore extends SessionStore {
  async get(sid: string, callback: (err?: any, session?: any) => void) {
    try {
      const session = await db.session.findUnique({ where: { sid } });
      callback(null, session?.data);
    } catch (err) {
      callback(err);
    }
  }

  async set(sid: string, session: any, callback?: (err?: any) => void) {
    try {
      await db.session.upsert({
        where: { sid },
        create: { sid, data: session, expiresAt: session.cookie.expires },
        update: { data: session, expiresAt: session.cookie.expires },
      });
      callback?.();
    } catch (err) {
      callback?.(err);
    }
  }

  async destroy(sid: string, callback?: (err?: any) => void) {
    try {
      await db.session.delete({ where: { sid } });
      callback?.();
    } catch (err) {
      callback?.(err);
    }
  }
}
```

## Type-Safe Sessions

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

## Session Authentication Middleware

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

## Multi-Factor Authentication with Sessions

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

## Testing Sessions

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

## Related

- [JWT Patterns](./auth-jwt.md) - JWT-based authentication
- [OAuth Patterns](./auth-oauth.md) - OAuth 2.0 flows
