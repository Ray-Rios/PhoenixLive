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
  alias PhoenixApp.Games.{AdminAction, Game, GameCharacter, GameServer, ServerCommand}

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
           :roster,
           :holo_sim_id,
           :launched_by_user_id,
           :updated_at
         ]},
      conflict_target: [:game_id, :host, :port],
      returning: true
    )
  end

  # ---------------------------------------------------------------------
  # Holo-sim instances
  # ---------------------------------------------------------------------

  @doc """
  The live instance running this sim, if there is one.

  Keyed on the SIM, not on a player. Public sims are joined by many people at
  once, so an instance belongs to the world it is running - whoever opened the
  door first is attribution, not ownership.

  This is what makes a second player joining an existing sim work, and what lets
  the owner walk out and back in without spawning a second pod.

  Filters on heartbeat freshness: a crashed pod leaves its row behind and would
  otherwise make a sim permanently unlaunchable.
  """
  def get_instance_for_sim(game_id, holo_sim_id) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-server_stale_after_seconds(), :second)
      |> DateTime.truncate(:second)

    GameServer
    |> where([s], s.game_id == ^game_id and s.holo_sim_id == ^holo_sim_id)
    |> where([s], s.status in ["online", "draining"])
    |> where([s], s.last_heartbeat_at >= ^cutoff)
    |> order_by([s], desc: s.last_heartbeat_at)
    |> limit(1)
    |> GamesRepo.one()
  end

  @doc """
  World servers only - instances are excluded from the public browser.

  Without this an instance would show up as a joinable shard in the character
  select screen, and a player could sidestep the whole access check by picking
  someone else's pod out of a list.
  """
  def list_world_servers(game_id, opts \\ []) do
    game_id
    |> list_available_servers(opts)
    |> Enum.filter(&is_nil(&1.holo_sim_id))
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

  @doc """
  Flip stale `online` rows to `offline`.

  The softer half of `prune_stale_servers/1`, and the one an admin screen wants:
  deleting a crashed instance makes it vanish with no explanation, which is
  indistinguishable from it never having existed. Marking it offline leaves the
  row, its last heartbeat and its final roster visible until pruning eventually
  clears it.

  Returns the number of rows changed.
  """
  def mark_stale_servers_offline(stale_after_seconds \\ nil) do
    seconds = stale_after_seconds || server_stale_after_seconds()

    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-seconds, :second)
      |> DateTime.truncate(:second)

    {count, _} =
      GameServer
      |> where([s], s.status in ["online", "draining"])
      |> where([s], s.last_heartbeat_at < ^cutoff)
      |> GamesRepo.update_all(set: [status: "offline", current_players: 0])

    {:ok, count}
  end

  # ---------------------------------------------------------------------
  # Admin operations
  #
  # Everything below is read or written by the /admin section, never by a
  # player. The command functions are the exception that proves it: they are
  # written by an admin and READ by a server, on its own heartbeat.
  # ---------------------------------------------------------------------

  @doc """
  Every server for a game, freshest first, regardless of status.

  Deliberately unfiltered - the whole point of the admin view is to see the
  offline and stale ones, which every player-facing query hides.
  """
  def list_servers_for_admin(game_id) do
    GameServer
    |> where([s], s.game_id == ^game_id)
    |> order_by([s], desc: s.last_heartbeat_at)
    |> GamesRepo.all()
  end

  @doc """
  True if this server's last heartbeat is too old to believe.

  The single place that judgement is made, so the admin list, the reaper and
  the instance lookup cannot disagree about what "alive" means.
  """
  def server_stale?(%GameServer{last_heartbeat_at: nil}), do: true

  def server_stale?(%GameServer{last_heartbeat_at: at}) do
    DateTime.diff(DateTime.utc_now(), at, :second) > server_stale_after_seconds()
  end

  @doc """
  The players a server reported on its last heartbeat.

  Returns `[]` for a server that has never reported one, so callers do not have
  to distinguish "empty" from "old build that does not send a roster".
  """
  def server_players(%GameServer{roster: %{"players" => players}}) when is_list(players), do: players
  def server_players(%GameServer{}), do: []

  @doc """
  Which server a user is currently on, if any.

  Answers "where is this player right now" - the question a count cannot.
  Containment against the jsonb roster, which the GIN index on that column
  turns into a lookup rather than a scan across every instance.

  Stale servers are excluded: a roster from a pod that died is a memory, not a
  location.
  """
  def find_player_server(game_id, user_id) when is_binary(user_id) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-server_stale_after_seconds(), :second)
      |> DateTime.truncate(:second)

    GameServer
    |> where([s], s.game_id == ^game_id)
    |> where([s], s.last_heartbeat_at >= ^cutoff)
    |> where(
      [s],
      fragment("? @> ?", s.roster, ^%{"players" => [%{"user_id" => user_id}]})
    )
    |> limit(1)
    |> GamesRepo.one()
  end

  @doc """
  Queue a command for a server. It is delivered on that server's next heartbeat.

  Not delivered here, and deliberately not awaited: the hub cannot reach into an
  instance, so "issued" is the strongest thing this can honestly report. The
  caller should surface `delivered_at` rather than implying the button worked.
  """
  def queue_server_command(server_id, command, payload \\ %{}, issued_by_user_id \\ nil) do
    %ServerCommand{}
    |> ServerCommand.changeset(%{
      "server_id" => server_id,
      "command" => command,
      "payload" => payload,
      "issued_by_user_id" => issued_by_user_id,
      "issued_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> GamesRepo.insert()
  end

  @doc """
  Hand a server its undelivered commands and mark them delivered.

  AT-MOST-ONCE, on purpose. The alternative is holding them until the server
  acknowledges, which turns a missed response into a command that runs twice -
  and "kick" and "shutdown" are both considerably worse when repeated than when
  dropped. An admin can press the button again; they cannot un-kick anyone.

  Read and mark happen in one transaction so two overlapping heartbeats from a
  restarting server cannot both collect the same instruction.
  """
  def take_pending_commands(server_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    GamesRepo.transaction(fn ->
      commands =
        ServerCommand
        |> where([c], c.server_id == ^server_id and is_nil(c.delivered_at))
        |> order_by([c], asc: c.issued_at)
        |> lock("FOR UPDATE SKIP LOCKED")
        |> GamesRepo.all()

      ids = Enum.map(commands, & &1.id)

      if ids != [] do
        ServerCommand
        |> where([c], c.id in ^ids)
        |> GamesRepo.update_all(set: [delivered_at: now, updated_at: now])
      end

      commands
    end)
  end

  @doc "Commands issued to a server, newest first. For the admin detail view."
  def list_server_commands(server_id, limit \\ 25) do
    ServerCommand
    |> where([c], c.server_id == ^server_id)
    |> order_by([c], desc: c.issued_at)
    |> limit(^limit)
    |> GamesRepo.all()
  end

  @doc "Record a privileged action. Never fails the operation it describes."
  def log_admin_action(attrs) do
    %AdminAction{}
    |> AdminAction.changeset(attrs)
    |> GamesRepo.insert()
  end

  @doc "Recent admin actions, newest first."
  def list_admin_actions(limit \\ 50) do
    AdminAction
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> GamesRepo.all()
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, :region, region), do: where(query, [s], s.region == ^region)
  defp maybe_filter(query, :version, version), do: where(query, [s], s.version == ^version)

  defp maybe_exclude_full(query, true), do: query
  defp maybe_exclude_full(query, false), do: where(query, [s], s.current_players < s.max_players)
end
