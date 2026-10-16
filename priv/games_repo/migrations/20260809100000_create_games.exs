defmodule Phxlive.GamesRepo.Migrations.CreateGames do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\""

    create_if_not_exists table(:games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:games, [:slug])

    # No seeded game: each game's plugin registers its own row when it is
    # activated (Phxlive.Plugins.ensure_game/1). This used to insert one
    # specific title; databases that ran that version keep their row.
  end

  def down do
    drop_if_exists index(:games, [:slug])
    drop_if_exists table(:games)
  end
end
