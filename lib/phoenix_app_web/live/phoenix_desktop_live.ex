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
    
    # TEMPORARILY DISABLED: Window persistence causing database errors
    # Restore saved windows on mount
    # windows = if socket.assigns[:windows] do
    #   socket.assigns.windows
    # else
    #   restore_saved_windows(assigns[:current_user])
    # end
    
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
    require Logger
    Logger.info("Opening app: #{app}")
    
    window_id = Ecto.UUID.generate()
    user = socket.assigns.current_user
    
    # TEMPORARILY DISABLED: Load saved layout if available (causing DB errors)
    # saved_layout = if user do
    #   PhoenixApp.Desktop.get_window_layout(user.id, app)
    # else
    #   nil
    # end
    
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

  def handle_event("close_window", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
      # TEMPORARILY DISABLED: Save window state before closing
      # window_to_close = Enum.find(socket.assigns.windows, &(&1.id == id))
      # if window_to_close && socket.assigns.current_user do
      #   save_window_state(socket.assigns.current_user.id, window_to_close)
      # end
      
      windows = Enum.reject(socket.assigns.windows, &(&1.id == id))
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("focus_window", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
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
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("minimize_window", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          updated_window = %{window | minimized: !window.minimized}
          
          # Save state
          if socket.assigns.current_user do
            # TEMP DISABLED: save_window_state(socket.assigns.current_user.id, updated_window)
          end
          
          updated_window
        else
          window
        end
      end)
    
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event(event, params, socket) when event in ["toggle_maximize", "maximize_window", "restore_window"] do
    with id when not is_nil(id) <- get_window_id(params) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          updated_window = %{window | maximized: !window.maximized}
          
          # Save state
          if socket.assigns.current_user do
            # TEMP DISABLED: save_window_state(socket.assigns.current_user.id, updated_window)
          end
          
          updated_window
        else
          window
        end
      end)
    
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("update_window_position", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
      windows = 
        Enum.map(socket.assigns.windows, fn window ->
          if window.id == id do
            updated_window = %{window | x: params["x"], y: params["y"]}
            
            # TEMP DISABLED: Persist to database if user is authenticated
            # if socket.assigns.current_user do
            #   Task.start(fn ->
            #     PhoenixApp.Desktop.save_window_layout(
            #       socket.assigns.current_user.id,
            #       window.app,
            #       %{x: params["x"], y: params["y"], width: window.width, height: window.height}
            #     )
            #   end)
            # end
            
            updated_window
          else
            window
          end
        end)
      
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("update_window_size", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
      windows = 
        Enum.map(socket.assigns.windows, fn window ->
          if window.id == id do
            updated_window = %{window | width: params["width"], height: params["height"]}
            
            # TEMP DISABLED: Persist to database if user is authenticated
            # if socket.assigns.current_user do
            #   Task.start(fn ->
            #     PhoenixApp.Desktop.save_window_layout(
            #       socket.assigns.current_user.id,
            #       window.app,
            #       %{x: window.x, y: window.y, width: params["width"], height: params["height"]}
            #     )
            #   end)
            # end
            
            updated_window
          else
            window
          end
        end)
      
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  # ==================== FILE MANAGER HANDLERS ====================

  def handle_event("change_view_mode", %{"mode" => mode, "window_id" => window_id}, socket) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == window_id && window.app == "file_manager" do
          updated_window = %{window | view_mode: mode}
          
          # Save view mode preference
          if socket.assigns.current_user do
            # TEMP DISABLED: save_window_state(socket.assigns.current_user.id, updated_window)
          end
          
          updated_window
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

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
          
          updated_window = %{window | 
            current_path: path, 
            current_items: items,
            breadcrumbs: breadcrumbs,
            current_page: 1
          }
          
          # Save navigation state
          if socket.assigns.current_user do
            # TEMP DISABLED: save_window_state(socket.assigns.current_user.id, updated_window)
          end
          
          updated_window
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

  # ==================== HELPERS ====================

  defp get_window_id(params) do
    Map.get(params, "window_id") || Map.get(params, "id")
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
          name: "#{user.name || user.email}'s Drive",
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
          target={@myself}
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
          <div class="text-right text-2xl text-white mb-4 p-2 glass-dark rounded">0</div>
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

  # ==================== PRIVATE HELPERS ====================

  # TEMPORARILY DISABLED - Window persistence functions
  # defp restore_saved_windows(nil), do: []
  # 
  # defp restore_saved_windows(user) do
  #   PhoenixApp.Desktop.list_user_layouts(user.id)
  #   |> Enum.map(fn layout ->
  #     ...window reconstruction logic...
  #   end)
  # end

  # defp save_window_state(user_id, window) do
  #   attrs = %{...}
  #   PhoenixApp.Desktop.save_window_layout(user_id, window.app, attrs)
  # end

  # defp app_title("file_manager"), do: "File Manager"
  # defp app_title("text_editor"), do: "Text Editor"
  # defp app_title("terminal"), do: "Terminal"
  # defp app_title("calculator"), do: "Calculator"
  # defp app_title("settings"), do: "Settings"
  # defp app_title(_), do: "Application"
end
