defmodule PhoenixApp.GamesRepo.Migrations.CreateGameServers do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:game_servers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false

      # Identity. A dedicated server is addressed by host:port, so that pair
      # (scoped to a game) is the natural upsert key - a restarted server
      # re-registers into its own row rather than creating a duplicate.
      add :host, :string, null: false
      add :port, :integer, null: false

      add :name, :string, null: false
      add :region, :string, null: false, default: "unknown"

      # online | draining | offline
      #
      # Kept as a plain string rather than a Postgres enum so adding a state
      # later is a code change, not a migration with a table lock.
      add :status, :string, null: false, default: "online"

      add :current_players, :integer, null: false, default: 0
      add :max_players, :integer, null: false, default: 64

      # Which system/level this shard is hosting. Null means a lobby or a
      # server that hasn't reported one yet.
      add :map_name, :string

      # Build version. Clients on a different version must not be sent here.
      add :version, :string

      # Liveness. Servers crash without deregistering, so presence in this
      # table is not evidence a server is alive - only a recent heartbeat is.
      add :last_heartbeat_at, :utc_datetime, null: false

      # Free-form: tick rate, instance type, Holo-sim template id, etc.
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:game_servers, [:game_id, :host, :port])

    # The hot query is "online servers for this game, freshest first".
    create_if_not_exists index(:game_servers, [:game_id, :status, :last_heartbeat_at])
  end

  def down do
    drop_if_exists index(:game_servers, [:game_id, :status, :last_heartbeat_at])
    drop_if_exists index(:game_servers, [:game_id, :host, :port])
    drop_if_exists table(:game_servers)
  end
end
