defmodule PhoenixAppWeb.TerminalLive do
  use PhoenixAppWeb, :live_view

  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      output: ["PowerShell Terminal v1.0", "Type commands to execute on the server."],
      input: "",
      history: [],
      history_index: 0,
      page_title: "Terminal"
    )}
  end

  def handle_event("execute_command", %{"command" => command}, socket) do
    trimmed_command = String.trim(command)
    
    if trimmed_command != "" do
      new_output = socket.assigns.output ++ ["PS> #{trimmed_command}"]
      result = execute_powershell_command(trimmed_command)
      final_output = new_output ++ [result]
      
      new_history = [trimmed_command | socket.assigns.history]
      
      {:noreply, assign(socket,
        output: final_output,
        input: "",
        history: new_history,
        history_index: 0
      )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_input", %{}, socket) do
    {:noreply, socket}
  end

  def handle_event("clear_terminal", _params, socket) do
    {:noreply, assign(socket, output: ["Terminal cleared."])}
  end

  defp execute_powershell_command(command) do
    try do
      case System.cmd("powershell", ["-Command", command], stderr_to_stdout: true) do
        {output, 0} -> 
          if String.trim(output) == "" do
            "Command executed successfully (no output)"
          else
            output
          end
        {error_output, _exit_code} -> 
          "Error: #{error_output}"
      end
    rescue
      e -> "Error executing command: #{Exception.message(e)}"
    end
  end

  def render(assigns) do
    ~H"""
    <.navbar current_user={@current_user} />
    <div class="min-h-screen bg-black">
      
      <div class="terminal-container h-screen bg-black text-green-400 font-mono overflow-hidden">
        <!-- Terminal Header -->
      <div class="terminal-header bg-gray-800 px-4 py-2 flex items-center justify-between border-b border-gray-600">
        <div class="flex items-center space-x-2">
          <div class="w-3 h-3 bg-red-500 rounded-full"></div>
          <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
          <div class="w-3 h-3 bg-green-500 rounded-full"></div>
          <span class="ml-4 text-white text-sm">PowerShell Terminal</span>
        </div>
        <button phx-click="clear_terminal" class="text-gray-400 hover:text-white text-sm">
          Clear
        </button>
      </div>

      <!-- Terminal Output -->
      <div class="terminal-output flex-1 p-4 overflow-y-auto" style="height: calc(100vh - 184px);">
        <%= for line <- @output do %>
          <div class="mb-1 whitespace-pre-wrap"><%= line %></div>
        <% end %>
      </div>

      <!-- Terminal Input -->
      <div class="terminal-input bg-gray-900 px-4 py-2 border-t border-gray-600">
        <form phx-submit="execute_command" class="flex items-center">
          <span class="text-green-400 mr-2">PS></span>
          <input 
            type="text" 
            name="command" 
            value={@input}
            phx-change="update_input"
            class="flex-1 bg-transparent text-green-400 outline-none"
            placeholder="Enter PowerShell command..."
            autocomplete="off"
            autofocus
          />
        </form>
      </div>
      </div>
    </div>
    """
  end
end