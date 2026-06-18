defmodule PhoenixApp.Repo.Migrations.CreateGameCharacters do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:zones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :spawn_x, :float, null: false, default: 0.0
      add :spawn_y, :float, null: false, default: 0.0
      add :spawn_z, :float, null: false, default: 0.0
      add :spawn_heading, :float, null: false, default: 0.0
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:zones, [:name])
    create_if_not_exists unique_index(:zones, [:slug])

    execute(
      """
      INSERT INTO zones (id, name, slug, description, spawn_x, spawn_y, spawn_z, spawn_heading, inserted_at, updated_at)
      VALUES (
        gen_random_uuid(),
        'Lobby',
        'lobby',
        'Default spawn: a large 80s style arcade room.',
        0.0,
        0.0,
        0.0,
        0.0,
        NOW(),
        NOW()
      )
      ON CONFLICT (slug) DO NOTHING
      """,
      "DELETE FROM zones WHERE slug = 'lobby'"
    )

    create_if_not_exists table(:characters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :character_type, :string, null: false
      add :model_path, :string, null: false
      add :approved_at, :utc_datetime, null: false

      add :last_x, :float, null: false, default: 0.0
      add :last_y, :float, null: false, default: 0.0
      add :last_z, :float, null: false, default: 0.0
      add :last_heading, :float, null: false, default: 0.0

      add :last_zone_id, references(:zones, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:characters, [:name])
    create_if_not_exists index(:characters, [:user_id])
    create_if_not_exists index(:characters, [:last_zone_id])
    create_if_not_exists index(:characters, [:user_id, :inserted_at])
  end

  def down do
    drop_if_exists index(:characters, [:user_id, :inserted_at])
    drop_if_exists index(:characters, [:last_zone_id])
    drop_if_exists index(:characters, [:user_id])
    drop_if_exists index(:characters, [:name])
    drop_if_exists table(:characters)

    drop_if_exists index(:zones, [:slug])
    drop_if_exists index(:zones, [:name])
    drop_if_exists table(:zones)
  end
end