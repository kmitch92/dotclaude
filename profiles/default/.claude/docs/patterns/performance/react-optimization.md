# React Performance Optimization

## Overview
React applications can suffer performance issues as they scale. This guide covers proven optimization techniques for production React applications.

## Rendering Optimization

### React.memo
Prevents re-renders when props haven't changed:

```tsx
const ExpensiveComponent = React.memo(({ data, onUpdate }) => {
  return <div>{/* expensive rendering */}</div>;
});

// Custom comparison for complex props
const ExpensiveComponent = React.memo(
  ({ data, onUpdate }) => <div>{/* ... */}</div>,
  (prevProps, nextProps) => {
    return prevProps.data.id === nextProps.data.id;
  }
);
```

**When to use:**
- Component renders frequently with same props
- Expensive render logic (large lists, complex calculations)
- Pure components (output depends only on props)

**When NOT to use:**
- Props change frequently
- Component is already fast
- Optimization adds more overhead than it saves

### useMemo
Memoizes expensive calculations:

```tsx
const ExpensiveCalculation = ({ items }) => {
  const sortedItems = useMemo(() => {
    return items
      .slice()
      .sort((a, b) => a.price - b.price)
      .filter(item => item.inStock);
  }, [items]);

  return <div>{sortedItems.map(item => ...)}</div>;
};
```

**When to use:**
- Expensive calculations (sorting, filtering large arrays)
- Creating objects/arrays passed as props
- Calculations that cause child re-renders

**Anti-pattern:**
```tsx
// BAD: Over-optimization
const simple = useMemo(() => a + b, [a, b]); // Overhead > benefit

// GOOD: Profile first, optimize when needed
const simple = a + b;
```

### useCallback
Prevents function recreation causing child re-renders:

```tsx
const ParentComponent = () => {
  const [count, setCount] = useState(0);

  // Without useCallback: new function every render
  const handleClick = useCallback(() => {
    setCount(c => c + 1);
  }, []); // Empty deps: function never changes

  return <MemoizedChild onClick={handleClick} />;
};
```

**When to use:**
- Callbacks passed to memoized child components
- Dependencies for useEffect/useMemo
- Event handlers in large lists

**When NOT to use:**
- Callbacks NOT passed to children
- No performance issue observed
- Component already re-renders on state change

## Component Splitting

### Code Splitting with React.lazy
Split large components into separate bundles:

```tsx
import { lazy, Suspense } from 'react';

const HeavyChart = lazy(() => import('./HeavyChart'));
const AdminPanel = lazy(() => import('./AdminPanel'));

const Dashboard = () => (
  <Suspense fallback={<LoadingSpinner />}>
    <HeavyChart data={data} />
  </Suspense>
);

// Route-based splitting
const routes = [
  { path: '/dashboard', component: lazy(() => import('./Dashboard')) },
  { path: '/admin', component: lazy(() => import('./Admin')) },
];
```

**When to use:**
- Large third-party libraries (charts, editors)
- Admin/rarely-used features
- Route-level splitting (entire pages)
- Modal/drawer content

### Extracting Expensive Components
Move expensive logic to separate components:

```tsx
// BAD: Entire parent re-renders
const Parent = () => {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(count + 1)}>Count: {count}</button>
      <ExpensiveList items={staticItems} /> {/* Re-renders on count change! */}
    </div>
  );
};

// GOOD: Expensive component isolated
const CounterSection = () => {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(count + 1)}>Count: {count}</button>;
};

const Parent = () => (
  <div>
    <CounterSection />
    <ExpensiveList items={staticItems} /> {/* Never re-renders */}
  </div>
);
```

## Virtualization

### react-window for Large Lists
Render only visible items:

```tsx
import { FixedSizeList } from 'react-window';

const VirtualizedList = ({ items }) => (
  <FixedSizeList
    height={600}
    itemCount={items.length}
    itemSize={50}
    width="100%"
  >
    {({ index, style }) => (
      <div style={style}>
        {items[index].name}
      </div>
    )}
  </FixedSizeList>
);
```

**When to use:**
- Lists with 100+ items
- Grid layouts with many cells
- Infinite scroll scenarios
- Chat messages, logs, feeds

**Libraries:**
- **react-window**: Lightweight (recommended for most cases)
- **react-virtual**: More features, TanStack ecosystem
- **react-virtuoso**: Simpler API, dynamic heights

## Bundle Size Optimization

### Tree Shaking
Import only what you need:

```tsx
// BAD: Imports entire library
import _ from 'lodash';
import { Button, Modal, Tooltip, Dropdown } from 'antd';

// GOOD: Imports specific functions/components
import debounce from 'lodash/debounce';
import Button from 'antd/es/button';
```

