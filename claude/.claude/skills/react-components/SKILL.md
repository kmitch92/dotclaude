---
name: react-components
description: React component composition with TypeScript. Props typing, HTML attributes extension, generics, discriminated unions, children patterns, state management.
---

# React Components with TypeScript

TypeScript patterns for React component composition and state management: props typing, HTML attributes, generics, discriminated unions, children patterns, useState, useReducer, and custom hooks.

## Basic Component Props

### Props with Type Safety and Defaults

```typescript
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
}

function Button({
  variant,
  size = 'md',
  children,
  onClick,
  disabled = false
}: ButtonProps) {
  return (
    <button
      className={`btn-${variant} btn-${size}`}
      onClick={onClick}
      disabled={disabled}
    >
      {children}
    </button>
  );
}
```

**When to use:** Clear required/optional props, default values, specific allowed values

**Common pitfalls:**
- ❌ Using `string` instead of union types
- ❌ Making all props optional
- ❌ Forgetting to document required behavior in types

## Extending HTML Attributes

### Inheriting Native Element Props

```typescript
interface CustomButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant: 'primary' | 'secondary';
  isLoading?: boolean;
}

function CustomButton({
  variant,
  isLoading,
  children,
  ...props
}: CustomButtonProps) {
  return (
    <button
      {...props}
      className={`btn-${variant}`}
    >
      {isLoading ? 'Loading...' : children}
    </button>
  );
}
```

**Available HTML type interfaces:**
- `React.ButtonHTMLAttributes<HTMLButtonElement>`
- `React.InputHTMLAttributes<HTMLInputElement>`
- `React.HTMLAttributes<HTMLElement>` (generic)
- `React.AnchorHTMLAttributes<HTMLAnchorElement>`
- `React.FormHTMLAttributes<HTMLFormElement>`
- `React.ImgHTMLAttributes<HTMLImageElement>`

**Best practice - merge className:**
```typescript
import { cn } from '@/lib/utils';

<button
  {...props}
  className={cn(`btn-${variant}`, props.className)}
>
  {children}
</button>
```

## Generic Components

### Type-Safe List Component

```typescript
interface ListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  keyExtractor: (item: T) => string | number;
}

function List<T>({ items, renderItem, keyExtractor }: ListProps<T>) {
  return (
    <ul>
      {items.map((item, index) => (
        <li key={keyExtractor(item)}>
          {renderItem(item, index)}
        </li>
      ))}
    </ul>
  );
}

// Usage with full type inference
interface Product {
  id: string;
  name: string;
  price: number;
}

<List<Product>
  items={products}
  renderItem={(product, index) => (
    <div>
      {index + 1}. {product.name} - ${product.price}
    </div>
  )}
  keyExtractor={(product) => product.id}
/>
```

**Benefits:**
- ✓ Full type safety for item properties
- ✓ Autocomplete in renderItem function
- ✓ Reusable across different data types

### Constraining Generics

```typescript
interface HasId {
  id: string | number;
}

interface ListProps<T extends HasId> {
  items: T[];
  renderItem: (item: T) => React.ReactNode;
}

function List<T extends HasId>({ items, renderItem }: ListProps<T>) {
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}
```

## Discriminated Unions

### Variant-Based Props

```typescript
type AlertProps =
  | { variant: 'success'; message: string; onDismiss?: () => void }
  | { variant: 'error'; message: string; error: Error; onRetry: () => void }
  | { variant: 'info'; message: string; actionLabel?: string; onAction?: () => void };

function Alert(props: AlertProps) {
  const baseClasses = `alert alert-${props.variant}`;

  return (
    <div className={baseClasses}>
      <p>{props.message}</p>
      {props.variant === 'error' && (
        <>
          <pre>{props.error.message}</pre>
          <button onClick={props.onRetry}>Retry</button>
        </>
      )}
      {props.variant === 'info' && props.actionLabel && (
        <button onClick={props.onAction}>{props.actionLabel}</button>
      )}
    </div>
  );
}
```

**When to use:** Component behavior changes significantly based on variant, different callbacks/props per variant

**Additional examples:**
```typescript
// Form field with type-specific props
type FieldProps =
  | { type: 'text'; value: string; maxLength?: number }
  | { type: 'number'; value: number; min?: number; max?: number }
  | { type: 'date'; value: Date; minDate?: Date; maxDate?: Date };

// Modal with conditional actions
type ModalProps =
  | { mode: 'confirm'; onConfirm: () => void; onCancel: () => void }
  | { mode: 'alert'; onClose: () => void }
  | { mode: 'prompt'; onSubmit: (value: string) => void; onCancel: () => void };

// API request state
type RequestState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };
```

**Best practice - exhaustive checking:**
```typescript
function Alert(props: AlertProps) {
  switch (props.variant) {
    case 'success':
      return <SuccessAlert {...props} />;
    case 'error':
      return <ErrorAlert {...props} />;
    case 'info':
      return <InfoAlert {...props} />;
    default:
      const _exhaustive: never = props;
      return _exhaustive;
  }
}
```

## Children Patterns

