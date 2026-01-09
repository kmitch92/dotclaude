# React Component Composition Patterns

TypeScript patterns for React component composition: props typing, HTML attributes, generics, discriminated unions, and children patterns.

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

**Advanced: Constraining generics**
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

## Related

- [Component State Patterns](./component-state.md) - State management, hooks, context
- [React Hooks Patterns](./hooks.md) - Custom hooks and composition
- [React Testing Patterns](./testing.md) - Testing React components
