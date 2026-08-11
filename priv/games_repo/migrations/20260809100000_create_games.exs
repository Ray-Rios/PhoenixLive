defmodule PhoenixApp.GamesRepo.Migrations.CreateGames do
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

    execute(
      """
      INSERT INTO games (id, slug, name, is_active, inserted_at, updated_at)
      VALUES (gen_random_uuid(), 'rays-space-sim', 'RaysSpaceSim', true, NOW(), NOW())
      ON CONFLICT (slug) DO NOTHING
      """,
      "DELETE FROM games WHERE slug = 'rays-space-sim'"
    )
  end

  def down do
    drop_if_exists index(:games, [:slug])
    drop_if_exists table(:games)
  end
end
