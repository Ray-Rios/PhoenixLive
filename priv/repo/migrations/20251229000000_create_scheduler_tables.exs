defmodule PhoenixApp.Repo.Migrations.CreateSchedulerTables do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :owner_id, :binary_id
      add :status, :string, default: "active"
      add :start_date, :utc_datetime
      add :end_date, :utc_datetime
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:owner_id])

    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :assignee_id, :binary_id
      add :status, :string, default: "todo"
      add :percent_complete, :integer, default: 0
      add :duration_seconds, :integer
      add :start_at, :utc_datetime
      add :end_at, :utc_datetime
      add :earliest_start_at, :utc_datetime
      add :latest_finish_at, :utc_datetime
      add :lock_version, :integer, default: 1

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:project_id])
    create index(:tasks, [:assignee_id])
  end
end
