defmodule PhoenixAppWeb.QuestLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts
  alias Phoenix.PubSub

  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user do
      PubSub.subscribe(PhoenixApp.PubSub, "galaxy:quest")

      player = %{
        id: user.id,
        name: user.name || user.email,
        color: user.avatar_color || "#3B82F6",
        x: :rand.uniform(700) + 50,
        y: :rand.uniform(500) + 50,
        message: nil,
        message_time: nil,
        avatar_url: user.avatar_url,
        last_seen: System.system_time(:millisecond)
      }

      PubSub.broadcast(PhoenixApp.PubSub, "galaxy:quest", {:player_joined, player})

      {:ok,
       assign(socket,
         user: user,
         players: %{user.id => player},
         page_title: "Galaxy Quest"
       )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_event("move_player", %{"x" => x, "y" => y}, socket) do
    user = socket.assigns.user
    player = socket.assigns.players[user.id]

    updated_player = %{player | x: x, y: y}
    PubSub.broadcast(PhoenixApp.PubSub, "galaxy:quest", {:player_moved, updated_player})

    {:noreply, assign(socket, players: Map.put(socket.assigns.players, user.id, updated_player))}
  end

  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    user = socket.assigns.user
    player = socket.assigns.players[user.id]

    updated_player = %{
      player 
      | message: String.slice(message, 0, 50),
        message_time: System.system_time(:millisecond)
    }

    PubSub.broadcast(PhoenixApp.PubSub, "galaxy:quest", {:player_message, updated_player})

    {:noreply, assign(socket, players: Map.put(socket.assigns.players, user.id, updated_player))}
  end

  def handle_event("send_message", %{"message" => ""}, socket), do: {:noreply, socket}

  def handle_event("player_abducted", %{"player_id" => player_id}, socket) do
    if player = socket.assigns.players[player_id] do
      respawned_player = %{
        player 
        | x: :rand.uniform(700) + 50,
          y: :rand.uniform(500) + 50,
          message: "I was abducted! 👽",
          message_time: System.system_time(:millisecond)
      }
      
      PubSub.broadcast(PhoenixApp.PubSub, "galaxy:quest", {:player_respawned, respawned_player})
      
      {:noreply, assign(socket, players: Map.put(socket.assigns.players, player_id, respawned_player))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:player_joined, player}, socket) do
    {:noreply, assign(socket, players: Map.put(socket.assigns.players, player.id, player))}
  end

  def handle_info({:player_left, player_id}, socket) do
    {:noreply, assign(socket, players: Map.delete(socket.assigns.players, player_id))}
  end

  def handle_info({:player_moved, player}, socket) do
    {:noreply, assign(socket, players: Map.put(socket.assigns.players, player.id, player))}
  end

  def handle_info({:player_message, player}, socket) do
    {:noreply, assign(socket, players: Map.put(socket.assigns.players, player.id, player))}
  end

  def handle_info({:player_respawned, player}, socket) do
    {:noreply, assign(socket, players: Map.put(socket.assigns.players, player.id, player))}
  end

  def terminate(_reason, socket) do
    if socket.assigns[:user] do
      PubSub.broadcast(PhoenixApp.PubSub, "galaxy:quest", {:player_left, socket.assigns.user.id})
    end
  end

  def render(assigns) do
    ~H"""
    <canvas 
      id="quest-canvas"
      phx-hook="QuestGame"
      data-players={Jason.encode!(@players)}
      data-current-player={@user.id}
      style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; z-index: 1000; background: #000011; cursor: crosshair;">
    </canvas>

    <div id="chat-overlay" style="position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); z-index: 1001;">
      <form phx-submit="send_message" style="display: flex; gap: 10px; background: rgba(0,0,0,0.9); padding: 12px; border-radius: 25px; backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2);">
        <input 
          type="text" 
          name="message" 
          placeholder="Type to chat..."
          maxlength="50"
          autocomplete="off"
          style="width: 350px; padding: 10px 16px; border: none; border-radius: 20px; background: rgba(255,255,255,0.1); color: white; outline: none; font-size: 14px;" />
        <button type="submit" style="padding: 10px 20px; border: none; border-radius: 20px; background: linear-gradient(45deg, #667eea 0%, #764ba2 100%); color: white; cursor: pointer; font-weight: bold;">Send</button>
      </form>
    </div>

    <div id="instructions" style="position: fixed; top: 20px; left: 20px; background: rgba(0,0,0,0.9); color: white; padding: 16px; border-radius: 12px; font-family: monospace; font-size: 13px; z-index: 1001;">
      <h3 style="margin: 0 0 12px 0; color: #a78bfa;">🌌 Galaxy Quest</h3>
      <p style="margin: 4px 0;">WASD/Arrows: Move</p>
      <p style="margin: 4px 0;">Click: Move to location</p>
      <p style="margin: 4px 0;">Avoid aliens!</p>
      <p style="margin: 4px 0;">Players: <%= map_size(@players) %></p>
    </div>

    <style>
      body { overflow: hidden; margin: 0; padding: 0; }
      html { overflow: hidden; margin: 0; padding: 0; }
    </style>
    """
  end
end