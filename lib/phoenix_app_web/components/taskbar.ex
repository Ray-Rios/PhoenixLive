defmodule PhoenixAppWeb.Components.Taskbar do
  @moduledoc """
  Taskbar component for the desktop environment
  """
  use PhoenixAppWeb, :html
  import PhoenixAppWeb.AvatarHelpers

  @doc """
  Renders the desktop taskbar with start menu and system tray
  """
  attr :current_user, :map, default: nil
  attr :open_windows, :list, default: []
  attr :show_start_menu, :boolean, default: false
  attr :target, :any, default: nil

  def taskbar(assigns) do
    ~H"""
    <div id="taskbar" class="fixed bottom-0 left-0 w-full h-12 auth-glass-panel border-t border-gray-700 z-50 transition-transform duration-300 ease-in-out">
      <div class="flex items-center justify-between h-full px-2">
        <!-- Start Menu Button -->
        <div class="relative">
          <button 
            phx-click="toggle_start_menu"
            phx-target={@target}
            class="start-button p-2 hover:bg-gray-700 rounded transition-colors duration-200">
            <img src="/tri.gif" alt="Start" class="w-8 h-8 object-contain" />
          </button>
          
          <!-- Start Menu -->
          <div :if={@show_start_menu} 
               class="absolute bottom-full left-0 mb-2 w-80 glass-dark rounded-lg shadow-2xl border border-gray-600 overflow-hidden">
            <div class="p-4 border-b border-gray-600">
              <div class="flex items-center space-x-3">
                <%= if @current_user do %>
                  <%= avatar_tag(@current_user, size_class: "w-10 h-10") %>
                  <div class="flex-1 min-w-0">
                    <div class="text-white font-medium truncate"><%= get_user_display_name(@current_user) %></div>
                    <div class="text-gray-400 text-sm truncate"><%= @current_user.email %></div>
                  </div>
                <% else %>
                  <div class="text-white">Guest User</div>
                <% end %>
              </div>
            </div>
            
            <!-- Applications Grid -->
            <div class="p-4">
              <div class="grid grid-cols-3 gap-3">
                <button 
                  type="button"
                  phx-click="open_app" 
                  phx-value-app="file_manager"
                  phx-target={@target}
                  class="flex flex-col items-center p-3 rounded-lg hover:bg-gray-700 transition-colors group"
                >
                  <div class="text-2xl mb-1 group-hover:scale-110 transition-transform">📁</div>
                  <div class="text-white text-xs text-center">File Manager</div>
                </button>
                
                <button 
                  type="button"
                  phx-click="open_app" 
                  phx-value-app="terminal"
                  phx-target={@target}
                  class="flex flex-col items-center p-3 rounded-lg hover:bg-gray-700 transition-colors group"
                >
                  <div class="text-2xl mb-1 group-hover:scale-110 transition-transform">💻</div>
                  <div class="text-white text-xs text-center">Terminal</div>
                </button>
                
                <button 
                  type="button"
                  phx-click="open_app" 
                  phx-value-app="calculator"
                  phx-target={@target}
                  class="flex flex-col items-center p-3 rounded-lg hover:bg-gray-700 transition-colors group"
                >
                  <div class="text-2xl mb-1 group-hover:scale-110 transition-transform">🧮</div>
                  <div class="text-white text-xs text-center">Calculator</div>
                </button>
                
                <button 
                  type="button"
                  phx-click="open_app" 
                  phx-value-app="notepad"
                  phx-target={@target}
                  class="flex flex-col items-center p-3 rounded-lg hover:bg-gray-700 transition-colors group"
                >
                  <div class="text-2xl mb-1 group-hover:scale-110 transition-transform">📝</div>
                  <div class="text-white text-xs text-center">Notepad</div>
                </button>
                
                <button 
                  type="button"
                  phx-click="open_app" 
                  phx-value-app="media_player"
                  phx-target={@target}
                  class="flex flex-col items-center p-3 rounded-lg hover:bg-gray-700 transition-colors group"
                >
                  <div class="text-2xl mb-1 group-hover:scale-110 transition-transform">🎵</div>
                  <div class="text-white text-xs text-center">Media Player</div>
                </button>
                
                <button 
                  type="button"
                  phx-click="open_app" 
                  phx-value-app="settings"
                  phx-target={@target}
                  class="flex flex-col items-center p-3 rounded-lg hover:bg-gray-700 transition-colors group"
                >
                  <div class="text-2xl mb-1 group-hover:scale-110 transition-transform">⚙️</div>
                  <div class="text-white text-xs text-center">Settings</div>
                </button>
              </div>
            </div>
            
            <!-- Quick Access Links -->
            <div class="border-t border-gray-600 p-3">
              <div class="space-y-1">
                <.link navigate={~p"/forum"} class="flex items-center space-x-2 px-3 py-2 rounded hover:bg-gray-700 text-gray-300 hover:text-white transition-colors">
                  <span>🎭</span>
                  <span class="text-sm">Forum</span>
                </.link>
                <.link navigate={~p"/shop"} class="flex items-center space-x-2 px-3 py-2 rounded hover:bg-gray-700 text-gray-300 hover:text-white transition-colors">
                  <span>💰</span>
                  <span class="text-sm">Shop</span>
                </.link>
                <.link navigate={~p"/blog"} class="flex items-center space-x-2 px-3 py-2 rounded hover:bg-gray-700 text-gray-300 hover:text-white transition-colors">
                  <span>🚬</span>
                  <span class="text-sm">Blog</span>
                </.link>
              </div>
            </div>
            
            <!-- Power Options -->
            <div class="border-t border-gray-600 p-3">
              <div class="flex justify-between">
                <%= if @current_user do %>
                  <.link navigate={~p"/auth/logout"} class="flex items-center space-x-2 px-3 py-2 rounded hover:bg-red-700 text-red-300 hover:text-white transition-colors">
                    <span>🚪</span>
                    <span class="text-sm">Logout</span>
                  </.link>
                <% else %>
                  <.link navigate={~p"/login"} class="flex items-center space-x-2 px-3 py-2 rounded hover:bg-blue-700 text-blue-300 hover:text-white transition-colors">
                    <span>🔑</span>
                    <span class="text-sm">Login</span>
                  </.link>
                <% end %>
                <button type="button" class="flex items-center space-x-2 px-3 py-2 rounded hover:bg-gray-700 text-gray-300 hover:text-white transition-colors">
                  <span>🔄</span>
                  <span class="text-sm">Restart</span>
                </button>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Pinned Items -->
        <div class="flex items-center space-x-1 px-2">
          <button 
            type="button"
            phx-click="open_app" 
            phx-value-app="file_manager"
            phx-target={@target}
            class="flex items-center space-x-2 px-3 py-2 rounded hover:bg-gray-700 text-gray-300 hover:text-white transition-colors group"
            title="File Explorer"
          >
            <span class="text-lg group-hover:scale-110 transition-transform">📁</span>
          </button>
        </div>
        
        <!-- Window Buttons (Running Applications) -->
        <div class="flex-1 flex items-center space-x-1 px-4">
          <% max_z_index = Enum.max_by(@open_windows, & &1.z_index, fn -> %{z_index: 0} end).z_index %>
          <%= for window <- @open_windows do %>
            <button 
              phx-click="focus_window" 
              phx-value-window_id={window.id}
              phx-target={@target}
              class={[
                "flex items-center space-x-2 px-3 py-2 rounded text-sm font-medium transition-colors duration-200 max-w-48",
                if(window.z_index == max_z_index, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")
              ]}
            >
              <span class="text-lg"><%= get_app_icon(window.app) %></span>
              <span class="truncate"><%= window.title %></span>
              <%= if window.minimized do %>
                <span class="text-xs opacity-75">(minimized)</span>
              <% end %>
            </button>
          <% end %>
        </div>
        
        <!-- System Tray -->
        <div class="flex items-center space-x-3">
          <!-- Notifications -->
          <button class="p-2 rounded hover:bg-gray-700 text-gray-300 hover:text-white transition-colors">
            <span class="text-lg">🔔</span>
          </button>
          
          <!-- Network Status -->
          <button class="p-2 rounded hover:bg-gray-700 text-gray-300 hover:text-white transition-colors">
            <span class="text-lg">📶</span>
          </button>
          
          <!-- Volume -->
          <button class="p-2 rounded hover:bg-gray-700 text-gray-300 hover:text-white transition-colors">
            <span class="text-lg">🔊</span>
          </button>
          
          <!-- Clock -->
          <div id="taskbar-clock" class="text-white text-sm font-medium px-3 py-2 glass-dark rounded">
            <div class="text-center">
              <div class="time">--:--</div>
              <div class="text-xs text-gray-400 date">--/--</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_user_display_name(user) do
    user.name || "User"
  end

  defp get_app_icon(app) do
    case app do
      "file_manager" -> "📁"
      "terminal" -> "💻"
      "calculator" -> "🧮"
      "notepad" -> "📝"
      "media_player" -> "🎵"
      "settings" -> "⚙️"
      "welcome" -> "👋"
      _ -> "💻"
    end
  end
end