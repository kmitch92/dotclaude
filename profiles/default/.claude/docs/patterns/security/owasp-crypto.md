# OWASP: Cryptography, Configuration, and Data Integrity

Cryptographic failures, security misconfiguration, vulnerable components, data integrity, and logging patterns.

## A02:2021 - Cryptographic Failures

### Description
Exposure of sensitive data due to weak or missing encryption.

### Password Hashing

Use bcrypt (12 rounds) or argon2. Never store plaintext.

```typescript
import bcrypt from 'bcrypt';
const SALT_ROUNDS = 12;
const hashedPassword = await bcrypt.hash(plainPassword, SALT_ROUNDS);
const isValid = await bcrypt.compare(plainPassword, user.passwordHash);
```

### Data Encryption at Rest

Use AES-256-GCM with unique IV per encryption. Store IV and tag with ciphertext.

```typescript
import crypto from 'crypto';
const ALGORITHM = 'aes-256-gcm';
const KEY = Buffer.from(process.env.ENCRYPTION_KEY, 'hex');

function encrypt(text: string): { encrypted: string; iv: string; tag: string } {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex') + cipher.final('hex');
  return { encrypted, iv: iv.toString('hex'), tag: cipher.getAuthTag().toString('hex') };
}
```

### Sensitive Data in Logs

Redact passwords, tokens, credit cards, SSNs before logging.

```typescript
function redactSensitiveData(data: any): any {
  const sensitiveFields = ['password', 'token', 'creditCard', 'ssn'];
  if (typeof data !== 'object') return data;
  const redacted = { ...data };
  for (const key of Object.keys(redacted)) {
    if (sensitiveFields.some(field => key.toLowerCase().includes(field))) {
      redacted[key] = '***REDACTED***';
    }
  }
  return redacted;
}
```

### Prevention
- Use TLS/HTTPS for all connections
- Hash passwords with bcrypt/argon2
- Encrypt sensitive data at rest (AES-256-GCM)
- Avoid sensitive data in URLs/logs
- Implement key rotation
- Use strong random values (crypto.randomBytes)

## A04:2021 - Insecure Design

Rate limit forgot password (3 attempts/hour), generic response to prevent email enumeration.

```typescript
import rateLimit from 'express-rate-limit';
const forgotPasswordLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 3 });

app.post('/forgot-password', forgotPasswordLimiter, async (req, res) => {
  const user = await db.user.findUnique({ where: { email: req.body.email } });
  if (user) await sendPasswordResetEmail(req.body.email);
  res.json({ message: 'If account exists, reset email sent' });
});
```

## A05:2021 - Security Misconfiguration

### Error Handling

Never expose stack traces in production. Generic error messages only.

```typescript
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { error: err });
  if (process.env.NODE_ENV === 'production') {
    res.status(500).json({ error: 'Internal server error' });
  } else {
    res.status(500).json({ error: err.message, stack: err.stack });
  }
});
```

### Security Headers & CORS

Use helmet for CSP, HSTS. Specific CORS origins only.

```typescript
import helmet from 'helmet';
app.use(helmet({ /* CSP, HSTS config */ }));

// CORS: specific origins only
app.use(cors({
  origin: ['https://myapp.com', 'https://www.myapp.com'],
  credentials: true,
}));
```

## A06:2021 - Vulnerable and Outdated Components

Run `npm audit` regularly. Use Dependabot/Renovate for automated updates. Monitor security advisories.

## A08:2021 - Software and Data Integrity Failures

### Webhook Signature Verification

Verify HMAC signatures before processing external webhooks.

```typescript
app.post('/webhook', async (req, res) => {
  const signature = req.headers['x-signature'];
  const expected = crypto.createHmac('sha256', WEBHOOK_SECRET).update(JSON.stringify(req.body)).digest('hex');
  if (signature !== expected) return res.status(401).json({ error: 'Invalid signature' });
  await processWebhook(req.body);
  res.json({ success: true });
});
```

### Input Validation

Always validate with Zod before processing. NEVER use `eval`.

```typescript
import { z } from 'zod';
const UserSchema = z.object({ name: z.string().max(100), email: z.string().email() });
const userData = UserSchema.parse(req.body.data);
```

## A09:2021 - Security Logging and Monitoring Failures

### Comprehensive Logging

Log all security events (login attempts, password resets, access failures). Never log passwords/tokens/PII.

```typescript
app.post('/login', async (req, res) => {
  const { email } = req.body;
  logger.info('Login attempt', { email, ip: req.ip });
  const user = await authenticateUser(req.body);
  if (!user) {
    logger.warn('Failed login', { email, ip: req.ip });
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  logger.info('Successful login', { userId: user.id, ip: req.ip });
  res.json({ success: true });
});
```

**Log:** Login attempts, password resets, account changes, access failures
**Never log:** Passwords, tokens, credit cards, API keys, PII

## Testing Security

```typescript
describe('Security Tests', () => {
  test('uses HTTPS in production', () => {
    if (process.env.NODE_ENV === 'production') {
      expect(app.get('trust proxy')).toBeTruthy();
    }
  });

  test('sets security headers', async () => {
    const response = await request(app).get('/');

    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-frame-options']).toBeDefined();
    expect(response.headers['strict-transport-security']).toBeDefined();
  });

  test('does not expose stack traces in production', async () => {
    process.env.NODE_ENV = 'production';

    const response = await request(app).get('/error-route');

    expect(response.status).toBe(500);
    expect(response.body.stack).toBeUndefined();
    expect(response.body.error).toBe('Internal server error');
  });

  test('verifies webhook signatures', async () => {
    const payload = { event: 'test' };
    const invalidSignature = 'invalid';

    const response = await request(app)
      .post('/webhook')
      .set('x-signature', invalidSignature)
      .send(payload);

    expect(response.status).toBe(401);
  });
});
```

## Resources

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)

## Related

- [OWASP Injection](./owasp-injection.md) - Injection and SSRF prevention
- [OWASP Authentication](./owasp-auth.md) - Access control and authentication
- [Authentication Patterns](./auth-jwt.md) - JWT, OAuth, sessions
