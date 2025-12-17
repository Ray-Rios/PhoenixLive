defmodule PhoenixAppWeb.AdminLive.Orders do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Commerce
  alias PhoenixAppWeb.Components.AdminSidebar

  on_mount {PhoenixAppWeb.UserAuth, :require_admin_user}

  @order_statuses ["pending", "processing", "shipped", "delivered", "cancelled", "refunded"]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Admin - Orders",
       orders: Commerce.list_orders(),
       order_statuses: @order_statuses,
       selected_order: nil,
       filter_status: nil
     )}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    status = if status == "", do: nil, else: status
    orders = if status, do: filter_orders_by_status(status), else: Commerce.list_orders()
    {:noreply, assign(socket, orders: orders, filter_status: status)}
  end

  def handle_event("update_status", %{"id" => id, "status" => new_status}, socket) do
    order = Commerce.get_order!(id)
    
    case Commerce.update_order(order, %{status: new_status}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(orders: Commerce.list_orders())
         |> put_flash(:info, "Order status updated to #{new_status}")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update order status")}
    end
  end

  def handle_event("view_order", %{"id" => id}, socket) do
    order = Commerce.get_order!(id)
    {:noreply, assign(socket, selected_order: order)}
  end

  def handle_event("close_order_details", _params, socket) do
    {:noreply, assign(socket, selected_order: nil)}
  end

  defp filter_orders_by_status(status) do
    Commerce.list_orders()
    |> Enum.filter(fn order -> order.status == status end)
  end

  def render(assigns) do
    ~H"""
    <AdminSidebar.admin_layout current_path="/admin/orders">
      <div class="max-w-6xl mx-auto">
        <div class="dark-glass p-8 rounded-xl">
          <!-- Header -->
          <div class="flex justify-between items-center mb-8">
            <div>
              <h1 class="text-3xl font-bold text-white">Orders</h1>
              <p class="text-gray-400 mt-1">Manage customer orders and fulfillment</p>
            </div>
            
            <!-- Filter -->
            <div class="flex items-center gap-3">
              <label class="text-gray-400 text-sm">Filter:</label>
              <select
                phx-change="filter_status"
                name="status"
                class="bg-gray-700 border-gray-600 text-white rounded-lg px-3 py-2 text-sm"
              >
                  <option value="">All Orders</option>
                  <%= for status <- @order_statuses do %>
                    <option value={status} selected={@filter_status == status}><%= String.capitalize(status) %></option>
                  <% end %>
                </select>
              </div>
            </div>

            <!-- Order Details Modal -->
            <%= if @selected_order do %>
              <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" phx-click="close_order_details">
                <div class="bg-gray-800 rounded-xl p-6 max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto" phx-click-away="close_order_details">
                  <div class="flex justify-between items-center mb-6">
                    <h3 class="text-xl font-bold text-white">Order Details</h3>
                    <button phx-click="close_order_details" class="text-gray-400 hover:text-white">✕</button>
                  </div>
                  
                  <div class="space-y-4">
                    <div class="grid grid-cols-2 gap-4">
                      <div>
                        <p class="text-gray-500 text-sm">Order ID</p>
                        <p class="text-white font-mono"><%= String.slice(@selected_order.id, -12..-1) %></p>
                      </div>
                      <div>
                        <p class="text-gray-500 text-sm">Status</p>
                        <p class="text-white"><%= String.capitalize(@selected_order.status || "pending") %></p>
                      </div>
                      <div>
                        <p class="text-gray-500 text-sm">Customer</p>
                        <p class="text-white"><%= if @selected_order.user, do: @selected_order.user.email, else: "Guest" %></p>
                      </div>
                      <div>
                        <p class="text-gray-500 text-sm">Total</p>
                        <p class="text-green-400 font-bold">$<%= @selected_order.total_amount %></p>
                      </div>
                    </div>
                    
                    <%= if @selected_order.order_items != [] do %>
                      <div class="border-t border-gray-700 pt-4 mt-4">
                        <h4 class="text-white font-medium mb-3">Order Items</h4>
                        <div class="space-y-2">
                          <%= for item <- @selected_order.order_items do %>
                            <div class="flex justify-between items-center bg-gray-700/50 rounded-lg px-4 py-2">
                              <span class="text-white">Item</span>
                              <span class="text-gray-400">Qty: <%= item.quantity %></span>
                              <span class="text-green-400">$<%= item.price %></span>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Orders Table -->
            <div class="bg-gray-800/50 rounded-lg border border-gray-700 overflow-hidden">
              <table class="w-full">
                <thead class="bg-black/30">
                  <tr>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Order ID</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Customer</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Total</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Status</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Date</th>
                    <th class="text-right text-gray-300 px-4 py-3 text-sm font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-700">
                  <%= if @orders == [] do %>
                    <tr>
                      <td colspan="6" class="px-4 py-8 text-center text-gray-500">
                        No orders yet
                      </td>
                    </tr>
                  <% else %>
                    <%= for order <- @orders do %>
                      <tr class="hover:bg-white/5">
                        <td class="px-4 py-3">
                          <span class="text-white font-mono text-sm">
                            #<%= String.slice(to_string(order.id), -8..-1) %>
                          </span>
                        </td>
                        <td class="px-4 py-3">
                          <p class="text-white text-sm"><%= if order.user, do: (order.user.name || order.user.email), else: "Guest" %></p>
                          <p class="text-gray-500 text-xs"><%= if order.user, do: order.user.email, else: "No account" %></p>
                        </td>
                        <td class="px-4 py-3 text-green-400 font-bold">
                          $<%= order.total_amount || "0.00" %>
                        </td>
                        <td class="px-4 py-3">
                          <select
                            phx-change="update_status"
                            phx-value-id={order.id}
                            name="status"
                            class={[
                              "px-2 py-1 rounded text-xs border-0",
                              case order.status do
                                "pending" -> "bg-yellow-600/30 text-yellow-300"
                                "processing" -> "bg-blue-600/30 text-blue-300"
                                "shipped" -> "bg-purple-600/30 text-purple-300"
                                "delivered" -> "bg-green-600/30 text-green-300"
                                "cancelled" -> "bg-red-600/30 text-red-300"
                                "refunded" -> "bg-gray-600/30 text-gray-300"
                                _ -> "bg-gray-600/30 text-gray-300"
                              end
                            ]}
                          >
                            <%= for status <- @order_statuses do %>
                              <option value={status} selected={order.status == status}>
                                <%= String.capitalize(status) %>
                              </option>
                            <% end %>
                          </select>
                        </td>
                        <td class="px-4 py-3 text-gray-400 text-sm">
                          <%= if order.inserted_at, do: Calendar.strftime(order.inserted_at, "%m/%d/%Y %I:%M %p"), else: "N/A" %>
                        </td>
                        <td class="px-4 py-3 text-right">
                          <button
                            phx-click="view_order"
                            phx-value-id={order.id}
                            class="text-blue-400 hover:text-blue-300 text-sm"
                          >
                            View Details
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </AdminSidebar.admin_layout>
    """
  end
end