defmodule PhoenixAppWeb.ShopLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Commerce

  # Note: on_mount :default is handled by router's live_session

  def mount(_params, _session, socket) do
    products = Commerce.list_products()
    categories = Commerce.list_categories()
    subscription_products = Commerce.list_subscription_products()
    featured = Commerce.list_featured_products()
    
    # Get current user's active subscriptions for display
    user_subscriptions = if socket.assigns[:current_user] do
      Commerce.get_user_active_subscriptions(socket.assigns.current_user)
      |> Enum.map(& &1.product_id)
    else
      []
    end
    
    {:ok, assign(socket,
      products: products,
      categories: categories,
      subscription_products: subscription_products,
      featured_products: featured,
      user_subscriptions: user_subscriptions,
      selected_category: nil,
      page_title: "Shop",
      view: :product_list
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
      product = try do
        Commerce.get_product!(product_id)
      rescue
        Ecto.Query.CastError -> nil
        Ecto.NoResultsError -> nil
      end
      
      cart = Commerce.get_or_create_cart(user)
      
      if product == nil do
        {:noreply, put_flash(socket, :error, "Product not found")}
      else
        case Commerce.add_to_cart(cart, product) do
        {:ok, _cart_item} ->
          {:noreply, put_flash(socket, :info, "#{product.name} added to cart")}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to add item to cart")}
      end
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

  def handle_event("subscribe", %{"product_id" => product_id}, socket) do
    user = socket.assigns.current_user
    
    if user do
      product = Commerce.get_product!(product_id)
      
      # Check if user already has this subscription
      if product_id in socket.assigns.user_subscriptions do
        {:noreply, put_flash(socket, :info, "You already have an active subscription to this plan")}
      else
        # For now, directly activate (in production, redirect to Stripe checkout)
        case Commerce.activate_subscription(user, product) do
          {:ok, _subscription} ->
            # Refresh user subscriptions
            user_subscriptions = Commerce.get_user_active_subscriptions(user) |> Enum.map(& &1.product_id)
            
            {:noreply, 
             socket
             |> assign(user_subscriptions: user_subscriptions)
             |> put_flash(:success, "Successfully subscribed to #{product.name}!")}
          
          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to activate subscription. Please try again.")}
        end
      end
    else
      {:noreply, redirect(socket, to: "/login")}
    end
  end

  # Helper functions
  defp format_storage(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_099_511_627_776 -> "#{div(bytes, 1_099_511_627_776)} TB"
      bytes >= 1_073_741_824 -> "#{div(bytes, 1_073_741_824)} GB"
      bytes >= 1_048_576 -> "#{div(bytes, 1_048_576)} MB"
      true -> "#{div(bytes, 1024)} KB"
    end
  end
  defp format_storage(_), do: "0 GB"

  defp humanize_feature(feature) when is_binary(feature) do
    feature
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  defp humanize_feature(_), do: ""

  defp product_icon("digital"), do: "📥"
  defp product_icon("subscription"), do: "🔄"
  defp product_icon("service"), do: "🛠️"
  defp product_icon(_), do: "📦"

  def render(assigns) do
    ~H"""
    <PhoenixAppWeb.Components.PageContainer.page_container>
        <%= if @view != :product_detail do %>
          <!-- Hero Section for Subscriptions -->
          <%= if @subscription_products != [] do %>
            <div class="mb-12">
              <h2 class="text-2xl font-bold text-white mb-6">📦 Upgrade Your Experience</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <%= for product <- @subscription_products do %>
                  <div class={"relative rounded-xl p-6 border-2 #{if product.featured, do: "border-blue-500 bg-gradient-to-br from-blue-900/50 to-purple-900/50", else: "border-gray-600 bg-gray-800/50"}"}>
                    <%= if product.featured do %>
                      <div class="absolute -top-3 left-1/2 -translate-x-1/2">
                        <span class="bg-gradient-to-r from-blue-500 to-purple-500 text-white text-xs font-bold px-3 py-1 rounded-full">
                          <%= product.badge_text || "RECOMMENDED" %>
                        </span>
                      </div>
                    <% end %>
                    
                    <div class="text-center mb-4">
                      <h3 class="text-xl font-bold text-white"><%= product.name %></h3>
                      <p class="text-gray-400 text-sm mt-1"><%= product.description %></p>
                    </div>
                    
                    <div class="text-center mb-6">
                      <span class="text-4xl font-bold text-white">$<%= product.price %></span>
                      <span class="text-gray-400">
                        <%= case product.billing_interval do %>
                          <% "monthly" -> %>/month
                          <% "yearly" -> %>/year
                          <% "lifetime" -> %> one-time
                          <% _ -> %>
                        <% end %>
                      </span>
                      <%= if product.trial_days > 0 do %>
                        <div class="text-green-400 text-sm mt-1"><%= product.trial_days %>-day free trial</div>
                      <% end %>
                    </div>
                    
                    <!-- Features List -->
                    <ul class="space-y-2 mb-6 text-sm">
                      <%= if product.grants_storage_bytes && product.grants_storage_bytes > 0 do %>
                        <li class="flex items-center text-gray-300">
                          <span class="text-green-400 mr-2">✓</span>
                          <%= format_storage(product.grants_storage_bytes) %> storage
                        </li>
                      <% end %>
                      <%= for feature <- (product.grants_features || []) do %>
                        <li class="flex items-center text-gray-300">
                          <span class="text-green-400 mr-2">✓</span>
                          <%= humanize_feature(feature) %>
                        </li>
                      <% end %>
                    </ul>
                    
                    <%= if product.id in @user_subscriptions do %>
                      <button disabled class="w-full bg-green-600/50 text-green-300 py-3 rounded-lg font-semibold cursor-not-allowed">
                        ✓ Active Subscription
                      </button>
                    <% else %>
                      <button phx-click="subscribe" phx-value-product_id={product.id}
                              class={"w-full py-3 rounded-lg font-semibold transition-colors #{if product.featured, do: "bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 text-white", else: "bg-gray-700 hover:bg-gray-600 text-white"}"}>
                        <%= if Decimal.compare(product.price, Decimal.new("0")) == :eq, do: "Get Started Free", else: "Subscribe Now" %>
                      </button>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          
          <!-- Product List View -->
          <div class="flex justify-between items-center mb-8">
            <h1 class="text-3xl font-bold text-white">
              <%= if @selected_category, do: @selected_category.name, else: "Digital Products" %>
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

          <!-- Products Grid (one-time purchases) -->
          <% one_time_products = Enum.filter(@products, fn p -> (p.billing_interval || "one_time") == "one_time" end) %>
          <div class="product-grid">
            <%= for product <- one_time_products do %>
              <div class="product-card">
                <.link navigate={"/shop/product/#{product.id}"}>
                  <div class="product-image bg-gradient-to-br from-gray-600 to-gray-800 flex items-center justify-center">
                    <span class="text-4xl"><%= product_icon(product.product_type) %></span>
                  </div>
                </.link>
                
                <div class="product-info">
                  <div class="flex items-center gap-2 mb-1">
                    <h3 class="product-title"><%= product.name %></h3>
                    <%= if product.product_type == "digital" do %>
                      <span class="text-xs bg-blue-600/30 text-blue-300 px-2 py-0.5 rounded">Digital</span>
                    <% end %>
                  </div>
                  <p class="text-gray-300 text-sm mb-2 line-clamp-2"><%= product.description %></p>
                  <div class="flex justify-between items-center">
                    <span class="product-price">
                      <%= if Decimal.compare(product.price, Decimal.new("0")) == :eq do %>
                        <span class="text-green-400">Free</span>
                      <% else %>
                        $<%= product.price %>
                      <% end %>
                    </span>
                    <button phx-click="add_to_cart" phx-value-product_id={product.id}
                            class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors">
                      <%= if product.product_type == "digital", do: "Get Now", else: "Add to Cart" %>
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @products == [] and @subscription_products == [] do %>
            <div class="text-center py-16">
              <div class="text-gray-400 text-xl">No products available yet</div>
              <p class="text-gray-500 mt-2">Check back soon for new offerings!</p>
            </div>
          <% end %>
        <% end %>

        <%= if @view == :product_detail do %>
          <!-- Product Detail View -->
          <div class="max-w-6xl mx-auto">
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
                  <%= if @product.weight do %>
                    <div class="flex items-center">
                      <span class="text-gray-400 w-24">Weight:</span>
                      <span><%= @product.weight %> lbs</span>
                    </div>
                  <% end %>
                  <%= if @product.dimensions do %>
                    <div class="flex items-center">
                      <span class="text-gray-400 w-24">Dimensions:</span>
                      <span><%= @product.dimensions %></span>
                    </div>
                  <% end %>
                </div>

                <div class="flex space-x-4">
                  <button phx-click="add_to_cart" phx-value-product_id={@product.id}
                          disabled={@product.stock_quantity == 0}
                          class="flex-1 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white px-8 py-3 rounded-lg font-semibold transition-colors">
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
        <% end %>
    </PhoenixAppWeb.Components.PageContainer.page_container>
    """
  end
end