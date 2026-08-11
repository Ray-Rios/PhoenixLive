defmodule PhoenixApp.Games do
  @moduledoc """
  Context for the multiplayer games platform (RaysSpaceSim and future titles).

  Backed by `PhoenixApp.GamesRepo`, a database isolated from the main site's
  `PhoenixApp.Repo`. Player identity (`user_id`) always comes from the main
  app's Guardian-authenticated `users` table; this context never touches
  passwords or emails.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.GamesRepo
  alias PhoenixApp.Games.{Game, GameCharacter, GameServer}

  @doc """
  Seconds without a heartbeat before a server is treated as gone.

  Deliberately several times the client's heartbeat interval. Set it too tight
  and one slow request drops a healthy, populated shard out of the browser.
  """
  def server_stale_after_seconds do
    Application.get_env(:phoenix_app, :game_server_stale_after_seconds, 90)
  end

  # ---------------------------------------------------------------------
  # Games
  # ---------------------------------------------------------------------

  def list_games do
    GamesRepo.all(Game)
  end

  def get_game_by_slug(slug) do
    GamesRepo.get_by(Game, slug: slug)
  end

  def get_game_by_slug!(slug) do
    GamesRepo.get_by!(Game, slug: slug)
  end

  def create_game(attrs) do
    %Game{}
    |> Game.changeset(attrs)
    |> GamesRepo.insert()
  end

  # ---------------------------------------------------------------------
  # Game Characters
  # ---------------------------------------------------------------------

  @doc "List all of a user's characters for a given game."
  def list_characters(game_id, user_id) do
    GameCharacter
    |> where([c], c.game_id == ^game_id and c.user_id == ^user_id)
    |> order_by([c], desc: c.last_played_at)
    |> GamesRepo.all()
  end

  def get_character(id), do: GamesRepo.get(GameCharacter, id)

  def get_character!(id), do: GamesRepo.get!(GameCharacter, id)

  @doc "Fetch a character, scoped to the owning user (prevents cross-account access)."
  def get_owned_character(game_id, user_id, character_id) do
    GameCharacter
    |> where([c], c.id == ^character_id and c.game_id == ^game_id and c.user_id == ^user_id)
    |> GamesRepo.one()
  end

  def create_character(attrs) do
    %GameCharacter{}
    |> GameCharacter.changeset(attrs)
    |> GamesRepo.insert()
  end

  @doc "Persist updated stats/settings, e.g. periodic checkpoint or on-disconnect save."
  def update_character(%GameCharacter{} = character, attrs) do
    character
    |> GameCharacter.changeset(attrs)
    |> GamesRepo.update()
  end

  def touch_character_last_played(%GameCharacter{} = character) do
    update_character(character, %{last_played_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  def delete_character(%GameCharacter{} = character) do
    GamesRepo.delete(character)
  end

  # ---------------------------------------------------------------------
  # Game Servers (shard registry)
  # ---------------------------------------------------------------------

  @doc """
  Upsert a dedicated server's registration from its heartbeat.

  Keyed on `{game_id, host, port}` so a server that restarts reclaims its own
  row instead of leaving a stale duplicate behind.
  """
  def register_server(attrs) do
    attrs =
      attrs
      |> Map.put("last_heartbeat_at", DateTime.utc_now() |> DateTime.truncate(:second))

    changeset = GameServer.changeset(%GameServer{}, attrs)

    # Only the volatile fields are refreshed on conflict. `inserted_at` and the
    # row id are left alone so a server keeps a stable identity across restarts.
    GamesRepo.insert(changeset,
      on_conflict:
        {:replace,
         [
           :name,
           :region,
           :status,
           :current_players,
           :max_players,
           :map_name,
           :version,
           :last_heartbeat_at,
           :metadata,
           :updated_at
         ]},
      conflict_target: [:game_id, :host, :port],
      returning: true
    )
  end

  @doc """
  Servers a player may join right now.

  Filters on a recent heartbeat rather than on `status` alone, because a
  crashed server leaves its last known status as `online` forever.

  Options:
    * `:region`          - restrict to one region
    * `:version`         - restrict to a build; clients on a different build
                           must not be offered a server they cannot join
    * `:include_full`    - default false
  """
  def list_available_servers(game_id, opts \\ []) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-server_stale_after_seconds(), :second)
      |> DateTime.truncate(:second)

    GameServer
    |> where([s], s.game_id == ^game_id)
    |> where([s], s.status == "online")
    |> where([s], s.last_heartbeat_at >= ^cutoff)
    |> maybe_filter(:region, opts[:region])
    |> maybe_filter(:version, opts[:version])
    |> maybe_exclude_full(Keyword.get(opts, :include_full, false))
    |> order_by([s], asc: s.current_players, asc: s.name)
    |> GamesRepo.all()
  end

  @doc """
  The single best server to drop a player into — least loaded that still has
  room. Returns nil when nothing is available, which callers must handle:
  "no servers online" is a normal state during a deploy, not an error.
  """
  def get_best_server(game_id, opts \\ []) do
    game_id
    |> list_available_servers(opts)
    |> List.first()
  end

  @doc "Every registered server for a game, including stale ones. For admin views."
  def list_all_servers(game_id) do
    GameServer
    |> where([s], s.game_id == ^game_id)
    |> order_by([s], asc: s.region, asc: s.name)
    |> GamesRepo.all()
  end

  def get_server(game_id, host, port) do
    GamesRepo.get_by(GameServer, game_id: game_id, host: host, port: port)
  end

  @doc "Graceful shutdown. Marks offline rather than deleting, so history survives."
  def mark_server_offline(game_id, host, port) do
    case get_server(game_id, host, port) do
      nil ->
        {:error, :not_found}

      server ->
        server
        |> GameServer.changeset(%{
          "status" => "offline",
          "current_players" => 0,
          "last_heartbeat_at" => DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> GamesRepo.update()
    end
  end

  @doc """
  Delete rows that have not reported in for a long time.

  Not required for correctness — `list_available_servers` already ignores
  them — but keeps an admin listing readable. Safe to run from a cron/scheduler.
  """
  def prune_stale_servers(older_than_seconds \\ 86_400) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-older_than_seconds, :second)
      |> DateTime.truncate(:second)

    {count, _} =
      GameServer
      |> where([s], s.last_heartbeat_at < ^cutoff)
      |> GamesRepo.delete_all()

    {:ok, count}
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, :region, region), do: where(query, [s], s.region == ^region)
  defp maybe_filter(query, :version, version), do: where(query, [s], s.version == ^version)

  defp maybe_exclude_full(query, true), do: query
  defp maybe_exclude_full(query, false), do: where(query, [s], s.current_players < s.max_players)
end
