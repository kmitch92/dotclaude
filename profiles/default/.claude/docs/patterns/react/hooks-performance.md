# React Hooks: Performance Optimization

Memoization patterns, performance optimization hooks, and when to optimize.

## useMemo and useCallback

### useMemo - Memoize Expensive Calculations

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

### useCallback - Memoize Function References

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

---

## React.memo - Component Memoization

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

---

## Common Performance Hooks

### useTransition - Non-Blocking Updates

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

### useDeferredValue - Defer Expensive Renders

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

---

## Optimization Patterns

### Stable References with useRef

```typescript
function Component({ onEvent }: { onEvent: () => void }) {
  // ✓ Keep latest callback without triggering re-renders
  const callbackRef = useRef(onEvent);
  callbackRef.current = onEvent;

  useEffect(() => {
    const handler = () => callbackRef.current();
    window.addEventListener('resize', handler);
    return () => window.removeEventListener('resize', handler);
  }, []); // Empty deps - ref never changes
}
```

### Avoid Inline Object Creation

```typescript
// ❌ Creates new object every render
function Parent() {
  return <Child style={{ padding: 10 }} />;
}

// ✓ Stable reference
const STYLE = { padding: 10 };

function Parent() {
  return <Child style={STYLE} />;
}

// ✓ Or use useMemo if style is dynamic
function Parent({ padding }: { padding: number }) {
  const style = useMemo(() => ({ padding }), [padding]);
  return <Child style={style} />;
}
```

### Lazy Initialization

```typescript
// ❌ Expensive computation runs every render
const [state, setState] = useState(expensiveComputation());

// ✓ Computation runs only once
const [state, setState] = useState(() => expensiveComputation());
```

---

## Performance Anti-Patterns

### Premature Optimization

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

### Over-Memoization

```typescript
// ❌ Too much memoization adds overhead
const MemoizedEverything = React.memo<Props>(({ data }) => {
  const processedData = useMemo(() => data, [data]); // Pointless
  const handleClick = useCallback(() => {}, []); // Pointless if no children use it
  const simple = useMemo(() => 2 + 2, []); // Way too simple

  return <div>{processedData}</div>;
});
```

---

## Profiling and Measurement

### React DevTools Profiler

```typescript
// Wrap component to measure render performance
import { Profiler } from 'react';

function App() {
  const onRenderCallback = (
    id: string,
    phase: 'mount' | 'update',
    actualDuration: number,
    baseDuration: number
  ) => {
    console.log(`${id} (${phase}) took ${actualDuration}ms`);
  };

  return (
    <Profiler id="App" onRender={onRenderCallback}>
      <ExpensiveComponent />
    </Profiler>
  );
}
```

### Performance Measurement Hook

```typescript
function useRenderCount(componentName: string) {
  const renderCount = useRef(0);

  useEffect(() => {
    renderCount.current += 1;
    console.log(`${componentName} rendered ${renderCount.current} times`);
  });
}

// Usage
function MyComponent() {
  useRenderCount('MyComponent');
  // ...
}
```

---

## Decision Guide: When to Optimize

### Measure First

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

### Optimization Checklist

Before optimizing:
- [ ] Measure actual performance issue
- [ ] Profile to identify bottleneck
- [ ] Verify optimization helps (measure again)

Optimization techniques (in order of effectiveness):
1. Split components (separate changing from static state)
2. Move state down (closer to where it's used)
3. Lift content up (children as props pattern)
4. React.memo for expensive components
5. useMemo for expensive calculations
6. useCallback for callbacks passed to memoized components

---

## Summary

**Memoization:**
- useMemo for expensive calculations
- useCallback for callbacks passed to memoized components
- React.memo for expensive component renders

**Modern optimization:**
- useTransition for non-blocking updates
- useDeferredValue for deferred expensive renders

**Best practices:**
- ✓ Measure before optimizing
- ✓ Profile to find real bottlenecks
- ✓ Start with component structure (split, move, lift)
- ✓ Use memoization sparingly for proven slow code
- ✗ Don't memoize everything (adds overhead)
- ✗ Don't optimize without measuring

See also:
- @~/.claude/docs/patterns/react/hooks-state.md for state management
- @~/.claude/docs/patterns/react/hooks-effects.md for side effects
- @~/.claude/docs/patterns/performance/react-optimization.md for comprehensive optimization strategies
