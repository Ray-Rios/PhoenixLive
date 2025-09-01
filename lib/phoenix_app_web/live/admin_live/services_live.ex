defmodule PhoenixAppWeb.AdminLive.ServicesLive do
  use PhoenixAppWeb, :live_view
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
        # Load service status for admin
        services = get_service_status()
        {:ok, assign(socket, services: services, page_title: "Services Management")}
    end
  end

  defp get_service_status do
    [
      %{
        name: "Phoenix Web Server",
        description: "Main web application server",
        url: "http://localhost:4000",
        port: 4000,
        status: :running,
        type: :web
      },
      %{
        name: "Game Server (Rust)",
        description: "UE5 Action RPG multiplayer backend",
        url: "http://localhost:8080",
        port: 8080,
        status: check_service_status("localhost", 8080),
        type: :game
      },
      %{
        name: "Pixel Streaming",
        description: "UE5 browser-based gaming service",
        url: "http://localhost:9070",
        port: 9070,
        status: check_service_status("localhost", 9070),
        type: :streaming
      },
      %{
        name: "PostgreSQL Database",
        description: "Primary database server",
        url: "postgresql://localhost:5432",
        port: 5432,
        status: check_service_status("localhost", 5432),
        type: :database
      }
    ]
  end

  defp check_service_status(host, port) do
    case :gen_tcp.connect(String.to_charlist(host), port, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :running
      {:error, _} ->
        :stopped
    end
  end

  @impl true
  def handle_event("refresh_status", _params, socket) do
    services = get_service_status()
    {:noreply, assign(socket, services: services)}
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
          <div class="flex justify-between items-center mb-8">
            <h1 class="text-3xl font-bold text-white">Services Management</h1>
            <button 
              phx-click="refresh_status"
              class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
            >
              🔄 Refresh Status
            </button>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%= for service <- @services do %>
              <div class={"bg-gray-800 rounded-lg p-6 border-l-4 #{status_border_color(service.status)}"}>
                <div class="flex items-center justify-between mb-4">
                  <div class="flex items-center space-x-3">
                    <div class={"#{service_icon_bg(service.type)} p-2 rounded-lg text-white text-2xl"}>
                      <%= service_icon_text(service.type) %>
                    </div>
                    <div>
                      <h3 class="text-xl font-bold text-white"><%= service.name %></h3>
                      <p class="text-gray-400 text-sm"><%= service.description %></p>
                    </div>
                  </div>
                  <div class="flex items-center space-x-2">
                    <span class={"#{status_badge_class(service.status)} px-3 py-1 rounded-full text-xs font-medium"}>
                      <%= status_text(service.status) %>
                    </span>
                  </div>
                </div>

                <div class="space-y-2 text-sm text-gray-300">
                  <div class="flex justify-between">
                    <span>Port:</span>
                    <span class="font-mono"><%= service.port %></span>
                  </div>
                  <div class="flex justify-between">
                    <span>URL:</span>
                    <a href={service.url} target="_blank" class="text-blue-400 hover:text-blue-300 font-mono">
                      <%= service.url %>
                    </a>
                  </div>
                </div>

                <%= if service.status == :running do %>
                  <div class="mt-4">
                    <a 
                      href={service.url} 
                      target="_blank"
                      class="inline-flex items-center px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors text-sm"
                    >
                      🚀 Open Service
                    </a>
                  </div>
                <% else %>
                  <div class="mt-4">
                    <span class="inline-flex items-center px-4 py-2 bg-red-600 text-white rounded-lg text-sm opacity-75">
                      ⚠️ Service Unavailable
                    </span>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Quick Actions -->
          <div class="mt-8 bg-gray-800 rounded-lg p-6">
            <h2 class="text-xl font-bold text-white mb-4">Quick Actions</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <button class="px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors">
                🔧 Restart Services
              </button>
              <button class="px-4 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors">
                � RView Logs
              </button>
              <button class="px-4 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors">
                ⚙️ Configuration
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_border_color(:running), do: "border-green-500"
  defp status_border_color(:stopped), do: "border-red-500"
  defp status_border_color(_), do: "border-yellow-500"

  defp status_badge_class(:running), do: "bg-green-100 text-green-800"
  defp status_badge_class(:stopped), do: "bg-red-100 text-red-800"
  defp status_badge_class(_), do: "bg-yellow-100 text-yellow-800"

  defp status_text(:running), do: "Running"
  defp status_text(:stopped), do: "Stopped"
  defp status_text(_), do: "Unknown"

  defp service_icon_bg(:web), do: "bg-blue-500"
  defp service_icon_bg(:game), do: "bg-green-500"
  defp service_icon_bg(:streaming), do: "bg-purple-500"
  defp service_icon_bg(:database), do: "bg-orange-500"

  defp service_icon_text(:web), do: "🌐"
  defp service_icon_text(:game), do: "🎮"
  defp service_icon_text(:streaming), do: "📺"
  defp service_icon_text(:database), do: "🗄️"
end