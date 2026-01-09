# OAuth 2.0 and OIDC Patterns

OAuth 2.0 authorization and OpenID Connect authentication implementation patterns for TypeScript applications.

## Overview

- **OAuth 2.0**: Authorization framework (grants access to resources)
- **OIDC**: Identity layer on top of OAuth 2.0 (authentication)

## Authorization Code Flow (Recommended)

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

  // Store state in session for validation
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

  // Verify and decode ID token
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
    update: {
      name: userInfo.name,
    },
  });

  // Create session
  req.session.userId = user.id;
  res.redirect('/dashboard');
});
```

## PKCE for Public Clients

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

// Store code_verifier securely (session storage for web, secure storage for mobile)
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

## Multi-Provider OAuth

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

app.get('/auth/:provider/callback', async (req, res) => {
  const { provider } = req.params;
  const { code, state } = req.query;

  if (state !== req.session.oauthState) {
    return res.status(403).json({ error: 'Invalid state' });
  }

  if (provider !== req.session.oauthProvider) {
    return res.status(403).json({ error: 'Provider mismatch' });
  }

  const oauthProvider = providers[provider];
  const result = await oauthProvider.client.getToken({
    code,
    redirect_uri: `https://myapp.com/auth/${provider}/callback`,
  });

  const userInfo = await oauthProvider.getUserInfo(result.token.access_token);

  const user = await db.user.upsert({
    where: { email: userInfo.email },
    create: {
      email: userInfo.email,
      name: userInfo.name,
      oauthProvider: provider,
      oauthId: userInfo.id,
    },
    update: { name: userInfo.name },
  });

  req.session.userId = user.id;
  res.redirect('/dashboard');
});
```

## ID Token Verification

```typescript
import { JwksClient } from 'jwks-rsa';
import jwt from 'jsonwebtoken';

// Verify Google ID token
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

## Token Storage and Refresh

```typescript
// Store OAuth tokens in database
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

  // Refresh token
  const oauthProvider = providers[provider];
  const result = await oauthProvider.client.createToken({
    access_token: token.accessToken,
    refresh_token: token.refreshToken,
  }).refresh();

  // Update stored token
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

## Security Considerations

### State Parameter (CSRF Protection)

```typescript
// Always use state parameter to prevent CSRF
const state = crypto.randomBytes(16).toString('hex');
req.session.oauthState = state;

// Validate on callback
if (state !== req.session.oauthState) {
  return res.status(403).json({ error: 'Invalid state parameter' });
}

// Clear state after use
delete req.session.oauthState;
```

### Redirect URI Validation

```typescript
// Whitelist redirect URIs
const ALLOWED_REDIRECT_URIS = [
  'https://myapp.com/auth/google/callback',
  'https://myapp.com/auth/github/callback',
];

function validateRedirectUri(uri: string): boolean {
  return ALLOWED_REDIRECT_URIS.includes(uri);
}
```

### Nonce for ID Tokens (OIDC)

```typescript
// Add nonce to prevent token replay attacks
const nonce = crypto.randomBytes(16).toString('hex');
req.session.oidcNonce = nonce;

const authUri = oauth2.authorizeURL({
  redirect_uri: 'https://myapp.com/auth/callback',
  scope: 'openid email profile',
  state,
  nonce, // Include nonce
});

// Validate nonce in ID token
const payload = await verifyIdToken(idToken);
if (payload.nonce !== req.session.oidcNonce) {
  throw new Error('Invalid nonce');
}
```

## Testing OAuth Flows

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
    // Mock OAuth token exchange
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
