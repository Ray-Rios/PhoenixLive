defmodule PhoenixApp.Repo.Migrations.CreateGameTables do
  use Ecto.Migration

  def change do
    # Game sessions table
    create table(:game_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :session_token, :text, null: false
      add :player_x, :float, default: 0.0
      add :player_y, :float, default: 0.0
      add :player_z, :float, default: 0.0
      add :rotation_x, :float, default: 0.0
      add :rotation_y, :float, default: 0.0
      add :rotation_z, :float, default: 0.0
      add :health, :integer, default: 100
      add :score, :integer, default: 0
      add :level, :integer, default: 1
      add :experience, :integer, default: 0
      add :is_active, :boolean, default: true
      add :last_heartbeat, :utc_datetime_usec, default: fragment("NOW()")

      timestamps(type: :utc_datetime_usec)
    end

    # Game events table for logging all game actions
    create table(:game_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:game_sessions, type: :binary_id, on_delete: :delete_all)
      add :player_id, :binary_id
      add :event_type, :text, null: false
      add :event_data, :map
      add :server_timestamp, :utc_datetime_usec, default: fragment("NOW()")
      add :client_timestamp, :utc_datetime_usec
      add :processed, :boolean, default: false
    end

    # Player stats table for persistent data
    create table(:player_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :total_score, :integer, default: 0
      add :total_playtime, :integer, default: 0
      add :games_played, :integer, default: 0
      add :highest_level, :integer, default: 1
      add :achievements, :map, default: %{}
      add :preferences, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # Game world state for persistent world elements
    create table(:world_state, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :world_id, :text, null: false
      add :object_id, :text, null: false
      add :object_type, :text, null: false
      add :position, :map, null: false
      add :rotation, :map, default: %{"x" => 0, "y" => 0, "z" => 0}
      add :scale, :map, default: %{"x" => 1, "y" => 1, "z" => 1}
      add :properties, :map, default: %{}
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime_usec)
    end

    # Create unique constraints
    create unique_index(:game_sessions, [:session_token])
    create unique_index(:player_stats, [:user_id])
    create unique_index(:world_state, [:world_id, :object_id])

    # Create indexes for performance
    create index(:game_sessions, [:user_id])
    create index(:game_sessions, [:is_active], where: "is_active = true")
    create index(:game_sessions, [:last_heartbeat])

    create index(:game_events, [:session_id])
    create index(:game_events, [:player_id])
    create index(:game_events, [:event_type])
    create index(:game_events, [:server_timestamp])
    create index(:game_events, [:processed], where: "processed = false")

    create index(:player_stats, [:user_id])
    create index(:player_stats, [:total_score])

    create index(:world_state, [:world_id])
    create index(:world_state, [:is_active], where: "is_active = true")
  end
end