---
name: react
description: React rules and preferences. Read by workers when a task brief lists this file.
disable-model-invocation: true
---

## Types

- Extend HTML element attribute types for prop interfaces.
- Use generics for reusable list/render-prop components; discriminated unions for variants.
- Hooks returning multiple values: return a tuple with `as const`.
- Context hooks: throw if the context value is undefined.

## Server vs client components

- No directive = server component (data fetching, DB access, large deps, SEO).
- `'use client'` = client component (interactivity, state, effects, browser APIs, hooks).
- Server components import client components, never the reverse.
- Server components use top-level async/await; client components render on both server (hydration) and client.

## Hooks

- Prefer `useTransition` for non-blocking submissions, `useOptimistic` for instant UI before server confirmation, `use()` to unwrap promises/context in render, `useActionState` for progressively-enhanced server actions.
- Call hooks only at the top level, never conditionally.
- Use the updater-function form (`setState(prev => ...)`) when new state depends on old.
- Clean up subscribing effects; cancel in-flight async effect work with `AbortController`.

## Framework routing

- Next.js App Router: `generateMetadata`, `generateStaticParams`, `export const revalidate`, stream slow content with `<Suspense>`.
- Remix / React Router v7: `loader` for reads, `action` for writes, `useLoaderData`, `<Form method="post">`, `useFetcher` for optimistic UI.

## Performance

- Memoize expensive renders/computations (`React.memo`, `useMemo`, `useCallback`) — not by default.
- Code-split at the route level with `lazy()` + `<Suspense>`.
- Virtualize lists over roughly 100 items.
- Prefer Server Components or React Query/SWR for caching over ad hoc client state.

## Forms & validation

- React Hook Form with a Zod resolver; define the schema first, derive the form type with `z.infer`.
- Prefer Next.js Server Actions with `useTransition` for progressive enhancement over client-only submission.

## Styling & responsive design

- Tailwind: mobile-first (base, then `md:`, `lg:` overrides); minimal `@apply`; touch targets at least 44px; CSS variables for themeable colors.
- Breakpoints: base = mobile, `sm:` 640px+, `md:` 768px+, `lg:` 1024px+, `xl:` 1280px+.
- ShadCN UI: use `cva` for variants, not hand-rolled logic. Mobile nav: drawer/sheet pattern, hidden on desktop.

## State management

- Server data: React Query/SWR client-side, direct fetch in Server Components.
- Local state: `useState`/`useReducer`. Cross-component state: Zustand or Context, not prop drilling.
- Form state: react-hook-form. Shareable/filter state: `useSearchParams`.

## Testing & error handling

- Query priority: `getByRole` > `getByLabelText` > `getByText`; avoid `getByTestId`; test behavior through the public API only.
- Wrap route-level UI in an error boundary with a friendly fallback; Next.js uses `error.tsx`; client components use try/catch with state or `form.formState.errors`.
