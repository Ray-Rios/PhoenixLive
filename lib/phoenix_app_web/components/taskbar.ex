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
  attr :show_notifications, :boolean, default: false
  attr :show_audio_panel, :boolean, default: false
  attr :show_calendar, :boolean, default: false
  attr :pending_invite_count, :integer, default: 0
  attr :calendar_notes, :map, default: %{}
  attr :selected_date, :string, default: nil
  attr :target, :any, default: nil
  attr :uploads, :map, default: %{}

  def taskbar(assigns) do
    ~H"""
    <div id="taskbar" class="fixed bottom-0 left-0 w-full h-[35px] auth-glass-panel border-t border-gray-700 z-50 transition-transform duration-300 ease-in-out">
      <div class="flex items-center justify-between h-full px-2">
        <!-- Start Menu Button -->
        <div class="relative">
          <button 
            phx-click="toggle_start_menu"
            phx-target={@target}
            class="start-button p-1 hover:glass-dark hover:bg-white/20 rounded transition-colors duration-200">
            <img src="/tri.gif" alt="Start" class="w-6 h-6 object-contain" />
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
                  <.link href={~p"/auth/logout"} method="post" class="flex items-center space-x-2 px-3 py-2 rounded hover:bg-red-700 text-red-300 hover:text-white transition-colors">
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
            class="flex items-center space-x-2 px-3 py-2 rounded hover:glass-dark hover:bg-white/20 text-gray-300 hover:text-white transition-colors group"
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
          <div class="relative">
            <button 
              phx-click="toggle_notifications"
              phx-target={@target}
              class="p-2 rounded hover:glass-dark hover:bg-white/20 text-gray-300 hover:text-white transition-colors relative"
            >
              <span class="text-lg">🔔</span>
              <%= if @pending_invite_count > 0 do %>
                <span class="absolute -top-1 -right-1 bg-red-500 text-white text-xs font-bold rounded-full h-5 w-5 flex items-center justify-center">
                  <%= min(@pending_invite_count, 9) %><%= if @pending_invite_count > 9, do: "+" %>
                </span>
              <% end %>
            </button>
          </div>
          
          <!-- Network Status -->
          <button class="p-2 rounded hover:glass-dark hover:bg-white/20 text-gray-300 hover:text-white transition-colors">
            <span class="text-lg">📶</span>
          </button>
          
          <!-- Volume -->
          <div class="relative">
            <button 
              phx-click="toggle_audio_panel"
              phx-target={@target}
              class="p-2 rounded hover:glass-dark hover:bg-white/20 text-gray-300 hover:text-white transition-colors"
            >
              <span class="text-lg">🔊</span>
            </button>
            
            <!-- Audio Control Panel -->
            <%= if @show_audio_panel do %>
              <div class="absolute bottom-full right-0 mb-2 w-80 glass-dark rounded-lg shadow-2xl border border-gray-600 overflow-hidden animate-slide-up">
                <div class="p-4 border-b border-gray-600">
                  <h3 class="text-white font-semibold">Audio & Notifications</h3>
                </div>
                
                <div class="p-4 space-y-4">
                  <!-- Notification Sounds Toggle -->
                  <div class="flex items-center justify-between">
                    <div class="flex-1">
                      <div class="text-white font-medium">Notification sounds</div>
                      <div class="text-gray-400 text-xs">Play sound for invites and alerts</div>
                    </div>
                    <button
                      phx-click="toggle_notification_sound"
                      phx-target={@target}
                      class={[
                        "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                        if(@current_user && @current_user.notification_sound_enabled, do: "bg-blue-600", else: "bg-gray-600")
                      ]}
                    >
                      <span class={[
                        "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                        if(@current_user && @current_user.notification_sound_enabled, do: "translate-x-6", else: "translate-x-1")
                      ]}></span>
                    </button>
                  </div>
                  
                  <!-- Master Volume -->
                  <div>
                    <div class="flex items-center justify-between mb-2">
                      <div class="text-white font-medium">Master Volume</div>
                      <div class="text-gray-400 text-sm"><%= trunc((@current_user && @current_user.master_volume || 0.5) * 100) %>%</div>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={trunc((@current_user && @current_user.master_volume || 0.5) * 100)}
                      phx-change="update_volume"
                      phx-target={@target}
                      name="volume"
                      class="w-full h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-blue-600"
                    />
                    <div class="flex justify-between text-xs text-gray-500 mt-1">
                      <span>0%</span>
                      <span>50%</span>
                      <span>100%</span>
                    </div>
                  </div>
                  
                  <!-- Test Sound Button -->
                  <button
                    phx-click="test_sound"
                    phx-target={@target}
                    class="w-full px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded transition-colors flex items-center justify-center gap-2"
                  >
                    <span>🔊</span>
                    <span>Test Sound</span>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
          
          <!-- Clock -->
          <div class="relative group h-full flex items-center">
            <button 
              id="taskbar-clock" 
              phx-click="toggle_calendar"
              phx-target={@target}
              class="px-2 py-[9px] rounded glass-dark hover:bg-white/20 text-gray-300 hover:text-white transition-colors text-sm font-medium"
            >
              <div class="text-center">
                <div class="time">--:--</div>
              </div>
            </button>
            
            <!-- Hover Date Tooltip -->
            <div class="absolute bottom-full right-0 mb-2 px-3 py-1 bg-gray-800 text-white text-xs rounded shadow-lg opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50 border border-gray-600">
              <span class="date-full">--/--/----</span>
            </div>

            <!-- Calendar Popup -->
            <%= if @show_calendar do %>
              <div class="absolute bottom-full right-0 mb-2 w-80 glass-dark rounded-lg shadow-2xl border border-gray-600 overflow-hidden animate-slide-up z-50">
                <div class="p-4 border-b border-gray-600 flex justify-between items-center">
                  <h3 class="text-white font-semibold date-full-header">Calendar</h3>
                  <button phx-click="toggle_calendar" phx-target={@target} class="text-gray-400 hover:text-white">✕</button>
                </div>
                <div class="p-4">
                  <!-- Simple Calendar Grid Placeholder -->
                  <div class="grid grid-cols-7 gap-1 text-center text-xs mb-4">
                    <div class="text-gray-400 font-bold">Su</div>
                    <div class="text-gray-400 font-bold">Mo</div>
                    <div class="text-gray-400 font-bold">Tu</div>
                    <div class="text-gray-400 font-bold">We</div>
                    <div class="text-gray-400 font-bold">Th</div>
                    <div class="text-gray-400 font-bold">Fr</div>
                    <div class="text-gray-400 font-bold">Sa</div>
                    <!-- Mock days for visual representation -->
                    <%= for day <- calendar_days() do %>
                      <div 
                        phx-click={if day, do: "select_date", else: nil}
                        phx-value-day={day}
                        phx-target={@target}
                        class={"p-2 rounded transition-colors relative " <> if(day, do: "hover:bg-blue-600 cursor-pointer text-gray-300 hover:text-white", else: "")}
                      >
                        <%= day %>
                        <%= if day && Map.has_key?(@calendar_notes, get_date_key(day)) do %>
                          <span class="absolute bottom-0.5 right-0.5 w-1.5 h-1.5 bg-yellow-400 rounded-full"></span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                  
                  <!-- Notes Section -->
                  <div class="border-t border-gray-600 pt-4">
                    <%= if @selected_date do %>
                      <h4 class="text-white text-sm font-medium mb-2">Notes for <%= @selected_date %></h4>
                      <form phx-submit="save_note" phx-change="validate_upload" phx-target={@target} phx-drop-target={@uploads.calendar_attachment.ref}>
                        <div class="relative">
                          <textarea 
                            name="note" 
                            placeholder="Add a note... (Drag & drop files)" 
                            class="w-full mb-2 p-2 bg-gray-700 border border-gray-600 rounded text-white text-sm focus:outline-none focus:border-blue-500 placeholder-gray-400 resize-none h-24"
                          ><%= Map.get(@calendar_notes, @selected_date, "") %></textarea>
                          
                          <!-- File Upload Preview -->
                          <%= if length(@uploads.calendar_attachment.entries) > 0 do %>
                            <div class="mb-2 p-2 bg-gray-800 rounded border border-gray-600">
                              <div class="text-xs text-gray-400 mb-1">Attachments:</div>
                              <%= for entry <- @uploads.calendar_attachment.entries do %>
                                <div class="flex items-center justify-between text-xs text-gray-300">
                                  <span class="truncate"><%= entry.client_name %></span>
                                  <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} phx-target={@target} class="text-red-400 hover:text-red-300">✕</button>
                                </div>
                              <% end %>
                            </div>
                          <% end %>
                        </div>

                        <div class="flex justify-between items-center gap-2">
                          <label class="cursor-pointer text-gray-400 hover:text-white" title="Attach file">
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path></svg>
                            <.live_file_input upload={@uploads.calendar_attachment} class="hidden" />
                          </label>
                          <div class="flex gap-2">
                            <button type="button" phx-click="close_note_input" phx-target={@target} class="px-3 py-1 text-gray-400 hover:text-white text-sm">Cancel</button>
                            <button type="submit" class="px-3 py-1 bg-blue-600 hover:bg-blue-700 text-white rounded text-sm font-medium transition-colors">
                              Save Note
                            </button>
                          </div>
                        </div>
                      </form>
                    <% else %>
                      <div class="text-center text-gray-500 text-sm py-4">
                        Select a date to add notes
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
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

  defp get_date_key(day) do
    today = Date.utc_today()
    "#{today.year}-#{String.pad_leading(to_string(today.month), 2, "0")}-#{String.pad_leading(to_string(day), 2, "0")}"
  end

  defp calendar_days do
    today = Date.utc_today()
    first_day = Date.beginning_of_month(today)
    last_day = Date.end_of_month(today)
    
    # Elixir: Mon=1, Sun=7.
    # Grid: Su=0, Mon=1...
    start_padding = 
      case Date.day_of_week(first_day) do
        7 -> 0 # Sunday
        n -> n
      end
      
    padding = List.duplicate(nil, start_padding)
    days = Enum.to_list(1..last_day.day)
    
    padding ++ days
  end
end