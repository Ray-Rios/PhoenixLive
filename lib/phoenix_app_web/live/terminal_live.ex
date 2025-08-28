defmodule PhoenixAppWeb.TerminalLive do
  use PhoenixAppWeb, :live_view

  on_mount {PhoenixAppWeb.UserAuth, :require_authenticated_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
      assign(socket,
        output: ["PowerShell Terminal v1.0", "Type commands to execute on the server."],
        input: "",
        history: [],
        history_index: nil,  # nil means not browsing history
        page_title: "Terminal"
      )
    }
  end

  # --- Event handlers ---

  @impl true
  def handle_event("execute_command", %{"command" => command}, socket) do
    trimmed = String.trim(command)

    if trimmed != "" do
      new_output = socket.assigns.output ++ ["PS> #{trimmed}"]
      result = execute_powershell_command(trimmed)
      final_output = new_output ++ [result]
      new_history = [trimmed | socket.assigns.history]

      {:noreply,
        assign(socket,
          output: final_output,
          input: "",
          history: new_history,
          history_index: nil
        )
      }
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_input", %{"command" => command}, socket) do
    {:noreply, assign(socket, input: command)}
  end

  @impl true
  def handle_event("clear_terminal", _params, socket) do
    {:noreply, assign(socket, output: ["Terminal cleared."])}
  end

  @impl true
  def handle_event("history_up", _params, socket) do
    {input, new_index} = history_navigation(socket.assigns, :up)
    {:noreply, assign(socket, input: input, history_index: new_index)}
  end

  @impl true
  def handle_event("history_down", _params, socket) do
    {input, new_index} = history_navigation(socket.assigns, :down)
    {:noreply, assign(socket, input: input, history_index: new_index)}
  end

  # --- Helpers ---

  defp execute_powershell_command(command) do
    try do
      case System.cmd("pwsh", ["-Command", command], stderr_to_stdout: true) do
        {output, 0} -> if String.trim(output) == "", do: "Command executed successfully (no output)", else: output
        {error_output, _} -> "Error: #{error_output}"
      end
    rescue
      e -> "Error executing command: #{Exception.message(e)}"
    end
  end

  defp history_navigation(assigns, :up) do
    history = assigns.history
    index =
      case assigns.history_index do
        nil -> 0
        i -> min(i + 1, length(history) - 1)
      end

    input = Enum.at(history, index) || ""
    {input, index}
  end

  defp history_navigation(assigns, :down) do
  history = assigns.history

  index =
    case assigns.history_index do
      nil -> nil
      i -> max(i - 1, -1)
    end

  input = if index == -1, do: "", else: Enum.at(history, index)
  new_index = if index == -1, do: nil, else: index

  {input, new_index}
  end

  # --- Render function ---

  @impl true
  def render(assigns) do
  ~H"""
  <div id="terminal-container" class="terminal-container">
    <!-- Terminal Output -->
    <pre id="terminal-output" class="terminal-output">
      <%= for line <- @output do %>
        <%= line %>
      <% end %>
    </pre>

    <!-- Terminal Input -->
    <form id="terminal-form" phx-submit="execute_command" class="terminal-input-form">
      <input
        id="terminal-input"
        phx-change="update_input"
        phx-hook="TerminalInputHook"
        type="text"
        name="command"
        value={@input}
        autocomplete="off"
        autofocus
      />
    </form>

    <!-- Terminal Controls -->
    <div id="terminal-controls" class="terminal-controls">
      <button type="button" phx-click="clear_terminal">Clear</button>
    </div>
  </div>
  """
  end
end
