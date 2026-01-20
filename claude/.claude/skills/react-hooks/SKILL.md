---
name: react-hooks
description: React hooks patterns. Custom hooks with TypeScript, Context patterns, useState/useEffect best practices, performance optimization with useMemo/useCallback.
---

# React Hooks

Comprehensive patterns for React hooks including state management, side effects, performance optimization, and custom hooks with TypeScript.

## State Hooks

### useState: Functional Updates

```typescript
// ❌ Avoid - stale closure issue
const [count, setCount] = useState(0);

useEffect(() => {
  const interval = setInterval(() => {
    setCount(count + 1); // Always uses initial count (0)
  }, 1000);
  return () => clearInterval(interval);
}, []); // Missing count in deps - incorrect

// ✓ Correct - functional update
useEffect(() => {
  const interval = setInterval(() => {
    setCount(prev => prev + 1); // Always uses current state
  }, 1000);
  return () => clearInterval(interval);
}, []); // Empty deps correct - no external dependencies
```

**When to use functional updates:**
- New state depends on previous state
- State updater used in callbacks with empty deps
- Avoiding stale closure bugs

### useState: Lazy Initialization

```typescript
// ❌ Expensive computation runs every render
const [data, setData] = useState(expensiveComputation());

// ✓ Computation runs only once on mount
const [data, setData] = useState(() => expensiveComputation());

// Examples of expensive initialization
const [cart, setCart] = useState(() => JSON.parse(localStorage.getItem('cart') || '[]'));
const [config, setConfig] = useState(() => loadConfigFromIndexedDB());
```

**When to use lazy initialization:**
- Reading from localStorage/sessionStorage
- Parsing large data structures
- Computing derived state from props
- Any synchronous operation taking >1ms

### useRef: Mutable Values Without Re-renders

```typescript
// ✓ DOM references
const inputRef = useRef<HTMLInputElement>(null);

useEffect(() => {
  inputRef.current?.focus();
}, []);

return <input ref={inputRef} />;

// ✓ Store mutable values (doesn't trigger re-render)
const intervalRef = useRef<number | null>(null);

const startTimer = () => {
  intervalRef.current = setInterval(() => tick(), 1000);
};

const stopTimer = () => {
  if (intervalRef.current) {
    clearInterval(intervalRef.current);
    intervalRef.current = null;
  }
};

// ✓ Store callback without triggering re-renders
const callbackRef = useRef(callback);
callbackRef.current = callback;

useEffect(() => {
  const handler = () => callbackRef.current();
  // handler always calls latest callback
}, []); // Empty deps - ref never changes
```

**useRef vs useState:**
- Use `useState` when change should trigger re-render
- Use `useRef` when change should NOT trigger re-render
- Refs persist across renders but don't cause updates

---

## Effect Hooks

### useEffect: Cleanup Functions

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

### useEffect: Dependency Arrays

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

## Performance Hooks

### useMemo: Memoize Expensive Calculations

```typescript
function DataTable({ data, filterText }: { data: Item[]; filterText: string }) {
  // ✓ Memoize expensive filtering operation
  const filteredData = useMemo(() => {
    return data.filter(item =>
      item.name.toLowerCase().includes(filterText.toLowerCase())
    ).sort((a, b) => a.name.localeCompare(b.name));
  }, [data, filterText]);

  return <Table data={filteredData} />;
}
```

**When to use useMemo:**
- Expensive computations (sorting, filtering large arrays)
- Creating objects passed as props to memoized components
- Calculations that run on every render but rarely change
- NOT for cheap operations (string concatenation, simple math)

### useCallback: Memoize Function References

```typescript
function SearchBox({ onSearch }: { onSearch: (query: string) => void }) {
  const [query, setQuery] = useState('');

  // ✓ Memoize callback to prevent child re-renders
  const handleSearch = useCallback(() => {
    onSearch(query);
  }, [query, onSearch]);

  return (
    <div>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      <ExpensiveButton onClick={handleSearch} />
    </div>
  );
}
```

