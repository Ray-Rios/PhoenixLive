defmodule PhoenixApp.Game do
  @moduledoc """
  The Game context - manages game sessions, events, and player stats
  using the unified user system from Accounts.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Accounts.User
  alias PhoenixApp.Game.{GameSession, GameEvent, PlayerStats, WorldState, Session}

  # ---------------------
  # Game Sessions
  # ---------------------

  def list_game_sessions do
    Repo.all(GameSession) |> Repo.preload(:user)
  end

  def get_game_session!(id), do: Repo.get!(GameSession, id) |> Repo.preload(:user)

  def get_active_session_for_user(%User{} = user) do
    from(s in GameSession,
      where: s.user_id == ^user.id and s.is_active == true,
      order_by: [desc: s.last_heartbeat],
      limit: 1
    )
    |> Repo.one()
  end

  def create_game_session(%User{} = user, attrs \\ %{}) do
    # End any existing active sessions for this user
    end_active_sessions_for_user(user)

    # Create new session
    session_token = generate_session_token()
    
    attrs = Map.merge(attrs, %{
      user_id: user.id,
      session_token: session_token,
      last_heartbeat: DateTime.utc_now()
    })

    %GameSession{}
    |> GameSession.changeset(attrs)
    |> Repo.insert()
  end

  def update_game_session(%GameSession{} = session, attrs) do
    session
    |> GameSession.changeset(attrs)
    |> Repo.update()
  end

  def end_game_session(%GameSession{} = session) do
    update_game_session(session, %{is_active: false})
  end

  def heartbeat_session(%GameSession{} = session) do
    update_game_session(session, %{last_heartbeat: DateTime.utc_now()})
  end

  defp end_active_sessions_for_user(%User{} = user) do
    from(s in GameSession,
      where: s.user_id == ^user.id and s.is_active == true
    )
    |> Repo.update_all(set: [is_active: false])
  end

  defp generate_session_token do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  # ---------------------
  # Game Events
  # ---------------------

  def list_game_events do
    Repo.all(GameEvent) |> Repo.preload([:session, :player])
  end

  def get_game_event!(id), do: Repo.get!(GameEvent, id) |> Repo.preload([:session, :player])

  def create_game_event(%GameSession{} = session, %User{} = player, attrs) do
    attrs = Map.merge(attrs, %{
      session_id: session.id,
      player_id: player.id,
      server_timestamp: DateTime.utc_now()
    })

    %GameEvent{}
    |> GameEvent.changeset(attrs)
    |> Repo.insert()
  end

  def mark_event_processed(%GameEvent{} = event) do
    event
    |> GameEvent.changeset(%{processed: true})
    |> Repo.update()
  end

  def get_unprocessed_events do
    from(e in GameEvent,
      where: e.processed == false,
      order_by: [asc: e.server_timestamp]
    )
    |> Repo.all()
    |> Repo.preload([:session, :player])
  end

  # ---------------------
  # Player Stats
  # ---------------------

  def list_player_stats do
    Repo.all(PlayerStats) |> Repo.preload(:user)
  end

  def get_player_stats!(%User{} = user) do
    case Repo.get_by(PlayerStats, user_id: user.id) do
      nil -> create_player_stats(user)
      stats -> {:ok, stats |> Repo.preload(:user)}
    end
  end

  def get_or_create_player_stats(%User{} = user) do
    case get_player_stats!(user) do
      {:ok, stats} -> stats
      stats -> stats
    end
  end

  def create_player_stats(%User{} = user, attrs \\ %{}) do
    attrs = Map.put(attrs, :user_id, user.id)

    %PlayerStats{}
    |> PlayerStats.changeset(attrs)
    |> Repo.insert()
  end

  def update_player_stats(%PlayerStats{} = stats, attrs) do
    stats
    |> PlayerStats.changeset(attrs)
    |> Repo.update()
  end

  def add_score(%User{} = user, points) when is_integer(points) do
    stats = get_or_create_player_stats(user)
    
    update_player_stats(stats, %{
      total_score: stats.total_score + points
    })
  end

  def add_playtime(%User{} = user, minutes) when is_integer(minutes) do
    stats = get_or_create_player_stats(user)
    
    update_player_stats(stats, %{
      total_playtime: stats.total_playtime + minutes,
      games_played: stats.games_played + 1
    })
  end

  def update_level(%User{} = user, new_level) when is_integer(new_level) do
    stats = get_or_create_player_stats(user)
    
    highest_level = max(stats.highest_level, new_level)
    
    update_player_stats(stats, %{
      highest_level: highest_level
    })
  end

  # ---------------------
  # World State
  # ---------------------

  def list_world_objects(world_id) do
    from(w in WorldState,
      where: w.world_id == ^world_id and w.is_active == true
    )
    |> Repo.all()
  end

  def get_world_object!(world_id, object_id) do
    Repo.get_by!(WorldState, world_id: world_id, object_id: object_id)
  end

  def create_world_object(attrs) do
    %WorldState{}
    |> WorldState.changeset(attrs)
    |> Repo.insert()
  end

  def update_world_object(%WorldState{} = object, attrs) do
    object
    |> WorldState.changeset(attrs)
    |> Repo.update()
  end

  def delete_world_object(%WorldState{} = object) do
    update_world_object(object, %{is_active: false})
  end

  # ---------------------
  # Game Statistics
  # ---------------------

  def get_game_stats do
    %{
      total_sessions: Repo.aggregate(GameSession, :count, :id),
      active_sessions: Repo.aggregate(from(s in GameSession, where: s.is_active == true), :count, :id),
      total_events: Repo.aggregate(GameEvent, :count, :id),
      unprocessed_events: Repo.aggregate(from(e in GameEvent, where: e.processed == false), :count, :id),
      total_players: Repo.aggregate(PlayerStats, :count, :id)
    }
  end

  def get_leaderboard(limit \\ 10) do
    from(p in PlayerStats,
      join: u in User, on: p.user_id == u.id,
      order_by: [desc: p.total_score],
      limit: ^limit,
      select: %{
        user_name: u.name,
        total_score: p.total_score,
        highest_level: p.highest_level,
        games_played: p.games_played
      }
    )
    |> Repo.all()
  end

  # ---------------------
  # API Sessions (for Rust API migration)
  # ---------------------

  @doc """
  Creates a new API session for the Rust API migration.
  """
  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a session by ID.
  """
  def get_session(id) do
    Repo.get(Session, id)
  end

  @doc """
  Gets a session by ID, raising if not found.
  """
  def get_session!(id) do
    Repo.get!(Session, id)
  end

  @doc """
  Updates a session.
  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end
end