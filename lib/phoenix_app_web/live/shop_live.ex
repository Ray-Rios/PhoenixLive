defmodule PhoenixAppWeb.ShopLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Commerce

  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}

  def mount(_params, _session, socket) do
    products = Commerce.list_products()
    categories = Commerce.list_categories()
    
    # If no products exist, create some dummy data
    {products, categories} = if Enum.empty?(products) do
      dummy_products = [
        %{id: "1", name: "Wireless Gaming Headset", description: "High-quality wireless gaming headset with 7.1 surround sound and noise cancellation.", price: Decimal.new("149.99"), sku: "WGH-001", stock_quantity: 25, is_active: true, image: nil},
        %{id: "2", name: "Mechanical Gaming Keyboard", description: "RGB backlit mechanical keyboard with Cherry MX switches.", price: Decimal.new("199.99"), sku: "MGK-002", stock_quantity: 15, is_active: true, image: nil},
        %{id: "3", name: "4K Webcam", description: "Ultra HD 4K webcam with auto-focus and built-in microphone.", price: Decimal.new("89.99"), sku: "4KW-003", stock_quantity: 30, is_active: true, image: nil},
        %{id: "4", name: "Wireless Mouse", description: "Ergonomic wireless mouse with precision tracking.", price: Decimal.new("49.99"), sku: "WM-004", stock_quantity: 50, is_active: true, image: nil},
        %{id: "5", name: "Gaming Monitor 27\"", description: "27-inch 144Hz gaming monitor with 1ms response time.", price: Decimal.new("299.99"), sku: "GM27-006", stock_quantity: 12, is_active: true, image: nil},
        %{id: "6", name: "USB-C Hub", description: "Multi-port USB-C hub with HDMI, USB 3.0, and SD card reader.", price: Decimal.new("59.99"), sku: "UCH-007", stock_quantity: 40, is_active: true, image: nil}
      ]
      
      dummy_categories = [
        %{id: "1", name: "Technology", slug: "technology", description: "Latest tech gadgets"},
        %{id: "2", name: "Gaming", slug: "gaming", description: "Gaming gear and accessories"}
      ]
      
      {dummy_products, dummy_categories}
    else
      {products, categories}
    end
    
    {:ok, assign(socket,
      products: products,
      categories: categories,
      selected_category: nil,
      page_title: "Shop"
    )}
  end

  def handle_params(%{"slug" => slug}, _uri, socket) do
    category = Commerce.get_category_by_slug!(slug)
    products = Commerce.list_products_by_category(category.id)
    
    {:noreply, assign(socket,
      products: products,
      selected_category: category,
      page_title: "Shop - #{category.name}"
    )}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    case Commerce.get_product!(id) do
      nil ->
        {:noreply, 
         socket
         |> put_flash(:error, "Product not found")
         |> push_navigate(to: ~p"/shop")}
      product ->
        {:noreply, assign(socket,
          product: product,
          page_title: product.name,
          view: :product_detail
        )}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, 
       socket
       |> put_flash(:error, "Product not found")
       |> push_navigate(to: ~p"/shop")}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, view: :product_list)}
  end

  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    user = socket.assigns.current_user
    
    if user do
      product = Commerce.get_product!(product_id)
      cart = Commerce.get_or_create_cart(user)
      
      case Commerce.add_to_cart(cart, product) do
        {:ok, _cart_item} ->
          {:noreply, put_flash(socket, :info, "#{product.name} added to cart")}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to add item to cart")}
      end
    else
      {:noreply, redirect(socket, to: "/login")}
    end
  end

  def handle_event("filter_category", %{"category_id" => ""}, socket) do
    products = Commerce.list_products()
    {:noreply, assign(socket, products: products, selected_category: nil)}
  end

  def handle_event("filter_category", %{"category_id" => category_id}, socket) do
    category = Commerce.get_category!(category_id)
    products = Commerce.list_products_by_category(category_id)
    {:noreply, assign(socket, products: products, selected_category: category)}
  end

  def render(assigns) do
    ~H"""
    <.navbar current_user={@current_user} />
    <div class="starry-background chat-container starry-background min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <div class="w-full max-w-[80%] mx-auto px-4 py-8 relative z-10 mt-[50px]">
        <!-- Product List View -->
        <div :if={@view != :product_detail}>
          <div class="flex justify-between items-center mb-8">
            <h1 class="text-3xl font-bold text-white">
              <%= if @selected_category, do: @selected_category.name, else: "Shop" %>
            </h1>
            
            <!-- Category Filter -->
            <form phx-change="filter_category" class="flex items-center space-x-4">
              <select name="category_id" class="bg-gray-700 text-white px-4 py-2 rounded-lg">
                <option value="">All Categories</option>
                <%= for category <- @categories do %>
                  <option value={category.id} selected={@selected_category && @selected_category.id == category.id}>
                    <%= category.name %>
                  </option>
                <% end %>
              </select>
            </form>
          </div>

          <!-- Products Grid -->
          <div class="product-grid">
            <%= for product <- @products do %>
              <div class="product-card">
                <.link navigate={"/shop/product/#{product.id}"}>
                  <div class="product-image bg-gradient-to-br from-gray-600 to-gray-800 flex items-center justify-center">
                    <span class="text-4xl">📦</span>
                  </div>
                </.link>
                
                <div class="product-info">
                  <h3 class="product-title"><%= product.name %></h3>
                  <p class="text-gray-300 text-sm mb-2 line-clamp-2"><%= product.description %></p>
                  <div class="flex justify-between items-center">
                    <span class="product-price">$<%= product.price %></span>
                    <button phx-click="add_to_cart" phx-value-product_id={product.id}
                            class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors">
                      Add to Cart
                    </button>
                  </div>
                  
                  <div :if={product.stock_quantity <= 5} class="mt-2">
                    <span class="text-orange-400 text-sm">Only <%= product.stock_quantity %> left!</span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <div :if={@products == []} class="text-center py-16">
            <div class="text-gray-400 text-xl">No products found</div>
            <p class="text-gray-500 mt-2">Try selecting a different category</p>
          </div>
        </div>

        <!-- Product Detail View -->
        <div :if={@view == :product_detail} class="max-w-6xl mx-auto">
          <nav class="mb-8">
            <.link navigate="/shop" class="text-blue-400 hover:text-blue-300">← Back to Shop</.link>
          </nav>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-12">
            <!-- Product Images -->
            <div>
              <div class="w-full h-96 bg-gradient-to-br from-gray-600 to-gray-800 rounded-lg shadow-lg flex items-center justify-center">
                <span class="text-8xl">📦</span>
              </div>
            </div>

            <!-- Product Info -->
            <div class="text-white">
              <h1 class="text-3xl font-bold mb-4"><%= @product.name %></h1>
              <p class="text-4xl font-bold text-green-400 mb-6">$<%= @product.price %></p>
              
              <div class="prose prose-invert mb-8">
                <p><%= @product.description %></p>
              </div>

              <div class="space-y-4 mb-8">
                <div class="flex items-center">
                  <span class="text-gray-400 w-24">SKU:</span>
                  <span><%= @product.sku %></span>
                </div>
                <div class="flex items-center">
                  <span class="text-gray-400 w-24">Stock:</span>
                  <span class={if @product.stock_quantity > 0, do: "text-green-400", else: "text-red-400"}>
                    <%= if @product.stock_quantity > 0, do: "#{@product.stock_quantity} available", else: "Out of stock" %>
                  </span>
                </div>
                <div :if={@product.weight} class="flex items-center">
                  <span class="text-gray-400 w-24">Weight:</span>
                  <span><%= @product.weight %> lbs</span>
                </div>
                <div :if={@product.dimensions} class="flex items-center">
                  <span class="text-gray-400 w-24">Dimensions:</span>
                  <span><%= @product.dimensions %></span>
                </div>
              </div>

              <div class="flex space-x-4">
                <button phx-click="add_to_cart" phx-value-product_id={@product.id}
                        disabled={@product.stock_quantity == 0}
                        class="flex-1 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed 
                               text-white px-8 py-3 rounded-lg font-semibold transition-colors">
                  <%= if @product.stock_quantity > 0, do: "Add to Cart", else: "Out of Stock" %>
                </button>
                
                <button class="bg-gray-700 hover:bg-gray-600 text-white px-6 py-3 rounded-lg transition-colors">
                  ♡ Wishlist
                </button>
              </div>

              <!-- Product Features -->
              <div class="mt-12">
                <h3 class="text-xl font-semibold mb-4">Features</h3>
                <ul class="space-y-2 text-gray-300">
                  <li>• High quality materials</li>
                  <li>• Fast shipping</li>
                  <li>• 30-day return policy</li>
                  <li>• Customer support</li>
                </ul>
              </div>
            </div>
          </div>

          <!-- Related Products -->
          <div class="mt-16">
            <h2 class="text-2xl font-bold text-white mb-8">Related Products</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-6">
              <!-- This would show related products -->
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end