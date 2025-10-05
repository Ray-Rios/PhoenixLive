defmodule PhoenixAppWeb.LobbyLive do
  use PhoenixAppWeb, :live_view
  
  alias PhoenixApp.PresenceTracker
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    user = Map.get(socket.assigns, :current_user, nil)
    cond do
      is_nil(user) ->
        {:ok, redirect(socket, to: ~p"/login")}
      user.role == "BANNED" ->
        {:ok, redirect(socket, to: ~p"/")}
      true -> :ok
    end

    if connected?(socket) && socket.assigns.current_user && socket.assigns.current_user.role != "BANNED" do
      # Join the lobby presence with static timestamp
      joined_at = System.system_time(:second)
      
      PresenceTracker.track(self(), "lobby", socket.assigns.current_user.id, %{
        username: socket.assigns.current_user.name,
        position: %{x: 0, y: 52, z: 0}, # Start in center of crater lake
        joined_at: joined_at,
        character_type: "fox" # Default character type
      })
      
      # Subscribe to presence updates and chat
      Phoenix.PubSub.subscribe(PhoenixApp.PubSub, "lobby")
      Phoenix.PubSub.subscribe(PhoenixApp.PubSub, "lobby:chat")

      # Broadcast a system welcome message (non-persistent) to new joiner only
      send(self(), :post_join_welcome)
    end

    {:ok,
     assign(socket,
       scene_config: %{
         camera: %{
           position: %{x: 0, y: 55, z: 0},
           target: %{x: 0, y: 50, z: 0},
           rotation: %{x: 0, y: 0, z: 0}
         },
         lighting: %{
           ambient: 0.3,
           directional: 0.7
         }
       },
       user: %{
         id: if(socket.assigns.current_user, do: socket.assigns.current_user.id, else: nil),
         username: if(socket.assigns.current_user, do: socket.assigns.current_user.name, else: "Guest"),
         position: %{x: 0, y: 52, z: 0},
         character_type: "fox"
       },
       users_present: [],
       debug_info: %{
         loaded_chunks: 0,
         fps: 60
       }
     )}
  end

  @impl true
  def handle_info(:post_join_welcome, socket) do
    # Send welcome message to this user only
    message = "🌟 Welcome to the 3D Lobby! Use WASD to move, A/D to turn, right-click+A/D to strafe."
    {:noreply, push_event(socket, "chat_message", %{
      username: "System",
      message: message,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      color: "#00ff00"
    })}
  end

  @impl true
  def handle_info({:user_joined, user_data}, socket) do
    # Broadcast to all clients that a user joined
    {:noreply, push_event(socket, "user_joined", user_data)}
  end

  @impl true
  def handle_info({:user_left, user_id}, socket) do
    # Broadcast to all clients that a user left
    {:noreply, push_event(socket, "user_left", %{user_id: user_id})}
  end

  @impl true
  def handle_info({:position_update, position_data}, socket) do
    # Forward position update to client (don't send back to the sender)
    if position_data.user_id != socket.assigns.current_user.id do
      {:noreply, push_event(socket, "position_update", position_data)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    # Handle presence changes and broadcast user join/leave events
    for {user_id, %{metas: [meta | _]}} <- diff.joins do
      # Broadcast user joined event
      PubSub.broadcast(PhoenixApp.PubSub, "lobby", {:user_joined, %{
        user_id: user_id,
        username: meta.username,
        position: meta.position,
        character_type: Map.get(meta, :character_type, "fox")
      }})
    end

    for {user_id, _} <- diff.leaves do
      # Broadcast user left event
      PubSub.broadcast(PhoenixApp.PubSub, "lobby", {:user_left, user_id})
    end

    # Update users_present list
    users_present = 
      PresenceTracker.list("lobby")
      |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
        %{
          id: user_id,
          username: meta.username,
          position: meta.position,
          character_type: Map.get(meta, :character_type, "fox")
        }
      end)

    {:noreply, assign(socket, users_present: users_present)}
  end

  @impl true
  def handle_info({:chat_message, chat_data}, socket) do
    {:noreply, push_event(socket, "chat_message", chat_data)}
  end

  @impl true
  def handle_event("update_position", %{"x" => x, "y" => y, "z" => z, "rotation_y" => rotation_y}, socket) do
    if socket.assigns.current_user do
      user_id = socket.assigns.current_user.id
      
      # Update presence tracker with new position
      PresenceTracker.update(self(), "lobby", user_id, fn meta ->
        Map.put(meta, :position, %{x: x, y: y, z: z, rotation_y: rotation_y})
      end)
      
      # Broadcast position update to other users
      position_data = %{
        user_id: user_id,
        x: x,
        y: y,
        z: z,
        rotation_y: rotation_y
      }
      
      PubSub.broadcast(PhoenixApp.PubSub, "lobby", {:position_update, position_data})
      
      # Update socket state
      updated_user = Map.put(socket.assigns.user, :position, %{x: x, y: y, z: z})
      {:noreply, assign(socket, user: updated_user)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("chat_message", %{"message" => message}, socket) do
    if socket.assigns.current_user && String.trim(message) != "" do
      chat_data = %{
        username: socket.assigns.current_user.name,
        message: String.trim(message),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        color: "#ffffff"
      }
      
      # Broadcast to all lobby users
      PubSub.broadcast(PhoenixApp.PubSub, "lobby:chat", {:chat_message, chat_data})
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("character_selected", %{"character_type" => character_type}, socket) do
    if socket.assigns.current_user do
      user_id = socket.assigns.current_user.id
      
      # Update presence tracker with new character type
      PresenceTracker.update(self(), "lobby", user_id, fn meta ->
        Map.put(meta, :character_type, character_type)
      end)
      
      # Update socket state
      updated_user = Map.put(socket.assigns.user, :character_type, character_type)
      {:noreply, assign(socket, user: updated_user)}
    else
      {:noreply, socket}
    end
  end

  # Helper functions
  defp round_pos(pos) when is_float(pos), do: Float.round(pos, 1)
  defp round_pos(pos), do: pos

  @impl true
  def render(assigns) do
    ~H"""
    <.page_with_navbar current_user={@current_user} flash={@flash} full_viewport={true}>
      <div id="world-builder-container" style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: #001122; z-index: 1;">
        <!-- Main 3D Scene -->
        <div id="scene-wrapper" phx-update="ignore" style="width: 100vw; height: 100vh; position: relative;">
          <!-- data-users temporarily empty to prevent churn; re-enable when multi-player rendering implemented -->
          <canvas id="world-builder-scene"
            phx-hook="OpenWorldLobbyScene"
            data-scene-config={Jason.encode!(@scene_config)}
            data-user={Jason.encode!(@user)}
            data-user-id={if @current_user, do: @current_user.id, else: ""}
            data-build-mode="false"
            data-users="[]"
            style="display: block; cursor: crosshair; width: 100vw; height: 100vh; position: absolute; top: 0; left: 0; z-index: 2;">
          </canvas>
        </div>

        <!-- Overlay Root -->
        <div id="lobby-ui" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; z-index: 100;">
          <!-- Status Panel (Play UI) -->
          <div class="play-ui-panel" style="position: absolute; top: 20px; left: 20px; color: white; font-family: monospace; pointer-events: auto; transition: transform .35s ease, opacity .35s ease;">
            <div style="background: rgba(0,0,0,0.8); padding: 12px; border-radius: 8px; border: 1px solid #444;">
              <div style="font-size: 16px; color: #60A5FA; margin-bottom: 8px;">🏗️ World Builder</div>
              <div style="font-size: 12px;">Player: <%= @user.username %></div>
              <div style="font-size: 12px;">Position: <%= round_pos(@user.position.x) %>, <%= round_pos(@user.position.y) %>, <%= round_pos(@user.position.z) %></div>
              <div style="font-size: 12px;">Players Online: <%= length(@users_present) %></div>
              <%= if @debug_info.loaded_chunks > 0 do %>
                <div style="font-size: 11px; color: #888; margin-top: 4px;">
                  Chunks: <%= @debug_info.loaded_chunks %> | FPS: <%= @debug_info.fps %>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Controls Help (Play UI) -->
          <div class="play-ui-panel" style="position: absolute; bottom: 20px; right: 20px; color: white; font-family: monospace; font-size: 11px; pointer-events: auto; transition: transform .35s ease, opacity .35s ease;">
            <div style="background: rgba(0,0,0,0.8); padding: 10px; border-radius: 6px; border: 1px solid #444;">
              <div style="color: #60A5FA; margin-bottom: 6px;">🎮 Controls</div>
              <div>WASD: Move</div>
              <div>A/D: Turn in place</div>
              <div>Right-click + A/D: Strafe</div>
              <div>Right-click + drag: Rotate camera</div>
              <div>Mouse wheel: Zoom</div>
              <div>Space: Jump</div>
              <div>Ctrl: Toggle build mode</div>
            </div>
          </div>

          <!-- User List -->
          <%= if length(@users_present) > 1 do %>
            <div class="play-ui-panel" style="position: absolute; top: 20px; right: 20px; color: white; font-family: monospace; font-size: 11px; pointer-events: auto; transition: transform .35s ease, opacity .35s ease;">
              <div style="background: rgba(0,0,0,0.8); padding: 10px; border-radius: 6px; border: 1px solid #444; max-width: 200px;">
                <div style="color: #60A5FA; margin-bottom: 6px;">👥 Players Online (<%= length(@users_present) %>)</div>
                <%= for user <- @users_present do %>
                  <div style={"margin: 2px 0; #{if user.id == @current_user.id, do: "color: #00ff00;", else: "color: #ccc;"}"}>
                    <%= if user.id == @current_user.id do %>
                      🟢 <%= user.username %> (You)
                    <% else %>
                      🔵 <%= user.username %>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Build UI Panel (hidden initially) -->
          <div id="build-ui-panel" class="build-ui-panel" style="position:absolute; top:60px; left:50%; transform:translate(-50%, -40px); opacity:0; pointer-events:none; font-family: monospace; color:#fff; transition: transform .35s ease, opacity .35s ease;">
            <div style="background:rgba(0,0,0,0.85); padding:14px 18px; border:1px solid #555; border-radius:10px; min-width:480px; display:flex; flex-direction:column; gap:12px;">
              <div style="font-size:15px; color:#38bdf8; display:flex; align-items:center; gap:8px;">
                🛠️ Build Mode <span id="build-mode-indicator" style="font-size:11px; color:#aaa;">(Ctrl to exit)</span>
              </div>
              <div style="display:flex; gap:8px; flex-wrap:wrap;">
                <button data-build-tool="raise" class="build-tool-btn">Raise</button>
                <button data-build-tool="lower" class="build-tool-btn">Lower</button>
                <button data-build-tool="paint" class="build-tool-btn">Paint</button>
                <button data-build-tool="place" class="build-tool-btn">Place</button>
                <button data-build-action="delete" class="build-tool-btn" style="margin-left:auto;">Delete Selected</button>
                <button data-build-action="clear" class="build-tool-btn">Clear All</button>
              </div>
              <div style="display:flex; gap:12px; align-items:center; flex-wrap:wrap; font-size:11px;">
                <label>Brush Size <input id="brush-size-input" type="range" min="1" max="20" value="5" /></label>
                <label>Strength <input id="brush-strength-input" type="range" min="1" max="10" value="1" /></label>
                <label>Material
                  <select id="material-select" style="background:#111; color:#fff; border:1px solid #444;">
                    <option value="grass">Grass</option>
                    <option value="stone">Stone</option>
                    <option value="sand">Sand</option>
                    <option value="dirt">Dirt</option>
                    <option value="wood">Wood</option>
                    <option value="metal">Metal</option>
                    <option value="crystal">Crystal</option>
                  </select>
                </label>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.page_with_navbar>
    """
  end
end
