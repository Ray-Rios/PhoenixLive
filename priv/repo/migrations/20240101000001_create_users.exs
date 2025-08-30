defmodule PhoenixApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :confirmed_at, :utc_datetime
      add :avatar_shape, :string
      add :avatar_color, :string
      add :is_online, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end