### Analyzing Bundle Size
```bash
# Webpack Bundle Analyzer
npm install --save-dev webpack-bundle-analyzer

# Vite Bundle Visualizer
npm install --save-dev rollup-plugin-visualizer

# View report
npm run build -- --analyze
```

**Red flags:**
- Duplicate libraries (e.g., two versions of React)
- Entire libraries included when only using 1-2 functions
- Large unused dependencies
- Unoptimized images/assets

### Dynamic Imports for Heavy Libraries
```tsx
// Load chart library only when needed
const ChartComponent = ({ data }) => {
  const [Chart, setChart] = useState(null);

  useEffect(() => {
    import('chart.js').then(module => {
      setChart(() => module.Chart);
    });
  }, []);

  if (!Chart) return <LoadingSpinner />;
  return <Chart data={data} />;
};
```

## Lazy Loading Patterns

### Images
```tsx
// Native lazy loading
<img src="large-image.jpg" loading="lazy" alt="..." />

// Intersection Observer for custom logic
const LazyImage = ({ src, alt }) => {
  const [loaded, setLoaded] = useState(false);
  const imgRef = useRef();

  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        setLoaded(true);
        observer.disconnect();
      }
    });
    observer.observe(imgRef.current);
    return () => observer.disconnect();
  }, []);

  return (
    <img
      ref={imgRef}
      src={loaded ? src : placeholder}
      alt={alt}
    />
  );
};
```

### Data Fetching
Defer non-critical data:

```tsx
const Dashboard = () => {
  // Load critical data immediately
  const { data: criticalData } = useQuery(['critical'], fetchCritical);

  // Defer analytics data
  const { data: analytics } = useQuery(
    ['analytics'],
    fetchAnalytics,
    { enabled: !!criticalData } // Wait for critical data first
  );

  return (
    <div>
      <CriticalSection data={criticalData} />
      {analytics ? <AnalyticsSection data={analytics} /> : null}
    </div>
  );
};
```

## Performance Profiling

### React DevTools Profiler
1. Install React DevTools browser extension
2. Open Profiler tab
3. Click record → interact with app → stop
4. Analyze flame graphs and ranked charts

**Key metrics:**
- **Render duration**: Time spent rendering component
- **Commit phase**: Time applying changes to DOM
- **Render count**: How many times component rendered
- **Why did this render**: Prop/state changes causing re-render

### Chrome Performance Tab
1. Open DevTools → Performance
2. Record interaction
3. Look for:
   - Long tasks (>50ms blocks main thread)
   - Excessive re-renders
   - JavaScript execution time
   - Layout thrashing

### Lighthouse Audits
```bash
# Run Lighthouse in CLI
npm install -g lighthouse
lighthouse https://yourapp.com --view
```

**Key metrics:**
- **First Contentful Paint (FCP)**: <1.8s
- **Time to Interactive (TTI)**: <3.8s
- **Total Blocking Time (TBT)**: <200ms
- **Cumulative Layout Shift (CLS)**: <0.1

## Common Pitfalls

### Creating Objects/Arrays in Render
```tsx
// BAD: New object every render causes child re-render
<Child config={{ theme: 'dark', size: 'large' }} />

// GOOD: Stable reference
const config = useMemo(() => ({ theme: 'dark', size: 'large' }), []);
<Child config={config} />
```

### Inline Functions as Props
```tsx
// BAD: New function every render
<Button onClick={() => handleClick(item.id)} />

// GOOD: Stable callback (if Button is memoized)
const onClick = useCallback(() => handleClick(item.id), [item.id]);
<Button onClick={onClick} />
```

### Over-Optimizing
```tsx
// BAD: Optimization overhead > benefit
const SimpleCounter = React.memo(({ count }) => <div>{count}</div>);

// GOOD: Let React do its job
const SimpleCounter = ({ count }) => <div>{count}</div>;
```

## Performance Budget
Set measurable goals:

- Bundle size: <200KB initial, <50KB per route
- Time to Interactive: <3s on 3G
- Re-render time: <16ms (60fps)
- List virtualization: Enabled for >100 items
- Code splitting: Enabled for routes and large features

## Testing Performance
```tsx
import { render } from '@testing-library/react';
import { performance } from 'perf_hooks';

test('component renders in <50ms', () => {
  const start = performance.now();
  render(<ExpensiveComponent data={largeDataset} />);
  const duration = performance.now() - start;

  expect(duration).toBeLessThan(50);
});
```

## Related
- [Database Optimization](./database-optimization.md)
- [Performance Profiling Tools](../../references/profiling-tools.md)
- [Backend Performance](../backend/performance.md)
