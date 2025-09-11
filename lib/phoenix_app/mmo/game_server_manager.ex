defmodule PhoenixApp.MMO.GameServerManager do
  @moduledoc """
  Manages multiple game servers with Redis coordination
  Essential for MMO scaling
  """
  
  use GenServer
  alias PhoenixApp.MMO.RedisCache
  alias Phoenix.PubSub
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    server_id = generate_server_id()
    
    # Register this server in Redis
    RedisCache.register_game_server(server_id, 1000)
    
    # Subscribe to cross-server events
    RedisCache.subscribe_to_chat("chat:global")
    RedisCache.subscribe_to_chat("server:events")
    
    # Start heartbeat timer
    :timer.send_interval(10_000, :heartbeat)
    
    {:ok, %{
      server_id: server_id,
      connected_players: %{},
      last_heartbeat: System.system_time(:millisecond)
    }}
  end
  
  # Player joins this server
  def handle_call({:player_join, player_id, session_data}, _from, state) do
    # Store session in Redis for cross-server access
    RedisCache.set_player_session(session_data.session_id, %{
      player_id: player_id,
      server_id: state.server_id,
      joined_at: System.system_time(:millisecond),
      world_zone: session_data.world_zone || "default"
    })
    
    # Update local state
    new_players = Map.put(state.connected_players, player_id, session_data)
    
    # Broadcast to other servers
    PubSub.broadcast(PhoenixApp.PubSub, "mmo:servers", {
      :player_joined, 
      %{player_id: player_id, server_id: state.server_id}
    })
    
    {:reply, :ok, %{state | connected_players: new_players}}
  end
  
  # Player position update
  def handle_call({:update_position, player_id, x, y, z}, _from, state) do
    # Store in Redis for cross-server queries
    RedisCache.set_player_position(player_id, x, y, z)
    
    # Update local cache
    if player_data = state.connected_players[player_id] do
      updated_data = %{player_data | x: x, y: y, z: z}
      new_players = Map.put(state.connected_players, player_id, updated_data)
      
      {:reply, :ok, %{state | connected_players: new_players}}
    else
      {:reply, {:error, :player_not_found}, state}
    end
  end
  
  # Get nearby players (cross-server)
  def handle_call({:get_nearby_players, x, y, radius}, _from, state) do
    nearby = RedisCache.get_nearby_players(x, y, radius)
    {:reply, nearby, state}
  end
  
  # Server heartbeat
  def handle_info(:heartbeat, state) do
    player_count = map_size(state.connected_players)
    capacity = max(0, 1000 - player_count)
    
    # Update server status in Redis
    RedisCache.register_game_server(state.server_id, capacity)
    
    # Broadcast server stats
    PubSub.broadcast(PhoenixApp.PubSub, "mmo:servers", {
      :server_heartbeat,
      %{
        server_id: state.server_id,
        player_count: player_count,
        capacity: capacity,
        timestamp: System.system_time(:millisecond)
      }
    })
    
    {:noreply, %{state | last_heartbeat: System.system_time(:millisecond)}}
  end
  
  # Handle Redis pub/sub messages
  def handle_info({:redix_pubsub, _pid, _ref, :message, {"chat:global", message}}, state) do
    case Jason.decode(message) do
      {:ok, chat_data} ->
        # Broadcast to local players
        PubSub.broadcast(PhoenixApp.PubSub, "game:chat", {
          :global_message, chat_data
        })
      _ -> :ok
    end
    
    {:noreply, state}
  end
  
  # Public API
  def player_join(player_id, session_data) do
    GenServer.call(__MODULE__, {:player_join, player_id, session_data})
  end
  
  def update_position(player_id, x, y, z) do
    GenServer.call(__MODULE__, {:update_position, player_id, x, y, z})
  end
  
  def get_nearby_players(x, y, radius \\ 1000) do
    GenServer.call(__MODULE__, {:get_nearby_players, x, y, radius})
  end
  
  def send_global_chat(player_name, message) do
    RedisCache.publish_global_chat(player_name, message)
  end
  
  defp generate_server_id do
    "server_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
  end
end