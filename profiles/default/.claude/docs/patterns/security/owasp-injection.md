# OWASP: Injection and SSRF

Injection attacks and Server-Side Request Forgery prevention patterns for TypeScript applications.

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

### Prevention
- Use parameterized queries (prepared statements)
- Use ORMs (Prisma, TypeORM)
- Validate and sanitize all input
- Use allow-lists for validation
- Avoid shell command execution with user input
- Principle of least privilege (limited DB permissions)

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

## Testing Injection Vulnerabilities

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

## Related

- [OWASP Authentication](./owasp-auth.md) - Access control and authentication failures
- [OWASP Cryptography](./owasp-crypto.md) - Cryptographic failures and misconfigurations
- [Input Validation Patterns](./input-validation.md) - Comprehensive validation strategies
