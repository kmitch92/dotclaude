# Refactoring Example: User Registration

Step-by-step refactoring demonstrating progressive improvement from poor to production-ready code.

## Step 0: Poor Code (Starting Point)

```typescript
function registerUser(email: string, username: string, password: string) {
  // Manual validation (15+ lines)
  if (!email || email.length === 0) throw new Error('Email required');
  if (!email.includes('@')) throw new Error('Invalid email');
  if (!username || username.length < 3) throw new Error('Username too short');
  if (username.length > 20) throw new Error('Username too long');
  if (!password || password.length < 8) throw new Error('Password too short');
  if (!/[A-Z]/.test(password)) throw new Error('Need uppercase');
  if (!/[a-z]/.test(password)) throw new Error('Need lowercase');
  if (!/[0-9]/.test(password)) throw new Error('Need number');

  const normalizedEmail = email.toLowerCase().trim();
  const existing = findUserByEmail(normalizedEmail);
  if (existing !== null) throw new Error('User exists');

  const hashedPassword = hashPassword(password);
  const user = {
    id: generateId(),
    email: normalizedEmail,
    username: username.trim(),
    password: hashedPassword,
    isActive: true,
    createdAt: new Date()
  };

  saveUser(user);
  sendEmail(user.email, 'Welcome!', 'Thanks for registering');
  return user;
}
```

**Problems:**
- Manual validation instead of schemas
- Multiple responsibilities (validation, persistence, email)
- Side effects mixed with logic
- Hard to test

## Step 1: Use Schema for Validation

```typescript
import { z } from 'zod';

const RegisterUserInputSchema = z.object({
  email: z.string().email(),
  username: z.string().min(3).max(20),
  password: z.string()
    .min(8)
    .regex(/[A-Z]/, 'Password must contain uppercase')
    .regex(/[a-z]/, 'Password must contain lowercase')
    .regex(/[0-9]/, 'Password must contain number')
});

type RegisterUserInput = z.infer<typeof RegisterUserInputSchema>;

function registerUser(input: RegisterUserInput) {
  const validated = RegisterUserInputSchema.parse(input);
  const normalizedEmail = validated.email.toLowerCase().trim();

  const existing = findUserByEmail(normalizedEmail);
  if (existing !== null) throw new Error('User exists');

  const hashedPassword = hashPassword(validated.password);
  const user = {
    id: generateId(),
    email: normalizedEmail,
    username: validated.username.trim(),
    password: hashedPassword,
    isActive: true,
    createdAt: new Date()
  };

  saveUser(user);
  sendEmail(user.email, 'Welcome!', 'Thanks for registering');
  return user;
}
```

**Improvements:**
- Removed 15+ lines of manual validation
- Single source of truth for validation
- Consistent error messages

## Step 2: Extract Functions (Single Responsibility)

```typescript
// Pure function: validate uniqueness
function ensureEmailUnique(email: string): void {
  const existing = findUserByEmail(email);
  if (existing !== null) throw new Error('User exists');
}

// Pure function: create user entity
function createUserEntity(input: RegisterUserInput, hashedPassword: string): User {
  return {
    id: generateId(),
    email: input.email.toLowerCase().trim(),
    username: input.username.trim(),
    password: hashedPassword,
    isActive: true,
    createdAt: new Date()
  };
}

// Pure function: send notification
function sendWelcomeNotification(email: string): void {
  sendEmail(email, 'Welcome!', 'Thanks for registering');
}

// Orchestrator: coordinates flow
function registerUser(input: RegisterUserInput): User {
  const validated = RegisterUserInputSchema.parse(input);
  const normalizedEmail = validated.email.toLowerCase().trim();

  ensureEmailUnique(normalizedEmail);
  const hashedPassword = hashPassword(validated.password);
  const user = createUserEntity(validated, hashedPassword);

  saveUser(user);
  sendWelcomeNotification(user.email);
  return user;
}
```

**Improvements:**
- Each function has single responsibility
- `registerUser` is readable orchestrator
- Functions testable independently

## Step 3: Dependency Injection (Final)

