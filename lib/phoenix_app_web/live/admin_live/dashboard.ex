defmodule PhoenixAppWeb.AdminLive.Dashboard do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.{Accounts, Commerce, Content, Files}

  def mount(_params, _session, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.is_admin do
      stats = get_dashboard_stats()
      
      {:ok, assign(socket,
        stats: stats,
        page_title: "Admin Dashboard"
      )}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  defp get_dashboard_stats do
    try do
      %{
        total_users: Accounts.count_users() || 0,
        total_orders: Commerce.count_orders() || 0,
        total_products: Commerce.count_products() || 0,
        total_posts: Content.count_posts() || 0,
        total_files: Files.count_files() || 0,
        recent_users: Accounts.list_recent_users(5) || [],
        recent_orders: Commerce.list_recent_orders(5) || [],
        revenue_today: Commerce.get_revenue_today() || 0,
        revenue_month: Commerce.get_revenue_month() || 0
      }
    rescue
      _ -> %{
        total_users: 0,
        total_orders: 0,
        total_products: 0,
        total_posts: 0,
        total_files: 0,
        recent_users: [],
        recent_orders: [],
        revenue_today: 0,
        revenue_month: 0
      }
    end
  end

  def render(assigns) do
    ~H"""
    <div class="starry-background min-h-screen">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <div class="flex relative z-10">
        <!-- Admin Sidebar -->
        <div class="w-64 bg-gray-900 min-h-screen">
          <div class="p-6">
            <h2 class="text-xl font-bold text-white mb-6">Admin Panel</h2>
            <nav class="space-y-2">
              <.link navigate="/admin" class="admin-nav-link active">
                📊 Dashboard
              </.link>
              <.link navigate="/admin/users" class="admin-nav-link">
                👥 Users
              </.link>
              <.link navigate="/admin/products" class="admin-nav-link">
                🛍️ Products
              </.link>
              <.link navigate="/admin/orders" class="admin-nav-link">
                📦 Orders
              </.link>
              <.link navigate="/admin/posts" class="admin-nav-link">
                📝 Blog Posts
              </.link>
              <.link navigate="/admin/channels" class="admin-nav-link">
                💬 Chat Channels
              </.link>
              <.link navigate="/admin/sql" class="admin-nav-link">
                🗄️ SQL Console
              </.link>
            </nav>
          </div>
        </div>

        <!-- Main Content -->
        <div class="flex-1 p-8">
          <h1 class="text-3xl font-bold text-white mb-8">Dashboard</h1>
          
          <!-- Stats Grid -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <div class="bg-gray-800 rounded-lg p-6">
              <div class="flex items-center">
                <div class="text-3xl text-blue-400 mr-4">👥</div>
                <div>
                  <div class="text-2xl font-bold text-white"><%= @stats.total_users %></div>
                  <div class="text-gray-400">Total Users</div>
                </div>
              </div>
            </div>
            
            <div class="bg-gray-800 rounded-lg p-6">
              <div class="flex items-center">
                <div class="text-3xl text-green-400 mr-4">📦</div>
                <div>
                  <div class="text-2xl font-bold text-white"><%= @stats.total_orders %></div>
                  <div class="text-gray-400">Total Orders</div>
                </div>
              </div>
            </div>
            
            <div class="bg-gray-800 rounded-lg p-6">
              <div class="flex items-center">
                <div class="text-3xl text-purple-400 mr-4">🛍️</div>
                <div>
                  <div class="text-2xl font-bold text-white"><%= @stats.total_products %></div>
                  <div class="text-gray-400">Products</div>
                </div>
              </div>
            </div>
            
            <div class="bg-gray-800 rounded-lg p-6">
              <div class="flex items-center">
                <div class="text-3xl text-yellow-400 mr-4">📝</div>
                <div>
                  <div class="text-2xl font-bold text-white"><%= @stats.total_posts %></div>
                  <div class="text-gray-400">Blog Posts</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Revenue Stats -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <div class="bg-gray-800 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Revenue Today</h3>
              <div class="text-3xl font-bold text-green-400">$<%= @stats.revenue_today || 0 %></div>
            </div>
            
            <div class="bg-gray-800 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Revenue This Month</h3>
              <div class="text-3xl font-bold text-green-400">$<%= @stats.revenue_month || 0 %></div>
            </div>
          </div>

          <!-- Recent Activity -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Recent Users -->
            <div class="bg-gray-800 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Recent Users</h3>
              <div class="space-y-3">
                <%= for user <- @stats.recent_users || [] do %>
                  <div class="flex items-center justify-between">
                    <div class="flex items-center space-x-3">
                      <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm"
                           style={"background-color: #{user.avatar_color}"}>
                        <%= String.first(user.name || user.email) %>
                      </div>
                      <div>
                        <div class="text-white font-medium"><%= user.name || user.email %></div>
                        <div class="text-gray-400 text-sm"><%= user.email %></div>
                      </div>
                    </div>
                    <div class="text-gray-400 text-sm">
                      <%= Calendar.strftime(user.inserted_at, "%m/%d") %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Recent Orders -->
            <div class="bg-gray-800 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Recent Orders</h3>
              <div class="space-y-3">
                <%= for order <- @stats.recent_orders || [] do %>
                  <div class="flex items-center justify-between">
                    <div>
                      <div class="text-white font-medium">Order #<%= String.slice(order.id, -8..-1) %></div>
                      <div class="text-gray-400 text-sm"><%= order.user.email %></div>
                    </div>
                    <div class="text-right">
                      <div class="text-green-400 font-bold">$<%= order.total_amount %></div>
                      <div class={["text-xs px-2 py-1 rounded",
                                  case order.status do
                                    "pending" -> "bg-yellow-600 text-yellow-100"
                                    "processing" -> "bg-blue-600 text-blue-100"
                                    "shipped" -> "bg-purple-600 text-purple-100"
                                    "delivered" -> "bg-green-600 text-green-100"
                                    "cancelled" -> "bg-red-600 text-red-100"
                                  end]}>
                        <%= String.capitalize(order.status) %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Quick Actions -->
          <div class="mt-8">
            <h3 class="text-lg font-semibold text-white mb-4">Quick Actions</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <.link navigate="/admin/products/new" 
                     class="bg-blue-600 hover:bg-blue-700 text-white p-4 rounded-lg text-center transition-colors">
                <div class="text-2xl mb-2">➕</div>
                <div>Add Product</div>
              </.link>
              
              <.link navigate="/admin/posts/new"
                     class="bg-green-600 hover:bg-green-700 text-white p-4 rounded-lg text-center transition-colors">
                <div class="text-2xl mb-2">📝</div>
                <div>Create Post</div>
              </.link>
              
              <.link navigate="/admin/sql"
                     class="bg-purple-600 hover:bg-purple-700 text-white p-4 rounded-lg text-center transition-colors">
                <div class="text-2xl mb-2">🗄️</div>
                <div>SQL Console</div>
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>

    <style>
      .admin-nav-link {
        @apply block w-full text-left px-4 py-2 text-gray-300 hover:bg-gray-800 hover:text-white rounded transition-colors;
      }
      .admin-nav-link.active {
        @apply bg-blue-600 text-white;
      }
    </style>
    """
  end
end