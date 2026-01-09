# React Hooks: State Management

Custom hooks, context patterns, and state management with TypeScript.

## Custom Hook Fundamentals

### Typed Custom Hook - Basic Pattern

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

---

## Context Patterns with TypeScript

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

## Common State Management Hooks

### usePrevious - Track Previous Value

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

---

## useState Best Practices

### Functional Updates

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

### Lazy Initialization

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

---

## useRef: Mutable Values Without Re-renders

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

## Summary

**Custom hooks checklist:**
- ✓ Name starts with `use` (React convention)
- ✓ Generic type parameters for reusability
- ✓ Return types explicitly declared (`as const` for tuples)

**Context checklist:**
- ✓ Type as `Type | undefined`, not `Type | null`
- ✓ Custom hook validates context exists
- ✓ Split state/actions for performance (large apps)
- ✓ Memoize context values when appropriate

**useState tips:**
- ✓ Use functional updates when state depends on previous value
- ✓ Use lazy initialization for expensive initial values
- ✓ Use refs for values that shouldn't trigger re-renders

See also:
- @~/.claude/docs/patterns/react/hooks-effects.md for side effects and cleanup
- @~/.claude/docs/patterns/react/hooks-performance.md for optimization patterns
