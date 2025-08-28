defmodule PhoenixAppWeb.QuestLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts
  alias Phoenix.PubSub

  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user do
      PubSub.subscribe(PhoenixApp.PubSub, "quest:lobby")

      player_data = %{
        id: user.id,
        name: user.name || user.email,
        color: user.avatar_color || "#3B82F6",
        x: user.position_x || 100.0,
        y: 100.0,
        velocityX: 0.0,
        velocityY: 0.0,
        message: nil,
        message_time: nil,
        avatar_url: user.avatar_url
      }

      PubSub.broadcast(PhoenixApp.PubSub, "quest:lobby", {:player_joined, player_data})

      {:ok,
       assign(socket,
         user: user,
         players: %{user.id => player_data},
         chat_messages: [],
         current_message: "",
         page_title: "Quest"
       )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  # Player movement events
  def handle_event("move_player", %{"x" => x, "y" => y}, socket) do
    user = socket.assigns.user
    current = socket.assigns.players[user.id]

    updated = %{
      current
      | x: max(0, min(800, x)),
        y: max(0, min(600, y))
    }

    Accounts.update_user_position(user, %{position_x: updated.x, position_y: updated.y})
    PubSub.broadcast(PhoenixApp.PubSub, "quest:lobby", {:player_moved, updated})

    {:noreply, assign(socket, players: Map.put(socket.assigns.players, user.id, updated))}
  end

  # Chat events
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    user = socket.assigns.user
    player = socket.assigns.players[user.id]

    updated = %{player | message: message, message_time: System.system_time(:millisecond)}

    chat_msg = %{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      user_name: user.name || user.email,
      content: message,
      timestamp: DateTime.utc_now()
    }

    PubSub.broadcast(PhoenixApp.PubSub, "quest:lobby", {:player_message, updated})
    PubSub.broadcast(PhoenixApp.PubSub, "quest:lobby", {:chat_message, chat_msg})

    {:noreply,
     assign(socket,
       players: Map.put(socket.assigns.players, user.id, updated),
       current_message: ""
     )}
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, current_message: message)}
  end

  # LiveView info broadcasts
  def handle_info({:player_joined, player}, socket), do: {:noreply, assign(socket, players: Map.put(socket.assigns.players, player.id, player))}
  def handle_info({:player_left, player_id}, socket), do: {:noreply, assign(socket, players: Map.delete(socket.assigns.players, player_id))}
  def handle_info({:player_moved, player}, socket), do: {:noreply, assign(socket, players: Map.put(socket.assigns.players, player.id, player))}
  def handle_info({:player_message, player}, socket), do: {:noreply, assign(socket, players: Map.put(socket.assigns.players, player.id, player))}
  def handle_info({:chat_message, msg}, socket) do
    {:noreply, assign(socket, chat_messages: [msg | socket.assigns.chat_messages] |> Enum.take(50))}
  end

  def terminate(_reason, socket) do
    if socket.assigns[:user] do
      PubSub.broadcast(PhoenixApp.PubSub, "quest:lobby", {:player_left, socket.assigns.user.id})
    end
  end

  # Render with ImpactJS canvas
  def render(assigns) do
    ~H"""
    <.navbar current_user={@current_user} />

    <div class="w-full h-full relative">
      <canvas id="impact-game" width="8000" height="6000"
              phx-hook="ImpactGame"
              data-players={Jason.encode!(@players)}
              data-current-player={@user.id}>
              data-level="/impact/levels/test.js">
      </canvas>

      <!-- Chat Input Overlay -->
      <div class="absolute bottom-4 left-1/2 transform -translate-x-1/2 z-20">
        <form phx-submit="send_message" class="flex space-x-2 bg-black bg-opacity-70 p-2 rounded-lg">
          <input type="text" name="message" value={@current_message}
                 phx-change="update_message"
                 placeholder="Chat above your avatar..."
                 class="w-80 bg-gray-700 text-white px-2 py-1 rounded" />
          <button type="submit" class="bg-yellow-600 text-white px-4 rounded">Send</button>
        </form>
      </div>
    </div>

    <script type="text/javascript">
      let Hooks = {};
      Hooks.ImpactGame = {
        mounted() {
          const canvas = this.el;
          const players = JSON.parse(canvas.dataset.players);
          const currentPlayerId = canvas.dataset.currentPlayer;
          const levelPath = canvas.dataset.level;

          // Initialize ImpactJS Game
          const levelPath = canvas.dataset.level;

        ig.module('game.main')
          .requires('impact.game','impact.entities','impact.levels.' + levelPath)
          .defines(function(){
            MyGame = ig.Game.extend({
              players: players,
              currentPlayerId: currentPlayerId,
              update: function(){
                this.parent();
                // movement, bouncing...
              },
              draw: function(){
                this.parent();
                // draw players and messages
              }
            });
            ig.main('#impact-game', MyGame, 60, 800, 600, 1);
          });


          this.handleEvent("playersUpdated", ({players}) => {
            MyGame.players = players;
          });
        },

        updated() {
          // update players from LiveView assigns
          for (const id in this.players){
            let p = this.players[id];
            const collision = this.collisionMap.trace(p.x, p.y, 16, 16);
            if (collision.collision.x || collision.collision.y){
              p.velocityX *= -1;
              p.velocityY *= -1;
             }
          }
        }
      }
      

      window.addEventListener('phx:hook', e => {
        window.liveSocket && window.liveSocket.connect();
      });
    </script>
    """
  end
end