**When to use useCallback:**
- Passing callbacks to memoized child components
- Callbacks in dependency arrays of other hooks
- Callbacks passed to custom hooks
- NOT for event handlers in non-memoized components

### React.memo: Component Memoization

```typescript
// ✓ Memoize expensive component
const ExpensiveListItem = React.memo<{ item: Item; onClick: (id: string) => void }>(
  ({ item, onClick }) => {
    return (
      <div onClick={() => onClick(item.id)}>
        <ExpensiveVisualization data={item.data} />
      </div>
    );
  }
);

// ✓ Custom comparison function
const UserCard = React.memo<{ user: User }>(
  ({ user }) => {
    return <div>{user.name} - {user.email}</div>;
  },
  (prevProps, nextProps) => {
    // Only re-render if name or email changed
    return prevProps.user.name === nextProps.user.name &&
           prevProps.user.email === nextProps.user.email;
  }
);
```

**When to use React.memo:**
- Component renders often with same props
- Component is expensive to render
- Component receives complex object props
- NOT for components that always receive different props

### useTransition: Non-Blocking Updates

```typescript
function SearchResults() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Item[]>([]);
  const [isPending, startTransition] = useTransition();

  const handleSearch = (newQuery: string) => {
    setQuery(newQuery);

    // Mark expensive update as non-urgent
    startTransition(() => {
      const filtered = expensiveSearch(newQuery);
      setResults(filtered);
    });
  };

  return (
    <div>
      <input value={query} onChange={(e) => handleSearch(e.target.value)} />
      {isPending ? <Spinner /> : <ResultsList results={results} />}
    </div>
  );
}
```

**When to use useTransition:**
- Expensive state updates (filtering, sorting large lists)
- Keep UI responsive during updates
- Differentiate urgent vs non-urgent updates

### useDeferredValue: Defer Expensive Renders

```typescript
function SearchResults({ query }: { query: string }) {
  // Defer expensive filtering until higher priority updates complete
  const deferredQuery = useDeferredValue(query);

  const results = useMemo(() => {
    return expensiveSearch(deferredQuery);
  }, [deferredQuery]);

  return (
    <div>
      {query !== deferredQuery && <Spinner />}
      <ResultsList results={results} />
    </div>
  );
}
```

**When to use useDeferredValue:**
- Expensive derived values from props/state
- Keep input responsive while expensive computation runs
- Alternative to debouncing with better UX

### Performance Anti-Patterns

```typescript
// ❌ Don't optimize everything
function SimpleComponent({ name }: { name: string }) {
  // Unnecessary - string concatenation is cheap
  const greeting = useMemo(() => `Hello, ${name}`, [name]);

  // Unnecessary - component isn't expensive
  const handleClick = useCallback(() => {
    console.log(name);
  }, [name]);

  return <div onClick={handleClick}>{greeting}</div>;
}

// ✓ Keep simple
function SimpleComponent({ name }: { name: string }) {
  const greeting = `Hello, ${name}`;
  const handleClick = () => console.log(name);

  return <div onClick={handleClick}>{greeting}</div>;
}
```

### Optimization Decision Guide

```
Performance issue? → No → Don't optimize
                   → Yes ↓

Profile with React DevTools
                   ↓

Identify slow component
                   ↓

Is it rendering too often? → Yes → React.memo or split state
                            → No ↓

Is calculation expensive? → Yes → useMemo
                          → No ↓

Are callbacks causing re-renders? → Yes → useCallback
                                  → No ↓

Is update blocking UI? → Yes → useTransition or useDeferredValue
                       → No → Profile more deeply
```

