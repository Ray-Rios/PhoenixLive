defmodule PhoenixApp.Repo.Migrations.AddUserStatusAndAvatar do
  use Ecto.Migration
@disable_ddl_transaction true

  def change do
    alter table(:users) do
      add :status, :string, default: "active"
      add :avatar_url, :string
    end

    # Update existing users to be admins by default
    execute "UPDATE users SET is_admin = true WHERE is_admin = false"
  end
end