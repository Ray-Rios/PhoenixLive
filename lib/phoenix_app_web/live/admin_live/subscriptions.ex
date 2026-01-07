defmodule PhoenixAppWeb.AdminLive.Subscriptions do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Commerce
  alias PhoenixAppWeb.Components.AdminSidebar

  on_mount {PhoenixAppWeb.UserAuth, :require_admin_user}

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Admin - Subscriptions",
       subscriptions: Commerce.list_subscriptions()
     )}
  end

  def handle_event("cancel_subscription", %{"id" => id}, socket) do
    subscription = Commerce.get_subscription!(id)
    
    case Commerce.cancel_subscription(subscription) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(subscriptions: Commerce.list_subscriptions())
         |> put_flash(:info, "Subscription canceled.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel subscription.")}
    end
  end

  def render(assigns) do
    ~H"""
    <AdminSidebar.admin_layout current_path="/admin/subscriptions">
      <div class="max-w-6xl mx-auto">
        <div class="dark-glass p-8 rounded-xl">
          <div class="flex justify-between items-center mb-8">
            <div>
              <h1 class="text-3xl font-bold text-white">Subscriptions</h1>
              <p class="text-gray-400 mt-1">Manage user subscriptions</p>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-left text-gray-300">
              <thead class="text-xs uppercase bg-gray-700/50 text-gray-400">
                <tr>
                  <th class="px-6 py-3">User</th>
                  <th class="px-6 py-3">Product</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Renews/Expires</th>
                  <th class="px-6 py-3">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-700">
                <%= for sub <- @subscriptions do %>
                  <tr class="hover:bg-gray-700/30">
                    <td class="px-6 py-4">
                      <div class="font-medium text-white"><%= sub.user.email %></div>
                    </td>
                    <td class="px-6 py-4"><%= sub.product.name %></td>
                    <td class="px-6 py-4">
                      <span class={"px-2 py-1 rounded-full text-xs " <> if(sub.status == "active", do: "bg-green-900 text-green-200", else: "bg-gray-700 text-gray-300")}>
                        <%= String.capitalize(sub.status) %>
                      </span>
                    </td>
                    <td class="px-6 py-4">
                      <%= if sub.cancel_at_period_end do %>
                        <span class="text-yellow-500">Cancels <%= Calendar.strftime(sub.current_period_end, "%b %d, %Y") %></span>
                      <% else %>
                        <%= Calendar.strftime(sub.current_period_end, "%b %d, %Y") %>
                      <% end %>
                    </td>
                    <td class="px-6 py-4">
                      <%= if sub.status == "active" and not sub.cancel_at_period_end do %>
                        <button phx-click="cancel_subscription" phx-value-id={sub.id} data-confirm="Are you sure?" class="text-red-400 hover:text-red-300 text-sm">
                          Cancel
                        </button>
                      <% end %>
                    </td>
                  </tr>
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
