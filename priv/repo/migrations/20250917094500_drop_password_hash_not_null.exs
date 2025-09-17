defmodule PhoenixApp.Repo.Migrations.DropPasswordHashNotNull do
  use Ecto.Migration

  def up do
    alter table(:users) do
      modify :password_hash, :string, null: true
    end
  end

  def down do
    # Revert to NOT NULL if rolling back; this will fail if NULLs exist.
    alter table(:users) do
      modify :password_hash, :string, null: false
    end
  end
end
