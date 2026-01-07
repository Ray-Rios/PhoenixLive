defmodule PhoenixApp.Repo.Migrations.CreateTaskDependencies do
  use Ecto.Migration

  def change do
    create table(:task_dependencies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :depends_on_task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :dependency_type, :string, default: "finish-start" # simple support for types
      add :lag_seconds, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:task_dependencies, [:task_id])
    create index(:task_dependencies, [:depends_on_task_id])
    create unique_index(:task_dependencies, [:task_id, :depends_on_task_id], name: :unique_task_dependency)
  end
end
