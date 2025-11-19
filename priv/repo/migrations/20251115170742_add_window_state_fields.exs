defmodule PhoenixApp.Repo.Migrations.AddWindowStateFields do
  use Ecto.Migration

  def change do
    alter table(:window_layouts) do
      add :current_path, :string
      add :view_mode, :string, default: "grid"
      add :breadcrumbs, :jsonb, default: "[]"
    end
  end
end