**Optimization techniques (in order of effectiveness):**
1. Split components (separate changing from static state)
2. Move state down (closer to where it's used)
3. Lift content up (children as props pattern)
4. React.memo for expensive components
5. useMemo for expensive calculations
6. useCallback for callbacks passed to memoized components

---

## Custom Hooks

### Typed Custom Hook: Basic Pattern

```typescript
function useLocalStorage<T>(key: string, initialValue: T) {
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch {
      return initialValue;
    }
  });

  const setValue = (value: T | ((val: T) => T)) => {
    const valueToStore = value instanceof Function ? value(storedValue) : value;
    setStoredValue(valueToStore);
    window.localStorage.setItem(key, JSON.stringify(valueToStore));
  };

  return [storedValue, setValue] as const;
}

// Usage with full type inference
const [theme, setTheme] = useLocalStorage<'light' | 'dark'>('theme', 'light');
setTheme('dark'); // Type-safe - only 'light' | 'dark' allowed
```

**Key patterns:**
- ✓ Generic type parameter for flexibility
- ✓ Lazy initialization with function (only runs once)
- ✓ Return `as const` for tuple type inference
- ✓ Handle both direct values and updater functions
- ✓ Error handling for failures

**Return type patterns:**
```typescript
// Tuple - useState-like API
return [value, setValue] as const;

// Object - named properties
return { value, setValue, reset };

// Single value - simple hooks
return value;
```

### usePrevious: Track Previous Value

```typescript
function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T>();

  useEffect(() => {
    ref.current = value;
  }, [value]);

  return ref.current;
}

// Usage - compare current and previous
function Counter() {
  const [count, setCount] = useState(0);
  const prevCount = usePrevious(count);

  return (
    <div>
      <p>Current: {count}</p>
      <p>Previous: {prevCount ?? 'N/A'}</p>
      <p>Changed by: {prevCount !== undefined ? count - prevCount : 0}</p>
      <button onClick={() => setCount(c => c + 1)}>Increment</button>
    </div>
  );
}
```

**Use cases:**
- Animation directions (slide left vs right)
- Detecting value changes
- Undo/redo functionality
- Comparing render values

### useMediaQuery: Responsive Hooks

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

### useAsync: Async Operations with Cleanup

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
    setData(null);
    setError(null);
    setIsLoading(false);
  }, []);

  return { data, error, isLoading, execute, reset };
}
```

### When to Create Custom Hooks

**✓ Good candidates for custom hooks:**

Reusable stateful logic:
```typescript
// Used in multiple components
useLocalStorage, useMediaQuery, useAsync
```

Complex logic with multiple hooks:
```typescript
function useForm<T>(initialValues: T) {
  const [values, setValues] = useState(initialValues);
  const [errors, setErrors] = useState({});
  const [touched, setTouched] = useState({});

  // Multiple hooks working together
  return { values, errors, touched, handleChange, handleBlur, handleSubmit };
}
```

Side effects with cleanup:
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

**❌ Keep inline instead:**

Single useState with no logic:
```typescript
// Don't create hook - too simple
function useCounter() {
  return useState(0);
}

// Keep inline
const [count, setCount] = useState(0);
```

One-off component-specific logic:
```typescript
// Don't extract if only used in one place
function useSpecificFormLogic() {
  // Complex but specific to one component
}
```

Simple derived values:
```typescript
// Don't create hook - keep inline
const fullName = `${firstName} ${lastName}`;
```

**Decision tree:**
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

## Context Patterns

### Basic Context Setup

```typescript
interface AuthContextType {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  isLoading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}

function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    checkAuth().then(setUser).finally(() => setIsLoading(false));
  }, []);

  const login = async (email: string, password: string) => {
    const user = await loginUser(email, password);
    setUser(user);
  };

  const logout = () => {
    logoutUser();
    setUser(null);
  };

  const value = { user, login, logout, isLoading };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// Usage
function Dashboard() {
  const { user, logout, isLoading } = useAuth(); // Type-safe

  if (isLoading) return <Spinner />;
  if (!user) return <Login />;

  return (
    <div>
      <p>Welcome, {user.name}</p>
      <button onClick={logout}>Logout</button>
    </div>
  );
}
```

**Why `undefined` in context type:**
- Context starts as `undefined` before provider mounts
- Forces consumers to handle missing provider case
- Hook throws descriptive error instead of runtime null errors

**Alternative: Default value (avoid)**
```typescript
// ❌ Avoid - masks missing provider errors
const AuthContext = createContext<AuthContextType>({
  user: null,
  login: async () => {},
  logout: () => {},
  isLoading: false
});
```

### Advanced Context: Actions and State Separation

```typescript
interface TodoState {
  todos: Todo[];
  filter: 'all' | 'active' | 'completed';
}

