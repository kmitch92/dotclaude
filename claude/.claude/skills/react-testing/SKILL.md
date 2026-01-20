---
name: react-testing
description: React Testing Library patterns. Behavioral testing, query methods, user interactions, async testing, MSW mocking, test data factories.
---

# React Testing Library - Complete Reference

Comprehensive guide to testing React components with React Testing Library, focusing on behavioral testing through user interactions.

## Core Philosophy

**Test behavior, not implementation.** Tests should verify what users see and do, treating component internals as a black box.

**Key principles:**
- ✓ Test through user interactions (clicks, typing, form submission)
- ✓ Query by accessible roles, labels, and text content
- ✓ Assert on visible outcomes (rendered text, DOM changes, aria attributes)
- ✗ Never access component state, props, or internal methods
- ✗ No shallow rendering or enzyme-style testing

---

## Query Methods

### Query Priority

Use this priority order when selecting queries:

#### 1. Accessible Queries (Preferred)

**getByRole** - Query by ARIA role (most robust):
```typescript
// Buttons
screen.getByRole('button', { name: 'Submit' });
screen.getByRole('button', { name: /submit/i }); // Case-insensitive regex

// Links
screen.getByRole('link', { name: 'Learn More' });

// Inputs
screen.getByRole('textbox', { name: 'Email' });
screen.getByRole('checkbox', { name: 'Accept terms' });
screen.getByRole('radio', { name: 'Option 1' });

// Other elements
screen.getByRole('heading', { name: 'Welcome' });
screen.getByRole('img', { name: 'Product photo' });
screen.getByRole('list');
screen.getByRole('listitem');
```

**Common ARIA roles:**
- `button` - `<button>`, `<input type="button">`, `role="button"`
- `link` - `<a href>`
- `textbox` - `<input type="text">`, `<textarea>`
- `checkbox` - `<input type="checkbox">`
- `radio` - `<input type="radio">`
- `heading` - `<h1>` through `<h6>`
- `img` - `<img>`, `role="img"`
- `list` - `<ul>`, `<ol>`
- `listitem` - `<li>`
- `navigation` - `<nav>`, `role="navigation"`
- `main` - `<main>`, `role="main"`

**getByLabelText** - Query inputs by associated label:
```typescript
// Via <label> element
<label htmlFor="email">Email</label>
<input id="email" />
screen.getByLabelText('Email');

// Via aria-label
<input aria-label="Search" />
screen.getByLabelText('Search');

// Via aria-labelledby
<span id="email-label">Email</span>
<input aria-labelledby="email-label" />
screen.getByLabelText('Email');
```

**getByPlaceholderText** - Query by placeholder (use sparingly):
```typescript
<input placeholder="Enter email" />
screen.getByPlaceholderText('Enter email');
```

#### 2. Semantic Queries

**getByText** - Query by text content:
```typescript
// Exact match
screen.getByText('Welcome back');

// Regex (case-insensitive)
screen.getByText(/welcome back/i);

// Function matcher
screen.getByText((content, element) => {
  return element?.tagName.toLowerCase() === 'p' && content.startsWith('Total:');
});
```

**getByAltText** - Query images by alt text:
```typescript
<img alt="Product photo" src="..." />
screen.getByAltText('Product photo');
```

**getByTitle** - Query by title attribute:
```typescript
<span title="Close dialog">×</span>
screen.getByTitle('Close dialog');
```

#### 3. Test IDs (Last Resort)

**getByTestId** - Only when other queries don't work:
```typescript
<div data-testid="custom-element">Content</div>
screen.getByTestId('custom-element');
```

**When to use data-testid:**
- No accessible role or label
- Content is dynamic or internationalized
- Need to test implementation-specific element

**Prefer improving markup instead:**
```typescript
// ❌ Using test ID unnecessarily
<div data-testid="submit-button" onClick={submit}>Submit</div>
screen.getByTestId('submit-button');

// ✓ Use semantic HTML
<button onClick={submit}>Submit</button>
screen.getByRole('button', { name: 'Submit' });
```

### Query Variants

**get\* vs query\* vs find\***

