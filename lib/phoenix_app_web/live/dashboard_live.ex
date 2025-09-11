defmodule PhoenixAppWeb.DashboardLive do
  use PhoenixAppWeb, :live_view

  import PhoenixAppWeb.Components.Navigation
  
  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}
  
  
  # _get_csrf_token function removed - not used

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    
    if current_user do
      {:ok, assign(socket, 
        page_title: "Dashboard",
        current_user: current_user
      )}
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  def render(assigns) do
    ~H"""
    <.navbar current_user={@current_user} />
    <.flash_group flash={@flash} />
    <div class="chat-container starry-background min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>

      <!-- Main Content -->
      <div class="w-full px-4 py-8 mt-[50px]">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">

          <!-- Welcome Card -->
          <div class="bg-white bg-opacity-10 backdrop-blur-sm rounded-xl p-6 col-span-full">
            <h2 class="text-3xl font-bold text-white mb-4">
              Welcome back, <%= @current_user.name || String.split(@current_user.email, "@") |> List.first() %>!
            </h2>
            <p class="text-gray-300">
              Ready to build something amazing? Choose from our templates or start from scratch.
            </p>
          </div>

          <!-- Generic Card Component -->
          <%= for {title, desc, color, path, icon_path} <- [
            {"Shop", "Browse and purchase products", "blue", "/shop", "M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"},
            {"Virtual Desktop", "Full desktop environment in your browser", "green", "/desktop", "M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"},
            {"Quest Arena", "Multiplayer game with WASD movement", "purple", "/quest", "M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"},
            {"Live Chat", "Real-time chat with other users", "indigo", "/chat", "M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"},
            {"Game", "Play the MMO game with pixel streaming", "red", "/game", "M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"},
            {"Unreal Engine", "UE5 integration and tools", "orange", "/unreal", "M13 10V3L4 14h7v7l9-11h-7z"},
            {"Profile Settings", "Customize your profile and settings", "pink", "/profile", "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"},
            {"Blog", "Read articles and tutorials", "yellow", "/blog", "M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"}
          ] do %>
            <div class="bg-white bg-opacity-10 backdrop-blur-sm rounded-xl p-6 hover:bg-opacity-20 transition-all duration-300 transform hover:scale-105">
              <div class="text-center">
                <div class={"w-16 h-16 bg-#{color}-500 rounded-full mx-auto mb-4 flex items-center justify-center"}>
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={icon_path}></path>
                  </svg>
                </div>
                <h3 class="text-xl font-bold text-white mb-2"><%= title %></h3>
                <p class="text-gray-300 mb-4"><%= desc %></p>
                <.link navigate={path} class={"bg-#{color}-600 hover:bg-#{color}-700 text-white px-4 py-2 rounded-lg transition-colors duration-300"}>
                  <%= if title == "Blog", do: "Read Blog", else: "Go" %>
                </.link>
              </div>
            </div>
          <% end %>

          <!-- Admin Panel (only for admins) -->
          <%= if @current_user.is_admin do %>
            <div class="bg-white bg-opacity-10 backdrop-blur-sm rounded-xl p-6 hover:bg-opacity-20 transition-all duration-300 transform hover:scale-105">
              <div class="text-center">
                <div class="w-16 h-16 bg-red-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"></path>
                  </svg>
                </div>
                <h3 class="text-xl font-bold text-white mb-2">Admin Panel</h3>
                <p class="text-gray-300 mb-4">Manage content and system settings</p>
                <.link navigate={~p"/admin"} class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg transition-colors duration-300">
                  Admin Panel
                </.link>
              </div>
            </div>

            <div class="bg-white bg-opacity-10 backdrop-blur-sm rounded-xl p-6 hover:bg-opacity-20 transition-all duration-300 transform hover:scale-105">
              <div class="text-center">
                <div class="w-16 h-16 bg-green-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                  </svg>
                </div>
                <h3 class="text-xl font-bold text-white mb-2">Game Admin</h3>
                <p class="text-gray-300 mb-4">Monitor game servers and players</p>
                <.link navigate={~p"/admin/game"} class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg transition-colors duration-300">
                  Game Admin
                </.link>
              </div>
            </div>

            <div class="bg-white bg-opacity-10 backdrop-blur-sm rounded-xl p-6 hover:bg-opacity-20 transition-all duration-300 transform hover:scale-105">
              <div class="text-center">
                <div class="w-16 h-16 bg-purple-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"></path>
                  </svg>
                </div>
                <h3 class="text-xl font-bold text-white mb-2">Game CMS</h3>
                <p class="text-gray-300 mb-4">Manage game content and data</p>
                <.link navigate={~p"/admin/game-cms"} class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition-colors duration-300">
                  Game CMS
                </.link>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
