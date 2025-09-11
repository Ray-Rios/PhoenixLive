defmodule PhoenixAppWeb.UserManagementLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts

  on_mount {PhoenixAppWeb.UserAuth, :require_admin_user}

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    
    {:ok, assign(socket,
      page_title: "User Management",
      users: users,
      user_stats: get_user_stats(users)
    )}
  end

  @impl true
  def handle_event("toggle_admin", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    
    case Accounts.update_user(user, %{is_admin: !user.is_admin}) do
      {:ok, _updated_user} ->
        {:noreply, socket
         |> assign(users: Accounts.list_users())
         |> put_flash(:info, "User admin status updated")}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user")}
    end
  end

  @impl true
  def handle_event("delete_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    
    # Don't allow deleting yourself
    if user.id == socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "Cannot delete your own account")}
    else
      case Accounts.delete_user(user) do
        {:ok, _deleted_user} ->
          {:noreply, socket
           |> assign(users: Accounts.list_users())
           |> put_flash(:info, "User deleted successfully")}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete user")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div class="flex items-center">
              <h1 class="text-3xl font-bold text-gray-900">User Management</h1>
            </div>
            <div class="flex items-center space-x-4">
              <.link navigate="/admin" class="text-blue-600 hover:text-blue-500">
                ← Back to Admin
              </.link>
            </div>
          </div>
        </div>
      </div>

      <!-- Stats Cards -->
      <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"></path>
                    </svg>
                  </div>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @user_stats.total %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                  </div>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Confirmed</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @user_stats.confirmed %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>
                    </svg>
                  </div>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Admins</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @user_stats.admins %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                  </div>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Recent</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @user_stats.recent %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Users Table -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">All Users</h3>
            
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Joined</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for user <- @users do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="flex items-center">
                          <div class="flex-shrink-0 h-10 w-10">
                            <div class={[
                              "h-10 w-10 rounded-full flex items-center justify-center text-white font-medium",
                              "bg-gradient-to-r from-blue-500 to-purple-600"
                            ]}>
                              <%= String.first(user.name || user.email) |> String.upcase() %>
                            </div>
                          </div>
                          <div class="ml-4">
                            <div class="text-sm font-medium text-gray-900"><%= user.name || "No name" %></div>
                            <div class="text-sm text-gray-500"><%= user.email %></div>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          if(user.confirmed_at, do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800")
                        ]}>
                          <%= if user.confirmed_at, do: "Confirmed", else: "Pending" %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          if(user.is_admin, do: "bg-purple-100 text-purple-800", else: "bg-gray-100 text-gray-800")
                        ]}>
                          <%= if user.is_admin, do: "Admin", else: "User" %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= Calendar.strftime(user.inserted_at, "%B %d, %Y") %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <button
                          phx-click="toggle_admin"
                          phx-value-user_id={user.id}
                          class={[
                            "mr-4 px-3 py-1 rounded text-xs font-medium",
                            if(user.is_admin, do: "bg-red-100 text-red-800 hover:bg-red-200", else: "bg-blue-100 text-blue-800 hover:bg-blue-200")
                          ]}
                        >
                          <%= if user.is_admin, do: "Remove Admin", else: "Make Admin" %>
                        </button>
                        <%= if user.id != @current_user.id do %>
                          <button
                            phx-click="delete_user"
                            phx-value-user_id={user.id}
                            data-confirm="Are you sure you want to delete this user?"
                            class="text-red-600 hover:text-red-900"
                          >
                            Delete
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
      </div>
    </div>
    """
  end

  defp get_user_stats(users) do
    total = length(users)
    confirmed = Enum.count(users, & &1.confirmed_at)
    admins = Enum.count(users, & &1.is_admin)
    
    # Users created in the last 30 days
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
    recent = Enum.count(users, fn user ->
      DateTime.compare(user.inserted_at, thirty_days_ago) == :gt
    end)

    %{
      total: total,
      confirmed: confirmed,
      admins: admins,
      recent: recent
    }
  end
end