defmodule PhoenixAppWeb.AdminLive.UserManagementLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts
  alias PhoenixAppWeb.UserAuth

  # Ensure current_user is loaded and authenticated
  on_mount {UserAuth, :require_authenticated_user}

  @impl true
  def mount(_params, _session, socket) do
    # Check if current_user exists and is admin
    current_user = socket.assigns[:current_user]

    cond do
      current_user == nil ->
        # Redirect if no user is logged in
        {:ok, redirect(socket, to: "/login")}

      not current_user.is_admin ->
        # Redirect if user is not admin
        {:ok, redirect(socket, to: "/dashboard")}

      true ->
        # Load users for admin
        users = Accounts.list_users()
        {:ok, assign(socket, users: users, page_title: "User Management", confirm_delete_user_id: nil)}
    end
  end

  @impl true
  def handle_event("toggle_admin", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    result =
      if user.is_admin do
        Accounts.remove_admin(user)
      else
        Accounts.make_admin(user)
      end

    case result do
      {:ok, _updated_user} ->
        users = Accounts.list_users()
        {:noreply, assign(socket, users: users)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user permissions")}
    end
  end

  @impl true
  def handle_event("toggle_status", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    result =
      if user.status == "active" do
        Accounts.disable_user(user)
      else
        Accounts.enable_user(user)
      end

    case result do
      {:ok, _updated_user} ->
        users = Accounts.list_users()
        {:noreply, assign(socket, users: users)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user status")}
    end
  end

  @impl true
  def handle_event("delete_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.delete_user(user) do
      {:ok, _deleted_user} ->
        users = Accounts.list_users()
        {:noreply, 
         socket
         |> assign(users: users)
         |> put_flash(:info, "User deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete user")}
    end
  end

  @impl true
  def handle_event("confirm_delete", %{"user_id" => user_id}, socket) do
    {:noreply, assign(socket, confirm_delete_user_id: user_id)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete_user_id: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="starry-background">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>

      <.navbar current_user={@current_user} />

      <div class="w-full max-w-[80%] mx-auto px-4 py-8 relative z-10 mt-[50px]">
        <div class="max-w-6xl mx-auto">
          <h1 class="text-3xl font-bold text-white mb-8">User Management</h1>
          <div class="bg-gray-800 rounded-lg overflow-hidden">
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead class="bg-gray-700">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">User</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Email</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Status</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Role</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Joined</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-700">
                  <%= for user <- @users do %>
                    <tr class="hover:bg-gray-700 transition-colors">
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-white">
                        <div class="flex items-center">
                          <div class="flex-shrink-0 h-8 w-8">
                            <div class="h-8 w-8 rounded-full bg-blue-500 flex items-center justify-center text-white text-sm font-medium">
                              <%= String.first(user.name || user.email) |> String.upcase() %>
                            </div>
                          </div>
                          <div class="ml-3">
                            <div class="text-sm font-medium text-white"><%= user.name || "No name" %></div>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300"><%= user.email %></td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{if (user.status || "active") == "active", do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                          <%= String.capitalize(user.status || "active") %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{if user.is_admin, do: "bg-purple-100 text-purple-800", else: "bg-gray-100 text-gray-800"}"}>
                          <%= if user.is_admin, do: "Admin", else: "Member" %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300"><%= Calendar.strftime(user.inserted_at, "%b %d, %Y") %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm">
                        <%= if user.id != @current_user.id do %>
                          <div class="flex space-x-2">
                            <button 
                              phx-click="toggle_admin" 
                              phx-value-user_id={user.id}
                              class={"px-3 py-1 text-xs font-medium rounded-md transition-colors #{if user.is_admin, do: "bg-red-600 hover:bg-red-700 text-white", else: "bg-blue-600 hover:bg-blue-700 text-white"}"}
                            >
                              <%= if user.is_admin, do: "Remove Admin", else: "Make Admin" %>
                            </button>
                            
                            <button 
                              phx-click="toggle_status" 
                              phx-value-user_id={user.id}
                              class={"px-3 py-1 text-xs font-medium rounded-md transition-colors #{if user.status == "active", do: "bg-yellow-600 hover:bg-yellow-700 text-white", else: "bg-green-600 hover:bg-green-700 text-white"}"}
                            >
                              <%= if user.status == "active", do: "Disable", else: "Enable" %>
                            </button>
                            
                            <%= if @confirm_delete_user_id == user.id do %>
                              <div class="flex space-x-1">
                                <button 
                                  phx-click="delete_user" 
                                  phx-value-user_id={user.id}
                                  class="px-3 py-1 text-xs font-medium bg-red-700 hover:bg-red-800 text-white rounded-md transition-colors"
                                >
                                  Confirm
                                </button>
                                <button 
                                  phx-click="cancel_delete"
                                  class="px-3 py-1 text-xs font-medium bg-gray-600 hover:bg-gray-700 text-white rounded-md transition-colors"
                                >
                                  Cancel
                                </button>
                              </div>
                            <% else %>
                              <button 
                                phx-click="confirm_delete" 
                                phx-value-user_id={user.id}
                                class="px-3 py-1 text-xs font-medium bg-red-600 hover:bg-red-700 text-white rounded-md transition-colors"
                              >
                                Delete
                              </button>
                            <% end %>
                          </div>
                        <% else %>
                          <span class="text-gray-400 text-xs">Current User</span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
