---
name: security-performance
description: Give the safety and performance rules and preferences, for OWASP and for production readiness. Workers read this file when a task brief names it.
disable-model-invocation: true
---

## Security principles

- Use defense in depth.
- Do not rely on one single control.
- Give the minimum privilege needed.
- If a function fails, it must keep each resource closed.
- Keep the system safe when an attacker knows how it works.
- Validate all external input.
- Check each resource access with an authorization check.
- Log each safety-relevant occurrence.

## Security implementation

- Hash passwords with bcrypt (cost 12) or argon2. Never use plaintext or a fast hash.
- Check authorization (ownership or role) on each resource access, not authentication alone.
- Validate all input with a Zod schema at the boundary.
- Use a parameterized query. Never build SQL with string concatenation.
- Trust the default output escaping of the framework.
- Sanitize raw HTML from user input, for example with DOMPurify, before you render it.
- Read secrets from environment variables or a secrets manager, validated with Zod — never hardcode.
- Set safety headers: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `Content-Security-Policy`.

## Security severity

### No tolerance: blocks production

- SQL `injection`, missing authentication, a hardcoded secret, XSS, IDOR, and command `injection`.

### Needs a fix soon

- A weak password, a missing rate limit, a missing header for safety, broad CORS, and sensitive data in a log.

### Worth improving

- MFA for an admin, a log for each audit, and a check for a dependency vulnerability.

## Performance principles

- Measure before you make it faster.
- Set the budget first.
- Find the most important path.
- Make that path faster, first (the 80/20 rule).
- Test it at a scale like production.

## Performance implementation

- React: memoize an expensive render or an expensive computation.
- React: make a large array virtual, when it holds roughly 100 items.
- Database: repair the N+1 pattern with a `JOIN`, or load the data eagerly.
- Database: put an index on each query predicate.
- Database: use connection pooling.
- Bundles: tree-shakeable imports and route-level code splitting.
- Cache: send the `Cache-Control` HTTP header.
- Cache: keep an application-level cache, for example Redis, for an expensive, repeated computation.

## Performance budgets

- Bundle, after gzip: 200KB for primary, 300KB for vendor, 500KB total.
- Load time: FCP at 1.5s, TTI at 3.0s, LCP at 2.5s.
- API latency: p50 at 100ms, p95 at 500ms, p99 at 1000ms.
- DB query time: a plain query at 10ms, a complex query at 50ms, the max at 100ms.

## Production gate

- A safety problem with no tolerance blocks the production release. Repair it first.
- The bundle budget, the API latency budget, and the DB query budget above must be met accurately, not approximately.
