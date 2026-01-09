# OWASP: Access Control and Authentication

Broken access control and authentication failure prevention for TypeScript applications.

## A01:2021 - Broken Access Control

### Description
Users can act outside their intended permissions, accessing unauthorized data or functionality.

### Common Vulnerabilities
- Missing authorization checks
- Insecure Direct Object References (IDOR)
- Privilege escalation
- CORS misconfiguration

### Insecure Direct Object References (IDOR)

Always verify ownership before delete/update operations.

```typescript
app.delete('/api/posts/:id', authenticate, async (req, res) => {
  const post = await db.post.findUnique({ where: { id: req.params.id } });
  if (!post) return res.status(404).json({ error: 'Not found' });
  if (post.authorId !== req.user.id) return res.status(403).json({ error: 'Forbidden' });
  await db.post.delete({ where: { id: req.params.id } });
  res.json({ success: true });
});
```

### Role-Based Access Control (RBAC)

Check user roles before allowing actions.

```typescript
function requireRole(allowedRoles: string[]) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Auth required' });
    if (!allowedRoles.includes(req.user.role)) return res.status(403).json({ error: 'Forbidden' });
    next();
  };
}

app.delete('/api/users/:id', requireRole(['admin']), async (req, res) => {
  await db.user.delete({ where: { id: req.params.id } });
});
```

### Resource-Level Authorization

Verify user owns resource before allowing update/delete. See RBAC example above.

### Prevention
- Deny by default (require explicit permission)
- Validate ownership on every request
- Use role-based access control (RBAC)
- Test with different user roles
- Log access control failures

## A07:2021 - Identification and Authentication Failures

### Description
Broken authentication allowing attackers to compromise accounts.

### Session Timeout

15 min sessions with httpOnly, secure, sameSite: strict cookies.

```typescript
app.use(session({
  cookie: { maxAge: 15 * 60 * 1000, httpOnly: true, secure: true, sameSite: 'strict' }
}));
```

### Password Policies

12+ chars with complexity requirements. Check against HaveIBeenPwned API.

```typescript
import { z } from 'zod';
const PasswordSchema = z.string().min(12).regex(/[a-z]/).regex(/[A-Z]/).regex(/[0-9]/).regex(/[^a-zA-Z0-9]/);

async function isPasswordBreached(password: string): Promise<boolean> {
  const hash = crypto.createHash('sha1').update(password).digest('hex').toUpperCase();
  const response = await fetch(`https://api.pwnedpasswords.com/range/${hash.substring(0, 5)}`);
  return (await response.text()).includes(hash.substring(5));
}
```

### Brute Force Protection

Rate limit (5 attempts/15 min) + account lockout after failures.

```typescript
import rateLimit from 'express-rate-limit';
const loginLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 5, skipSuccessfulRequests: true });

app.post('/login', loginLimiter, async (req, res) => {
  const user = await db.user.findUnique({ where: { email: req.body.email } });
  if (!user) return res.status(401).json({ error: 'Invalid credentials' });
  if (user.lockedUntil && user.lockedUntil > new Date()) {
    return res.status(423).json({ error: 'Account locked' });
  }
  const isValid = await bcrypt.compare(req.body.password, user.passwordHash);
  if (!isValid) {
    const failedAttempts = user.failedLoginAttempts + 1;
    if (failedAttempts >= 5) {
      await db.user.update({ where: { id: user.id }, data: { failedLoginAttempts: failedAttempts, lockedUntil: new Date(Date.now() + 30 * 60 * 1000) } });
      return res.status(423).json({ error: 'Account locked' });
    }
    await db.user.update({ where: { id: user.id }, data: { failedLoginAttempts: failedAttempts } });
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  await db.user.update({ where: { id: user.id }, data: { failedLoginAttempts: 0, lockedUntil: null } });
  req.session.userId = user.id;
  res.json({ success: true });
});
```

### Multi-Factor Authentication

Use TOTP (speakeasy library) for 2FA.

```typescript
import speakeasy from 'speakeasy';

app.post('/mfa/setup', authenticate, async (req, res) => {
  const secret = speakeasy.generateSecret({ name: `MyApp (${req.user.email})` });
  await db.user.update({ where: { id: req.user.id }, data: { mfaSecret: secret.base32 } });
  res.json({ secret: secret.base32, qrCode: secret.otpauth_url });
});

app.post('/mfa/verify', authenticate, async (req, res) => {
  const user = await db.user.findUnique({ where: { id: req.user.id } });
  const verified = speakeasy.totp.verify({ secret: user.mfaSecret, encoding: 'base32', token: req.body.code, window: 1 });
  if (!verified) return res.status(401).json({ error: 'Invalid MFA code' });
  await db.user.update({ where: { id: req.user.id }, data: { mfaEnabled: true } });
  res.json({ success: true });
});
```

### Prevention
- Implement multi-factor authentication
- Strong password requirements (12+ chars)
- Check against breach databases
- Rate limiting on login attempts
- Secure session management
- No default credentials
- Account lockout after failed attempts

## CORS Misconfiguration

Never use `origin: '*'`. Whitelist specific origins only.

```typescript
app.use(cors({ origin: ['https://myapp.com'], credentials: true }));
```

## Testing Access Control

```typescript
describe('Access Control', () => {
  test('requires authentication', async () => {
    const response = await request(app).get('/api/profile');
    expect(response.status).toBe(401);
  });

  test('validates ownership', async () => {
    const otherUserPost = await createPost({ authorId: 'other-user' });

    const response = await request(app)
      .delete(`/api/posts/${otherUserPost.id}`)
      .set('Authorization', `Bearer ${userToken}`);

    expect(response.status).toBe(403);
  });

  test('requires admin role', async () => {
    const response = await request(app)
      .delete('/api/users/123')
      .set('Authorization', `Bearer ${regularUserToken}`);

    expect(response.status).toBe(403);
  });

  test('rate limits login attempts', async () => {
    const requests = Array.from({ length: 10 }, () =>
      request(app).post('/login').send({ email, password: 'wrong' })
    );

    const responses = await Promise.all(requests);
    const tooManyRequests = responses.filter(r => r.status === 429);

    expect(tooManyRequests.length).toBeGreaterThan(0);
  });

  test('locks account after failed attempts', async () => {
    // Make 5 failed login attempts
    for (let i = 0; i < 5; i++) {
      await request(app).post('/login').send({ email, password: 'wrong' });
    }

    const response = await request(app).post('/login').send({ email, password: 'correct' });

    expect(response.status).toBe(423);
    expect(response.body.error).toContain('locked');
  });
});
```

## Related

- [JWT Authentication](./auth-jwt.md) - JWT implementation patterns
- [OAuth Patterns](./auth-oauth.md) - OAuth 2.0 flows
- [Session Management](./auth-sessions.md) - Server-side sessions
- [OWASP Injection](./owasp-injection.md) - Injection prevention
- [OWASP Cryptography](./owasp-crypto.md) - Cryptographic failures
