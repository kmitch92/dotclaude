# React Hooks: Side Effects and Cleanup

Effect hooks, cleanup patterns, dependency management, and async operations.

## useEffect: Cleanup Functions

```typescript
// ✓ Cleanup subscriptions
useEffect(() => {
  const subscription = subscribeToData(userId);
  return () => subscription.unsubscribe();
}, [userId]);

// ✓ Cleanup timers
useEffect(() => {
  const timer = setTimeout(() => showNotification(), 3000);
  return () => clearTimeout(timer);
}, []);

// ✓ Cleanup event listeners
useEffect(() => {
  const handler = () => console.log('resize');
  window.addEventListener('resize', handler);
  return () => window.removeEventListener('resize', handler);
}, []);

// ✓ Cleanup AbortController for fetch
useEffect(() => {
  const controller = new AbortController();

  async function loadData() {
    try {
      const data = await fetchData({ signal: controller.signal });
      setData(data);
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error(error);
      }
    }
  }

  loadData();
  return () => controller.abort();
}, []);
```

**Always cleanup:**
- Subscriptions (WebSocket, EventSource, RxJS)
- Timers (setTimeout, setInterval)
- Event listeners (window, document)
- Fetch requests (AbortController)
- Animation frames (requestAnimationFrame)

---

## Dependency Arrays: Common Patterns

```typescript
// ✓ Run once on mount
useEffect(() => {
  initializeApp();
}, []);

// ✓ Run when specific values change
useEffect(() => {
  loadUser(userId);
}, [userId]);

// ✓ Run when any dependency changes
useEffect(() => {
  saveData(formData, userId, timestamp);
}, [formData, userId, timestamp]);

// ❌ Avoid - missing dependencies (ESLint error)
useEffect(() => {
  loadUser(userId); // userId should be in deps
}, []);

// ✓ Include all dependencies
useEffect(() => {
  const handler = () => processData(data);
  window.addEventListener('resize', handler);
  return () => window.removeEventListener('resize', handler);
}, [data]); // Include data - handler uses it

// ✓ Or use ref for stable reference
const dataRef = useRef(data);
dataRef.current = data;

useEffect(() => {
  const handler = () => processData(dataRef.current);
  window.addEventListener('resize', handler);
  return () => window.removeEventListener('resize', handler);
}, []); // Empty deps - dataRef never changes
```

**Dependency best practices:**
- ✓ Include ALL dependencies (follow ESLint exhaustive-deps)
- ✓ Use functional updates to reduce dependencies
- ✓ Use refs for stable references when needed
- ✓ Extract constants outside component to avoid deps

---

## Common Side Effect Hooks

### useDebounce - Delay Rapid Updates

```typescript
**Use cases:**
- Search input (avoid API call on every keystroke)
- Window resize handlers
- Auto-save functionality
- Real-time validation

### useMediaQuery - Responsive Hooks

```typescript
function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(() => {
    if (typeof window === 'undefined') return false;
    return window.matchMedia(query).matches;
  });

  useEffect(() => {
    const mediaQuery = window.matchMedia(query);
    const handler = (event: MediaQueryListEvent) => setMatches(event.matches);

    mediaQuery.addEventListener('change', handler);
    return () => mediaQuery.removeEventListener('change', handler);
  }, [query]);

  return matches;
}

// Usage - responsive components
function Navigation() {
  const isMobile = useMediaQuery('(max-width: 768px)');

  return isMobile ? <MobileNav /> : <DesktopNav />;
}

// Common breakpoints
const useIsMobile = () => useMediaQuery('(max-width: 768px)');
const useIsTablet = () => useMediaQuery('(min-width: 769px) and (max-width: 1024px)');
const useIsDesktop = () => useMediaQuery('(min-width: 1025px)');
```


---

## Complete Example: Async Hook with Cleanup

```typescript
interface UseAsyncOptions<T> {
  immediate?: boolean;
  onSuccess?: (data: T) => void;
  onError?: (error: Error) => void;
}

interface UseAsyncReturn<T, Args extends any[]> {
  data: T | null;
  error: Error | null;
  isLoading: boolean;
  execute: (...args: Args) => Promise<void>;
  reset: () => void;
}

function useAsync<T, Args extends any[]>(
  asyncFn: (...args: Args) => Promise<T>,
  options: UseAsyncOptions<T> = {}
): UseAsyncReturn<T, Args> {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const execute = useCallback(
    async (...args: Args) => {
      setIsLoading(true);
      setError(null);

      try {
        const result = await asyncFn(...args);
        setData(result);
        options.onSuccess?.(result);
      } catch (err) {
        const error = err instanceof Error ? err : new Error(String(err));
        setError(error);
        options.onError?.(error);
      } finally {
        setIsLoading(false);
      }
    },
    [asyncFn, options]
  );

  const reset = useCallback(() => {

### Good Candidates for Custom Hooks

**✓ Reusable stateful logic:**
```typescript
// Used in multiple components
useLocalStorage, useDebounce, useMediaQuery
```

**✓ Complex logic with multiple hooks:**
```typescript
function useForm<T>(initialValues: T) {
  const [values, setValues] = useState(initialValues);
  const [errors, setErrors] = useState({});
  const [touched, setTouched] = useState({});

  // Multiple hooks working together
  return { values, errors, touched, handleChange, handleBlur, handleSubmit };
}
```

**✓ Side effects with cleanup:**
```typescript
function useWebSocket(url: string) {
  const [data, setData] = useState(null);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    const ws = new WebSocket(url);
    ws.onopen = () => setIsConnected(true);
    ws.onmessage = (e) => setData(JSON.parse(e.data));
    return () => ws.close();
  }, [url]);

  return { data, isConnected };
}
```

### Keep Inline Instead

**❌ Single useState with no logic:**
```typescript
// Don't create hook - too simple
function useCounter() {
  return useState(0);
}

// Keep inline
const [count, setCount] = useState(0);
```

**❌ One-off component-specific logic:**
```typescript
// Don't extract if only used in one place
function useSpecificFormLogic() {
  // Complex but specific to one component
}
```

**❌ Simple derived values:**
```typescript
// Don't create hook - keep inline
const fullName = `${firstName} ${lastName}`;
```

### Decision Tree

```
Does logic involve React hooks? → No → Regular function
                                → Yes ↓

Is it used in 2+ components? → No → Keep inline
                              → Yes ↓

Does it manage related state/effects? → No → Keep inline
                                      → Yes ↓

CREATE CUSTOM HOOK
```

---

## Summary

**Effect hooks checklist:**
- ✓ Cleanup functions for side effects
- ✓ Include ALL dependencies (follow ESLint exhaustive-deps)
- ✓ Use AbortController for fetch requests
- ✓ Handle loading, error, and success states

**Common patterns:**
- useDebounce for delayed updates
- useMediaQuery for responsive behavior
- useOnClickOutside for dropdown/modal close
- useAsync for async operations with cleanup

**When to create custom hook:**
- Logic reused in 2+ components
- Combines multiple hooks with related purpose
- Encapsulates complex side effects with cleanup
- NOT for trivial logic or one-off use cases

See also:
- @~/.claude/docs/patterns/react/hooks-state.md for state management
- @~/.claude/docs/patterns/react/hooks-performance.md for optimization patterns
