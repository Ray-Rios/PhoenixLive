defmodule PhoenixAppWeb.FileManagerLauncher do
  @moduledoc """
  Component that renders app icons in the navigation bar for launching file manager windows.
  """
  use PhoenixAppWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="file-manager-launcher">
      <!-- File Manager Icon -->
      <button 
        class="p-2 hover:bg-gray-700 rounded-lg transition-colors tooltip-container"
        phx-click="launch_file_manager"
        phx-target={@myself}
        title="File Manager"
      >
        <svg class="w-6 h-6 text-gray-400 hover:text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2v0m0 8l4-4m4 4l4-4"></path>
        </svg>
        <span class="tooltip">File Manager</span>
      </button>
    </div>
    """
  end

  @impl true
  def handle_event("launch_file_manager", _params, socket) do
    # Generate a unique ID for this file manager window
    window_id = "file_manager_#{System.unique_integer([:positive])}"
    
    # Send message to parent LiveView to open file manager window
    send(self(), {:open_file_manager, window_id, socket.assigns.current_user})
    
    {:noreply, socket}
  end
end