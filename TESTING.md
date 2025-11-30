# Testing Strategy

This project follows a pragmatic testing approach focused on business logic and critical paths.

## Test Types

### 1. Unit Tests (Elixir/ExUnit) - 🎯 Primary Focus
**Location:** `test/phoenix_app/**/*_test.exs`

Fast, deterministic tests for business logic, data models, and utility functions.

**Example:**
```elixir
test "calculates cart total correctly" do
  cart = %Cart{items: [
    %{price: Decimal.new("10.00"), quantity: 2},
    %{price: Decimal.new("5.00"), quantity: 1}
  ]}
  
  assert Cart.total(cart) == Decimal.new("25.00")
end
```

**Run:** `mix test test/phoenix_app`

### 2. Controller/API Tests - 🎯 Primary Focus
**Location:** `test/phoenix_app_web/controllers/**/*_test.exs`

Test your API endpoints, authentication flows, and HTTP responses.

**Example:**
```elixir
test "POST /api/auth/login with valid credentials", %{conn: conn} do
  conn = post(conn, ~p"/api/auth/login", %{
    email: "user@example.com",
    password: "Pass123!"
  })
  
  assert %{"success" => true, "token" => token} = json_response(conn, 200)
end
```

**Run:** `mix test test/phoenix_app_web/controllers`

### 3. LiveView Tests - 🎯 Primary Focus
**Location:** `test/phoenix_app_web/live/**/*_test.exs`

Test LiveView interactions, real-time updates, and UI behavior using Phoenix's built-in LiveView testing tools.

**Example:**
```elixir
test "adds product to cart", %{conn: conn, user: user} do
  conn = init_test_session(conn, %{"user_id" => user.id})
  {:ok, view, _html} = live(conn, ~p"/shop")
  
  view
  |> element("button[phx-click='add_to_cart']")
  |> render_click()
  
  assert render(view) =~ "added to cart"
end
```

**Run:** `mix test test/phoenix_app_web/live`

### 4. E2E Smoke Test (Playwright) - 🔍 Minimal
**Location:** `assets/test/playwright/tests/smoke.spec.ts`

One simple test that verifies the app boots and loads the homepage. No authentication, no complex flows.

**Example:**
```typescript
test('app boots and homepage loads', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('body')).toBeVisible();
});
```

**Run:** `cd assets && npm run test:e2e`

## Test Coverage Goals

- **Business Logic:** 80%+ coverage with unit tests
- **API Endpoints:** Critical paths (auth, payments, data mutations) fully tested
- **LiveView:** Key user interactions tested
- **E2E:** Basic smoke test only - visual/UX validation done via manual QA

## Running Tests

```bash
# Run all Elixir tests
mix test

# Run specific test file
mix test test/phoenix_app_web/controllers/api/api_auth_controller_test.exs

# Run tests matching a pattern
mix test --only auth

# Run E2E smoke test
cd assets && npm run test:e2e

# Watch mode for frontend tests
cd assets && npm run test:e2e:ui
```

## Why This Approach?

1. **Fast feedback:** Unit and controller tests run in milliseconds
2. **Deterministic:** No flaky timing issues or browser quirks
3. **Easy to debug:** Test failures point directly to broken business logic
4. **Low maintenance:** Tests break only when actual functionality changes
5. **Phoenix-native:** Uses tools designed specifically for Phoenix/LiveView

## What We Don't Test

- **Visual design:** Handled by manual QA and design reviews
- **Cross-browser compatibility:** Modern browsers converge; issues are rare
- **Complex E2E flows:** High maintenance, low signal - prefer integration tests
- **Performance:** Use dedicated load testing tools (not part of test suite)

## Adding New Tests

**When adding a feature:**
1. Write unit tests for business logic first
2. Add controller tests for any new API endpoints
3. Add LiveView tests if it's an interactive feature
4. Manual QA for visual/UX validation
5. Update E2E smoke test ONLY if the homepage changes fundamentally

**Golden rule:** If a test is flaky or takes > 5 seconds, reconsider its value.
