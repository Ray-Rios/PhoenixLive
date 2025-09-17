defmodule PhoenixApp.Repo.Migrations.AddHashedPasswordToUsers do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS hashed_password text")
  end

  def down do
    execute("ALTER TABLE users DROP COLUMN IF EXISTS hashed_password")
  end
end
