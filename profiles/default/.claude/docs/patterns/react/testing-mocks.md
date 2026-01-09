# React Testing: Mocking and Test Utilities

Mocking patterns, test data factories, and custom render utilities for React tests.

## Mock API Calls with MSW (Recommended)

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

---

## Mock Functions (Jest)

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

---

## Mock Context Providers

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

---

## Factory Functions for Test Data

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

---

## Custom Render Utilities

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

## Mock Modules

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

---

## Mock localStorage

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

---

## Mock Timers

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

---

## Mock React Router

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

## Summary

**Mocking approaches:**
- **MSW**: Mock API at network level (most realistic)
- **jest.fn()**: Mock callbacks and event handlers
- **jest.mock()**: Mock entire modules
- **Context providers**: Inject mock context values
- **Custom render**: Wrap with common providers

**Factory patterns:**
- Partial overrides for flexibility
- Sensible defaults
- Compose for nested structures
- Type-safe with TypeScript

**Custom utilities:**
- `renderWithProviders` for consistent setup
- `renderWithRouter` for route testing
- Mock localStorage, timers as needed

**Best practices:**
- Clear mocks between tests (beforeEach)
- Use MSW for HTTP mocking (avoid mocking fetch directly)
- Create factories for complex test data
- Custom render functions reduce boilerplate
