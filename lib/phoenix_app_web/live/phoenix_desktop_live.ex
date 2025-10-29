defmodule PhoenixAppWeb.PhoenixDesktopLive do
  @moduledoc """
  Global Phoenix Desktop environment (taskbar + windows).
  
  This LiveComponent provides a persistent desktop environment with taskbar and windows.
  """
  use PhoenixAppWeb, :live_component
  alias Phoenix.PubSub

  def update(assigns, socket) do
    # Subscribe to desktop updates for real-time collaboration
    if connected?(socket) do
      PubSub.subscribe(PhoenixApp.PubSub, "desktop:public")
    end
    
    {:ok, 
     socket
     |> assign(assigns)
     |> assign_new(:windows, fn -> [] end)
     |> assign_new(:next_z_index, fn -> 1 end)
     |> assign_new(:show_start_menu, fn -> false end)
     |> assign_new(:taskbar_visible, fn -> true end)}
  end

  # ==================== EVENT HANDLERS ====================

  def handle_event("toggle_start_menu", _params, socket) do
    {:noreply, assign(socket, show_start_menu: !socket.assigns.show_start_menu)}
  end

  def handle_event("open_app", %{"app" => app}, socket) do
    window_id = Ecto.UUID.generate()
    user = socket.assigns.current_user
    
    new_window = case app do
      "file_manager" ->
        # Load file manager with drive view
        is_admin = user && user.is_admin
        
        # Start at root showing available drives
        drives = get_available_drives(user)

        %{
          id: window_id,
          title: "File Manager",
          app: "file_manager",
          x: 150,
          y: 150,
          width: 800,
          height: 600,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          current_path: "/",
          current_items: drives,
          breadcrumbs: [],
          search_query: "",
          filter: "all",
          view_mode: "grid",
          current_page: 1,
          page_size: 20,
          is_admin: is_admin || false,
          user_id: user && user.id
        }
      
      "text_editor" ->
        %{
          id: window_id,
          title: "Text Editor",
          app: "text_editor",
          x: 200,
          y: 200,
          width: 700,
          height: 500,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          content: ""
        }
      
      "terminal" ->
        %{
          id: window_id,
          title: "Terminal",
          app: "terminal",
          x: 250,
          y: 250,
          width: 800,
          height: 500,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          history: [],
          current_directory: "~"
        }
      
      "calculator" ->
        %{
          id: window_id,
          title: "Calculator",
          app: "calculator",
          x: 300,
          y: 300,
          width: 350,
          height: 450,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          display: "0",
          memory: 0
        }
      
      "notepad" ->
        %{
          id: window_id,
          title: "Notepad",
          app: "notepad",
          x: 350,
          y: 150,
          width: 600,
          height: 400,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          content: ""
        }
      
      "media_player" ->
        %{
          id: window_id,
          title: "Media Player",
          app: "media_player",
          x: 400,
          y: 200,
          width: 600,
          height: 400,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          current_track: nil,
          playing: false
        }
      
      "settings" ->
        %{
          id: window_id,
          title: "Settings",
          app: "settings",
          x: 450,
          y: 250,
          width: 700,
          height: 500,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index
        }
      
      _ ->
        %{
          id: window_id,
          title: "Unknown App",
          app: "unknown",
          x: 100,
          y: 100,
          width: 400,
          height: 300,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index
        }
    end
    
    {:noreply, 
     socket
     |> assign(:windows, [new_window | socket.assigns.windows])
     |> assign(:next_z_index, socket.assigns.next_z_index + 1)
     |> assign(:show_start_menu, false)}
  end

  def handle_event("close_window", %{"id" => id}, socket) do
    windows = Enum.reject(socket.assigns.windows, &(&1.id == id))
    {:noreply, assign(socket, :windows, windows)}
  end

  def handle_event("focus_window", %{"id" => id}, socket) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          %{window | z_index: socket.assigns.next_z_index}
        else
          window
        end
      end)
    
    {:noreply, 
     socket
     |> assign(:windows, windows)
     |> assign(:next_z_index, socket.assigns.next_z_index + 1)}
  end

  def handle_event("minimize_window", %{"id" => id}, socket) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          %{window | minimized: !window.minimized}
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  def handle_event("maximize_window", %{"id" => id}, socket) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          %{window | maximized: !window.maximized}
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  def handle_event("update_window_position", %{"id" => id, "x" => x, "y" => y}, socket) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          %{window | x: x, y: y}
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  def handle_event("update_window_size", %{"id" => id, "width" => width, "height" => height}, socket) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          %{window | width: width, height: height}
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  # ==================== FILE MANAGER HANDLERS ====================

  def handle_event("navigate_to", %{"path" => path, "window_id" => window_id}, socket) do
    user = socket.assigns.current_user
    
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == window_id && window.app == "file_manager" do
          # Handle drive navigation
          items = cond do
            path == "/" ->
              get_available_drives(user)
            
            String.starts_with?(path, "public://") ->
              get_public_drive_contents(path, user)
            
            String.starts_with?(path, "user://") ->
              get_user_drive_contents(path, user)
            
            true ->
              []
          end
          
          breadcrumbs = build_breadcrumbs(path)
          
          %{window | 
            current_path: path, 
            current_items: items,
            breadcrumbs: breadcrumbs,
            current_page: 1
          }
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  def handle_event("navigate_back", %{"window_id" => window_id}, socket) do
    user = socket.assigns.current_user
    
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == window_id && window.app == "file_manager" do
          parent_path = get_parent_path(window.current_path)
          
          items = cond do
            parent_path == "/" ->
              get_available_drives(user)
            
            String.starts_with?(parent_path, "public://") ->
              get_public_drive_contents(parent_path, user)
            
            String.starts_with?(parent_path, "user://") ->
              get_user_drive_contents(parent_path, user)
            
            true ->
              []
          end
          
          breadcrumbs = build_breadcrumbs(parent_path)
          
          %{window | 
            current_path: parent_path,
            current_items: items,
            breadcrumbs: breadcrumbs,
            current_page: 1
          }
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  # ==================== HELPER FUNCTIONS ====================

  defp get_available_drives(user) do
    drives = [
      %{
        id: "public",
        name: "Public Drive",
        description: "Shared files for all users",
        type: :drive,
        icon: "🌐",
        path: "public://",
        size: "Shared",
        modified: DateTime.utc_now()
      }
    ]
    
    if user do
      drives ++ [
        %{
          id: "user_#{user.id}",
          name: "#{user.username || user.email}'s Drive",
          description: "Personal storage space",
          type: :drive,
          icon: "💾",
          path: "user://#{user.id}",
          size: "Personal",
          modified: DateTime.utc_now()
        }
      ]
    else
      drives
    end
  end

  defp get_public_drive_contents(_path, _user) do
    # TODO: Implement actual public file system
    [
      %{id: "1", name: "Documents", type: :folder, icon: "📁", path: "public://documents", size: "-", modified: DateTime.utc_now()},
      %{id: "2", name: "Images", type: :folder, icon: "📁", path: "public://images", size: "-", modified: DateTime.utc_now()},
      %{id: "3", name: "README.txt", type: :file, icon: "📄", path: "public://readme.txt", size: "1.2 KB", modified: DateTime.utc_now()}
    ]
  end

  defp get_user_drive_contents(_path, _user) do
    # TODO: Implement actual user file system
    [
      %{id: "1", name: "My Documents", type: :folder, icon: "📁", path: "user://documents", size: "-", modified: DateTime.utc_now()},
      %{id: "2", name: "Downloads", type: :folder, icon: "📁", path: "user://downloads", size: "-", modified: DateTime.utc_now()},
      %{id: "3", name: "Pictures", type: :folder, icon: "📁", path: "user://pictures", size: "-", modified: DateTime.utc_now()}
    ]
  end

  defp build_breadcrumbs(path) do
    case path do
      "/" -> []
      "public://" -> [%{name: "Public Drive", path: "public://"}]
      "user://" <> _ ->
        [%{name: "User Drive", path: "user://"}]
      _ ->
        # Build breadcrumb trail from path segments
        segments = String.split(path, "/", trim: true)
        Enum.with_index(segments, fn segment, idx ->
          accumulated_path = Enum.take(segments, idx + 1) |> Enum.join("/")
          %{name: segment, path: "/" <> accumulated_path}
        end)
    end
  end

  defp get_parent_path(path) do
    case path do
      "/" -> "/"
      path ->
        path
        |> String.split("/")
        |> Enum.drop(-1)
        |> case do
          [] -> "/"
          segments -> Enum.join(segments, "/")
        end
    end
  end

  # ==================== RENDER ====================

  defp render_window_content(assigns, window) do
    case window.app do
      "file_manager" ->
        assigns = assign(assigns, :window, window)
        ~H"""
        <PhoenixAppWeb.Components.Window.file_manager_content 
          window={@window}
          current_user={@current_user}
        />
        """
      "terminal" ->
        ~H"""
        <div class="p-4 font-mono text-sm text-green-400 bg-black h-full">
          <div>Terminal Emulator</div>
          <div class="mt-2">$ <span class="animate-pulse">_</span></div>
        </div>
        """
      "calculator" ->
        ~H"""
        <div class="p-4 bg-gray-900 h-full flex flex-col">
          <div class="text-right text-2xl text-white mb-4 p-2 bg-gray-800 rounded">0</div>
          <div class="grid grid-cols-4 gap-2 flex-1">
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">7</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">8</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">9</button>
            <button class="bg-blue-600 hover:bg-blue-500 text-white rounded p-2">÷</button>
          </div>
        </div>
        """
      "notepad" ->
        ~H"""
        <div class="h-full">
          <textarea class="w-full h-full bg-white text-black p-4 font-mono resize-none border-0 focus:outline-none" placeholder="Start typing..."></textarea>
        </div>
        """
      _ ->
        ~H"""
        <div class="p-4 text-center text-gray-400">
          <p>Application content not available</p>
        </div>
        """
    end
  end

  def render(assigns) do
    ~H"""
    <div id="phoenix-desktop" class="pointer-events-none">
      <!-- Windows layer - positioned above page content -->
      <div class="fixed inset-0 z-40 pointer-events-none">
        <%= for window <- @windows do %>
          <div class="pointer-events-auto" style={"z-index: #{window.z_index}"}>
            <PhoenixAppWeb.Components.Window.desktop_window window={window} current_user={@current_user} target={@myself}>
              <%= render_window_content(assigns, window) %>
            </PhoenixAppWeb.Components.Window.desktop_window>
          </div>
        <% end %>
      </div>
      
      <!-- Taskbar - always visible at bottom -->
      <div class="pointer-events-auto">
        <PhoenixAppWeb.Components.Taskbar.taskbar 
          current_user={@current_user}
          open_windows={@windows}
          show_start_menu={@show_start_menu}
          target={@myself}
        />
      </div>
    </div>
    """
  end
end