```typescript
// getBy* - Throws error if not found (use for elements that should exist)
const button = screen.getByRole('button', { name: 'Submit' });

// queryBy* - Returns null if not found (use for conditional elements)
const error = screen.queryByText('Error occurred');
expect(error).not.toBeInTheDocument(); // Assert element doesn't exist

// findBy* - Returns promise, waits for element (use for async content)
const message = await screen.findByText('Success!', {}, { timeout: 3000 });
```

**Decision tree:**
```
Should element exist now?
  Yes → getBy*
  No → queryBy* (for asserting absence)

Will element appear after async operation?
  Yes → findBy* (waits up to 1000ms by default)
```

**Multiple Elements: getAllBy\*, queryAllBy\*, findAllBy\***

```typescript
// All buttons
const buttons = screen.getAllByRole('button');
expect(buttons).toHaveLength(3);

// All list items
const items = screen.getAllByRole('listitem');
expect(items).toHaveLength(5);

// Multiple matches with text
const errors = screen.getAllByText(/error/i);
```

---

## User Interactions

### userEvent (Preferred)

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

describe('LoginForm', () => {
  it('should submit login credentials', async () => {
    const onSubmit = jest.fn();
    render(<LoginForm onSubmit={onSubmit} />);

    // Type into inputs
    await userEvent.type(screen.getByLabelText('Email'), 'user@example.com');
    await userEvent.type(screen.getByLabelText('Password'), 'password123');

    // Click submit button
    await userEvent.click(screen.getByRole('button', { name: 'Sign In' }));

    // Assert callback called with correct data
    expect(onSubmit).toHaveBeenCalledWith({
      email: 'user@example.com',
      password: 'password123'
    });
  });
});
```

**userEvent methods:**
```typescript
// Click interactions
await userEvent.click(element);
await userEvent.dblClick(element);

// Keyboard interactions
await userEvent.type(element, 'Hello world');
await userEvent.clear(element);
await userEvent.keyboard('{Enter}');
await userEvent.tab(); // Focus next element

// Select interactions
await userEvent.selectOptions(selectElement, 'value');
await userEvent.deselectOptions(selectElement, 'value');

// Upload files
const file = new File(['content'], 'file.txt', { type: 'text/plain' });
await userEvent.upload(inputElement, file);

// Hover
await userEvent.hover(element);
await userEvent.unhover(element);
```

### fireEvent (Simpler, Synchronous)

```typescript
import { fireEvent } from '@testing-library/react';

// Basic click
fireEvent.click(button);

// Change input value
fireEvent.change(input, { target: { value: 'new value' } });

// Submit form
fireEvent.submit(form);

// Custom events
fireEvent.mouseEnter(element);
fireEvent.focus(element);
fireEvent.blur(element);
```

**userEvent vs fireEvent:**
- Use `userEvent` for realistic user interactions (types one character at a time, dispatches multiple events)
- Use `fireEvent` for simple unit-like tests where exact user simulation isn't needed
- `userEvent` is async, `fireEvent` is synchronous

---

## Testing Async Behavior

### waitFor - Wait for Assertion

```typescript
import { waitFor } from '@testing-library/react';

it('should display error message after failed submission', async () => {
  render(<RegistrationForm />);

  await userEvent.type(screen.getByLabelText('Email'), 'invalid');
  await userEvent.click(screen.getByRole('button', { name: 'Register' }));

  // Wait for error message to appear
  await waitFor(() => {
    expect(screen.getByText('Invalid email format')).toBeInTheDocument();
  });
});

// With custom timeout and interval
await waitFor(
  () => {
    expect(screen.getByText('Loaded')).toBeInTheDocument();
  },
  { timeout: 3000, interval: 100 }
);
```

### findBy\* - Simpler Async Queries

```typescript
// ✓ Preferred - cleaner
const message = await screen.findByText('Success!');
expect(message).toBeInTheDocument();

// ❌ Verbose - equivalent using waitFor
await waitFor(() => {
  expect(screen.getByText('Success!')).toBeInTheDocument();
});
```

### waitForElementToBeRemoved

```typescript
it('should remove loading spinner after data loads', async () => {
  render(<DataTable />);

  const spinner = screen.getByText('Loading...');

  await waitForElementToBeRemoved(spinner);

  expect(screen.getByText('Data loaded')).toBeInTheDocument();
});
```

---

## Common Testing Patterns

### Form Submission

Test form validation, user input, and successful submission with mock functions.

```typescript
it('should submit form with valid data', async () => {
  const onSubmit = jest.fn();
  render(<ContactForm onSubmit={onSubmit} />);
  await userEvent.type(screen.getByLabelText('Name'), 'John Doe');
  await userEvent.click(screen.getByRole('button', { name: 'Send' }));
  expect(onSubmit).toHaveBeenCalledWith({ name: 'John Doe', /* ... */ });
});

