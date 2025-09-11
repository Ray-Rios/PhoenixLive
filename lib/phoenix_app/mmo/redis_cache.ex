defmodule PhoenixApp.MMO.RedisCache do
  @moduledoc """
  Redis caching layer for MMO game state
  Critical for scaling beyond single server
  """
  
  @redis_name :redix
  
  # Player state management
  def set_player_position(player_id, x, y, z) do
    timestamp = System.system_time(:millisecond)
    
    # Store position with timestamp
    Redix.command(@redis_name, [
      "HSET", "player:#{player_id}:state",
      "x", x, "y", y, "z", z, 
      "last_update", timestamp
    ])
    
    # Add to geospatial index for proximity queries
    Redix.command(@redis_name, [
      "GEOADD", "world:positions", x, y, "player:#{player_id}"
    ])
  end
  
  def get_nearby_players(x, y, radius_meters \\ 1000) do
    case Redix.command(@redis_name, [
      "GEORADIUS", "world:positions", x, y, radius_meters, "m", 
      "WITHCOORD", "WITHDIST", "COUNT", 50
    ]) do
      {:ok, results} -> 
        Enum.map(results, fn [player_key, distance, [px, py]] ->
          player_id = String.replace(player_key, "player:", "")
          %{
            player_id: player_id,
            x: String.to_float(px),
            y: String.to_float(py),
            distance: String.to_float(distance)
          }
        end)
      _ -> []
    end
  end
  
  # Session management across servers
  def set_player_session(session_id, player_data) do
    Redix.command(@redis_name, [
      "SETEX", "session:#{session_id}", 3600,
      Jason.encode!(player_data)
    ])
  end
  
  def get_player_session(session_id) do
    case Redix.command(@redis_name, ["GET", "session:#{session_id}"]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, data} -> {:ok, Jason.decode!(data)}
      error -> error
    end
  end
  
  # Cross-server messaging
  def publish_global_chat(player_name, message) do
    Redix.command(@redis_name, [
      "PUBLISH", "chat:global",
      Jason.encode!(%{
        player: player_name,
        message: message,
        timestamp: System.system_time(:millisecond)
      })
    ])
  end
  
  def subscribe_to_chat(channel \\ "chat:global") do
    Redix.PubSub.subscribe(@redis_name, [channel], self())
  end
  
  # Leaderboards
  def update_leaderboard(category, player_id, score) do
    Redix.command(@redis_name, [
      "ZADD", "leaderboard:#{category}", score, player_id
    ])
  end
  
  def get_leaderboard(category, limit \\ 100) do
    case Redix.command(@redis_name, [
      "ZREVRANGE", "leaderboard:#{category}", 0, limit - 1, "WITHSCORES"
    ]) do
      {:ok, results} ->
        results
        |> Enum.chunk_every(2)
        |> Enum.map(fn [player_id, score] ->
          %{player_id: player_id, score: String.to_integer(score)}
        end)
      _ -> []
    end
  end
  
  # World state
  def set_world_event(event_id, event_data, ttl_seconds \\ 1800) do
    Redix.command(@redis_name, [
      "SETEX", "world:event:#{event_id}", ttl_seconds,
      Jason.encode!(event_data)
    ])
  end
  
  def get_world_event(event_id) do
    case Redix.command(@redis_name, ["GET", "world:event:#{event_id}"]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, data} -> {:ok, Jason.decode!(data)}
      error -> error
    end
  end
  
  # Server load balancing
  def register_game_server(server_id, capacity \\ 1000) do
    Redix.command(@redis_name, [
      "HSET", "servers:active", server_id, capacity
    ])
    
    # Set TTL for server heartbeat
    Redix.command(@redis_name, [
      "EXPIRE", "server:#{server_id}:heartbeat", 30
    ])
  end
  
  def get_least_loaded_server do
    case Redix.command(@redis_name, ["HGETALL", "servers:active"]) do
      {:ok, [_ | _] = servers} ->
        servers
        |> Enum.chunk_every(2)
        |> Enum.map(fn [server_id, capacity] -> 
          {server_id, String.to_integer(capacity)} 
        end)
        |> Enum.max_by(fn {_server, capacity} -> capacity end)
        |> elem(0)
      _ -> nil
    end
  end
end