defmodule PhoenixAppWeb.LobbyLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.PresenceTracker

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) && socket.assigns.current_user do
      # Join the lobby presence
      PresenceTracker.track(self(), "lobby", socket.assigns.current_user.id, %{
        username: socket.assigns.current_user.name,
        position: %{x: 0, y: 0, z: 0},
        joined_at: System.system_time(:second)
      })
      
      # Subscribe to presence updates
      Phoenix.PubSub.subscribe(PhoenixApp.PubSub, "lobby")
    end

    {:ok,
     assign(socket,
       scene_config: %{
         camera: %{
           position: %{x: 0, y: 2, z: 8},
           target: %{x: 0, y: 0, z: 0},
           mode: "lobby" # lobby, character_select, desktop
         },
         lighting: %{ambient: 0.6, directional: 0.8},
         environment: "lobby",
         editor_scene: "/assets/js/babylon/scenes/zone1_lobby/lobby_scene.babylon"
       },
       user: %{
         character: nil,
         customization: %{
           skin_tone: "medium",
           hair_color: "brown",
           outfit: "casual"
         }
       },
       active_panels: [],
       available_panels: [
         %{id: "profile", title: "Profile", route: "/profile", position: %{x: -3, y: 1, z: 0}},
         %{id: "inventory", title: "Inventory", route: "/inventory", position: %{x: 0, y: 1, z: 0}}
       ],
       users_present: list_present_users()
     )}
  end

  # -------------------
  # Camera & Navigation Events
  # -------------------

  @impl true
  def handle_event("camera_move", %{"mode" => mode, "position" => pos}, socket) do
    scene_config = put_in(socket.assigns.scene_config, [:camera, :mode], mode)
    scene_config = put_in(scene_config, [:camera, :position], pos)
    
    {:noreply, assign(socket, scene_config: scene_config)}
  end

  @impl true
  def handle_event("enter_character_select", _params, socket) do
    scene_config = put_in(socket.assigns.scene_config, [:camera, :mode], "character_select")
    scene_config = put_in(scene_config, [:camera, :position], %{x: 0, y: 1.5, z: 3})
    scene_config = put_in(scene_config, [:camera, :target], %{x: 0, y: 1, z: 0})
    
    {:noreply, assign(socket, scene_config: scene_config)}
  end

  @impl true
  def handle_event("enter_desktop_mode", _params, socket) do
    scene_config = put_in(socket.assigns.scene_config, [:camera, :mode], "desktop")
    scene_config = put_in(scene_config, [:camera, :position], %{x: 0, y: 1, z: 5})
    
    {:noreply, assign(socket, scene_config: scene_config)}
  end

  # -------------------
  # Panel Management
  # -------------------

  @impl true
  def handle_event("open_panel", %{"panel_id" => panel_id}, socket) do
    panel = Enum.find(socket.assigns.available_panels, &(&1.id == panel_id))
    
    if panel && panel not in socket.assigns.active_panels do
      active_panels = [panel | socket.assigns.active_panels]
      {:noreply, assign(socket, active_panels: active_panels)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_panel", %{"panel_id" => panel_id}, socket) do
    active_panels = Enum.reject(socket.assigns.active_panels, &(&1.id == panel_id))
    {:noreply, assign(socket, active_panels: active_panels)}
  end

  @impl true
  def handle_event("focus_panel", %{"panel_id" => panel_id}, socket) do
    panel = Enum.find(socket.assigns.active_panels, &(&1.id == panel_id))
    
    if panel do
      # Move camera to focus on this panel
      scene_config = put_in(socket.assigns.scene_config, [:camera, :target], panel.position)
      {:noreply, assign(socket, scene_config: scene_config)}
    else
      {:noreply, socket}
    end
  end

  # -------------------
  # Character Events
  # -------------------

  @impl true
  def handle_event("customize_character", %{"attribute" => attr, "value" => value}, socket) do
    customization = put_in(socket.assigns.user.customization, [String.to_atom(attr)], value)
    user = put_in(socket.assigns.user, [:customization], customization)
    
    {:noreply, assign(socket, user: user)}
  end

  @impl true
  def handle_event("select_character", %{"character_id" => character_id}, socket) do
    user = put_in(socket.assigns.user, [:character], character_id)
    
    # Transition to desktop mode
    scene_config = put_in(socket.assigns.scene_config, [:camera, :mode], "desktop")
    
    {:noreply, assign(socket, user: user, scene_config: scene_config)}
  end

  # -------------------
  # Babylon.js Events
  # -------------------

  @impl true
  def handle_event("babylon_interaction", %{"type" => "click", "mesh" => mesh_name}, socket) do
    case mesh_name do
      "character_select_trigger" ->
        handle_event("enter_character_select", %{}, socket)
      
      "desktop_trigger" ->
        handle_event("enter_desktop_mode", %{}, socket)
      
      "panel_" <> panel_id ->
        handle_event("open_panel", %{"panel_id" => panel_id}, socket)
      
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("babylon_key", %{"key" => key}, socket) do
    case key do
      "c" -> handle_event("enter_character_select", %{}, socket)
      "d" -> handle_event("enter_desktop_mode", %{}, socket)
      "Escape" -> 
        # Return to lobby view
        scene_config = put_in(socket.assigns.scene_config, [:camera, :mode], "lobby")
        {:noreply, assign(socket, scene_config: scene_config)}
      _ -> {:noreply, socket}
    end
  end

  # -------------------
  # Render
  # -------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div id="lobby-container" style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: #000;">
      <!-- Main 3D Scene -->
      <div id="scene-wrapper" style="width: 100%; height: 100%;">
        <canvas id="lobby-scene"
                phx-hook="LobbyScene"
                data-scene-config={Jason.encode!(@scene_config)}
                data-user={Jason.encode!(@user)}
                data-panels={Jason.encode!(@active_panels)}
                style="display: block; cursor: crosshair; image-rendering: pixelated; width: 100%; height: 100%;">
        </canvas>
      </div>

      <!-- UI Overlay -->
      <div id="lobby-ui" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; z-index: 100;">
        
        <!-- Mode Indicator -->
        <div style="position: absolute; top: 20px; left: 20px; color: white; font-family: monospace; pointer-events: auto;">
          <div style="background: rgba(0,0,0,0.7); padding: 10px; border-radius: 5px;">
            <div>Mode: <%= @scene_config.camera.mode %></div>
            <div>Active Panels: <%= length(@active_panels) %></div>
            <%= if @user.character do %>
              <div>Character: <%= @user.character %></div>
            <% end %>
          </div>
        </div>

        <!-- Quick Actions -->
        <div style="position: absolute; bottom: 20px; right: 20px; pointer-events: auto;">
          <div style="display: flex; gap: 10px; flex-direction: column;">
            <button phx-click="enter_character_select"
                    style="background: #4F46E5; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">
              Character Select (C)
            </button>
            <button phx-click="enter_desktop_mode"
                    style="background: #059669; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">
              Desktop Mode (D)
            </button>
          </div>
        </div>

        <!-- Panel Controls -->
        <%= if @scene_config.camera.mode == "desktop" do %>
          <div style="position: absolute; top: 20px; right: 20px; pointer-events: auto;">
            <div style="background: rgba(0,0,0,0.8); padding: 15px; border-radius: 10px; color: white;">
              <h3 style="margin: 0 0 10px 0;">Available Panels</h3>
              <%= for panel <- @available_panels do %>
                <button phx-click="open_panel" phx-value-panel_id={panel.id}
                        style="display: block; width: 100%; margin: 5px 0; padding: 8px; background: #374151; color: white; border: none; border-radius: 3px; cursor: pointer;">
                  <%= panel.title %>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Character Customization -->
        <%= if @scene_config.camera.mode == "character_select" do %>
          <div style="position: absolute; left: 20px; top: 50%; transform: translateY(-50%); pointer-events: auto;">
            <div style="background: rgba(0,0,0,0.8); padding: 20px; border-radius: 10px; color: white; min-width: 250px;">
              <h3 style="margin: 0 0 15px 0;">Character Customization</h3>
              
              <div style="margin-bottom: 15px;">
                <label>Skin Tone:</label>
                <select phx-change="customize_character" name="attribute" value="skin_tone" 
                        style="width: 100%; padding: 5px; margin-top: 5px;">
                  <option value="light">Light</option>
                  <option value="medium" selected={@user.customization.skin_tone == "medium"}>Medium</option>
                  <option value="dark">Dark</option>
                </select>
              </div>

              <div style="margin-bottom: 15px;">
                <label>Hair Color:</label>
                <select phx-change="customize_character" name="attribute" value="hair_color"
                        style="width: 100%; padding: 5px; margin-top: 5px;">
                  <option value="black">Black</option>
                  <option value="brown" selected={@user.customization.hair_color == "brown"}>Brown</option>
                  <option value="blonde">Blonde</option>
                  <option value="red">Red</option>
                </select>
              </div>

              <button phx-click="select_character" phx-value-character_id="player_1"
                      style="width: 100%; padding: 10px; background: #10B981; color: white; border: none; border-radius: 5px; cursor: pointer; margin-top: 10px;">
                Enter World
              </button>
            </div>
          </div>
        <% end %>

        <!-- Instructions -->
        <div style="position: absolute; bottom: 20px; left: 20px; color: white; font-family: monospace; pointer-events: none;">
          <div style="background: rgba(0,0,0,0.7); padding: 10px; border-radius: 5px; font-size: 12px;">
            <div>ESC - Return to Lobby</div>
            <div>C - Character Select</div>
            <div>D - Desktop Mode</div>
            <div>Click objects to interact</div>
          </div>
        </div>
      </div>

      <!-- Hidden iframes for panel content -->
      <%= for panel <- @active_panels do %>
        <iframe id={"panel-content-#{panel.id}"}
                src={panel.route}
                style="position: absolute; left: -9999px; width: 800px; height: 600px; border: none; background: white;">
        </iframe>
      <% end %>
    </div>
    """
  end

  # Handle presence updates
  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    users_present = list_present_users()
    
    # Push updated user list to JavaScript
    {:noreply, 
     socket
     |> assign(:users_present, users_present)
     |> push_event("update_users", %{users: users_present})}
  end

  # Handle user position updates from JavaScript
  @impl true  
  def handle_event("update_position", %{"x" => x, "y" => y, "z" => z}, socket) do
    if socket.assigns.current_user do
      PresenceTracker.update(self(), "lobby", socket.assigns.current_user.id, %{
        username: socket.assigns.current_user.name,
        position: %{x: x, y: y, z: z},
        joined_at: System.system_time(:second)
      })
    end
    
    {:noreply, socket}
  end

  defp list_present_users do
    PresenceTracker.list("lobby")
    |> Enum.map(fn {_user_id, %{metas: [meta | _]}} -> meta end)
  end
end