it('should show validation errors', async () => {
  render(<ContactForm onSubmit={jest.fn()} />);
  await userEvent.click(screen.getByRole('button', { name: 'Send' }));
  expect(screen.getByText('Name is required')).toBeInTheDocument();
});
```

### Conditional Rendering

Test loading, success, and error states with `findBy*` for async.

```typescript
it('should show loading state initially', () => {
  render(<UserProfile userId="123" />);
  expect(screen.getByText('Loading...')).toBeInTheDocument();
});

it('should show user data after loading', async () => {
  render(<UserProfile userId="123" />);
  await screen.findByRole('heading', { name: 'John Doe' });
  expect(screen.queryByText('Loading...')).not.toBeInTheDocument();
});

it('should show error state on failure', async () => {
  jest.spyOn(api, 'fetchUser').mockRejectedValue(new Error('API error'));
  render(<UserProfile userId="123" />);
  await screen.findByText('Failed to load user');
});
```

### Toggle/Show/Hide

Test visibility changes with `queryBy*` for absence checks.

```typescript
it('should show menu when clicked', async () => {
  render(<Dropdown />);
  expect(screen.queryByRole('menu')).not.toBeInTheDocument();
  await userEvent.click(screen.getByRole('button', { name: 'Options' }));
  expect(screen.getByRole('menu')).toBeInTheDocument();
});

it('should hide menu when clicking outside', async () => {
  render(<Dropdown />);
  await userEvent.click(screen.getByRole('button', { name: 'Options' }));
  await userEvent.click(document.body);
  expect(screen.queryByRole('menu')).not.toBeInTheDocument();
});
```

### List Rendering

Test list output and interactions with `getAllByRole`.

```typescript
it('should render all todo items', () => {
  const todos = [
    { id: '1', text: 'Buy milk', completed: false },
    { id: '2', text: 'Walk dog', completed: true }
  ];
  render(<TodoList todos={todos} />);
  expect(screen.getAllByRole('listitem')).toHaveLength(2);
});

it('should toggle todo completion on click', async () => {
  const onToggle = jest.fn();
  render(<TodoList todos={[{ id: '1', text: 'Buy milk', completed: false }]} onToggle={onToggle} />);
  await userEvent.click(screen.getByRole('checkbox', { name: 'Buy milk' }));
  expect(onToggle).toHaveBeenCalledWith('1');
});
```

### Accessibility Testing

```typescript
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

