defmodule PhoenixApp.Repo.Migrations.CreateSuspiciousRequests do
  use Ecto.Migration

  def change do
    create table(:suspicious_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ip_address, :string, null: false
      add :path, :string, null: false
      add :method, :string, null: false
      add :user_agent, :text
      add :request_type, :string, null: false
      add :status_code, :integer
      add :blocked, :boolean, default: false
      add :fingerprint_hash, :string

      timestamps(type: :utc_datetime)
    end

    create index(:suspicious_requests, [:ip_address])
    create index(:suspicious_requests, [:request_type])
    create index(:suspicious_requests, [:inserted_at])
  end
end