### ReactNode - Most Common

```typescript
interface CardProps {
  title: string;
  children: React.ReactNode;
}

function Card({ title, children }: CardProps) {
  return (
    <div className="card">
      <h2>{title}</h2>
      <div className="card-body">{children}</div>
    </div>
  );
}
```

**When to use:** Flexible content, any renderable JSX

### Render Props Pattern

```typescript
interface DataLoaderProps<T> {
  url: string;
  children: (data: T | null, loading: boolean, error: Error | null) => React.ReactNode;
}

function DataLoader<T>({ url, children }: DataLoaderProps<T>) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    fetch(url)
      .then(res => res.json())
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, [url]);

  return <>{children(data, loading, error)}</>;
}

// Usage
<DataLoader<User> url="/api/user">
  {(user, loading, error) => {
    if (loading) return <Spinner />;
    if (error) return <ErrorMessage error={error} />;
    if (!user) return <NotFound />;
    return <UserProfile user={user} />;
  }}
</DataLoader>
```

**When to use:** Need to pass data/state to children, children need control over rendering logic

**Alternative: Render prop as explicit prop**
```typescript
interface TabsProps {
  activeTab: string;
  renderTab: (tabId: string, isActive: boolean) => React.ReactNode;
}
```

### Restricted Children Types

```typescript
interface TabsProps {
  children: React.ReactElement<TabProps> | React.ReactElement<TabProps>[];
}

function Tabs({ children }: TabsProps) {
  const tabs = React.Children.toArray(children);
  return <div className="tabs">{tabs}</div>;
}
```

**When to use:** Component expects specific child component types (Tabs/Tab, Accordion/Panel)

## Event Handler Typing

### Basic Event Handlers

```typescript
interface FormProps {
  onSubmit: (data: FormData) => void;
  onCancel: () => void;
}

function Form({ onSubmit, onCancel }: FormProps) {
  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    onSubmit(formData);
  };

  return (
    <form onSubmit={handleSubmit}>
      <button type="submit">Submit</button>
      <button type="button" onClick={onCancel}>Cancel</button>
    </form>
  );
}
```

### Generic Event Handlers with Type Safety

```typescript
interface SelectProps<T> {
  value: T;
  options: T[];
  onChange: (value: T) => void;
  getLabel: (option: T) => string;
  getValue: (option: T) => string;
}

function Select<T>({ value, options, onChange, getLabel, getValue }: SelectProps<T>) {
  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const selectedValue = e.target.value;
    const selected = options.find(opt => getValue(opt) === selectedValue);
    if (selected) onChange(selected);
  };

  return (
    <select value={getValue(value)} onChange={handleChange}>
      {options.map(opt => (
        <option key={getValue(opt)} value={getValue(opt)}>
          {getLabel(opt)}
        </option>
      ))}
    </select>
  );
}
```

## Component State Management

### useState with TypeScript

**Basic Type Inference:**
```typescript
// Type inferred from initial value
const [count, setCount] = useState(0); // number
const [name, setName] = useState(''); // string
const [isOpen, setOpen] = useState(false); // boolean
```

**Explicit Type Annotation:**
```typescript
// When initial value is null or undefined
const [user, setUser] = useState<User | null>(null);
const [data, setData] = useState<string | number>(0);

// Union types
type Status = 'idle' | 'loading' | 'success' | 'error';
const [status, setStatus] = useState<Status>('idle');

// Complex objects
interface FormState {
  values: Record<string, string>;
  errors: Record<string, string>;
  touched: Record<string, boolean>;
}
const [form, setForm] = useState<FormState>({
  values: {},
  errors: {},
  touched: {}
});
```

### useReducer with Discriminated Unions

```typescript
interface State {
  count: number;
  lastAction: string;
}

type Action =
  | { type: 'increment' }
  | { type: 'decrement' }
  | { type: 'set'; payload: number }
  | { type: 'reset' };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'increment':
      return { count: state.count + 1, lastAction: 'increment' };
    case 'decrement':
      return { count: state.count - 1, lastAction: 'decrement' };
    case 'set':
      return { count: action.payload, lastAction: 'set' };
    case 'reset':
      return { count: 0, lastAction: 'reset' };
    default:
      const _exhaustive: never = action;
      return state;
  }
}

// Usage
const [state, dispatch] = useReducer(reducer, { count: 0, lastAction: '' });

dispatch({ type: 'increment' });
dispatch({ type: 'set', payload: 10 });
```

**Benefits:**
- Exhaustive checking ensures all action types handled
- Type-safe payload for each action type
- Compile-time errors for invalid actions

### Complex State Management Example

