defmodule PhoenixApp.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, :binary_id
      add :action, :string, null: false
      add :target_type, :string
      add :target_id, :binary_id
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:audit_logs, [:actor_id])
    create index(:audit_logs, [:target_type, :target_id])
  end
end