```typescript
// Dependencies interfaces
type UserRepository = {
  findByEmail: (email: string) => User | null;
  save: (user: User) => void;
};

type PasswordHasher = {
  hash: (password: string) => string;
};

type EmailService = {
  send: (to: string, subject: string, body: string) => void;
};

type IdGenerator = {
  generate: () => string;
};

// Pure functions with injected dependencies
function ensureEmailUnique(email: string, repository: UserRepository): void {
  const existing = repository.findByEmail(email);
  if (existing !== null) throw new Error('User exists');
}

function createUserEntity(
  input: RegisterUserInput,
  hashedPassword: string,
  idGenerator: IdGenerator
): User {
  return {
    id: idGenerator.generate(),
    email: input.email.toLowerCase().trim(),
    username: input.username.trim(),
    password: hashedPassword,
    isActive: true,
    createdAt: new Date()
  };
}

// Factory: returns configured function
function createRegisterUser(
  repository: UserRepository,
  hasher: PasswordHasher,
  emailService: EmailService,
  idGenerator: IdGenerator
) {
  return (input: RegisterUserInput): User => {
    const validated = RegisterUserInputSchema.parse(input);
    const normalizedEmail = validated.email.toLowerCase().trim();

    ensureEmailUnique(normalizedEmail, repository);
    const hashedPassword = hasher.hash(validated.password);
    const user = createUserEntity(validated, hashedPassword, idGenerator);

    repository.save(user);
    emailService.send(user.email, 'Welcome!', 'Thanks');
    return user;
  };
}

// Production configuration
const registerUser = createRegisterUser(
  productionRepository,
  productionHasher,
  productionEmailService,
  productionIdGenerator
);
```

**Improvements:**
- Fully testable without real services
- Dependencies explicit and replaceable
- Easy to mock in tests

## Test Example

```typescript
import { describe, it, expect, vi } from 'vitest';

describe('User Registration', () => {
  it('should register new user with valid input', () => {
    // Mock dependencies
    const mockRepository: UserRepository = {
      findByEmail: vi.fn(() => null),
      save: vi.fn()
    };

    const mockHasher: PasswordHasher = {
      hash: vi.fn(() => 'hashed-password')
    };

    const mockEmailService: EmailService = {
      send: vi.fn()
    };

    const mockIdGenerator: IdGenerator = {
      generate: vi.fn(() => 'test-id-123')
    };

    // Create testable function
    const registerUser = createRegisterUser(
      mockRepository,
      mockHasher,
      mockEmailService,
      mockIdGenerator
    );

    // Execute
    const user = registerUser({
      email: 'TEST@EXAMPLE.COM',
      username: 'testuser',
      password: 'SecurePass1'
    });

    // Assert
    expect(user.id).toBe('test-id-123');
    expect(user.email).toBe('test@example.com'); // normalized
    expect(mockRepository.findByEmail).toHaveBeenCalledWith('test@example.com');
    expect(mockHasher.hash).toHaveBeenCalledWith('SecurePass1');
    expect(mockRepository.save).toHaveBeenCalledWith(user);
    expect(mockEmailService.send).toHaveBeenCalled();
  });

  it('should throw error when user exists', () => {
    const mockRepository: UserRepository = {
      findByEmail: vi.fn(() => ({
        id: 'existing',
        email: 'test@example.com',
        username: 'existing',
        password: 'hashed',
        isActive: true,
        createdAt: new Date()
      })),
      save: vi.fn()
    };

    const registerUser = createRegisterUser(
      mockRepository,
      { hash: () => 'hashed' },
      { send: () => {} },
      { generate: () => 'id' }
    );

    expect(() =>
      registerUser({
        email: 'test@example.com',
        username: 'testuser',
        password: 'SecurePass1'
      })
    ).toThrow('User exists');
  });
});
```

## Key Takeaways

1. **Schema-First**: Replace manual validation with schemas
2. **Guard Clauses**: Check errors early and exit
3. **Single Responsibility**: Each function does one thing
4. **Dependency Injection**: Make dependencies explicit for testability
5. **Incremental Refactoring**: Small steps, tests passing at each stage

## Related
- [Refactoring Patterns](../patterns/refactoring/common-patterns.md)
- [When to Refactor](../patterns/refactoring/when-to-refactor.md)
