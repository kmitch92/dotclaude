---
name: security-owasp
description: OWASP security patterns. Injection prevention (SQL, NoSQL, command, XSS), authentication vulnerabilities, cryptographic best practices.
---

# OWASP Security Patterns

OWASP Top 10 vulnerability prevention patterns for TypeScript applications.

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

### CORS Misconfiguration

Never use `origin: '*'`. Whitelist specific origins only.

```typescript
app.use(cors({ origin: ['https://myapp.com'], credentials: true }));
```

### Prevention
- Deny by default (require explicit permission)
- Validate ownership on every request
- Use role-based access control (RBAC)
- Test with different user roles
- Log access control failures

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

## A03:2021 - Injection

### Description
Untrusted data sent to interpreter as part of command/query, tricking it into executing unintended commands.

### Types
- SQL Injection
- NoSQL Injection
- Command Injection
- LDAP Injection

### SQL Injection

```typescript
// ❌ Vulnerable: String concatenation
const query = `SELECT * FROM users WHERE email = '${userInput}'`;
// Input: ' OR '1'='1
// Result: SELECT * FROM users WHERE email = '' OR '1'='1'
// Returns all users!

// ✓ Secure: Parameterized queries
const query = 'SELECT * FROM users WHERE email = ?';
const result = await db.query(query, [userInput]);

// ✓ Secure: ORM (Prisma)
const user = await db.user.findUnique({
  where: { email: userInput } // Automatically parameterized
});
```

### NoSQL Injection

```typescript
// ❌ Vulnerable: Direct object injection
const user = await db.collection('users').findOne({
  email: req.body.email, // Input: {"$ne": null}
  password: req.body.password
});
// Bypasses password check!

// ✓ Secure: Validate input types
import { z } from 'zod';

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const { email, password } = LoginSchema.parse(req.body);
const user = await db.collection('users').findOne({ email, password });
```

### Command Injection

```typescript
// ❌ Vulnerable: Executing shell commands with user input
const filename = req.query.file;
exec(`cat ${filename}`, (error, stdout) => {
  res.send(stdout);
});
// Input: file.txt; rm -rf /
// Executes: cat file.txt; rm -rf /

// ✓ Secure: Validate and sanitize input
const filename = path.basename(req.query.file); // Remove path traversal
const safePath = path.join(SAFE_DIRECTORY, filename);

// Check file is within allowed directory
if (!safePath.startsWith(SAFE_DIRECTORY)) {
  return res.status(400).json({ error: 'Invalid filename' });
}

// Use filesystem API instead of shell
const content = await fs.promises.readFile(safePath, 'utf-8');
res.send(content);
```

### Prevention
- Use parameterized queries (prepared statements)
- Use ORMs (Prisma, TypeORM)
- Validate and sanitize all input
- Use allow-lists for validation
- Avoid shell command execution with user input
- Principle of least privilege (limited DB permissions)

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

### Security Headers

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

## A10:2021 - Server-Side Request Forgery (SSRF)

### Description
Fetching remote resources without validating user-supplied URL.

### Vulnerable Example

```typescript
// ❌ Vulnerable: Fetch arbitrary URLs
app.get('/fetch', async (req, res) => {
  const url = req.query.url;
  const response = await fetch(url); // Attacker can access internal services!
  res.send(await response.text());
});
// Attack: /fetch?url=http://localhost:6379/
// Can access Redis, databases, cloud metadata endpoint
```

### Secure Implementation

```typescript
// ✓ Secure: Validate URL against allow-list
const ALLOWED_DOMAINS = ['api.example.com', 'cdn.example.com'];

app.get('/fetch', async (req, res) => {
  const url = new URL(req.query.url);

  // Check protocol
  if (!['http:', 'https:'].includes(url.protocol)) {
    return res.status(400).json({ error: 'Invalid protocol' });
  }

  // Check domain
  if (!ALLOWED_DOMAINS.includes(url.hostname)) {
    return res.status(400).json({ error: 'Domain not allowed' });
  }

  // Prevent IP addresses and localhost
  if (/^\d+\.\d+\.\d+\.\d+$/.test(url.hostname) || url.hostname === 'localhost') {
    return res.status(400).json({ error: 'IP addresses not allowed' });
  }

  const response = await fetch(url.toString());
  res.send(await response.text());
});
```

