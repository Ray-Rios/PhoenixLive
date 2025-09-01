defmodule PhoenixApp.GameEngine do
  use GenServer
  require Logger

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_game_session(live_view_pid) do
    GenServer.call(__MODULE__, {:start_session, live_view_pid})
  end

  def get_session_pid(live_view_pid) do
    GenServer.call(__MODULE__, {:get_session, live_view_pid})
  end

  def get_game_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def spawn_entity(type, x, y, opts \\ %{}) do
    GenServer.cast(__MODULE__, {:spawn_entity, type, x, y, opts})
  end

  def update_player_position(player_id, x, y) do
    GenServer.cast(__MODULE__, {:update_player, player_id, x, y})
  end

  # Server Callbacks
  @impl true
  def init(_opts) do
    # Schedule periodic updates
    :timer.send_interval(100, :game_tick)
    
    state = %{
      entities: [],
      players: %{},
      sessions: %{},
      tick_count: 0
    }
    
    Logger.info("GameEngine started")
    {:ok, state}
  end

  @impl true
  def handle_call({:start_session, live_view_pid}, _from, state) do
    session_id = generate_id()
    {:ok, session_pid} = PhoenixApp.GameSession.start_link(session_id, live_view_pid)
    
    new_sessions = Map.put(state.sessions, live_view_pid, session_pid)
    
    {:reply, {:ok, session_pid}, %{state | sessions: new_sessions}}
  end

  @impl true
  def handle_call({:get_session, live_view_pid}, _from, state) do
    session_pid = Map.get(state.sessions, live_view_pid)
    {:reply, session_pid, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:spawn_entity, type, x, y, opts}, state) do
    entity = create_entity(type, x, y, opts)
    new_entities = [entity | state.entities]
    
    # Broadcast to all connected clients
    Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "game:updates", 
      {:entity_spawned, entity})
    
    {:noreply, %{state | entities: new_entities}}
  end

  @impl true
  def handle_cast({:update_player, player_id, x, y}, state) do
    updated_players = Map.put(state.players, player_id, %{x: x, y: y, last_update: System.system_time(:millisecond)})
    
    Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "game:updates", 
      {:player_moved, player_id, x, y})
    
    {:noreply, %{state | players: updated_players}}
  end

  @impl true
  def handle_info(:game_tick, state) do
    # Update game logic
    updated_entities = update_entities(state.entities)
    
    # Spawn new entities occasionally
    new_entities = maybe_spawn_entities(updated_entities, state.tick_count)
    
    # Broadcast game state to all sessions
    Enum.each(state.sessions, fn {_live_view_pid, session_pid} ->
      if Process.alive?(session_pid) do
        send(session_pid, {:game_update, new_entities})
      end
    end)
    
    {:noreply, %{state | entities: new_entities, tick_count: state.tick_count + 1}}
  end

  # Private functions
  defp create_entity(type, x, y, opts) do
    base_entity = %{
      id: generate_id(),
      type: type,
      x: x,
      y: y,
      created_at: System.system_time(:millisecond)
    }
    
    case type do
      :alien ->
        Map.merge(base_entity, %{
          health: 100,
          speed: Enum.random(1..3),
          direction: :rand.uniform() * 2 * :math.pi(),
          behavior: :patrol,
          faction: :alien
        })
      
      :spaceship ->
        Map.merge(base_entity, %{
          health: 150,
          speed: Enum.random(2..4),
          direction: :rand.uniform() * 2 * :math.pi(),
          behavior: :combat,
          faction: Enum.random([:rebel, :empire])
        })
      
      :rocket ->
        Map.merge(base_entity, %{
          health: 50,
          speed: Enum.random(5..8),
          direction: opts[:direction] || 0,
          behavior: :projectile,
          owner: opts[:owner],
          lifetime: 3000 # 3 seconds
        })
      
      _ ->
        base_entity
    end
  end

  defp update_entities(entities) do
    current_time = System.system_time(:millisecond)
    
    entities
    |> Enum.map(&update_entity(&1, current_time))
    |> Enum.filter(&entity_alive?(&1, current_time))
  end

  defp update_entity(entity, current_time) do
    case entity.type do
      :alien ->
        update_alien(entity, current_time)
      
      :spaceship ->
        update_spaceship(entity, current_time)
      
      :rocket ->
        update_rocket(entity, current_time)
      
      _ ->
        entity
    end
  end

  defp update_alien(alien, _current_time) do
    # Simple movement
    new_x = alien.x + :math.cos(alien.direction) * alien.speed
    new_y = alien.y + :math.sin(alien.direction) * alien.speed
    
    # Wrap around screen (assuming 800x600 for now)
    wrapped_x = wrap_coordinate(new_x, 800)
    wrapped_y = wrap_coordinate(new_y, 600)
    
    # Change direction occasionally
    new_direction = if :rand.uniform() < 0.02 do
      :rand.uniform() * 2 * :math.pi()
    else
      alien.direction
    end
    
    %{alien | x: wrapped_x, y: wrapped_y, direction: new_direction}
  end

  defp update_spaceship(spaceship, _current_time) do
    # Similar to alien but with combat behavior
    new_x = spaceship.x + :math.cos(spaceship.direction) * spaceship.speed
    new_y = spaceship.y + :math.sin(spaceship.direction) * spaceship.speed
    
    wrapped_x = wrap_coordinate(new_x, 800)
    wrapped_y = wrap_coordinate(new_y, 600)
    
    %{spaceship | x: wrapped_x, y: wrapped_y}
  end

  defp update_rocket(rocket, current_time) do
    # Move rocket
    new_x = rocket.x + :math.cos(rocket.direction) * rocket.speed
    new_y = rocket.y + :math.sin(rocket.direction) * rocket.speed
    
    %{rocket | x: new_x, y: new_y}
  end

  defp entity_alive?(entity, current_time) do
    case entity.type do
      :rocket ->
        current_time - entity.created_at < entity.lifetime
      _ ->
        entity.health > 0
    end
  end

  defp wrap_coordinate(coord, max) do
    cond do
      coord < 0 -> max + coord
      coord > max -> coord - max
      true -> coord
    end
  end

  defp maybe_spawn_entities(entities, tick_count) do
    # Spawn new entities every 50 ticks (5 seconds) if we have fewer than 10
    if rem(tick_count, 50) == 0 and length(entities) < 10 do
      entity_type = Enum.random([:alien, :spaceship])
      x = :rand.uniform() * 800
      y = :rand.uniform() * 400 # Keep in upper area
      
      new_entity = create_entity(entity_type, x, y, %{})
      [new_entity | entities]
    else
      entities
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
end

defmodule PhoenixApp.GameSession do
  use GenServer

  def start_link(session_id, live_view_pid) do
    GenServer.start_link(__MODULE__, {session_id, live_view_pid})
  end

  @impl true
  def init({session_id, live_view_pid}) do
    state = %{
      session_id: session_id,
      live_view_pid: live_view_pid,
      entities: []
    }
    
    {:ok, state}
  end

  @impl true
  def handle_info({:game_update, entities}, state) do
    # Send update to LiveView
    send(state.live_view_pid, {:game_update, entities})
    {:noreply, %{state | entities: entities}}
  end
end