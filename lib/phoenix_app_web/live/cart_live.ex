defmodule PhoenixAppWeb.CartLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Commerce

  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    if user do
      cart = Commerce.get_or_create_cart(user)
      cart_total = Commerce.calculate_cart_total(cart)
      
      {:ok, assign(socket,
        cart: cart,
        cart_total: cart_total,
        page_title: "Shopping Cart"
      )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_event("update_quantity", %{"item_id" => item_id, "quantity" => quantity_str}, socket) do
    quantity = String.to_integer(quantity_str)
    
    if quantity > 0 do
      cart_item = Commerce.get_cart_item!(item_id)
      
      case Commerce.update_cart_item(cart_item, %{quantity: quantity}) do
        {:ok, _updated_item} ->
          cart = Commerce.get_or_create_cart(socket.assigns.current_user)
          cart_total = Commerce.calculate_cart_total(cart)
          
          {:noreply, assign(socket, cart: cart, cart_total: cart_total)}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update quantity")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_item", %{"item_id" => item_id}, socket) do
    cart_item = Commerce.get_cart_item!(item_id)
    
    case Commerce.remove_from_cart(cart_item) do
      {:ok, _} ->
        cart = Commerce.get_or_create_cart(socket.assigns.current_user)
        cart_total = Commerce.calculate_cart_total(cart)
        
        {:noreply, assign(socket, cart: cart, cart_total: cart_total)
         |> put_flash(:info, "Item removed from cart")}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove item")}
    end
  end

  def handle_event("clear_cart", _params, socket) do
    case Commerce.clear_cart(socket.assigns.cart) do
      {_count, _} ->
        cart = Commerce.get_or_create_cart(socket.assigns.current_user)
        cart_total = Commerce.calculate_cart_total(cart)
        
        {:noreply, assign(socket, cart: cart, cart_total: cart_total)
         |> put_flash(:info, "Cart cleared")}
    end
  end

  def render(assigns) do
    ~H"""
    <.navbar current_user={@current_user} />
    <div class="starry-background w-full max-w-[80%] mx-auto px-4 py-8 relative z-10 mt-[50px]">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      
      <div class="max-w-4xl mx-auto">
          <h1 class="text-3xl font-bold text-white mb-8">Shopping Cart</h1>
          
          <div :if={@cart.cart_items == []} class="text-center py-16">
            <div class="text-gray-400 text-xl">Your cart is empty</div>
            <p class="text-gray-500 mt-2">Add some items to get started</p>
            <.link navigate="/shop" class="inline-block mt-4 bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition-colors">
              Continue Shopping
            </.link>
          </div>

          <div :if={@cart.cart_items != []} class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Cart Items -->
            <div class="lg:col-span-2">
              <div class="bg-gray-800 rounded-lg p-6">
                <h2 class="text-xl font-semibold text-white mb-6">Cart Items</h2>
                
                <div class="space-y-4">
                  <%= for item <- @cart.cart_items do %>
                    <div class="flex items-center space-x-4 p-4 bg-gray-700 rounded-lg">
                      <div class="w-16 h-16 bg-gradient-to-br from-gray-600 to-gray-800 rounded flex items-center justify-center">
                        <span class="text-2xl">📦</span>
                      </div>
                      
                      <div class="flex-1">
                        <h3 class="text-white font-medium"><%= item.product.name %></h3>
                        <p class="text-gray-400 text-sm"><%= item.product.sku %></p>
                        <p class="text-green-400 font-bold">$<%= item.product.price %></p>
                      </div>
                      
                      <div class="flex items-center space-x-2">
                        <input type="number" value={item.quantity} min="1" max={item.product.stock_quantity}
                               phx-change="update_quantity" phx-value-item_id={item.id}
                               class="w-16 bg-gray-600 text-white px-2 py-1 rounded text-center" />
                        
                        <button phx-click="remove_item" phx-value-item_id={item.id}
                                class="text-red-400 hover:text-red-300 p-1">
                          🗑️
                        </button>
                      </div>
                      
                      <div class="text-white font-bold">
                        $<%= Decimal.mult(item.product.price, item.quantity) %>
                      </div>
                    </div>
                  <% end %>
                </div>
                
                <div class="mt-6 pt-4 border-t border-gray-600">
                  <button phx-click="clear_cart" 
                          class="text-red-400 hover:text-red-300 text-sm"
                          onclick="return confirm('Are you sure you want to clear your cart?')">
                    Clear Cart
                  </button>
                </div>
              </div>
            </div>

            <!-- Order Summary -->
            <div class="lg:col-span-1">
              <div class="bg-gray-800 rounded-lg p-6 sticky top-4">
                <h2 class="text-xl font-semibold text-white mb-6">Order Summary</h2>
                
                <div class="space-y-3 mb-6">
                  <div class="flex justify-between text-gray-300">
                    <span>Subtotal</span>
                    <span>$<%= @cart_total %></span>
                  </div>
                  <div class="flex justify-between text-gray-300">
                    <span>Shipping</span>
                    <span>Free</span>
                  </div>
                  <div class="flex justify-between text-gray-300">
                    <span>Tax</span>
                    <span>$<%= Decimal.mult(@cart_total, Decimal.new("0.08")) %></span>
                  </div>
                  <div class="border-t border-gray-600 pt-3">
                    <div class="flex justify-between text-white font-bold text-lg">
                      <span>Total</span>
                      <span>$<%= Decimal.add(@cart_total, Decimal.mult(@cart_total, Decimal.new("0.08"))) %></span>
                    </div>
                  </div>
                </div>
                
                <.link navigate="/checkout" 
                       class="w-full bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg font-semibold text-center block transition-colors">
                  Proceed to Checkout
                </.link>
                
                <.link navigate="/shop" 
                       class="w-full bg-gray-600 hover:bg-gray-700 text-white py-2 rounded-lg text-center block mt-3 transition-colors">
                  Continue Shopping
                </.link>
              </div>
            </div>
          </div>
      </div>
    </div>
    """
  end
end