describe('LoginForm', () => {
  it('should have no accessibility violations', async () => {
    const { container } = render(<LoginForm />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('should have proper ARIA labels', () => {
    render(<LoginForm />);

    expect(screen.getByLabelText('Email')).toHaveAttribute('type', 'email');
    expect(screen.getByLabelText('Password')).toHaveAttribute('type', 'password');
    expect(screen.getByRole('button', { name: 'Sign In' })).toBeEnabled();
  });
});
```

### Disabled State Testing

```typescript
describe('PaymentForm', () => {
  it('should not submit while processing', async () => {
    const onSubmit = jest.fn(() => new Promise(() => {})); // Never resolves
    render(<PaymentForm onSubmit={onSubmit} />);

    const button = screen.getByRole('button', { name: 'Pay' });

    await userEvent.click(button);

    // Button disabled during processing
    expect(button).toBeDisabled();

    // Second click doesn't call onSubmit again
    await userEvent.click(button);
    expect(onSubmit).toHaveBeenCalledTimes(1);
  });
});
```

### Multi-Step Forms

Test step navigation forward/backward.

```typescript
it('should navigate through steps', async () => {
  render(<RegistrationWizard />);
  expect(screen.getByRole('heading', { name: 'Personal Information' })).toBeInTheDocument();
  await userEvent.click(screen.getByRole('button', { name: 'Next' }));
  expect(screen.getByRole('heading', { name: 'Account Information' })).toBeInTheDocument();
});

it('should allow going back', async () => {
  render(<RegistrationWizard />);
  await userEvent.click(screen.getByRole('button', { name: 'Next' }));
  await userEvent.click(screen.getByRole('button', { name: 'Back' }));
  expect(screen.getByRole('heading', { name: 'Personal Information' })).toBeInTheDocument();
});
```

### Search/Filter Patterns

Test filtering by search query or dropdown selection.

```typescript
it('should filter by search query', async () => {
  const products = [
    { id: '1', name: 'Widget', category: 'tools' },
    { id: '2', name: 'Gadget', category: 'electronics' }
  ];
  render(<ProductList products={products} />);
  await userEvent.type(screen.getByLabelText('Search'), 'gad');
  expect(screen.getByText('Gadget')).toBeInTheDocument();
  expect(screen.queryByText('Widget')).not.toBeInTheDocument();
});
```

### Pagination

Test page navigation and visibility of items.

```typescript
it('should paginate through items', async () => {
  const items = Array.from({ length: 50 }, (_, i) => ({ id: String(i), name: `Item ${i}` }));
  render(<PaginatedList items={items} pageSize={10} />);
  expect(screen.getByText('Item 0')).toBeInTheDocument();
  expect(screen.queryByText('Item 10')).not.toBeInTheDocument();
  await userEvent.click(screen.getByRole('button', { name: 'Next' }));
  expect(screen.queryByText('Item 0')).not.toBeInTheDocument();
  expect(screen.getByText('Item 10')).toBeInTheDocument();
});
```

### Modal/Dialog Testing

Test modal interactions: confirm, cancel, escape key.

```typescript
it('should confirm action', async () => {
  const onConfirm = jest.fn();
  render(<ConfirmationModal onConfirm={onConfirm} onCancel={jest.fn()} />);
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }));
  expect(onConfirm).toHaveBeenCalledTimes(1);
});

it('should close on escape key', async () => {
  const onCancel = jest.fn();
  render(<ConfirmationModal onConfirm={jest.fn()} onCancel={onCancel} />);
  await userEvent.keyboard('{Escape}');
  expect(onCancel).toHaveBeenCalledTimes(1);
});
```

### Error Boundaries

Test error catching and fallback rendering.

```typescript
it('should catch errors and display fallback', () => {
  const ThrowError = () => { throw new Error('Test error'); };
  const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
  render(
    <ErrorBoundary fallback={<div>Something went wrong</div>}>
      <ThrowError />
    </ErrorBoundary>
  );
  expect(screen.getByText('Something went wrong')).toBeInTheDocument();
  spy.mockRestore();
});
```

---

## Mocking Strategies

### Mock API Calls with MSW (Recommended)

```typescript
import { rest } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
  rest.get('/api/users/:id', (req, res, ctx) => {
    return res(
      ctx.json({
        id: req.params.id,
        name: 'John Doe',
        email: 'john@example.com'
      })
    );
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('UserProfile', () => {
  it('should fetch and display user data', async () => {
    render(<UserProfile userId="123" />);
    const name = await screen.findByText('John Doe');
    expect(name).toBeInTheDocument();
  });

  it('should handle API errors', async () => {
    server.use(
      rest.get('/api/users/:id', (req, res, ctx) => {
        return res(ctx.status(500), ctx.json({ error: 'Server error' }));
      })
    );

    render(<UserProfile userId="123" />);
    const error = await screen.findByText('Failed to load user');
    expect(error).toBeInTheDocument();
  });
});
```

**MSW benefits:**
- Tests actual HTTP requests (more realistic than mocking fetch)
- Works with any request library (fetch, axios, etc.)
- Reusable handlers across tests
- No brittle mocking of implementation details

### Mock Functions (Jest)

```typescript
describe('PaymentForm', () => {
  it('should call onSubmit with payment details', async () => {
    const onSubmit = jest.fn();
    render(<PaymentForm onSubmit={onSubmit} />);

    await userEvent.type(screen.getByLabelText('Card Number'), '4242424242424242');
    await userEvent.type(screen.getByLabelText('CVV'), '123');
    await userEvent.click(screen.getByRole('button', { name: 'Pay' }));

    expect(onSubmit).toHaveBeenCalledTimes(1);
    expect(onSubmit).toHaveBeenCalledWith({
      cardNumber: '4242424242424242',
      cvv: '123'
    });
  });

  it('should handle async submission', async () => {
    const onSubmit = jest.fn().mockResolvedValue({ success: true });
    render(<PaymentForm onSubmit={onSubmit} />);

    await userEvent.click(screen.getByRole('button', { name: 'Pay' }));

    await waitFor(() => {
      expect(screen.getByText('Payment successful')).toBeInTheDocument();
    });
  });

  it('should handle submission errors', async () => {
    const onSubmit = jest.fn().mockRejectedValue(new Error('Payment failed'));
    render(<PaymentForm onSubmit={onSubmit} />);

    await userEvent.click(screen.getByRole('button', { name: 'Pay' }));

    await waitFor(() => {
      expect(screen.getByText('Payment failed')).toBeInTheDocument();
    });
  });
});
```

### Mock Context Providers

```typescript
function renderWithAuth(ui: React.ReactElement, user: User | null = null) {
  const mockAuthContext = {
    user,
    login: jest.fn(),
    logout: jest.fn(),
    isLoading: false
  };

  return render(
    <AuthContext.Provider value={mockAuthContext}>
      {ui}
    </AuthContext.Provider>
  );
}

describe('Dashboard', () => {
  it('should show user name when logged in', () => {
    const user = { id: '1', name: 'John Doe', email: 'john@example.com' };
    renderWithAuth(<Dashboard />, user);
    expect(screen.getByText('Welcome, John Doe')).toBeInTheDocument();
  });

  it('should redirect when not logged in', () => {
    renderWithAuth(<Dashboard />, null);
    expect(screen.getByText('Please sign in')).toBeInTheDocument();
  });
});
```

### Mock Modules

```typescript
// Mock entire module
jest.mock('./api', () => ({
  fetchUser: jest.fn(),
  updateUser: jest.fn()
}));

import { fetchUser, updateUser } from './api';

describe('UserProfile', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should fetch user on mount', async () => {
    (fetchUser as jest.Mock).mockResolvedValue({
      id: '1',
      name: 'John Doe'
    });

    render(<UserProfile userId="1" />);

    expect(fetchUser).toHaveBeenCalledWith('1');
    expect(await screen.findByText('John Doe')).toBeInTheDocument();
  });
});
```

### Mock localStorage

```typescript
const localStorageMock = (() => {
  let store: Record<string, string> = {};

  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => {
      store[key] = value;
    },
    removeItem: (key: string) => {
      delete store[key];
    },
    clear: () => {
      store = {};
    }
  };
})();

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock
});