### Cloud Metadata Endpoints

```typescript
// AWS: Block access to instance metadata
const BLOCKED_IPS = [
  '169.254.169.254', // AWS metadata
  '::ffff:169.254.169.254',
  '127.0.0.1',
  'localhost',
];

function isBlockedIP(hostname: string): boolean {
  return BLOCKED_IPS.some(ip => hostname.includes(ip));
}
```

### Prevention
- URL allow-lists (not deny-lists)
- Disable HTTP redirects
- Network segmentation
- Block private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Validate and sanitize URLs
- Use dedicated service for external requests

## Input Validation Patterns

### Zod Schema Validation

```typescript
import { z } from 'zod';

const UserInputSchema = z.object({
  email: z.string().email(),
  age: z.number().int().min(0).max(120),
  website: z.string().url().optional(),
  role: z.enum(['user', 'admin']),
});

app.post('/api/users', async (req, res) => {
  try {
    const validated = UserInputSchema.parse(req.body);
    // Safe to use validated data
  } catch (error) {
    return res.status(400).json({ error: 'Invalid input' });
  }
});
```

### Path Traversal Prevention

```typescript
import path from 'path';

// ❌ Vulnerable
const filePath = path.join(UPLOAD_DIR, req.query.file);
// Input: ../../etc/passwd

// ✓ Secure: Validate resolved path
function safeJoin(base: string, userPath: string): string | null {
  const resolved = path.resolve(base, userPath);
  if (!resolved.startsWith(path.resolve(base))) {
    return null; // Path traversal detected
  }
  return resolved;
}

const filePath = safeJoin(UPLOAD_DIR, req.query.file);
if (!filePath) {
  return res.status(400).json({ error: 'Invalid file path' });
}
```

### File Upload Validation

```typescript
import { z } from 'zod';

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

const FileUploadSchema = z.object({
  mimetype: z.enum(ALLOWED_MIME_TYPES as [string, ...string[]]),
  size: z.number().max(MAX_FILE_SIZE),
});

app.post('/upload', upload.single('file'), async (req, res) => {
  try {
    FileUploadSchema.parse({
      mimetype: req.file.mimetype,
      size: req.file.size,
    });

    // Additional check: Verify file signature (magic bytes)
    const buffer = await fs.promises.readFile(req.file.path);
    if (!isValidImage(buffer)) {
      throw new Error('Invalid file signature');
    }

    // Process file
  } catch (error) {
    return res.status(400).json({ error: 'Invalid file' });
  }
});
```

## Testing Security

### Access Control Tests

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

### Injection Prevention Tests

```typescript
describe('Injection Prevention', () => {
  test('prevents SQL injection', async () => {
    const response = await request(app)
      .get('/users')
      .query({ email: "' OR '1'='1" });

    expect(response.status).not.toBe(200);
  });

  test('prevents command injection', async () => {
    const response = await request(app)
      .get('/download')
      .query({ file: 'test.txt; rm -rf /' });

    expect(response.status).toBe(400);
    expect(response.body.error).toBe('Invalid filename');
  });

  test('prevents SSRF to localhost', async () => {
    const response = await request(app)
      .get('/fetch')
      .query({ url: 'http://localhost:6379/' });

    expect(response.status).toBe(400);
    expect(response.body.error).toContain('not allowed');
  });

  test('prevents SSRF to AWS metadata', async () => {
    const response = await request(app)
      .get('/fetch')
      .query({ url: 'http://169.254.169.254/latest/meta-data/' });

    expect(response.status).toBe(400);
  });

  test('prevents path traversal', async () => {
    const response = await request(app)
      .get('/download')
      .query({ file: '../../etc/passwd' });

    expect(response.status).toBe(400);
    expect(response.body.error).toBe('Invalid file path');
  });
});
```

### Security Configuration Tests

```typescript
describe('Security Configuration', () => {
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