```typescript
interface Todo {
  id: string;
  text: string;
  completed: boolean;
}

type TodoState = {
  todos: Todo[];
  filter: 'all' | 'active' | 'completed';
};

type TodoAction =
  | { type: 'add'; payload: { text: string } }
  | { type: 'toggle'; payload: { id: string } }
  | { type: 'delete'; payload: { id: string } }
  | { type: 'setFilter'; payload: { filter: TodoState['filter'] } };

function todoReducer(state: TodoState, action: TodoAction): TodoState {
  switch (action.type) {
    case 'add':
      const newTodo: Todo = {
        id: crypto.randomUUID(),
        text: action.payload.text,
        completed: false
      };
      return { ...state, todos: [...state.todos, newTodo] };
    case 'toggle':
      return {
        ...state,
        todos: state.todos.map(todo =>
          todo.id === action.payload.id
            ? { ...todo, completed: !todo.completed }
            : todo
        )
      };
    case 'delete':
      return {
        ...state,
        todos: state.todos.filter(todo => todo.id !== action.payload.id)
      };
    case 'setFilter':
      return { ...state, filter: action.payload.filter };
    default:
      const _exhaustive: never = action;
      return state;
  }
}
```

## Custom Hooks

### Simple Custom Hook

```typescript
function useToggle(initialValue = false) {
  const [isOn, setIsOn] = useState(initialValue);

  return {
    isOn,
    toggle: () => setIsOn(prev => !prev),
    setOn: () => setIsOn(true),
    setOff: () => setIsOn(false),
  };
}

// Usage
const modal = useToggle(false);
<button onClick={modal.toggle}>Toggle Modal</button>
{modal.isOn && <Modal onClose={modal.setOff} />}
```

### Generic Custom Hook

```typescript
function useLocalStorage<T>(
  key: string,
  initialValue: T
): [T, (value: T | ((prev: T) => T)) => void] {
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch {
      return initialValue;
    }
  });

  const setValue = (value: T | ((prev: T) => T)) => {
    try {
      const valueToStore =
        value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    } catch (error) {
      console.error(`Error saving to localStorage:`, error);
    }
  };

  return [storedValue, setValue];
}

// Usage
const [theme, setTheme] = useLocalStorage<'light' | 'dark'>('theme', 'light');
```

### Context with Custom Hook

```typescript
interface AuthContextValue {
  user: User | null;
  login: (credentials: Credentials) => Promise<void>;
  logout: () => void;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}

// Usage
function LoginButton() {
  const { login, isAuthenticated } = useAuth();
  // ...
}
```

## Complete Form Component Example

Composition of TypeScript patterns for type-safe form handling.

```typescript
interface FormField {
  name: string;
  label: string;
  type: 'text' | 'email' | 'number';
  required?: boolean;
}

interface FormProps<T extends Record<string, any>> {
  fields: FormField[];
  initialValues: T;
  onSubmit: (values: T) => void | Promise<void>;
  onCancel?: () => void;
  submitLabel?: string;
  children?: React.ReactNode;
}

function Form<T extends Record<string, any>>({
  fields,
  initialValues,
  onSubmit,
  onCancel,
  submitLabel = 'Submit',
  children
}: FormProps<T>) {
  const [values, setValues] = useState<T>(initialValues);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleChange = (name: keyof T) => (value: string) => {
    setValues(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      await onSubmit(values);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {fields.map(field => (
        <div key={field.name}>
          <label>{field.label}</label>
          <input
            type={field.type}
            name={field.name}
            value={String(values[field.name] ?? '')}
            onChange={(e) => handleChange(field.name)(e.target.value)}
            required={field.required}
          />
        </div>
      ))}
      {children}
      <div className="flex gap-2">
        <button type="submit" disabled={isSubmitting}>
          {isSubmitting ? 'Submitting...' : submitLabel}
        </button>
        {onCancel && (
          <button type="button" onClick={onCancel}>
            Cancel
          </button>
        )}
      </div>
    </form>
  );
}

// Usage
interface UserFormData {
  name: string;
  email: string;
  age: number;
}

<Form<UserFormData>
  fields={[
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'email', label: 'Email', type: 'email', required: true },
    { name: 'age', label: 'Age', type: 'number' }
  ]}
  initialValues={{ name: '', email: '', age: 0 }}
  onSubmit={async (data) => {
    await saveUser(data);
  }}
  onCancel={() => router.back()}
  submitLabel="Create User"
>
  <p className="text-sm text-gray-500">
    All fields marked with * are required
  </p>
</Form>
```

## Summary

**Choose the right pattern:**

**Component Props:**
- Basic props with union types for clear APIs
- Extend HTML attributes for native element wrappers
- Generics for reusable components across different data types
- Discriminated unions for variant-based behavior

**State Management:**
- **useState** - Simple state, single values, form inputs
- **useReducer** - Complex state logic, multiple sub-values, state transitions
- **Custom hooks** - Reusable stateful logic, encapsulate complexity
- **Context** - Global state, avoid prop drilling, theme/auth

**Common mistakes to avoid:**
- Using `string` instead of union types
- Not providing explicit types when initial value is null
- Mutating state directly instead of creating new objects/arrays
- Missing exhaustive checks in reducer switch statements
- Not throwing error in custom hook when context is undefined
- Over-using context (prefer composition and props)

**Remember:**
- Types document expected props and state shape
- Immutability is mandatory - always create new objects/arrays
- Discriminated unions provide type-safe variants and state machines
- Custom hooks encapsulate reusable stateful behavior
- Composition over inheritance for React components
