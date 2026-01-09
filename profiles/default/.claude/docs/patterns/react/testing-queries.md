# React Testing: Queries and Interactions

Query methods, user interactions, and testing fundamentals with React Testing Library.

## Core Philosophy

**Test behavior, not implementation.** Tests should verify what users see and do, treating component internals as a black box.

**Key principles:**
- ✓ Test through user interactions (clicks, typing, form submission)
- ✓ Query by accessible roles, labels, and text content
- ✓ Assert on visible outcomes (rendered text, DOM changes, aria attributes)
- ✗ Never access component state, props, or internal methods
- ✗ No shallow rendering or enzyme-style testing

---

## Query Priority

React Testing Library provides multiple query methods. Use this priority order:

### 1. Accessible Queries (Preferred)

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

### 2. Semantic Queries

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

### 3. Test IDs (Last Resort)

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

---

## Query Variants

### get* vs query* vs find*

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

### getAllBy*, queryAllBy*, findAllBy*

Query multiple elements:
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

### findBy* - Simpler Async Queries

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

## Summary

**Query priority:**
1. `getByRole` (most robust, tests accessibility)
2. `getByLabelText` (forms)
3. `getByText` (content)
4. `getByTestId` (last resort)

**Interaction priority:**
1. `userEvent` (realistic user simulation)
2. `fireEvent` (simple synchronous events)

**Testing checklist:**
- ✓ Test through user interactions (click, type, submit)
- ✓ Query by accessible attributes (role, label, text)
- ✓ Assert on visible outcomes (rendered content, DOM state)
- ✓ Use async queries (`findBy*`) for delayed content
- ✗ Never access component internals (state, props, methods)
- ✗ Never shallow render
- ✗ Never test implementation details

See also:
- @~/.claude/docs/patterns/react/testing-patterns.md for common testing patterns
- @~/.claude/docs/patterns/react/testing-mocks.md for mocking and test utilities
