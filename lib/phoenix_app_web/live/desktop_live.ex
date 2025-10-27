defmodule PhoenixAppWeb.DesktopLive do
  use PhoenixAppWeb, :live_view
  alias Phoenix.PubSub

  on_mount {PhoenixAppWeb.UserAuth, :require_authenticated_user}

  def mount(_params, _session, socket) do
    _user = socket.assigns.current_user
    
    # Subscribe to desktop updates for real-time collaboration
    PubSub.subscribe(PhoenixApp.PubSub, "desktop:public")
    
    initial_windows = [
      %{
        id: "welcome",
        title: "Welcome to Phoenix Desktop",
        app: "welcome",
        x: 100,
        y: 100,
        width: 500,
        height: 400,
        minimized: false,
        maximized: false,
        z_index: 1
      }
    ]
    
    {:ok, assign(socket,
      windows: initial_windows,
      next_z_index: 2,
      desktop_files: get_desktop_files(),
      selected_files: [],
      context_menu: nil,
      page_title: "Desktop",
      show_start_menu: false
    )}
  end

  def handle_event("toggle_start_menu", _params, socket) do
    {:noreply, assign(socket, show_start_menu: !socket.assigns.show_start_menu)}
  end

  def handle_event("open_app", %{"app" => app}, socket) do
    window_id = Ecto.UUID.generate()
    
    new_window = case app do
      "file_manager" ->
        # Load file manager data
        user = socket.assigns.current_user
        is_admin = user && user.is_admin
        
        uploads = if is_admin do
          list_all_uploads()
        else
          list_user_uploads(user)
        end

        stats = if is_admin do
          get_upload_stats(uploads)
        else
          get_user_upload_stats(uploads)
        end

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
          uploads: uploads,
          filtered_uploads: uploads,
          stats: stats,
          search_query: "",
          filter: "all",
          view_mode: "grid",
          current_page: 1,
          page_size: 20,
          is_admin: is_admin || false
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
      
      "calculator" ->
        %{
          id: window_id,
          title: "Calculator",
          app: "calculator",
          x: 300,
          y: 250,
          width: 300,
          height: 400,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          display: "0",
          operation: nil,
          previous: nil
        }
      
      "terminal" ->
        %{
          id: window_id,
          title: "Terminal",
          app: "terminal",
          x: 250,
          y: 300,
          width: 600,
          height: 400,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          history: ["Welcome to Phoenix Terminal", "Type 'help' for available commands"],
          current_input: ""
        }
      
      "chat" ->
        %{
          id: window_id,
          title: "Desktop Chat",
          app: "chat",
          x: 350,
          y: 150,
          width: 400,
          height: 500,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          messages: []
        }
      
      "browser" ->
        %{
          id: window_id,
          title: "Web Browser",
          app: "browser",
          x: 100,
          y: 50,
          width: 900,
          height: 700,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          url: "https://example.com",
          history: ["https://example.com"]
        }
      
      _ ->
        %{
          id: window_id,
          title: "Unknown App",
          app: app,
          x: 200,
          y: 200,
          width: 400,
          height: 300,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index
        }
    end
    
    windows = [new_window | socket.assigns.windows]
    
    {:noreply, assign(socket, 
      windows: windows,
      next_z_index: socket.assigns.next_z_index + 1
    )}
  end

  def handle_event("close_window", %{"window_id" => window_id}, socket) do
    windows = Enum.reject(socket.assigns.windows, &(&1.id == window_id))
    {:noreply, assign(socket, windows: windows)}
  end

  def handle_event("minimize_window", %{"window_id" => window_id}, socket) do
    windows = Enum.map(socket.assigns.windows, fn window ->
      if window.id == window_id do
        %{window | minimized: true}
      else
        window
      end
    end)
    
    {:noreply, assign(socket, windows: windows)}
  end

  def handle_event("restore_window", %{"window_id" => window_id}, socket) do
    windows = Enum.map(socket.assigns.windows, fn window ->
      if window.id == window_id do
        %{window | minimized: false, z_index: socket.assigns.next_z_index}
      else
        window
      end
    end)
    
    {:noreply, assign(socket, 
      windows: windows,
      next_z_index: socket.assigns.next_z_index + 1
    )}
  end

  def handle_event("maximize_window", %{"window_id" => window_id}, socket) do
    windows = Enum.map(socket.assigns.windows, fn window ->
      if window.id == window_id do
        %{window | maximized: !window.maximized, z_index: socket.assigns.next_z_index}
      else
        window
      end
    end)
    
    {:noreply, assign(socket, 
      windows: windows,
      next_z_index: socket.assigns.next_z_index + 1
    )}
  end

  def handle_event("focus_window", %{"window_id" => window_id}, socket) do
    windows = Enum.map(socket.assigns.windows, fn window ->
      if window.id == window_id do
        %{window | z_index: socket.assigns.next_z_index}
      else
        window
      end
    end)
    
    {:noreply, assign(socket, 
      windows: windows,
      next_z_index: socket.assigns.next_z_index + 1
    )}
  end

  def handle_event("calculator_input", %{"window_id" => window_id, "value" => value}, socket) do
    windows = Enum.map(socket.assigns.windows, fn window ->
      if window.id == window_id and window.app == "calculator" do
        calculate(window, value)
      else
        window
      end
    end)
    
    {:noreply, assign(socket, windows: windows)}
  end

  def handle_event("terminal_command", %{"window_id" => window_id, "command" => command}, socket) do
    windows = Enum.map(socket.assigns.windows, fn window ->
      if window.id == window_id and window.app == "terminal" do
        execute_terminal_command(window, command)
      else
        window
      end
    end)
    
    {:noreply, assign(socket, windows: windows)}
  end

  def handle_event("text_editor_save", %{"window_id" => window_id, "content" => content}, socket) do
    windows = Enum.map(socket.assigns.windows, fn window ->
      if window.id == window_id and window.app == "text_editor" do
        %{window | content: content}
      else
        window
      end
    end)
    
    {:noreply, assign(socket, windows: windows) |> put_flash(:info, "File saved")}
  end

  defp calculate(window, value) do
    case value do
      "C" -> %{window | display: "0", operation: nil, previous: nil}
      "=" -> 
        if window.operation && window.previous do
          result = perform_calculation(window.previous, window.display, window.operation)
          %{window | display: to_string(result), operation: nil, previous: nil}
        else
          window
        end
      op when op in ["+", "-", "*", "/"] ->
        %{window | operation: op, previous: window.display, display: "0"}
      digit ->
        new_display = if window.display == "0", do: digit, else: window.display <> digit
        %{window | display: new_display}
    end
  end

  defp perform_calculation(a, b, op) do
    a_num = String.to_float(a)
    b_num = String.to_float(b)
    
    case op do
      "+" -> a_num + b_num
      "-" -> a_num - b_num
      "*" -> a_num * b_num
      "/" -> if b_num != 0, do: a_num / b_num, else: 0
    end
  end

  defp execute_terminal_command(window, command) do
    response = case String.trim(command) do
      "help" -> "Available commands: help, clear, date, whoami, ls, pwd"
      "clear" -> ""
      "date" -> DateTime.utc_now() |> DateTime.to_string()
      "whoami" -> "phoenix_user"
      "ls" -> "desktop  documents  downloads  pictures"
      "pwd" -> "/home/phoenix_user"
      "" -> ""
      cmd -> "Command not found: #{cmd}"
    end
    
    new_history = if command == "clear" do
      []
    else
      [response, "$ #{command}" | window.history] |> Enum.take(100)
    end
    
    %{window | history: new_history, current_input: ""}
  end

  defp get_desktop_files do
    [
      %{name: "Documents", type: "folder", icon: "📁"},
      %{name: "Pictures", type: "folder", icon: "🖼️"},
      %{name: "Downloads", type: "folder", icon: "📥"},
      %{name: "README.txt", type: "file", icon: "📄"},
      %{name: "Welcome.pdf", type: "file", icon: "📕"}
    ]
  end

  # File management helpers (borrowed from UploadsLive)
  defp list_all_uploads do
    alias PhoenixApp.Repo
    import Ecto.Query

    # Combine both UserMedia and UserFile uploads
    media_uploads = Repo.all(
      from m in PhoenixApp.Content.UserMedia,
      preload: [:user],
      order_by: [desc: m.inserted_at]
    )

    file_uploads = Repo.all(
      from f in PhoenixApp.Files.UserFile,
      where: not is_nil(f.user_id),
      preload: [:user],
      order_by: [desc: f.inserted_at]
    )

    # Normalize the data structure
    normalized_media = Enum.map(media_uploads, &normalize_media_upload/1)
    normalized_files = Enum.map(file_uploads, &normalize_file_upload/1)

    (normalized_media ++ normalized_files)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  defp list_user_uploads(user) when is_nil(user), do: []

  defp list_user_uploads(user) do
    alias PhoenixApp.Repo
    import Ecto.Query

    # Get only uploads for the specific user
    media_uploads = Repo.all(
      from m in PhoenixApp.Content.UserMedia,
      where: m.user_id == ^user.id,
      preload: [:user],
      order_by: [desc: m.inserted_at]
    )

    file_uploads = Repo.all(
      from f in PhoenixApp.Files.UserFile,
      where: f.user_id == ^user.id,
      preload: [:user],
      order_by: [desc: f.inserted_at]
    )

    # Normalize the data structure
    normalized_media = Enum.map(media_uploads, &normalize_media_upload/1)
    normalized_files = Enum.map(file_uploads, &normalize_file_upload/1)

    (normalized_media ++ normalized_files)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  defp normalize_media_upload(media) do
    %{
      id: media.id,
      filename: media.filename,
      original_filename: media.original_filename,
      file_type: media.file_type,
      mime_type: media.mime_type,
      file_size: media.file_size,
      file_path: media.file_path,
      url: media.url,
      is_public: media.is_public,
      user: media.user,
      inserted_at: media.inserted_at,
      source: :media
    }
  end

  defp normalize_file_upload(file) do
    %{
      id: file.id,
      filename: file.filename,
      original_filename: file.original_filename,
      file_type: determine_file_type(file.content_type || ""),
      mime_type: file.content_type,
      file_size: file.file_size,
      file_path: file.file_path,
      url: file.file && PhoenixApp.UserFileUpload.url({file.file, file}),
      is_public: file.is_public,
      user: file.user,
      inserted_at: file.inserted_at,
      source: :files
    }
  end

  defp get_upload_stats(uploads) do
    %{
      total_uploads: length(uploads),
      total_size: Enum.sum(Enum.map(uploads, & &1.file_size)),
      images: Enum.count(uploads, & &1.file_type == "image"),
      videos: Enum.count(uploads, & &1.file_type == "video"),
      audio: Enum.count(uploads, & &1.file_type == "audio"),
      documents: Enum.count(uploads, & &1.file_type == "document"),
      other: Enum.count(uploads, & &1.file_type not in ["image", "video", "audio", "document"]),
      public: Enum.count(uploads, & &1.is_public),
      private: Enum.count(uploads, & !&1.is_public)
    }
  end

  defp get_user_upload_stats(uploads) do
    get_upload_stats(uploads)
  end

  defp determine_file_type(mime_type) when is_nil(mime_type), do: "other"
  defp determine_file_type(mime_type) do
    cond do
      String.starts_with?(mime_type, "image/") -> "image"
      String.starts_with?(mime_type, "video/") -> "video"
      String.starts_with?(mime_type, "audio/") -> "audio"
      mime_type in ["model/gltf+json", "model/gltf-binary", "application/octet-stream"] -> "3d"
      mime_type in ["application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text/plain"] -> "document"
      String.starts_with?(mime_type, "application/") -> "document"
      true -> "other"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen pointer-events-none">
      <!-- Flash Messages -->
      <.flash_group flash={@flash} />
      
      <div class="desktop-container pointer-events-auto">
            
      <!-- Desktop Icons -->
      <div class="absolute top-4 left-4 space-y-4 z-10">
        <%= for file <- @desktop_files do %>
          <div class="flex flex-col items-center cursor-pointer hover:bg-white hover:bg-opacity-10 p-2 rounded"
               ondblclick={"if('#{file.type}' === 'folder') { alert('Opening #{file.name}...'); }"}>
            <div class="text-4xl mb-1"><%= file.icon %></div>
            <div class="text-white text-xs text-center max-w-16 break-words"><%= file.name %></div>
          </div>
        <% end %>
      </div>

      <!-- Windows -->
      <%= for window <- @windows do %>
        <PhoenixAppWeb.Components.Window.desktop_window window={window} current_user={@current_user}>
          <%= case window.app do %>
            <% "file_manager" -> %>
              <PhoenixAppWeb.Components.Window.file_manager_content 
                window={window}
                current_user={@current_user}
                uploads={Map.get(window, :uploads, [])}
                stats={Map.get(window, :stats, %{})}
                filtered_uploads={Map.get(window, :filtered_uploads, [])}
                search_query={Map.get(window, :search_query, "")}
                filter={Map.get(window, :filter, "all")}
                view_mode={Map.get(window, :view_mode, "grid")}
                current_page={Map.get(window, :current_page, 1)}
                page_size={Map.get(window, :page_size, 20)}
                is_admin={Map.get(window, :is_admin, false)}
              />
            <% "welcome" -> %>
              <div class="p-6">
                <h2 class="text-2xl font-bold mb-4">Welcome to Phoenix Desktop!</h2>
                <p class="mb-4">This is a desktop environment built with Phoenix LiveView.</p>
                <p class="mb-4">Click the Start button in the taskbar to open applications.</p>
                <div class="space-y-2">
                  <button phx-click="open_app" phx-value-app="file_manager" class="block bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded">
                    📁 Open File Manager
                  </button>
                  <button phx-click="open_app" phx-value-app="terminal" class="block bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded">
                    💻 Open Terminal
                  </button>
                  <button phx-click="open_app" phx-value-app="calculator" class="block bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded">
                    🧮 Open Calculator
                  </button>
                </div>
              </div>
            <% "terminal" -> %>
              <div class="p-4 font-mono text-sm h-full overflow-hidden flex flex-col">
                <div class="flex-1 overflow-auto bg-black p-4 rounded">
                  <%= for line <- Enum.reverse(Map.get(window, :history, [])) do %>
                    <div class="text-green-400"><%= line %></div>
                  <% end %>
                </div>
                <form phx-submit="terminal_command" phx-value-window_id={window.id} class="mt-2">
                  <div class="flex">
                    <span class="text-green-400 mr-2">$</span>
                    <input
                      type="text"
                      name="command"
                      value={Map.get(window, :current_input, "")}
                      class="flex-1 bg-transparent text-white focus:outline-none"
                      autocomplete="off"
                    />
                  </div>
                </form>
              </div>
            <% "calculator" -> %>
              <div class="p-4">
                <div class="bg-black text-white text-2xl p-4 rounded mb-4 text-right">
                  <%= Map.get(window, :display, "0") %>
                </div>
                <div class="grid grid-cols-4 gap-2">
                  <%= for button <- ["C", "±", "%", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "0", "0", ".", "="] do %>
                    <button
                      phx-click="calculator_input"
                      phx-value-window_id={window.id}
                      phx-value-value={button}
                      class="bg-gray-600 hover:bg-gray-700 text-white p-3 rounded text-lg font-semibold"
                    >
                      <%= button %>
                    </button>
                  <% end %>
                </div>
              </div>
            <% _ -> %>
              <div class="p-6">
                <h2 class="text-xl font-bold mb-4"><%= window.title %></h2>
                <p>Application content goes here...</p>
              </div>
          <% end %>
        </PhoenixAppWeb.Components.Window.desktop_window>
      <% end %>

      <!-- Taskbar -->
      <PhoenixAppWeb.Components.Taskbar.taskbar 
        current_user={@current_user} 
        open_windows={@windows}
        show_start_menu={@show_start_menu} 
      />
      </div>
    </div>
    """
  end
end