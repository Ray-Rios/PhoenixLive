defmodule PhoenixAppWeb.LobbyLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.{PresenceTracker, Chat}
  import PhoenixAppWeb.Components.PageWrapper

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) && socket.assigns.current_user do
      # Join the lobby presence
      PresenceTracker.track(self(), "lobby", socket.assigns.current_user.id, %{
        username: socket.assigns.current_user.name,
        position: %{x: 0, y: 52, z: 0}, # Start in center of crater lake
        joined_at: System.system_time(:second)
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
           mode: "open_world" # forced
         },
         lighting: %{ambient: 0.6, directional: 0.8, sun_intensity: 0.8},
         environment: "craterlake",
         world_config: %{
           world_size: 8192,
           chunk_size: 1024,
           load_radius: 2,
           unload_radius: 4,
           sea_level: 50,
           spawn_position: %{x: 0, y: 52, z: 0}
         }
       },
       user: %{
         username: if(socket.assigns.current_user, do: socket.assigns.current_user.name, else: "Anonymous"),
         avatar: "cat",
         position: %{x: 0, y: 52, z: 0}
       },
       chat_messages: [],
       users_present: list_present_users(),
       chat_visible: true,
       debug_info: %{fps: 60, loaded_chunks: 0, players_visible: 0}
     )}
  end

  # -------------------
  # Open World & Chat Events  
  # -------------------

  @impl true
  def handle_event("send_chat_message", %{"message" => message, "username" => username, "position" => position}, socket) do
    if socket.assigns.current_user && String.trim(message) != "" do
      # Create chat message data
      chat_data = %{
        id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
        username: username,
        message: String.trim(message) |> String.slice(0, 500), # Limit length
        position: position,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        type: "user"
      }
      
      # Broadcast chat message to all lobby users
      Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "lobby:chat", {:chat_message, chat_data})
      
      # Add to local messages
      chat_messages = [chat_data | socket.assigns.chat_messages] |> Enum.take(50) # Keep last 50 messages
      
      {:noreply, assign(socket, chat_messages: chat_messages)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_position", %{"x" => x, "y" => y, "z" => z}, socket) do
    if socket.assigns.current_user do
      # Update user position in presence
      PresenceTracker.update(self(), "lobby", socket.assigns.current_user.id, %{
        username: socket.assigns.current_user.name,
        position: %{x: x, y: y, z: z},
        joined_at: System.system_time(:second)
      })
      
      # Update local user position
      user = put_in(socket.assigns.user.position, %{x: x, y: y, z: z})
      {:noreply, assign(socket, user: user)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, chat_visible: !socket.assigns.chat_visible)}
  end

  @impl true
  def handle_event("debug_info_update", info, socket) do
    {:noreply, assign(socket, debug_info: Map.merge(socket.assigns.debug_info, info))}
  end

  # -------------------
  # Legacy panel & character select events removed

  # -------------------
  # Babylon.js Events
  # -------------------

  @impl true
  def handle_event("babylon_interaction", _payload, socket), do: {:noreply, socket}

  @impl true
  def handle_event("babylon_key", %{"key" => key}, socket) do
    case key do
      "t" -> handle_event("toggle_chat", %{}, socket)
      "Escape" -> {:noreply, socket}
      _ -> {:noreply, socket}
    end
  end

  # -------------------
  # PubSub Event Handlers  
  # -------------------

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

  @impl true
  def handle_info({:chat_message, chat_data}, socket) do
    # Add new chat message and push to client
    chat_messages = [chat_data | socket.assigns.chat_messages] |> Enum.take(50)
    
    {:noreply,
     socket
     |> assign(:chat_messages, chat_messages)
     |> push_event("chat_message", chat_data)}
  end

  @impl true
  def handle_info(:post_join_welcome, socket) do
    # Push a system chat event only to this client (not broadcast)
    system_msg = %{
      username: "[system]",
      message: "Welcome to CraterLake! Swim to shore and explore.",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      system: true,
      type: "system"
    }
    {:noreply, push_event(socket, "chat_message", system_msg)}
  end

  @impl true
  def handle_info(%{event: "camera_mode_change", camera_mode: camera_mode}, socket) do
    # Update camera mode inside scene_config and notify client
    scene_config = put_in(socket.assigns.scene_config, [:camera, :mode], camera_mode)
    {:noreply, assign(socket, scene_config: scene_config)}
  end

  # -------------------
  # Render
  # -------------------

  @impl true
  def render(assigns) do
    ~H"""
    <.page_with_navbar current_user={@current_user} flash={@flash}>
      <div id="craterlake-container" style="position: fixed; top: 30px; left: 0; width: 100vw; height: calc(100vh - 30px); background: #001122;">
        <!-- Main 3D Scene -->
        <div id="scene-wrapper" style="width: 100%; height: 100%;">
          <canvas id="craterlake-scene"
                  phx-hook="OpenWorldLobbyScene"
                  data-scene-config={Jason.encode!(@scene_config)}
                  data-user={Jason.encode!(@user)}
                  data-users={Jason.encode!(@users_present)}
                  style="display: block; cursor: crosshair; width: 100%; height: 100%;">
          </canvas>
        </div>

        <!-- Overlay Root -->
        <div id="lobby-ui" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; z-index: 100;">
          <!-- Status Panel -->
          <div style="position: absolute; top: 20px; left: 20px; color: white; font-family: monospace; pointer-events: auto;">
            <div style="background: rgba(0,0,0,0.8); padding: 12px; border-radius: 8px; border: 1px solid #444;">
              <div style="font-size: 16px; color: #60A5FA; margin-bottom: 8px;">🐱 CraterLake Adventure</div>
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

          <!-- Controls (top-right) -->
            <div style="position: absolute; top: 20px; right: 20px; color: white; font-family: monospace; pointer-events: none;">
              <div style="background: rgba(0,0,0,0.8); padding: 12px; border-radius: 8px; border: 1px solid #444; font-size: 12px;">
                <div style="color: #10B981; margin-bottom: 8px;">🎮 Controls</div>
                <div><kbd>W A S D</kbd> - Move cat</div>
                <div><kbd>Mouse</kbd> - Look around</div>
                <div><kbd>T</kbd> - Toggle chat</div>
                <div style="margin-top: 8px; color: #888;">💡 Swim to shore and explore the crater!</div>
              </div>
            </div>

          <!-- Chat Toggle Button -->
          <%= if !@chat_visible do %>
            <button phx-click="toggle_chat"
                    style="position: absolute; bottom: 20px; left: 20px; padding: 12px; background: #10B981; color: white; border: none; border-radius: 6px; cursor: pointer; font-family: monospace; pointer-events: auto;">
              💬 Show Chat
            </button>
          <% end %>

          <!-- Player List -->
          <%= if length(@users_present) > 1 do %>
            <div style="position: absolute; top: 20px; left: 50%; transform: translateX(-50%); color: white; font-family: monospace; pointer-events: none;">
              <div style="background: rgba(0,0,0,0.8); padding: 12px; border-radius: 8px; border: 1px solid #444; text-align: center;">
                <div style="color: #60A5FA; margin-bottom: 8px; font-size: 14px;">🐾 Other Cats Swimming</div>
                <%= for user <- @users_present do %>
                  <%= if user.username != @user.username do %>
                    <div style="font-size: 11px; margin-bottom: 2px;">🐱 <%= user.username %></div>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Welcome overlay removed: replaced by system chat message -->
        </div> <!-- /lobby-ui -->

        <!-- Bottom-left instructions -->
        <div style="position: absolute; bottom: 20px; left: 20px; color: white; font-family: monospace; pointer-events: none;">
          <div style="background: rgba(0,0,0,0.7); padding: 10px; border-radius: 5px; font-size: 12px;">
            <div>ESC - Return to Lobby</div>
            <div>C - Character Select</div>
            <div>D - Desktop Mode</div>
            <div>Click objects to interact</div>
          </div>
        </div>

  <!-- Removed legacy panel iframes -->
      </div> <!-- /craterlake-container -->
    </.page_with_navbar>
    """
  end

  defp list_present_users do
    PresenceTracker.list("lobby")
    |> Enum.map(fn {_user_id, %{metas: [meta | _]}} -> meta end)
  end

  # Safe rounding helper for coordinates which may be integers or floats or nil
  defp round_pos(nil), do: 0
  defp round_pos(v) when is_integer(v), do: v
  defp round_pos(v) when is_float(v), do: Float.round(v, 1)
end