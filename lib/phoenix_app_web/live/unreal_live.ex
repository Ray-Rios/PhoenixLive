defmodule PhoenixAppWeb.UnrealLive do
  use PhoenixAppWeb, :live_view
  alias Phoenix.PubSub

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    if user do
      # Subscribe to unreal game updates
      PubSub.subscribe(PhoenixApp.PubSub, "unreal:game")
      
      {:ok, assign(socket,
        user: user,
        game_state: :menu,
        player_stats: %{
          level: 1,
          health: 100,
          mana: 50,
          experience: 0,
          coins: 0
        },
        chat_messages: [],
        current_message: "",
        game_log: ["Welcome to the Unreal Experience!"],
        page_title: "Unreal"
      )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_event("start_game", _params, socket) do
    # Initialize game state
    game_log = ["Game started!", "Use WASD to move, Space to jump" | socket.assigns.game_log]
    
    # Broadcast game start
    PubSub.broadcast(PhoenixApp.PubSub, "unreal:game", {:player_joined, socket.assigns.user})
    
    {:noreply, assign(socket, 
      game_state: :playing,
      game_log: game_log
    )}
  end

  def handle_event("pause_game", _params, socket) do
    {:noreply, assign(socket, game_state: :paused)}
  end

  def handle_event("resume_game", _params, socket) do
    {:noreply, assign(socket, game_state: :playing)}
  end

  def handle_event("quit_game", _params, socket) do
    PubSub.broadcast(PhoenixApp.PubSub, "unreal:game", {:player_left, socket.assigns.user})
    {:noreply, assign(socket, game_state: :menu)}
  end

  def handle_event("player_action", %{"action" => action}, socket) do
    {new_stats, log_message} = handle_game_action(socket.assigns.player_stats, action)
    
    game_log = [log_message | socket.assigns.game_log] |> Enum.take(20)
    
    {:noreply, assign(socket, 
      player_stats: new_stats,
      game_log: game_log
    )}
  end

  def handle_event("send_chat", %{"message" => message}, socket) when message != "" do
    user = socket.assigns.user
    
    chat_message = %{
      id: Ecto.UUID.generate(),
      user_name: user.name || user.email,
      content: message,
      timestamp: DateTime.utc_now()
    }
    
    # Broadcast to other players
    PubSub.broadcast(PhoenixApp.PubSub, "unreal:game", {:chat_message, chat_message})
    
    {:noreply, assign(socket, current_message: "")}
  end

  def handle_event("send_chat", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, current_message: message)}
  end

  def handle_info({:chat_message, message}, socket) do
    messages = [message | socket.assigns.chat_messages] |> Enum.take(50)
    {:noreply, assign(socket, chat_messages: messages)}
  end

  def handle_info({:player_joined, player}, socket) do
    if player.id != socket.assigns.user.id do
      game_log = ["#{player.name || player.email} joined the game" | socket.assigns.game_log]
      {:noreply, assign(socket, game_log: game_log)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:player_left, player}, socket) do
    if player.id != socket.assigns.user.id do
      game_log = ["#{player.name || player.email} left the game" | socket.assigns.game_log]
      {:noreply, assign(socket, game_log: game_log)}
    else
      {:noreply, socket}
    end
  end

  defp handle_game_action(stats, action) do
    case action do
      "attack" ->
        new_stats = Map.update(stats, :experience, 0, &(&1 + 10))
        {new_stats, "You attacked an enemy! +10 XP"}
      
      "heal" ->
        if stats.mana >= 10 do
          new_stats = stats
                     |> Map.update(:health, 100, &min(&1 + 25, 100))
                     |> Map.update(:mana, 50, &(&1 - 10))
          {new_stats, "You healed yourself! +25 HP, -10 Mana"}
        else
          {stats, "Not enough mana to heal!"}
        end
      
      "explore" ->
        coins_found = :rand.uniform(5)
        new_stats = Map.update(stats, :coins, 0, &(&1 + coins_found))
        {new_stats, "You explored and found #{coins_found} coins!"}
      
      "rest" ->
        new_stats = Map.update(stats, :mana, 50, &min(&1 + 15, 50))
        {new_stats, "You rested and recovered mana. +15 Mana"}
      
      _ ->
        {stats, "Unknown action"}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="starry-background chat-container starry-background min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <div class="container mx-auto px-4 py-8 relative z-10">
        <h1 class="text-4xl font-bold text-white mb-8 text-center">Unreal Experience</h1>
        
        <!-- Game Menu -->
        <div :if={@game_state == :menu} class="max-w-2xl mx-auto">
          <div class="bg-gray-900 rounded-lg p-8 text-center">
            <h2 class="text-3xl font-bold text-white mb-6">Welcome to the Adventure</h2>
            <p class="text-gray-300 mb-8">
              Embark on an epic journey in this Unreal Engine inspired experience. 
              Battle monsters, collect treasures, and chat with other players in real-time.
            </p>
            
            <div class="space-y-4">
              <button phx-click="start_game" 
                      class="w-full bg-blue-600 hover:bg-blue-700 text-white text-xl py-4 rounded-lg transition-colors">
                🎮 Start Adventure
              </button>
              
              <div class="grid grid-cols-2 gap-4">
                <button class="bg-gray-700 hover:bg-gray-600 text-white py-3 rounded-lg transition-colors">
                  📊 Leaderboard
                </button>
                <button class="bg-gray-700 hover:bg-gray-600 text-white py-3 rounded-lg transition-colors">
                  ⚙️ Settings
                </button>
              </div>
            </div>
            
            <!-- Game Preview -->
            <div class="mt-8 bg-gray-800 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Game Features</h3>
              <div class="grid grid-cols-2 gap-4 text-sm text-gray-300">
                <div>• Real-time multiplayer</div>
                <div>• Character progression</div>
                <div>• Combat system</div>
                <div>• Chat integration</div>
                <div>• Exploration</div>
                <div>• Treasure hunting</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Game Playing -->
        <div :if={@game_state == :playing} class="grid grid-cols-1 lg:grid-cols-4 gap-6">
          <!-- Game Viewport -->
          <div class="lg:col-span-3">
            <div class="bg-gray-900 rounded-lg p-4 mb-4">
              <!-- Game Controls -->
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-bold text-white">Adventure Mode</h2>
                <div class="flex space-x-2">
                  <button phx-click="pause_game" class="bg-yellow-600 hover:bg-yellow-700 text-white px-4 py-2 rounded transition-colors">
                    ⏸️ Pause
                  </button>
                  <button phx-click="quit_game" class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded transition-colors">
                    🚪 Quit
                  </button>
                </div>
              </div>
              
              <!-- Game Canvas/Viewport -->
              <div class="bg-gradient-to-b from-blue-900 to-green-900 rounded-lg h-96 relative overflow-hidden">
                <!-- Simulated 3D Environment -->
                <div class="absolute inset-0 flex items-center justify-center">
                  <div class="text-center text-white">
                    <div class="text-6xl mb-4">🏰</div>
                    <div class="text-xl font-bold mb-2">Fantasy Realm</div>
                    <div class="text-sm text-gray-300">Use the action buttons to interact with the world</div>
                  </div>
                </div>
                
                <!-- Player Avatar -->
                <div class="absolute bottom-4 left-1/2 transform -translate-x-1/2">
                  <div class="w-12 h-12 rounded-full flex items-center justify-center text-white text-xl"
                       style={"background-color: #{@user.avatar_color}"}>
                    🧙‍♂️
                  </div>
                </div>
                
                <!-- Environment Elements -->
                <div class="absolute top-4 left-4 text-4xl">🌲</div>
                <div class="absolute top-8 right-8 text-3xl">⛰️</div>
                <div class="absolute bottom-8 left-8 text-2xl">🗿</div>
                <div class="absolute top-1/2 right-4 text-3xl">🐉</div>
              </div>
              
              <!-- Action Buttons -->
              <div class="grid grid-cols-4 gap-2 mt-4">
                <button phx-click="player_action" phx-value-action="attack"
                        class="bg-red-600 hover:bg-red-700 text-white py-3 rounded transition-colors">
                  ⚔️ Attack
                </button>
                <button phx-click="player_action" phx-value-action="heal"
                        class="bg-green-600 hover:bg-green-700 text-white py-3 rounded transition-colors">
                  💚 Heal
                </button>
                <button phx-click="player_action" phx-value-action="explore"
                        class="bg-blue-600 hover:bg-blue-700 text-white py-3 rounded transition-colors">
                  🗺️ Explore
                </button>
                <button phx-click="player_action" phx-value-action="rest"
                        class="bg-purple-600 hover:bg-purple-700 text-white py-3 rounded transition-colors">
                  😴 Rest
                </button>
              </div>
            </div>
            
            <!-- Chat Integration -->
            <div class="bg-gray-800 rounded-lg p-4">
              <h3 class="text-lg font-semibold text-white mb-4">Game Chat</h3>
              
              <div class="h-32 overflow-y-auto mb-4 space-y-2">
                <%= for message <- Enum.reverse(@chat_messages) do %>
                  <div class="text-sm">
                    <span class="text-blue-400 font-medium"><%= message.user_name %>:</span>
                    <span class="text-gray-300"><%= message.content %></span>
                  </div>
                <% end %>
              </div>
              
              <form phx-submit="send_chat" class="flex space-x-2">
                <input type="text" name="message" value={@current_message}
                       phx-change="update_message"
                       placeholder="Chat with other players..."
                       class="flex-1 bg-gray-700 text-white px-3 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded transition-colors">
                  Send
                </button>
              </form>
            </div>
          </div>

          <!-- Game Sidebar -->
          <div class="lg:col-span-1 space-y-6">
            <!-- Player Stats -->
            <div class="bg-gray-800 rounded-lg p-4">
              <h3 class="text-lg font-semibold text-white mb-4">Player Stats</h3>
              
              <div class="space-y-3">
                <div>
                  <div class="flex justify-between text-sm">
                    <span class="text-gray-300">Level</span>
                    <span class="text-white font-bold"><%= @player_stats.level %></span>
                  </div>
                </div>
                
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span class="text-gray-300">Health</span>
                    <span class="text-red-400"><%= @player_stats.health %>/100</span>
                  </div>
                  <div class="w-full bg-gray-700 rounded-full h-2">
                    <div class="bg-red-500 h-2 rounded-full" style={"width: #{@player_stats.health}%"}></div>
                  </div>
                </div>
                
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span class="text-gray-300">Mana</span>
                    <span class="text-blue-400"><%= @player_stats.mana %>/50</span>
                  </div>
                  <div class="w-full bg-gray-700 rounded-full h-2">
                    <div class="bg-blue-500 h-2 rounded-full" style={"width: #{@player_stats.mana * 2}%"}></div>
                  </div>
                </div>
                
                <div>
                  <div class="flex justify-between text-sm">
                    <span class="text-gray-300">Experience</span>
                    <span class="text-yellow-400"><%= @player_stats.experience %></span>
                  </div>
                </div>
                
                <div>
                  <div class="flex justify-between text-sm">
                    <span class="text-gray-300">Coins</span>
                    <span class="text-yellow-400">💰 <%= @player_stats.coins %></span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Game Log -->
            <div class="bg-gray-800 rounded-lg p-4">
              <h3 class="text-lg font-semibold text-white mb-4">Game Log</h3>
              
              <div class="h-48 overflow-y-auto space-y-1">
                <%= for log_entry <- Enum.reverse(@game_log) do %>
                  <div class="text-sm text-gray-300"><%= log_entry %></div>
                <% end %>
              </div>
            </div>

            <!-- Quick Actions -->
            <div class="bg-gray-800 rounded-lg p-4">
              <h3 class="text-lg font-semibold text-white mb-4">Quick Actions</h3>
              
              <div class="space-y-2">
                <button class="w-full bg-gray-700 hover:bg-gray-600 text-white py-2 rounded transition-colors text-sm">
                  📦 Inventory
                </button>
                <button class="w-full bg-gray-700 hover:bg-gray-600 text-white py-2 rounded transition-colors text-sm">
                  🗺️ Map
                </button>
                <button class="w-full bg-gray-700 hover:bg-gray-600 text-white py-2 rounded transition-colors text-sm">
                  ⚙️ Settings
                </button>
                <button class="w-full bg-gray-700 hover:bg-gray-600 text-white py-2 rounded transition-colors text-sm">
                  📊 Stats
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Game Paused -->
        <div :if={@game_state == :paused} class="max-w-md mx-auto">
          <div class="bg-gray-900 rounded-lg p-8 text-center">
            <h2 class="text-2xl font-bold text-white mb-6">Game Paused</h2>
            <div class="space-y-4">
              <button phx-click="resume_game" 
                      class="w-full bg-green-600 hover:bg-green-700 text-white py-3 rounded-lg transition-colors">
                ▶️ Resume Game
              </button>
              <button phx-click="quit_game"
                      class="w-full bg-red-600 hover:bg-red-700 text-white py-3 rounded-lg transition-colors">
                🚪 Quit to Menu
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end