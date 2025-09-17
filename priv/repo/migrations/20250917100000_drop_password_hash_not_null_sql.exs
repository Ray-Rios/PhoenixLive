defmodule PhoenixApp.Repo.Migrations.DropPasswordHashNotNullSql do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;")
  end

  def down do
    # Re-add NOT NULL constraint; will fail if NULL values exist.
    execute("ALTER TABLE users ALTER COLUMN password_hash SET NOT NULL;")
  end
end