describe('useLocalStorage', () => {
  beforeEach(() => {
    localStorageMock.clear();
  });

  it('should persist value to localStorage', () => {
    const { result } = renderHook(() => useLocalStorage('key', 'default'));
    const [, setValue] = result.current;

    act(() => {
      setValue('new value');
    });

    expect(localStorageMock.getItem('key')).toBe('"new value"');
  });
});
```

### Mock Timers

```typescript
describe('AutoSave', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('should auto-save after delay', async () => {
    const onSave = jest.fn();
    render(<AutoSaveForm onSave={onSave} delay={1000} />);

    await userEvent.type(screen.getByLabelText('Content'), 'Hello');

    act(() => {
      jest.advanceTimersByTime(500);
    });
    expect(onSave).not.toHaveBeenCalled();

    act(() => {
      jest.advanceTimersByTime(500);
    });
    expect(onSave).toHaveBeenCalledWith('Hello');
  });
});
```

### Mock React Router

```typescript
import { MemoryRouter } from 'react-router-dom';

function renderWithRouter(
  ui: React.ReactElement,
  { initialEntries = ['/'] } = {}
) {
  return render(
    <MemoryRouter initialEntries={initialEntries}>
      {ui}
    </MemoryRouter>
  );
}

describe('Navigation', () => {
  it('should render correct page for route', () => {
    renderWithRouter(<App />, { initialEntries: ['/about'] });
    expect(screen.getByText('About Page')).toBeInTheDocument();
  });
});
```

---

## Test Utilities

### Factory Functions for Test Data

```typescript
// Factory with defaults and overrides
function getMockUser(overrides?: Partial<User>): User {
  return {
    id: '1',
    name: 'John Doe',
    email: 'john@example.com',
    role: 'user',
    createdAt: new Date('2024-01-01'),
    ...overrides
  };
}

