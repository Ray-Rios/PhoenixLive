defmodule PhoenixApp.Repo.Migrations.CreateWindowLayouts do
  use Ecto.Migration

  def change do
    create table(:window_layouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :app, :string, null: false
      add :x, :integer, null: false, default: 100
      add :y, :integer, null: false, default: 100
      add :width, :integer, null: false, default: 800
      add :height, :integer, null: false, default: 600
      add :z_index, :integer, default: 1
      add :minimized, :boolean, default: false
      add :maximized, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:window_layouts, [:user_id, :app])
    create index(:window_layouts, [:user_id])
  end
end
