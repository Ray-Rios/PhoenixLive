defmodule PhoenixAppWeb.Components.Window do
  @moduledoc """
  Window component for the desktop environment
  """
  use Phoenix.Component
  use Gettext, backend: PhoenixAppWeb.Gettext

  @doc """
  Renders a desktop window with resize, move, minimize, maximize capabilities
  """
  attr :window, :map, required: true
  attr :current_user, :map, default: nil
  attr :target, :any, default: nil
  slot :inner_block, required: true

  def desktop_window(assigns) do
    ~H"""
    <div :if={!@window.minimized} 
         class={["desktop-window", if(@window.maximized, do: "!w-full !h-full !top-0 !left-0")]}
         style={"left: #{@window.x}px; top: #{@window.y}px; width: #{@window.width}px; height: #{@window.height}px; z-index: #{@window.z_index}"}
         id={"window-#{@window.id}"}
         phx-hook="DesktopWindow"
         phx-click="focus_window" 
         phx-target={@target}
         phx-value-window_id={@window.id}>
      
      <!-- Window Header -->
      <div class="window-header auth-glass-panel border-b border-gray-600 px-4 py-2 flex justify-between items-center cursor-move">
        <div class="flex items-center space-x-3">
          <span class="text-lg"><%= get_app_icon(@window.app) %></span>
          <span class="text-white font-medium"><%= @window.title %></span>
        </div>
        
        <div class="flex items-center space-x-1">
          <button 
            type="button"
            phx-click="minimize_window" 
            phx-value-window_id={@window.id}
            phx-target={@target}
            class="w-6 h-6 bg-yellow-500 hover:bg-yellow-600 rounded-full flex items-center justify-center transition-colors"
            title="Minimize"
          >
            <span class="text-xs text-black">−</span>
          </button>
          
          <button 
            type="button"
            phx-click="toggle_maximize"
            phx-value-window_id={@window.id}
            phx-target={@target}
            class="w-6 h-6 bg-green-500 hover:bg-green-600 rounded-full flex items-center justify-center transition-colors"
            title={if @window.maximized, do: "Restore", else: "Maximize"}
          >
            <span class="text-xs text-black">□</span>
          </button>
          
          <button 
            type="button"
            phx-click="close_window" 
            phx-value-window_id={@window.id}
            phx-target={@target}
            class="w-6 h-6 bg-red-500 hover:bg-red-600 rounded-full flex items-center justify-center transition-colors"
            title="Close"
          >
            <span class="text-xs text-white">×</span>
          </button>
        </div>
      </div>
      
      <!-- Window Content -->
      <div class="window-content auth-glass-panel text-white flex-1 overflow-hidden">
        <%= render_slot(@inner_block) %>
      </div>
      
      <!-- Resize Handles -->
      <div id={"#{@window.id}-resize-n"} class="resize-handle resize-n" phx-hook="ResizeHandle" data-direction="n"></div>
      <div id={"#{@window.id}-resize-s"} class="resize-handle resize-s" phx-hook="ResizeHandle" data-direction="s"></div>
      <div id={"#{@window.id}-resize-e"} class="resize-handle resize-e" phx-hook="ResizeHandle" data-direction="e"></div>
      <div id={"#{@window.id}-resize-w"} class="resize-handle resize-w" phx-hook="ResizeHandle" data-direction="w"></div>
      <div id={"#{@window.id}-resize-ne"} class="resize-handle resize-ne" phx-hook="ResizeHandle" data-direction="ne"></div>
      <div id={"#{@window.id}-resize-nw"} class="resize-handle resize-nw" phx-hook="ResizeHandle" data-direction="nw"></div>
      <div id={"#{@window.id}-resize-se"} class="resize-handle resize-se" phx-hook="ResizeHandle" data-direction="se"></div>
      <div id={"#{@window.id}-resize-sw"} class="resize-handle resize-sw" phx-hook="ResizeHandle" data-direction="sw"></div>
    </div>
    """
  end

  @doc """
  Renders the File Manager content
  """
  attr :window, :map, required: true
  attr :current_user, :map, default: nil
  attr :uploads, :list, default: []
  attr :stats, :map, default: %{}
  attr :filtered_uploads, :list, default: []
  attr :search_query, :string, default: ""
  attr :filter, :string, default: "all"
  attr :view_mode, :string, default: "grid"
  attr :current_page, :integer, default: 1
  attr :page_size, :integer, default: 20
  attr :is_admin, :boolean, default: false
  attr :target, :any, default: nil

  def file_manager_content(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Toolbar -->
      <div class="glass-dark border-b border-gray-600 p-3">
        <div class="flex items-center justify-between gap-4">
          <!-- Navigation -->
          <div class="flex items-center space-x-2">
            <button 
              type="button"
              phx-click="navigate_back"
              phx-value-window_id={@window.id}
              phx-target={@target}
              disabled={@window.current_path == "/"}
              class={["p-2 rounded", if(@window.current_path == "/", do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-700")]}
            >
              ← Back
            </button>
            <button 
              type="button"
              phx-click="navigate_to"
              phx-value-window_id={@window.id}
              phx-value-path="/"
              phx-target={@target}
              class="p-2 hover:bg-gray-700 rounded"
            >
              🏠 Home
            </button>
          </div>
          
          <!-- Breadcrumb Navigation -->
          <div class="flex-1 flex items-center space-x-1 text-sm overflow-x-auto">
            <button 
              type="button"
              phx-click="navigate_to"
              phx-value-window_id={@window.id}
              phx-value-path="/"
              phx-target={@target}
              class="text-blue-400 hover:text-blue-300"
            >
              Root
            </button>
            <%= for breadcrumb <- @window.breadcrumbs do %>
              <span class="text-gray-500">/</span>
              <button 
                type="button"
                phx-click="navigate_to"
                phx-value-window_id={@window.id}
                phx-value-path={breadcrumb.path}
                phx-target={@target}
                class="text-blue-400 hover:text-blue-300 whitespace-nowrap"
              >
                <%= breadcrumb.name %>
              </button>
            <% end %>
          </div>
          
          <!-- View Options -->
          <div class="flex items-center space-x-2">
            <form phx-change="validate_upload" phx-submit="save_upload" phx-target={@target} class="flex items-center">
              <label class="cursor-pointer p-2 hover:bg-gray-700 rounded text-white flex items-center gap-2" title="Upload Files">
                <span>⬆️</span>
                <.live_file_input upload={@uploads.files} class="hidden" />
              </label>
              <input type="hidden" name="window_id" value={@window.id} />
            </form>
            
            <button 
              type="button"
              phx-click="change_view_mode" 
              phx-value-mode="grid" 
              phx-value-window_id={@window.id}
              phx-target={@target}
              class={["p-2 rounded", if(@window.view_mode == "grid", do: "bg-blue-600", else: "hover:bg-gray-700")]}
            >
              ⊞
            </button>
            <button 
              type="button"
              phx-click="change_view_mode" 
              phx-value-mode="list" 
              phx-value-window_id={@window.id}
              phx-target={@target}
              class={["p-2 rounded", if(@window.view_mode == "list", do: "bg-blue-600", else: "hover:bg-gray-700")]}
            >
              ☰
            </button>
          </div>
        </div>
      </div>
      
      <!-- File/Drive Area -->
      <div class="flex-1 overflow-auto p-4 bg-gray-900 relative" phx-drop-target={@uploads.files.ref}>
        <%= if @window.current_path == "/" do %>
          <!-- Drive Selection View -->
          <div class="grid grid-cols-2 gap-6 max-w-2xl mx-auto mt-8">
            <%= for drive <- @window.current_items do %>
              <div 
                phx-click="navigate_to"
                phx-value-window_id={@window.id}
                phx-value-path={drive.path}
                phx-target={@target}
                class="glass-dark rounded-xl p-8 transition-all cursor-pointer hover:bg-gray-700 hover:scale-105 border-2 border-blue-500/30 hover:border-blue-500/60"
              >
                <div class="text-center">
                  <div class="text-6xl mb-4"><%= drive.icon %></div>
                  <div class="text-white text-lg font-bold mb-2"><%= drive.name %></div>
                  <div class="text-gray-400 text-sm"><%= drive.description %></div>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- File/Folder View -->
          <%= if @window.view_mode == "grid" do %>
            <div class="grid grid-cols-5 gap-4">
              <%= for item <- @window.current_items do %>
                <div 
                  phx-click={if item.type in ["drive", "folder"], do: "navigate_to", else: "open_file"}
                  phx-value-window_id={@window.id}
                  phx-value-path={item.path}
                  phx-value-url={Map.get(item, :url)}
                  phx-target={@target}
                  class="glass-dark rounded-lg p-4 transition-colors cursor-pointer hover:bg-gray-700 group"
                >
                  <div class="text-center">
                    <div class="text-4xl mb-2"><%= item.icon %></div>
                    <div class="text-white text-sm truncate" title={item.name}><%= item.name %></div>
                    <%= if item.size do %>
                      <div class="text-gray-400 text-xs mt-1"><%= format_bytes(item.size) %></div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <!-- List View -->
            <div class="space-y-1">
              <%= for item <- @window.current_items do %>
                <div 
                  phx-click={if item.type in ["drive", "folder"], do: "navigate_to", else: "open_file"}
                  phx-value-window_id={@window.id}
                  phx-value-path={item.path}
                  phx-value-url={Map.get(item, :url)}
                  phx-target={@target}
                  class="flex items-center justify-between p-3 hover:glass-dark rounded transition-colors cursor-pointer"
                >
                  <div class="flex items-center space-x-3 flex-1 min-w-0">
                    <div class="text-2xl"><%= item.icon %></div>
                    <div class="flex-1 min-w-0">
                      <div class="text-white text-sm truncate"><%= item.name %></div>
                      <%= if item.size do %>
                        <div class="text-gray-400 text-xs"><%= format_bytes(item.size) %></div>
                      <% end %>
                    </div>
                  </div>
                  <div class="text-gray-500 text-xs">
                    <%= item.type %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
        
        <%= if @window.current_items == [] do %>
          <div class="text-center text-gray-500 mt-20">
            <div class="text-6xl mb-4">📂</div>
            <div class="text-lg">This folder is empty</div>
          </div>
        <% end %>
      </div>
      
      <!-- Status Bar -->
      <div class="glass-dark border-t border-gray-600 px-4 py-2 text-sm text-gray-300">
        <div class="flex justify-between items-center">
          <div>
            <%= length(@window.current_items) %> items
            <%= if @window.current_path != "/" do %>
              • <%= @window.current_path %>
            <% end %>
          </div>
          
          <!-- Upload Progress -->
          <div class="flex flex-col gap-1 items-end">
            <%= for entry <- @uploads.files.entries do %>
              <div class="flex items-center gap-2">
                <div class="text-xs truncate max-w-[100px]"><%= entry.client_name %></div>
                <div class="w-20 h-2 bg-gray-700 rounded-full overflow-hidden">
                  <div class="h-full bg-blue-500" style={"width: #{entry.progress}%"}></div>
                </div>
                <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-target={@target} class="text-red-400 hover:text-red-300 text-xs">×</button>
              </div>
              <%= for err <- upload_errors(@uploads.files, entry) do %>
                <div class="text-red-500 text-xs"><%= error_to_string(err) %></div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:external_client_failure), do: "External client failure"
  defp error_to_string(_), do: "Error"

  # Helper functions
  defp get_app_icon(app) do
    case app do
      "file_manager" -> "📁"
      "terminal" -> "💻"
      "calculator" -> "🧮"
      "notepad" -> "📝"
      "media_player" -> "🎵"
      "settings" -> "⚙️"
      "welcome" -> "👋"
      "text_editor" -> "📝"
      "browser" -> "🌐"
      _ -> "💻"
    end
  end

  defp format_bytes(nil), do: "0 B"
  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  defp format_bytes(_), do: "0 B"
end