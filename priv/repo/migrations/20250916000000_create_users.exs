defmodule PhoenixApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
  execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
  # Canonical users table: include password_hash as the canonical column.
  create_if_not_exists table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :string, null: false
      add :name, :string
      # Keep legacy `hashed_password` for backwards-compatibility during upgrades,
      # but prefer `password_hash` as the canonical column used by the app.
      add :hashed_password, :text
      add :password_hash, :text
      add :confirmed_at, :utc_datetime
      add :avatar_shape, :string, default: "circle"
      add :avatar_color, :string, default: "#3B82F6"
      add :avatar_url, :string
      add :is_online, :boolean, default: false
      add :is_admin, :boolean, default: true
      add :status, :string, default: "active"
      add :role, :string, default: "subscriber"
      add :two_factor_secret, :string
      add :two_factor_enabled, :boolean, default: false
      add :two_factor_backup_codes, {:array, :string}, default: []
      add :position_x, :float, default: 400.0
      add :position_y, :float, default: 300.0
      add :last_activity, :utc_datetime

      timestamps()
    end

  create_if_not_exists unique_index(:users, [:email])

  # Backfill any missing canonical password_hash from legacy hashed_password and
  # then remove the legacy column. This is idempotent: it only copies when
  # password_hash IS NULL and hashed_password IS NOT NULL.
  execute("UPDATE users SET password_hash = hashed_password WHERE password_hash IS NULL AND hashed_password IS NOT NULL;")
  execute("ALTER TABLE users DROP COLUMN IF EXISTS hashed_password;")
  end
end
