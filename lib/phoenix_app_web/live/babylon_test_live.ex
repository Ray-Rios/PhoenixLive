defmodule PhoenixAppWeb.BabylonTestLive do
  use PhoenixAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       scene_config: %{
         camera: %{position: %{x: 0, y: 5, z: 10}, target: %{x: 0, y: 0, z: 0}},
         lighting: %{ambient: 0.7, directional: 0.5},
         editor_scene: nil  # Path to editor scene file
       },
       test_assets: []
     )}
  end

  # -------------------
  # Babylon.js events
  # -------------------

  @impl true
  def handle_event("babylon_interaction", %{"type" => type, "mesh" => mesh}, socket) do
    {:noreply, push_log(socket, %{type: type, mesh: mesh})}
  end

  @impl true
  def handle_event("babylon_key", %{"key" => key}, socket) do
    {:noreply, push_log(socket, %{type: "key", key: key})}
  end

  @impl true
  def handle_event("babylon_error", %{"message" => msg}, socket) do
    {:noreply, push_log(socket, %{type: "error", message: msg})}
  end

  @impl true
  def handle_event("babylon_fallback", %{"reason" => reason}, socket) do
    {:noreply, push_log(socket, %{type: "fallback", reason: reason})}
  end

  # -------------------
  # UI Events
  # -------------------

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    {:noreply, push_log(socket, %{type: "chat", message: message})}
  end

  @impl true
  def handle_event("run_test", _params, socket) do
    {:noreply, push_log(socket, %{type: "test", message: "Running Babylon.js test"})}
  end

  @impl true
  def handle_event("create_test_scene", _params, socket) do
    {:noreply, push_log(socket, %{type: "scene", message: "Creating test scene"})}
  end

  @impl true
  def handle_event("debug_scene", _params, socket) do
    {:noreply, push_log(socket, %{type: "debug", message: "Debugging scene"})}
  end

  @impl true
  def handle_event("load_editor_scene", _params, socket) do
    scene_config = Map.put(socket.assigns.scene_config, :editor_scene, "/assets/js/babylon/editor/sample_project.bjseditor")
    {:noreply, assign(socket, scene_config: scene_config)}
  end

  # -------------------
  # Helpers
  # -------------------

  defp push_log(socket, log) do
    push_event(socket, "display_log", log)
  end

  # -------------------
  # Render
  # -------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div id="canvas-wrapper"
         style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
                overflow: hidden; z-index: 1000; background: #000011;">
      <canvas id="babylon-scene"
              phx-hook="BabylonScene"
              data-scene-config={Jason.encode!(@scene_config)}
              data-assets={Jason.encode!(@test_assets)}
              style="display: block; cursor: crosshair; width: 100%; height: 100%;">
      </canvas>
    </div>

    <!-- Chat + Controls -->
    <div id="chat-overlay"
         style="position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
                z-index: 1001;">
      <form phx-submit="send_message"
            class="flex gap-2 bg-black/90 p-3 rounded-2xl backdrop-blur border border-white/20">
        <input type="text" name="message" placeholder="Type to chat..."
               maxlength="50" autocomplete="off"
               class="w-80 px-4 py-2 rounded-xl bg-white/10 text-white text-sm focus:outline-none"/>
        <button type="submit"
                class="px-4 py-2 rounded-xl bg-gradient-to-r from-blue-500 to-purple-600 text-white font-bold">
          Send
        </button>
      </form>

      <div class="bg-gray-800 rounded-lg p-6 mt-4">
        <h2 class="text-xl font-semibold text-white mb-4">Test Controls</h2>
        <div class="flex gap-4">
          <button phx-click="run_test"
                  class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg">
            Run Babylon.js Test
          </button>
          <button phx-click="create_test_scene"
                  class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg">
            Create Test Scene
          </button>
          <button phx-click="debug_scene"
                  class="bg-yellow-600 hover:bg-yellow-700 text-white px-4 py-2 rounded-lg">
            Debug Scene
          </button>
          <button phx-click="load_editor_scene"
                  class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg">
            Load Editor Scene
          </button>
        </div>
      </div>
    </div>
    """
  end
end
