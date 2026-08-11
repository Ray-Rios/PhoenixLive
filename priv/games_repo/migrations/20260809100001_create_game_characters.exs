defmodule PhoenixApp.GamesRepo.Migrations.CreateGameCharacters do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:game_characters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false

      # References PhoenixApp.Repo's users.id - no FK constraint possible cross-database
      add :user_id, :binary_id, null: false

      add :name, :string, null: false
      add :stats, :map, null: false, default: %{}
      add :settings, :map, null: false, default: %{}
      add :last_played_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:game_characters, [:game_id, :user_id, :name])
    create_if_not_exists index(:game_characters, [:game_id, :user_id])
  end

  def down do
    drop_if_exists index(:game_characters, [:game_id, :user_id])
    drop_if_exists index(:game_characters, [:game_id, :user_id, :name])
    drop_if_exists table(:game_characters)
  end
end
