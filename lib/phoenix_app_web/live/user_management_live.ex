defmodule PhoenixAppWeb.UserManagementLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts
  
  require Logger

  # Ensure current_user is loaded and authenticated
  on_mount {PhoenixAppWeb.UserAuth, :require_admin_user}

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
        # Ensure first user is admin
        ensure_first_user_is_admin()
        
        # Load users and default role setting
        users = Accounts.list_users()
        default_role = PhoenixApp.Settings.get_default_user_role()
        
        {:ok, assign(socket, users: users, page_title: "User Management", confirm_delete_user_id: nil, default_role: default_role)}
    end
  end

  # Ensure the first registered user gets admin privileges
  defp ensure_first_user_is_admin do
    import Ecto.Query
    
    case Accounts.count_users() do
      0 -> :ok  # No users yet
      count when count > 0 ->
        # Check if there are any admin users
        admin_count = Accounts.count_admin_users()
        
        if admin_count == 0 do
          # No admins exist, make the first user admin
          first_user = from(u in PhoenixApp.Accounts.User, order_by: [asc: u.inserted_at], limit: 1) 
                      |> PhoenixApp.Repo.one()
          
          if first_user do
            Accounts.make_admin(first_user)
            Logger.info("Made first user #{first_user.email} an admin")
          end
        end
    end
  end

  @impl true
  def handle_event("change_default_role", params, socket) do
    # Handle both map and url-encoded string from form submission
    role = case params do
      %{"default_role" => role} -> role
      %{"value" => value} when is_binary(value) ->
        # Parse URL-encoded string like "default_role=admin"
        case String.split(value, "=") do
          ["default_role", role] -> role
          _ -> nil
        end
      _ -> nil
    end
    
    Logger.info("Attempting to change default role to: #{inspect(role)}, from params: #{inspect(params)}")
    
    case PhoenixApp.Settings.set_default_user_role(role) do
      {:ok, result} ->
        Logger.info("Successfully set default role to: #{role}, result: #{inspect(result)}")
        {:noreply, socket 
         |> assign(default_role: role)
         |> put_flash(:info, "Default role updated to #{role}")}
      
      {:error, reason} ->
        Logger.error("Failed to set default role: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to update default role")}
    end
  end

  @impl true
  def handle_event("change_role", %{"user_id" => user_id, "role" => role}, socket) do
    user = Accounts.get_user!(user_id)
    
    case Accounts.update_user_role(user, role) do
      {:ok, _updated_user} ->
        users = Accounts.list_users()
        {:noreply, assign(socket, users: users) |> put_flash(:info, "User role updated successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user role")}
    end
  end

  @impl true
  def handle_event("toggle_status", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    
    # Get current status (accounting for unverified users)
    current_status = get_user_status(user)
    
    # Toggle: if active -> disabled, otherwise -> active
    new_status = if current_status == "active", do: "disabled", else: "active"
    
    # If activating an unverified user, also verify their email
    attrs = if current_status == "unverified" and new_status == "active" do
      %{status: new_status, email_verified_at: DateTime.utc_now()}
    else
      %{status: new_status}
    end
    
    case Accounts.update_user(user, attrs) do
      {:ok, _updated_user} ->
        users = Accounts.list_users()
        
        socket = 
          socket
          |> put_flash(:info, "User status updated to #{new_status}")
          |> assign(:users, users)
          
        {:noreply, socket}
        
      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Failed to update user status")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_delete", %{"user_id" => user_id}, socket) do
    {:noreply, assign(socket, confirm_delete_user_id: user_id)}
  end

  @impl true
  def handle_event("delete_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    
    case Accounts.delete_user(user) do
      {:ok, _deleted_user} ->
        users = Accounts.list_users()
        {:noreply, assign(socket, users: users, confirm_delete_user_id: nil) |> put_flash(:info, "User deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete user")}
    end
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete_user_id: nil)}
  end

  # Helper function to determine user role
  defp get_user_role(user) do
    cond do
      user.is_admin -> "admin"
      user.role && user.role != "subscriber" -> user.role
      true -> "member"
    end
  end

  # Helper function to determine actual user status
  defp get_user_status(user) do
    cond do
      # Check if email is unverified
      is_nil(user.email_verified_at) -> "unverified"
      # Check explicit status field
      user.status != nil -> user.status
      # Default to active
      true -> "active"
    end
  end

  # Helper function for status badge colors
  defp status_badge_class(status) do
    case status do
      "unverified" -> "bg-yellow-100 text-yellow-800"
      "active" -> "bg-green-100 text-green-800"
      "disabled" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <div class="w-full max-w-[85%] mx-auto px-4 py-8 relative z-10 mt-[50px]">
        <div class="max-w-7xl mx-auto">
          <h1 class="text-3xl font-bold text-white mb-8">User Management</h1>
          
          <!-- Default Role Setting -->
          <div class="glass-dark rounded-lg p-6 mb-6">
            <h2 class="text-lg font-semibold text-white mb-4">Default Role Settings</h2>
            <form phx-submit="change_default_role" class="flex items-center space-x-4">
              <label class="text-sm font-medium text-gray-300">Default role for new users:</label>
              <select 
                name="default_role"
                onchange="this.form.requestSubmit()"
                class="bg-gray-700 text-white px-3 py-2 rounded border border-gray-600 focus:border-blue-500"
              >
                <option value="guest" selected={@default_role == "guest"}>Guest</option>
                <option value="member" selected={@default_role == "member"}>Member</option>
                <option value="moderator" selected={@default_role == "moderator"}>Moderator</option>
                <option value="editor" selected={@default_role == "editor"}>Editor</option>
                <option value="gm" selected={@default_role == "gm"}>GM</option>
                <option value="admin" selected={@default_role == "admin"}>Admin</option>
              </select>
              <span class="text-xs text-gray-400">Currently set to: <strong><%= String.capitalize(@default_role) %></strong></span>
            </form>
          </div>
          
          <div class="glass-dark rounded-lg shadow-lg">
            <div class="p-6 border-b border-gray-700">
              <h2 class="text-lg font-semibold text-white">Users (<%= length(@users) %>)</h2>
            </div>
            <div class="overflow-x-auto">
              <div class="min-w-full inline-block align-middle">
                <table class="min-w-full">
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
                        <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{status_badge_class(get_user_status(user))}"}>
                          <%= String.capitalize(get_user_status(user)) %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <%= case get_user_role(user) do %>
                          <% "admin" -> %>
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">Admin</span>
                          <% "gm" -> %>
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-purple-100 text-purple-800">GM</span>
                          <% "editor" -> %>
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">Editor</span>
                          <% "moderator" -> %>
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-yellow-100 text-yellow-800">Moderator</span>
                          <% "member" -> %>
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">Member</span>
                          <% "guest" -> %>
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">Guest</span>
                          <% "banned" -> %>
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-black text-white">BANNED</span>
                          <% _ -> %>
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">Member</span>
                        <% end %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300"><%= Calendar.strftime(user.inserted_at, "%b %d, %Y") %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm">
                        <%= if user.id != @current_user.id do %>
                          <div class="flex flex-col lg:flex-row gap-2">
                            <form phx-change="change_role">
                              <input type="hidden" name="user_id" value={user.id} />
                              <select 
                                name="role"
                                class="bg-gray-700 text-white text-xs px-2 py-1 rounded border border-gray-600 focus:border-blue-500"
                              >
                                <option value="banned" selected={get_user_role(user) == "banned"}>BANNED</option>
                                <option value="guest" selected={get_user_role(user) == "guest"}>Guest</option>
                                <option value="member" selected={get_user_role(user) == "member"}>Member</option>
                                <option value="moderator" selected={get_user_role(user) == "moderator"}>Moderator</option>
                                <option value="editor" selected={get_user_role(user) == "editor"}>Editor</option>
                                <option value="gm" selected={get_user_role(user) == "gm"}>GM</option>
                                <option value="admin" selected={get_user_role(user) == "admin"}>Admin</option>
                              </select>
                            </form>
                            
                            <button 
                              phx-click="toggle_status" 
                              phx-value-user_id={user.id}
                              class={"px-3 py-1 text-xs font-medium rounded-md transition-colors #{if get_user_status(user) == "active", do: "bg-yellow-600 hover:bg-yellow-700 text-white", else: "bg-green-600 hover:bg-green-700 text-white"}"}
                            >
                              <%= if get_user_status(user) == "active", do: "Disable", else: "Activate" %>
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
    </div>
    """
  end
end