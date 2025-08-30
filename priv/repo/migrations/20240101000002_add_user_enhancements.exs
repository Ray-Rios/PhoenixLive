defmodule PhoenixApp.Repo.Migrations.AddUserEnhancements do
  use Ecto.Migration
@disable_ddl_transaction true

  def change do
    alter table(:users) do
      add :name, :string
      add :avatar_file, :string
      add :is_admin, :boolean, default: false
      add :two_factor_secret, :string
      add :two_factor_enabled, :boolean, default: false
      add :two_factor_backup_codes, {:array, :string}, default: []
      add :position_x, :float, default: 400.0
      add :position_y, :float, default: 300.0
      add :last_activity, :utc_datetime
    end

    create index(:users, [:is_admin])
    create index(:users, [:two_factor_enabled])
  end
end