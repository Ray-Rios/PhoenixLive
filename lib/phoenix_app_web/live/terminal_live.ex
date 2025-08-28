defmodule PhoenixAppWeb.TerminalLive do
  use PhoenixAppWeb, :live_view

  on_mount {PhoenixAppWeb.UserAuth, :require_authenticated_user}

  def mount(_params, _session, socket) do
    {:ok,
      assign(socket,
        output: ["PowerShell Terminal v1.0", "Type commands to execute on the server."],
        input: "",
        history: [],
        history_index: 0,
        page_title: "Terminal"
      )
    }
  end

  def handle_event("execute_command", %{"command" => command}, socket) do
    trimmed_command = String.trim(command)

    if trimmed_command != "" do
      new_output = socket.assigns.output ++ ["PS> #{trimmed_command}"]
      result = execute_powershell_command(trimmed_command)
      final_output = new_output ++ [result]
      new_history = [trimmed_command | socket.assigns.history]

      {:noreply,
        assign(socket,
          output: final_output,
          input: "",
          history: new_history,
          history_index: 0
        )
      }
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_input", %{"command" => command}, socket) do
    {:noreply, assign(socket, input: command)}
  end

  def handle_event("clear_terminal", _params, socket) do
    {:noreply, assign(socket, output: ["Terminal cleared."])}
  end

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
end
