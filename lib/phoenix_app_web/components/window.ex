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
  slot :inner_block, required: true

  def desktop_window(assigns) do
    ~H"""
    <div :if={!@window.minimized} 
         class={["desktop-window", if(@window.maximized, do: "!w-full !h-full !top-0 !left-0")]}
         style={"left: #{@window.x}px; top: #{@window.y}px; width: #{@window.width}px; height: #{@window.height}px; z-index: #{@window.z_index}"}
         id={"window-#{@window.id}"}
         phx-hook="DesktopWindow"
         phx-click="focus_window" 
         phx-value-window_id={@window.id}>
      
      <!-- Window Header -->
      <div class="window-header bg-gray-800 border-b border-gray-600 px-4 py-2 flex justify-between items-center cursor-move">
        <div class="flex items-center space-x-3">
          <span class="text-lg"><%= get_app_icon(@window.app) %></span>
          <span class="text-white font-medium"><%= @window.title %></span>
        </div>
        
        <div class="flex items-center space-x-1">
          <button 
            phx-click="minimize_window" 
            phx-value-window_id={@window.id}
            class="w-6 h-6 bg-yellow-500 hover:bg-yellow-600 rounded-full flex items-center justify-center transition-colors"
            title="Minimize"
          >
            <span class="text-xs text-black">−</span>
          </button>
          
          <button 
            phx-click={if @window.maximized, do: "restore_window", else: "maximize_window"}
            phx-value-window_id={@window.id}
            class="w-6 h-6 bg-green-500 hover:bg-green-600 rounded-full flex items-center justify-center transition-colors"
            title={if @window.maximized, do: "Restore", else: "Maximize"}
          >
            <span class="text-xs text-black">□</span>
          </button>
          
          <button 
            phx-click="close_window" 
            phx-value-window_id={@window.id}
            class="w-6 h-6 bg-red-500 hover:bg-red-600 rounded-full flex items-center justify-center transition-colors"
            title="Close"
          >
            <span class="text-xs text-white">×</span>
          </button>
        </div>
      </div>
      
      <!-- Window Content -->
      <div class="window-content bg-gray-900 text-white flex-1 overflow-hidden">
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

  def file_manager_content(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Toolbar -->
      <div class="bg-gray-800 border-b border-gray-600 p-3">
        <div class="flex items-center justify-between gap-4">
          <!-- Navigation -->
          <div class="flex items-center space-x-2">
            <button class="p-2 hover:bg-gray-700 rounded">
              ← Back
            </button>
            <button class="p-2 hover:bg-gray-700 rounded">
              → Forward
            </button>
            <button class="p-2 hover:bg-gray-700 rounded">
              ↑ Up
            </button>
          </div>
          
          <!-- Search -->
          <div class="flex-1 max-w-md">
            <form phx-submit="file_search" phx-target={"#window-#{@window.id}"}>
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search files..."
                class="w-full bg-gray-700 text-white rounded px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                phx-debounce="300"
              />
            </form>
          </div>
          
          <!-- View Options -->
          <div class="flex items-center space-x-2">
            <button 
              phx-click="change_view_mode" 
              phx-value-mode="grid" 
              phx-value-window_id={@window.id}
              class={["p-2 rounded", if(@view_mode == "grid", do: "bg-blue-600", else: "hover:bg-gray-700")]}
            >
              ⊞
            </button>
            <button 
              phx-click="change_view_mode" 
              phx-value-mode="list" 
              phx-value-window_id={@window.id}
              class={["p-2 rounded", if(@view_mode == "list", do: "bg-blue-600", else: "hover:bg-gray-700")]}
            >
              ☰
            </button>
          </div>
        </div>
        
        <!-- Filters -->
        <div class="flex items-center space-x-2 mt-2">
          <%= for {label, type} <- [{"All", "all"}, {"Images", "image"}, {"Videos", "video"}, {"Documents", "document"}] do %>
            <button
              phx-click="filter_files"
              phx-value-type={type}
              phx-value-window_id={@window.id}
              class={["px-3 py-1 rounded text-sm", if(@filter == type, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}
            >
              <%= label %>
            </button>
          <% end %>
        </div>
      </div>
      
      <!-- File Area -->
      <div class="flex-1 overflow-auto p-4">
        <%= if @view_mode == "grid" do %>
          <!-- Grid View -->
          <div class="grid grid-cols-4 gap-4">
            <%= for upload <- paginated_uploads(@filtered_uploads, @current_page, @page_size) do %>
              <div class="bg-gray-800 rounded-lg p-3 hover:bg-gray-700 transition-colors cursor-pointer group">
                <div class="text-center">
                  <div class="text-3xl mb-2">
                    <%= if upload.file_type == "image" && upload.url do %>
                      <img src={upload.url} alt={upload.original_filename} class="w-12 h-12 mx-auto object-cover rounded" />
                    <% else %>
                      <span><%= file_type_icon(upload.file_type) %></span>
                    <% end %>
                  </div>
                  <div class="text-white text-xs truncate"><%= upload.original_filename %></div>
                  <div class="text-gray-400 text-xs"><%= format_bytes(upload.file_size) %></div>
                  
                  <!-- Quick Actions -->
                  <div class="mt-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <div class="flex justify-center space-x-1">
                      <%= if @is_admin do %>
                        <button 
                          phx-click="toggle_public" 
                          phx-value-id={upload.id}
                          class={["text-xs px-2 py-1 rounded", if(upload.is_public, do: "bg-green-600", else: "bg-gray-600")]}
                        >
                          <%= if upload.is_public, do: "🌐", else: "🔒" %>
                        </button>
                      <% end %>
                      <button 
                        phx-click="delete_upload" 
                        phx-value-id={upload.id}
                        class="text-xs px-2 py-1 rounded bg-red-600 hover:bg-red-700"
                        data-confirm="Delete this file?"
                      >
                        🗑️
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- List View -->
          <div class="space-y-1">
            <%= for upload <- paginated_uploads(@filtered_uploads, @current_page, @page_size) do %>
              <div class="flex items-center justify-between p-2 hover:bg-gray-800 rounded transition-colors">
                <div class="flex items-center space-x-3 flex-1 min-w-0">
                  <div class="text-lg">
                    <%= if upload.file_type == "image" && upload.url do %>
                      <img src={upload.url} alt={upload.original_filename} class="w-6 h-6 object-cover rounded" />
                    <% else %>
                      <span><%= file_type_icon(upload.file_type) %></span>
                    <% end %>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="text-white text-sm truncate"><%= upload.original_filename %></div>
                    <div class="text-gray-400 text-xs"><%= format_bytes(upload.file_size) %></div>
                  </div>
                </div>
                
                <div class="flex items-center space-x-2">
                  <%= if @is_admin do %>
                    <button 
                      phx-click="toggle_public" 
                      phx-value-id={upload.id}
                      class={["text-xs px-2 py-1 rounded", if(upload.is_public, do: "bg-green-600 text-white", else: "bg-gray-600 text-gray-300")]}
                    >
                      <%= if upload.is_public, do: "Public", else: "Private" %>
                    </button>
                  <% end %>
                  <button 
                    phx-click="delete_upload" 
                    phx-value-id={upload.id}
                    class="text-xs px-2 py-1 rounded bg-red-600 hover:bg-red-700 text-white"
                    data-confirm="Delete this file?"
                  >
                    Delete
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      
      <!-- Status Bar -->
      <div class="bg-gray-800 border-t border-gray-600 px-4 py-2 text-sm text-gray-300">
        <div class="flex justify-between items-center">
          <div>
            <%= length(@filtered_uploads) %> items
            <%= if @stats[:total_size] do %>
              • <%= format_bytes(@stats.total_size) %> total
            <% end %>
          </div>
          <%= if length(@filtered_uploads) > @page_size do %>
            <div class="flex items-center space-x-2">
              <button 
                :if={@current_page > 1}
                phx-click="change_page" 
                phx-value-page={@current_page - 1}
                phx-value-window_id={@window.id}
                class="px-2 py-1 bg-gray-700 rounded hover:bg-gray-600"
              >
                ← Prev
              </button>
              <span>Page <%= @current_page %></span>
              <button 
                :if={@current_page * @page_size < length(@filtered_uploads)}
                phx-click="change_page" 
                phx-value-page={@current_page + 1}
                phx-value-window_id={@window.id}
                class="px-2 py-1 bg-gray-700 rounded hover:bg-gray-600"
              >
                Next →
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

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

  defp file_type_icon("image"), do: "🖼️"
  defp file_type_icon("video"), do: "🎥"
  defp file_type_icon("audio"), do: "🎵"
  defp file_type_icon("3d"), do: "🎲"
  defp file_type_icon("document"), do: "📄"
  defp file_type_icon(_), do: "📁"

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp paginated_uploads(uploads, current_page, page_size) do
    start_index = (current_page - 1) * page_size
    Enum.slice(uploads, start_index, page_size)
  end
end