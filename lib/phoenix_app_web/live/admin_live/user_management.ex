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
        {:ok, assign(socket, users: users, page_title: "User Management")}
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
                    <th>User</th>
                    <th>Email</th>
                    <th>Status</th>
                    <th>Role</th>
                    <th>Joined</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-700">
                  <%= for user <- @users do %>
                    <tr class="hover:bg-gray-700">
                      <td><%= user.name || user.email %></td>
                      <td><%= user.email %></td>
                      <td><%= String.capitalize(user.status || "active") %></td>
                      <td><%= if user.is_admin, do: "Admin", else: "Member" %></td>
                      <td><%= Calendar.strftime(user.inserted_at, "%b %d, %Y") %></td>
                      <td>
                        <%= if user.id != @current_user.id do %>
                          <button phx-click="toggle_admin" phx-value-user_id={user.id}>
                            <%= if user.is_admin, do: "Remove Admin", else: "Make Admin" %>
                          </button>
                          <button phx-click="toggle_status" phx-value-user_id={user.id}>
                            <%= if user.status == "active", do: "Disable", else: "Enable" %>
                          </button>
                        <% else %>
                          <span>Current User</span>
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
