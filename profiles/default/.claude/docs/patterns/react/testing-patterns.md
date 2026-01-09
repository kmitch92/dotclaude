# React Testing: Common Patterns

Common testing scenarios and patterns for React components.

## Form Submission

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

---

## Conditional Rendering

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

---

## Toggle/Show/Hide

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

---

## List Rendering

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

---

## Accessibility Testing

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

---

## Disabled State Testing

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

---

## Multi-Step Forms

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

---

## Search/Filter Patterns

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

---

## Pagination

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

---

## Modal/Dialog Testing

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

---

## Error Boundaries

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

## Summary

**Common patterns covered:**
- Form submission and validation
- Conditional rendering (loading, error, success states)
- Toggle/show/hide interactions
- List rendering and iteration
- Accessibility testing with jest-axe
- Disabled state and button prevention
- Multi-step forms and wizards
- Search and filter functionality
- Pagination
- Modal/dialog interactions
- Error boundaries

**Key principles:**
- Always test through user interactions
- Assert on visible outcomes
- Use accessible queries (roles, labels)
- Handle async operations with findBy* or waitFor
- Test edge cases (empty states, errors, disabled states)

See also:
- @~/.claude/docs/patterns/react/testing-queries.md for query fundamentals
- @~/.claude/docs/patterns/react/testing-mocks.md for mocking patterns