interface TodoActions {
  addTodo: (text: string) => void;
  toggleTodo: (id: string) => void;
  deleteTodo: (id: string) => void;
  setFilter: (filter: TodoState['filter']) => void;
}

// Separate contexts for state and actions (optimization)
const TodoStateContext = createContext<TodoState | undefined>(undefined);
const TodoActionsContext = createContext<TodoActions | undefined>(undefined);

function useTodoState() {
  const context = useContext(TodoStateContext);
  if (!context) throw new Error('useTodoState must be used within TodoProvider');
  return context;
}

function useTodoActions() {
  const context = useContext(TodoActionsContext);
  if (!context) throw new Error('useTodoActions must be used within TodoProvider');
  return context;
}

function TodoProvider({ children }: { children: React.ReactNode }) {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [filter, setFilter] = useState<'all' | 'active' | 'completed'>('all');

  // Actions memoized to prevent unnecessary re-renders
  const actions = useMemo<TodoActions>(() => ({
    addTodo: (text: string) => {
      setTodos(prev => [...prev, { id: crypto.randomUUID(), text, completed: false }]);
    },
    toggleTodo: (id: string) => {
      setTodos(prev => prev.map(t => t.id === id ? { ...t, completed: !t.completed } : t));
    },
    deleteTodo: (id: string) => {
      setTodos(prev => prev.filter(t => t.id !== id));
    },
    setFilter
  }), []);

  const state = { todos, filter };

  return (
    <TodoStateContext.Provider value={state}>
      <TodoActionsContext.Provider value={actions}>
        {children}
      </TodoActionsContext.Provider>
    </TodoStateContext.Provider>
  );
}

// Usage - components only re-render when used context changes
function TodoList() {
  const { todos, filter } = useTodoState(); // Re-renders on state change
  const { toggleTodo } = useTodoActions(); // Doesn't cause re-renders

  const filtered = todos.filter(t => {
    if (filter === 'active') return !t.completed;
    if (filter === 'completed') return t.completed;
    return true;
  });

  return (
    <ul>
      {filtered.map(todo => (
        <li key={todo.id} onClick={() => toggleTodo(todo.id)}>
          {todo.text}
        </li>
      ))}
    </ul>
  );
}
```

**Benefits of split contexts:**
- ✓ Components using only actions don't re-render on state changes
- ✓ Better performance for large apps
- ✓ Clearer separation of concerns

**When to split:**
- Large context with frequent updates
- Many components need actions but not state
- Performance profiling shows unnecessary re-renders

---

## Summary Checklist

**Custom hooks:**
- ✓ Name starts with `use` (React convention)
- ✓ Generic type parameters for reusability
- ✓ Return types explicitly declared (`as const` for tuples)

**Context:**
- ✓ Type as `Type | undefined`, not `Type | null`
- ✓ Custom hook validates context exists
- ✓ Split state/actions for performance (large apps)
- ✓ Memoize context values when appropriate

**useState:**
- ✓ Use functional updates when state depends on previous value
- ✓ Use lazy initialization for expensive initial values
- ✓ Use refs for values that shouldn't trigger re-renders

**useEffect:**
- ✓ Cleanup functions for side effects
- ✓ Include ALL dependencies (follow ESLint exhaustive-deps)
- ✓ Use AbortController for fetch requests
- ✓ Handle loading, error, and success states

**Performance:**
- ✓ Measure before optimizing
- ✓ Profile to find real bottlenecks
- ✓ Start with component structure (split, move, lift)
- ✓ Use memoization sparingly for proven slow code
- ✗ Don't memoize everything (adds overhead)
- ✗ Don't optimize without measuring
