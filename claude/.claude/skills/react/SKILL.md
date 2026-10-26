---
name: react
description: React rules and preferences. Workers read it when a task brief names this file.
disable-model-invocation: true
---

## Types

- Extend HTML element attribute types for prop interfaces.
- Use generics for components that show many items or use the render-prop pattern.
- Use discriminated unions for variants.
- Hooks returning many values: return a tuple with `as const`.
- Context hooks: throw if the context has no value.

## Server vs client components

- Without a directive, this is a server component (data fetching, DB access, large deps, SEO).
- With `'use client'`, this is a client component.
- It includes interactivity and state.
- It also includes effects, browser APIs, and hooks.
- Server components import client components. Client components never import server components.
- Server components use top-level async or await. Client components render on the server (hydration) and on the client.

## Hooks

- Prefer `useTransition` for non-blocking submissions.
- Prefer `useOptimistic` for instant UI before the server replies.
- Prefer `use()` to unwrap promises or context in render.
- Prefer `useActionState` for `Server Actions` with `progressive enhancement`.
- Call hooks only at the top level, never conditionally.
- Use the updater-function pattern (`setState(prev => ...)`) when new state must use the previous state.
- Clean up subscribing effects.
- Cancel effect work that is not done, with `AbortController`.

## Framework routing

- Next.js App Router: `generateMetadata`, `generateStaticParams`, `export const revalidate`, stream slow content with `<Suspense>`.
- Remix / React Router v7: `loader` for reads, `action` for writes, `useLoaderData`, `<Form method="post">`, `useFetcher` for optimistic UI.

## Performance

- Memoize expensive renders/computations (`React.memo`, `useMemo`, `useCallback`) — not by default.
- Code-split at the routing level with `lazy()` + `<Suspense>`.
- Virtualize when you show above roughly 100 items.
- Prefer Server Components or React Query/SWR to cache data.
- Prefer them above ad hoc state in the client.

## Forms & validation

- `React Hook Form` with a Zod resolver: set the schema first.
- Get the type from the schema with `z.infer`.
- Prefer Next.js `Server Actions` with `useTransition` for `progressive enhancement` above client-only submission.

## Styling & responsive design

- Tailwind: write mobile-first.
- Start with the smallest-screen styles. Add `md:` and `lg:` overrides on top.
- Keep `@apply` to a minimum.
- Touch targets: 44px or more.
- Use CSS variables for colors that change with the theme.
- Breakpoints: the smallest screen is mobile, `sm:` 640px+, `md:` 768px+, `lg:` 1024px+, `xl:` 1280px+.
- ShadCN UI: use `cva` for variants, not hand-rolled logic.
- Mobile nav: use a panel or sheet pattern, hidden on desktop.

## State management

- Server data: use React Query or SWR on the client side.
- In Server Components, fetch straight from the source.
- Local state: `useState`/`useReducer`. Cross-component state: Zustand or Context, not prop drilling.
- Input state: `react-hook-form`. Shareable/filter state: `useSearchParams`.

## Testing & error handling

- Query sequence, by importance: `getByRole` first, `getByLabelText` next, `getByText` last.
- Prevent `getByTestId`.
- Test behavior only through the public API.
- Put route-level UI in an error boundary with a friendly fallback.
- Next.js uses `error.tsx` for this.
- Client components use try/catch with state, or `form.formState.errors`.