function getMockProduct(overrides?: Partial<Product>): Product {
  return {
    id: '1',
    name: 'Widget',
    price: 29.99,
    inStock: true,
    category: 'electronics',
    ...overrides
  };
}

// Usage in tests
describe('ProductCard', () => {
  it('should display product name and price', () => {
    const product = getMockProduct({ name: 'Gadget', price: 49.99 });
    render(<ProductCard product={product} />);

    expect(screen.getByText('Gadget')).toBeInTheDocument();
    expect(screen.getByText('$49.99')).toBeInTheDocument();
  });

  it('should show out of stock message', () => {
    const product = getMockProduct({ inStock: false });
    render(<ProductCard product={product} />);
    expect(screen.getByText('Out of stock')).toBeInTheDocument();
  });
});
```

**Factory best practices:**
- Use partial overrides for flexibility
- Provide sensible defaults
- Compose factories for nested structures

### Custom Render Utilities

```typescript
// Custom render with common providers
function renderWithProviders(
  ui: React.ReactElement,
  {
    theme = 'light',
    user = null,
    ...renderOptions
  }: {
    theme?: 'light' | 'dark';
    user?: User | null;
  } = {}
) {
  const Wrapper = ({ children }: { children: React.ReactNode }) => (
    <ThemeProvider theme={theme}>
      <AuthProvider initialUser={user}>
        <Router>
          {children}
        </Router>
      </AuthProvider>
    </ThemeProvider>
  );

  return render(ui, { wrapper: Wrapper, ...renderOptions });
}

// Usage
describe('Dashboard', () => {
  it('should render with dark theme', () => {
    renderWithProviders(<Dashboard />, { theme: 'dark' });
    expect(document.body).toHaveClass('dark');
  });

  it('should show user content when logged in', () => {
    const user = getMockUser();
    renderWithProviders(<Dashboard />, { user });
    expect(screen.getByText(`Welcome, ${user.name}`)).toBeInTheDocument();
  });
});
```

**Custom render benefits:**
- Consistent provider setup across tests
- Less boilerplate in test files
- Easy to add/remove global providers
- Type-safe configuration options

---

## Avoiding Implementation Details

### ❌ Bad: Testing Implementation

```typescript
// ❌ Accessing component state
expect(wrapper.state('isOpen')).toBe(true);

// ❌ Testing internal methods
expect(component.validateEmail).toHaveBeenCalled();

// ❌ Checking props
expect(wrapper.find(Button).props().disabled).toBe(false);

// ❌ Shallow rendering
const wrapper = shallow(<Component />);

// ❌ Testing implementation details of hooks
expect(useEffect).toHaveBeenCalled();
```

### ✓ Good: Testing Behavior

```typescript
// ✓ Test visible output
expect(screen.getByText('Menu is open')).toBeInTheDocument();

// ✓ Test through user actions
await userEvent.type(screen.getByLabelText('Email'), 'invalid');
expect(screen.getByText('Invalid email')).toBeInTheDocument();

// ✓ Test DOM changes
const button = screen.getByRole('button');
expect(button).not.toBeDisabled();

// ✓ Full rendering
render(<Component />);

// ✓ Test side effects through observable behavior
await userEvent.click(screen.getByRole('button', { name: 'Save' }));
expect(await screen.findByText('Saved successfully')).toBeInTheDocument();
```

---

## Quick Reference

**Query priority:**
1. `getByRole` (most robust, tests accessibility)
2. `getByLabelText` (forms)
3. `getByText` (content)
4. `getByTestId` (last resort)

**Interaction priority:**
1. `userEvent` (realistic user simulation)
2. `fireEvent` (simple synchronous events)

**Mocking approaches:**
- **MSW**: Mock API at network level (most realistic)
- **jest.fn()**: Mock callbacks and event handlers
- **jest.mock()**: Mock entire modules
- **Context providers**: Inject mock context values
- **Custom render**: Wrap with common providers

**Testing checklist:**
- ✓ Test through user interactions (click, type, submit)
- ✓ Query by accessible attributes (role, label, text)
- ✓ Assert on visible outcomes (rendered content, DOM state)
- ✓ Use async queries (`findBy*`) for delayed content
- ✗ Never access component internals (state, props, methods)
- ✗ Never shallow render
- ✗ Never test implementation details
