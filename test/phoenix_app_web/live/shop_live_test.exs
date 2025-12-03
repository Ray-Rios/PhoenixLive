defmodule PhoenixAppWeb.ShopLiveTest do
  use PhoenixAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias PhoenixApp.{Accounts, Commerce, Repo}

  setup do
    # Create a test user for authenticated tests
    {:ok, user} = Accounts.create_user(%{
      email: "shop_test_#{System.unique_integer([:positive])}@example.com",
      name: "Shop Tester",
      password: "Test@1234"
    })
    {:ok, user} = Accounts.verify_user_email_direct(user)

    %{user: user}
  end

  describe "shop page" do
    test "displays product grid", %{conn: conn, user: user} do
      conn = conn |> init_test_session(%{"user_id" => user.id})

      {:ok, view, html} = live(conn, ~p"/shop")

      # Check that the shop page loads and shows products
      assert html =~ "Shop"
      # Should have a product grid container
      assert has_element?(view, ".product-grid") or has_element?(view, "[class*='product']")
    end

    test "allows adding product to cart when logged in", %{conn: conn, user: user} do
      # Create a test product
      {:ok, product} = Commerce.create_product(%{
        name: "Test Product #{System.unique_integer([:positive])}",
        description: "A test product",
        price: Decimal.new("29.99"),
        sku: "TEST-#{System.unique_integer([:positive])}",
        stock_quantity: 10,
        is_active: true
      })

      conn = conn |> init_test_session(%{"user_id" => user.id})
      {:ok, view, _html} = live(conn, ~p"/shop")

      # Simulate clicking add to cart
      result = view
               |> element("button[phx-click='add_to_cart'][phx-value-product_id='#{product.id}']")
               |> render_click()

      # Should show success feedback (adjust assertion based on your actual flash/toast implementation)
      assert result =~ "added to cart" or result =~ "Cart" or result =~ "Success"
    end
  end

  describe "product detail" do
    test "shows product details when navigating to specific product", %{conn: conn, user: user} do
      {:ok, product} = Commerce.create_product(%{
        name: "Detail Test Product",
        description: "Testing product detail view",
        price: Decimal.new("49.99"),
        sku: "DETAIL-001",
        stock_quantity: 5,
        is_active: true
      })

      conn = conn |> init_test_session(%{"user_id" => user.id})
      {:ok, view, html} = live(conn, ~p"/shop/product/#{product.id}")

      assert html =~ product.name
      assert html =~ product.description
      assert html =~ "49.99"
    end
  end
end
