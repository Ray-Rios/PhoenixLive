defmodule PhoenixApp.Repo.Migrations.CreateSecurityTracking do
  use Ecto.Migration

  def change do
    # Table for tracking login attempts
    create table(:login_attempts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false  # IP address or device fingerprint
      add :identifier_type, :string, null: false  # "ip" or "fingerprint"
      add :attempt_count, :integer, default: 0
      add :last_attempt_at, :utc_datetime
      add :ip_address, :string
      add :user_agent, :text
      add :successful, :boolean, default: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      
      timestamps(type: :utc_datetime)
    end

    create index(:login_attempts, [:identifier])
    create index(:login_attempts, [:identifier_type])
    create index(:login_attempts, [:ip_address])
    create index(:login_attempts, [:last_attempt_at])
    create index(:login_attempts, [:user_id])

    # Table for manually blocked identifiers (IP or device fingerprint)
    create table(:blocked_identifiers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false
      add :identifier_type, :string, null: false  # "ip" or "fingerprint"
      add :reason, :text
      add :blocked_at, :utc_datetime, null: false
      add :blocked_by_user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      add :expires_at, :utc_datetime  # NULL means permanent block
      add :auto_blocked, :boolean, default: false  # Auto-blocked by system vs manual
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:blocked_identifiers, [:identifier, :identifier_type])
    create index(:blocked_identifiers, [:blocked_at])
    create index(:blocked_identifiers, [:expires_at])
    create index(:blocked_identifiers, [:auto_blocked])

    # Table for device fingerprints
    create table(:device_fingerprints, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :fingerprint_hash, :string, null: false
      add :user_agent, :text
      add :platform, :string
      add :first_seen_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      add :trusted, :boolean, default: false
      add :metadata, :map  # Store additional fingerprint details as JSON
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_fingerprints, [:fingerprint_hash])
    create index(:device_fingerprints, [:user_id])
    create index(:device_fingerprints, [:first_seen_at])
    create index(:device_fingerprints, [:last_seen_at])
    create index(:device_fingerprints, [:trusted])

    # Table for behavioral analysis data
    create table(:behavioral_data, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :session_id, :string
      add :device_fingerprint_id, references(:device_fingerprints, on_delete: :delete_all, type: :uuid)
      add :mouse_movements, :integer, default: 0
      add :keystrokes, :integer, default: 0
      add :form_focus_time, :integer  # milliseconds
      add :time_to_submit, :integer  # milliseconds
      add :seems_human, :boolean, default: false
      add :timestamp, :utc_datetime, null: false
      
      timestamps(type: :utc_datetime)
    end

    create index(:behavioral_data, [:device_fingerprint_id])
    create index(:behavioral_data, [:session_id])
    create index(:behavioral_data, [:timestamp])
    create index(:behavioral_data, [:seems_human])

    # Table for allowlist (trusted IPs/fingerprints that bypass rate limiting)
    create table(:allowed_identifiers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false
      add :identifier_type, :string, null: false  # "ip" or "fingerprint"
      add :reason, :text
      add :added_at, :utc_datetime, null: false
      add :added_by_user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:allowed_identifiers, [:identifier, :identifier_type])
    create index(:allowed_identifiers, [:added_at])
  end
end
