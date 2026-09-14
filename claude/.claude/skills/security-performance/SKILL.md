---
name: security-performance
description: Security and performance rules and preferences (OWASP, production readiness). Read by workers when a task brief lists this file.
disable-model-invocation: true
---

## Security principles

- Defense in depth (no single control is sufficient); least privilege; fail securely (an error never leaves a resource open); no security through obscurity.
- Validate all external input; mediate every resource access with an authorization check; audit security-relevant events.

## Security implementation

- Hash passwords with bcrypt (cost 12) or argon2 — never plaintext or a fast hash.
- Check authorization (ownership or role) on every resource access, not just authentication.
- Validate all input with a Zod schema at the boundary; use parameterized queries, never string-concatenated SQL.
- Rely on the framework's default output escaping; sanitize (e.g. DOMPurify) before rendering raw HTML from user input.
- Read secrets from environment variables or a secrets manager, validated with Zod — never hardcode.
- Set security headers: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `Content-Security-Policy`.

## Security severity

- Critical (zero tolerance, blocks production): SQL injection, missing auth, hardcoded secrets, XSS, IDOR, command injection.
- Warning: weak passwords, missing rate limiting, missing security headers, broad CORS, sensitive data in logs.
- Improvement: MFA for admins, audit logging, dependency vulnerability scans.

## Performance principles

- Measure before optimizing. Set budgets upfront. Optimize the critical path first (80/20 rule). Test at production-like scale.

## Performance implementation

- React: memoize expensive renders/computations; virtualize lists over roughly 100 items.
- Database: fix N+1 with a JOIN or eager load; index every query predicate; use connection pooling.
- Bundles: tree-shakeable imports and route-level code splitting.
- Caching: HTTP `Cache-Control` headers; an application cache (e.g. Redis) for expensive repeated computations.

## Performance budgets

- Bundle (gzipped): 200KB main, 300KB vendor, 500KB total.
- Load time: FCP 1.5s, TTI 3.0s, LCP 2.5s. API latency: p50 100ms, p95 500ms, p99 1000ms. DB query: simple 10ms, complex 50ms, max 100ms.

## Production gate

- Any Critical security issue blocks production release — fix before anything else.
- Bundle size, API latency, and DB query budgets above must be met, not just close.
