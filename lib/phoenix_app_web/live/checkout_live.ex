defmodule PhoenixAppWeb.CheckoutLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Commerce

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user do
      cart = Commerce.get_or_create_cart(user)

      if cart.cart_items == [] do
        {:ok, redirect(socket, to: "/cart")}
      else
        cart_total = Commerce.calculate_cart_total(cart)
        tax_amount = Decimal.mult(cart_total, Decimal.new("0.08"))
        total_amount = Decimal.add(cart_total, tax_amount)

        {:ok,
         assign(socket,
           cart: cart,
           cart_total: cart_total,
           tax_amount: tax_amount,
           total_amount: total_amount,
           billing_address: %{},
           shipping_address: %{},
           same_as_billing: true,
           page_title: "Checkout"
         )}
      end
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_event("toggle_same_address", _params, socket) do
    {:noreply, assign(socket, same_as_billing: !socket.assigns.same_as_billing)}
  end

  def handle_event("update_billing", %{"address" => address_params}, socket) do
    {:noreply, assign(socket, billing_address: address_params)}
  end

  def handle_event("update_shipping", %{"address" => address_params}, socket) do
    {:noreply, assign(socket, shipping_address: address_params)}
  end

  def handle_event("place_order", _params, socket) do
    user = socket.assigns.current_user
    cart = socket.assigns.cart

    shipping_address =
      if socket.assigns.same_as_billing do
        socket.assigns.billing_address
      else
        socket.assigns.shipping_address
      end

    order_attrs = %{
      total_amount: socket.assigns.total_amount,
      billing_address: socket.assigns.billing_address,
      shipping_address: shipping_address,
      status: "pending"
    }

    case Commerce.create_order(user, order_attrs) do
      {:ok, order} ->
        Enum.each(cart.cart_items, fn cart_item ->
          Commerce.create_order_item(order, %{
            product_id: cart_item.product_id,
            quantity: cart_item.quantity,
            price: cart_item.product.price
          })
        end)

        Commerce.clear_cart(cart)
        {:noreply, redirect(socket, to: "/profile/orders")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to place order")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="starry-background chat-container min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>

      <!-- Chat Container -->
      <div class="container mx-auto px-4 py-8 relative z-10">
        <div class="max-w-6xl mx-auto">
          <h1 class="text-3xl font-bold text-white mb-8">Checkout</h1>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- Checkout Form -->
            <div class="space-y-6">
              <!-- Billing Address -->
              <div class="bg-gray-800 rounded-lg p-6">
                <h2 class="text-xl font-semibold text-white mb-4">Billing Address</h2>
                <form phx-change="update_billing">
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <input type="text" name="address[first_name]" placeholder="First Name"
                           class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                    <input type="text" name="address[last_name]" placeholder="Last Name"
                           class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                  </div>

                  <input type="text" name="address[street]" placeholder="Street Address"
                         class="w-full mt-4 bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />

                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
                    <input type="text" name="address[city]" placeholder="City"
                           class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                    <input type="text" name="address[state]" placeholder="State"
                           class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                    <input type="text" name="address[zip]" placeholder="ZIP Code"
                           class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                  </div>
                </form>
              </div>

              <!-- Shipping Address -->
              <div class="bg-gray-800 rounded-lg p-6">
                <div class="flex items-center justify-between mb-4">
                  <h2 class="text-xl font-semibold text-white">Shipping Address</h2>
                  <label class="flex items-center text-gray-300">
                    <input type="checkbox" checked={@same_as_billing} phx-click="toggle_same_address"
                           class="mr-2 rounded bg-gray-600 border-gray-500" />
                    Same as billing
                  </label>
                </div>

                <div :if={!@same_as_billing}>
                  <form phx-change="update_shipping">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <input type="text" name="address[first_name]" placeholder="First Name"
                             class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                      <input type="text" name="address[last_name]" placeholder="Last Name"
                             class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                    </div>

                    <input type="text" name="address[street]" placeholder="Street Address"
                           class="w-full mt-4 bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />

                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
                      <input type="text" name="address[city]" placeholder="City"
                             class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                      <input type="text" name="address[state]" placeholder="State"
                             class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                      <input type="text" name="address[zip]" placeholder="ZIP Code"
                             class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                    </div>
                  </form>
                </div>
              </div>

              <!-- Payment Method -->
              <div class="bg-gray-800 rounded-lg p-6">
                <h2 class="text-xl font-semibold text-white mb-4">Payment Method</h2>
                <div class="text-gray-300">
                  <p>Payment processing will be integrated with Stripe.</p>
                  <p class="text-sm mt-2">For demo purposes, clicking "Place Order" will create the order.</p>
                </div>
              </div>
            </div>

            <!-- Order Summary -->
            <div>
              <div class="bg-gray-800 rounded-lg p-6 sticky top-4">
                <h2 class="text-xl font-semibold text-white mb-6">Order Summary</h2>

                <!-- Order Items -->
                <div class="space-y-3 mb-6">
                  <%= for item <- @cart.cart_items do %>
                    <div class="flex items-center space-x-3">
                      <img src={PhoenixApp.ProductImage.url({item.product.image, item.product}, :thumb) || "/images/default_product.png"} 
                           alt={item.product.name} class="w-12 h-12 object-cover rounded" />
                      <div class="flex-1">
                        <div class="text-white text-sm"><%= item.product.name %></div>
                        <div class="text-gray-400 text-xs">Qty: <%= item.quantity %></div>
                      </div>
                      <div class="text-white font-medium">
                        $<%= Decimal.mult(item.product.price, item.quantity) %>
                      </div>
                    </div>
                  <% end %>
                </div>

                <!-- Totals -->
                <div class="space-y-2 mb-6 pt-4 border-t border-gray-600">
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
                    <span>$<%= @tax_amount %></span>
                  </div>
                  <div class="border-t border-gray-600 pt-2">
                    <div class="flex justify-between text-white font-bold text-lg">
                      <span>Total</span>
                      <span>$<%= @total_amount %></span>
                    </div>
                  </div>
                </div>

                <button phx-click="place_order"
                        class="w-full bg-green-600 hover:bg-green-700 text-white py-3 rounded-lg font-semibold transition-colors">
                  Place Order
                </button>

                <.link navigate="/cart"
                       class="w-full bg-gray-600 hover:bg-gray-700 text-white py-2 rounded-lg text-center block mt-3 transition-colors">
                  Back to Cart
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
