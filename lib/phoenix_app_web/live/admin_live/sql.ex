defmodule PhoenixAppWeb.AdminLive.SQL do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Repo
  import Ecto.Query

  def mount(_params, _session, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.is_admin do
      {:ok, assign(socket,
        query: "",
        results: nil,
        error: nil,
        history: [],
        page_title: "SQL Console"
      )}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  def handle_event("execute_query", %{"query" => query}, socket) do
    query = String.trim(query)
    
    if query == "" do
      {:noreply, socket}
    else
      case execute_safe_query(query) do
        {:ok, results} ->
          history = [%{query: query, results: results, timestamp: DateTime.utc_now()} | socket.assigns.history]
          |> Enum.take(10)
          
          {:noreply, assign(socket,
            results: results,
            error: nil,
            history: history
          )}
        
        {:error, error} ->
          {:noreply, assign(socket,
            results: nil,
            error: error
          )}
      end
    end
  end

  def handle_event("clear_results", _params, socket) do
    {:noreply, assign(socket, results: nil, error: nil)}
  end

  def handle_event("load_query", %{"query" => query}, socket) do
    {:noreply, assign(socket, query: query)}
  end

  defp execute_safe_query(query_string) do
    # Only allow SELECT queries for safety
    normalized_query = String.downcase(String.trim(query_string))
    
    cond do
      String.starts_with?(normalized_query, "select") ->
        try do
          result = Ecto.Adapters.SQL.query!(Repo, query_string, [])
          
          formatted_results = %{
            columns: result.columns,
            rows: result.rows,
            num_rows: result.num_rows
          }
          
          {:ok, formatted_results}
        rescue
          e -> {:error, Exception.message(e)}
        end
      
      String.starts_with?(normalized_query, "show") ->
        # Allow SHOW commands for PostgreSQL
        try do
          result = Ecto.Adapters.SQL.query!(Repo, query_string, [])
          
          formatted_results = %{
            columns: result.columns,
            rows: result.rows,
            num_rows: result.num_rows
          }
          
          {:ok, formatted_results}
        rescue
          e -> {:error, Exception.message(e)}
        end
      
      String.starts_with?(normalized_query, "describe") or String.starts_with?(normalized_query, "\\d") ->
        # Allow table descriptions
        try do
          result = Ecto.Adapters.SQL.query!(Repo, query_string, [])
          
          formatted_results = %{
            columns: result.columns,
            rows: result.rows,
            num_rows: result.num_rows
          }
          
          {:ok, formatted_results}
        rescue
          e -> {:error, Exception.message(e)}
        end
      
      true ->
        {:error, "Only SELECT, SHOW, and DESCRIBE queries are allowed for security reasons"}
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
              <.link navigate="/admin" class="admin-nav-link">
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
              <.link navigate="/admin/sql" class="admin-nav-link active">
                🗄️ SQL Console
              </.link>
            </nav>
          </div>
        </div>

        <!-- Main Content -->
        <div class="flex-1 p-8">
          <div class="flex justify-between items-center mb-8">
            <h1 class="text-3xl font-bold text-white">SQL Console</h1>
            <div class="text-sm text-gray-400">
              ⚠️ Only SELECT, SHOW, and DESCRIBE queries allowed
            </div>
          </div>
          
          <!-- Query Input -->
          <div class="bg-gray-800 rounded-lg p-6 mb-6">
            <form phx-submit="execute_query">
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-300 mb-2">SQL Query</label>
                <textarea name="query" rows="6" 
                          class="w-full bg-gray-900 text-white font-mono text-sm p-4 rounded border border-gray-600 focus:border-blue-500 focus:outline-none"
                          placeholder="SELECT * FROM users LIMIT 10;"
                          value={@query}></textarea>
              </div>
              
              <div class="flex space-x-4">
                <button type="submit" 
                        class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded transition-colors">
                  Execute Query
                </button>
                <button type="button" phx-click="clear_results"
                        class="bg-gray-600 hover:bg-gray-700 text-white px-6 py-2 rounded transition-colors">
                  Clear Results
                </button>
              </div>
            </form>
          </div>

          <!-- Quick Queries -->
          <div class="bg-gray-800 rounded-lg p-6 mb-6">
            <h3 class="text-lg font-semibold text-white mb-4">Quick Queries</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <button phx-click="load_query" phx-value-query="SELECT * FROM users ORDER BY inserted_at DESC LIMIT 10;"
                      class="bg-gray-700 hover:bg-gray-600 text-white p-3 rounded text-left transition-colors">
                <div class="font-medium">Recent Users</div>
                <div class="text-sm text-gray-400">Last 10 registered users</div>
              </button>
              
              <button phx-click="load_query" phx-value-query="SELECT status, COUNT(*) as count FROM orders GROUP BY status;"
                      class="bg-gray-700 hover:bg-gray-600 text-white p-3 rounded text-left transition-colors">
                <div class="font-medium">Order Status</div>
                <div class="text-sm text-gray-400">Count by status</div>
              </button>
              
              <button phx-click="load_query" phx-value-query="SELECT name, price, stock_quantity FROM products WHERE is_active = true ORDER BY price DESC;"
                      class="bg-gray-700 hover:bg-gray-600 text-white p-3 rounded text-left transition-colors">
                <div class="font-medium">Active Products</div>
                <div class="text-sm text-gray-400">By price descending</div>
              </button>
              
              <button phx-click="load_query" phx-value-query="SELECT DATE(inserted_at) as date, COUNT(*) as registrations FROM users GROUP BY DATE(inserted_at) ORDER BY date DESC LIMIT 7;"
                      class="bg-gray-700 hover:bg-gray-600 text-white p-3 rounded text-left transition-colors">
                <div class="font-medium">Daily Registrations</div>
                <div class="text-sm text-gray-400">Last 7 days</div>
              </button>
              
              <button phx-click="load_query" phx-value-query="SELECT content_type, COUNT(*) as count FROM user_files GROUP BY content_type ORDER BY count DESC;"
                      class="bg-gray-700 hover:bg-gray-600 text-white p-3 rounded text-left transition-colors">
                <div class="font-medium">File Types</div>
                <div class="text-sm text-gray-400">By upload count</div>
              </button>
              
              <button phx-click="load_query" phx-value-query="SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
                      class="bg-gray-700 hover:bg-gray-600 text-white p-3 rounded text-left transition-colors">
                <div class="font-medium">All Tables</div>
                <div class="text-sm text-gray-400">Database schema</div>
              </button>
            </div>
          </div>

          <!-- Error Display -->
          <div :if={@error} class="bg-red-900 border border-red-600 rounded-lg p-4 mb-6">
            <div class="flex items-center">
              <div class="text-red-400 mr-2">❌</div>
              <div class="text-red-100 font-medium">Query Error</div>
            </div>
            <div class="text-red-200 mt-2 font-mono text-sm"><%= @error %></div>
          </div>

          <!-- Results Display -->
          <div :if={@results} class="bg-gray-800 rounded-lg p-6 mb-6">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold text-white">Query Results</h3>
              <div class="text-sm text-gray-400">
                <%= @results.num_rows %> row(s) returned
              </div>
            </div>
            
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-600">
                    <%= for column <- @results.columns do %>
                      <th class="text-left py-2 px-4 text-gray-300 font-medium"><%= column %></th>
                    <% end %>
                  </tr>
                </thead>
                <tbody>
                  <%= for row <- @results.rows do %>
                    <tr class="border-b border-gray-700 hover:bg-gray-700">
                      <%= for cell <- row do %>
                        <td class="py-2 px-4 text-gray-200">
                          <%= case cell do %>
                            <% nil -> %>
                              <span class="text-gray-500 italic">NULL</span>
                            <% value when is_binary(value) -> %>
                              <%= if String.length(value) > 50 do %>
                                <span title={value}><%= String.slice(value, 0, 50) %>...</span>
                              <% else %>
                                <%= value %>
                              <% end %>
                            <% value -> %>
                              <%= inspect(value) %>
                          <% end %>
                        </td>
                      <% end %>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Query History -->
          <div :if={@history != []} class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-lg font-semibold text-white mb-4">Query History</h3>
            <div class="space-y-4">
              <%= for entry <- @history do %>
                <div class="border-b border-gray-700 pb-4 last:border-b-0">
                  <div class="flex justify-between items-start mb-2">
                    <button phx-click="load_query" phx-value-query={entry.query}
                            class="text-blue-400 hover:text-blue-300 font-mono text-sm text-left">
                      <%= entry.query %>
                    </button>
                    <div class="text-xs text-gray-500">
                      <%= Calendar.strftime(entry.timestamp, "%H:%M:%S") %>
                    </div>
                  </div>
                  <div class="text-xs text-gray-400">
                    <%= entry.results.num_rows %> rows returned
                  </div>
                </div>
              <% end %>
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