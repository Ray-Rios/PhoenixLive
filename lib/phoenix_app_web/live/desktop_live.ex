defmodule PhoenixAppWeb.DesktopLive do
  use PhoenixAppWeb, :live_view
  alias Phoenix.PubSub

  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}

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
      page_title: "Desktop"
    )}
  end

  def handle_event("open_app", %{"app" => app}, socket) do
    window_id = Ecto.UUID.generate()
    
    new_window = case app do
      "file_manager" ->
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
          z_index: socket.assigns.next_z_index
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

  def render(assigns) do
    ~H"""
    <div class="desktop-container starry-background">

      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
            
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
        <div :if={!window.minimized} 
             class={["desktop-window", if(window.maximized, do: "!w-full !h-full !top-0 !left-0")]}
             style={"left: #{window.x}px; top: #{window.y}px; width: #{window.width}px; height: #{window.height}px; z-index: #{window.z_index}"}
             id={"window-#{window.id}"}
             phx-hook="DesktopWindow"
             phx-click="focus_window" phx-value-window_id={window.id}>
          
          <!-- Window Header -->
          <div class="window-header">
            <span class="font-medium text-gray-800"><%= window.title %></span>
            <div class="window-controls">
              <div class="window-control minimize" phx-click="minimize_window" phx-value-window_id={window.id}></div>
              <div class="window-control maximize" phx-click="maximize_window" phx-value-window_id={window.id}></div>
              <div class="window-control close" phx-click="close_window" phx-value-window_id={window.id}></div>
            </div>
          </div>

          <!-- Window Content -->
          <div class="window-content">
            <!-- Welcome App -->
            <div :if={window.app == "welcome"}>
              <h2 class="text-2xl font-bold mb-4">Welcome to Phoenix Desktop!</h2>
              <p class="mb-4">This is a web-based desktop environment built with Phoenix LiveView.</p>
              <div class="grid grid-cols-2 gap-4">
                <button phx-click="open_app" phx-value-app="file_manager" 
                        class="bg-blue-500 text-white p-4 rounded hover:bg-blue-600 transition-colors">
                  📁 File Manager
                </button>
                <button phx-click="open_app" phx-value-app="text_editor"
                        class="bg-green-500 text-white p-4 rounded hover:bg-green-600 transition-colors">
                  📝 Text Editor
                </button>
                <button phx-click="open_app" phx-value-app="calculator"
                        class="bg-purple-500 text-white p-4 rounded hover:bg-purple-600 transition-colors">
                  🧮 Calculator
                </button>
                <button phx-click="open_app" phx-value-app="terminal"
                        class="bg-gray-800 text-white p-4 rounded hover:bg-gray-700 transition-colors">
                  💻 Terminal
                </button>
                <button phx-click="open_app" phx-value-app="chat"
                        class="bg-indigo-500 text-white p-4 rounded hover:bg-indigo-600 transition-colors">
                  💬 Chat
                </button>
                <button phx-click="open_app" phx-value-app="browser"
                        class="bg-orange-500 text-white p-4 rounded hover:bg-orange-600 transition-colors">
                  🌐 Browser
                </button>
              </div>
            </div>

            <!-- File Manager App -->
            <div :if={window.app == "file_manager"}>
              <div class="flex items-center mb-4 space-x-2">
                <button class="px-3 py-1 bg-gray-200 rounded hover:bg-gray-300">Back</button>
                <button class="px-3 py-1 bg-gray-200 rounded hover:bg-gray-300">Forward</button>
                <div class="flex-1 bg-gray-100 px-3 py-1 rounded">/home/user</div>
              </div>
              <div class="grid grid-cols-4 gap-4">
                <%= for file <- @desktop_files do %>
                  <div class="flex flex-col items-center p-2 hover:bg-gray-100 rounded cursor-pointer">
                    <div class="text-3xl mb-2"><%= file.icon %></div>
                    <div class="text-sm text-center"><%= file.name %></div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Text Editor App -->
            <div :if={window.app == "text_editor"}>
              <div class="flex items-center mb-2 space-x-2">
                <button phx-click="text_editor_save" phx-value-window_id={window.id} phx-value-content={window.content || ""}
                        class="px-3 py-1 bg-blue-500 text-white rounded hover:bg-blue-600">Save</button>
                <span class="text-sm text-gray-600">Untitled.txt</span>
              </div>
              <textarea class="w-full h-80 p-2 border rounded font-mono text-sm resize-none"
                        placeholder="Start typing..."
                        value={window.content || ""}></textarea>
            </div>

            <!-- Calculator App -->
            <div :if={window.app == "calculator"}>
              <div class="bg-gray-900 text-white p-4 rounded">
                <div class="bg-black p-4 mb-4 text-right text-2xl font-mono rounded">
                  <%= window.display || "0" %>
                </div>
                <div class="grid grid-cols-4 gap-2">
                  <%= for button <- ["C", "/", "*", "-", "7", "8", "9", "+", "4", "5", "6", "+", "1", "2", "3", "=", "0", "0", ".", "="] do %>
                    <button phx-click="calculator_input" phx-value-window_id={window.id} phx-value-value={button}
                            class={["p-3 rounded font-bold transition-colors",
                                   if(button in ["C", "/", "*", "-", "+", "="], 
                                      do: "bg-orange-500 hover:bg-orange-600", 
                                      else: "bg-gray-700 hover:bg-gray-600")]}>
                      <%= button %>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Terminal App -->
            <div :if={window.app == "terminal"}>
              <div class="bg-black text-green-400 p-4 font-mono text-sm h-full overflow-hidden flex flex-col">
                <div class="flex-1 overflow-y-auto mb-2">
                  <%= for line <- Enum.reverse(window.history || []) do %>
                    <div><%= line %></div>
                  <% end %>
                </div>
                <form phx-submit="terminal_command" phx-value-window_id={window.id} class="flex">
                  <span class="mr-2">$</span>
                  <input type="text" name="command" value={window.current_input || ""}
                         class="flex-1 bg-transparent outline-none text-green-400"
                         autocomplete="off" />
                </form>
              </div>
            </div>

            <!-- Chat App -->
            <div :if={window.app == "chat"}>
              <div class="flex flex-col h-full">
                <div class="flex-1 overflow-y-auto p-2 bg-gray-50 mb-2">
                  <div class="text-center text-gray-500 text-sm">Desktop Chat Room</div>
                  <%= for message <- window.messages || [] do %>
                    <div class="mb-2">
                      <span class="font-bold"><%= message.user %>:</span>
                      <span><%= message.content %></span>
                    </div>
                  <% end %>
                </div>
                <div class="flex">
                  <input type="text" placeholder="Type a message..." 
                         class="flex-1 px-3 py-2 border rounded-l" />
                  <button class="px-4 py-2 bg-blue-500 text-white rounded-r hover:bg-blue-600">Send</button>
                </div>
              </div>
            </div>

            <!-- Browser App -->
            <div :if={window.app == "browser"}>
              <div class="flex items-center mb-2 space-x-2">
                <button class="px-3 py-1 bg-gray-200 rounded hover:bg-gray-300">←</button>
                <button class="px-3 py-1 bg-gray-200 rounded hover:bg-gray-300">→</button>
                <button class="px-3 py-1 bg-gray-200 rounded hover:bg-gray-300">⟳</button>
                <input type="text" value={window.url || "https://example.com"}
                       class="flex-1 px-3 py-1 border rounded" />
              </div>
              <div class="bg-white border rounded h-80 p-4">
                <h1 class="text-2xl font-bold mb-4">Example Website</h1>
                <p class="mb-4">This is a simulated web browser within the desktop environment.</p>
                <p>In a real implementation, this could load actual web content or internal applications.</p>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Taskbar -->
      <div class="desktop-taskbar">
        <div class="flex items-center space-x-4">
          <!-- Start Menu -->
          <button class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded transition-colors">
            🏠 Start
          </button>
          
          <!-- Running Apps -->
          <%= for window <- @windows do %>
            <button phx-click={if window.minimized, do: "restore_window", else: "focus_window"} 
                    phx-value-window_id={window.id}
                    class={["px-3 py-1 rounded text-sm transition-colors",
                           if(window.minimized, 
                              do: "bg-gray-600 text-gray-300 hover:bg-gray-500", 
                              else: "bg-gray-700 text-white hover:bg-gray-600")]}>
              <%= window.title %>
            </button>
          <% end %>
        </div>
        
        <!-- System Tray -->
        <div class="flex items-center space-x-2 text-white text-sm">
          <span><%= DateTime.utc_now() |> Calendar.strftime("%H:%M") %></span>
          <span><%= Date.utc_today() |> Calendar.strftime("%m/%d/%Y") %></span>
        </div>
      </div>
    </div>
    """
  end
end