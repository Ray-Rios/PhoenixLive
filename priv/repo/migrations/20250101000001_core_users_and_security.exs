defmodule PhoenixApp.Repo.Migrations.CoreUsersAndSecurity do
  @moduledoc """
  ============================================================================
  CORE USERS & SECURITY TABLES
  ============================================================================
  Users, authentication, tokens, security tracking, and access control.
  """
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    # ============================================================================
    # USERS
    # ============================================================================
    
    create_if_not_exists table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :password_hash, :string, null: false
      add :confirmed_at, :utc_datetime
      add :is_online, :boolean, default: false
      add :is_admin, :boolean, default: true
      add :last_activity, :utc_datetime
      add :avatar_shape, :string, default: "circle"
      add :avatar_color, :string, default: "#3B82F6"
      add :avatar_file, :string
      add :avatar_url, :string
      add :avatar_opacity, :integer, default: 100
      add :status, :string, default: "active"
      add :role, :string, default: "subscriber"
      add :bio, :text
      add :two_factor_secret, :string
      add :two_factor_enabled, :boolean, default: false
      add :two_factor_backup_codes, {:array, :string}, default: []
      add :position_x, :float, default: 400.0
      add :position_y, :float, default: 300.0
      
      # Security & verification fields
      add :email_verified_at, :utc_datetime
      add :email_verification_token, :string
      add :email_verification_sent_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0
      add :locked_until, :utc_datetime
      add :password_reset_token, :string
      add :password_reset_sent_at, :utc_datetime
      add :approved_at, :utc_datetime
      add :approved_by_id, :binary_id
      add :registration_ip, :string
      add :last_login_ip, :string
      add :last_login_at, :utc_datetime

      # User preferences
      add :background_preference, :string, default: "galaxy"
      add :background_custom_data, :map, default: %{}
      add :allow_channel_invites, :boolean, default: true
      add :blocked_user_ids, {:array, :binary_id}, default: []
      add :notification_sound_enabled, :boolean, default: true
      add :master_volume, :float, default: 0.7
      add :channel_order, {:array, :binary_id}, default: []
      
      # Subscription/quota fields
      add :stripe_customer_id, :string
      add :storage_quota_bytes, :bigint, default: 1_073_741_824  # 1GB
      add :storage_used_bytes, :bigint, default: 0
      add :subscription_tier, :string, default: "free"
      add :subscription_features, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    # Add self-referencing foreign key for approved_by_id
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'users_approved_by_id_fkey'
      ) THEN
        ALTER TABLE users 
        ADD CONSTRAINT users_approved_by_id_fkey 
        FOREIGN KEY (approved_by_id) 
        REFERENCES users(id) 
        ON DELETE SET NULL;
      END IF;
    END $$;
    """

    create_if_not_exists unique_index(:users, [:email])
    create_if_not_exists unique_index(:users, [:name], name: :users_name_unique_index)
    create_if_not_exists index(:users, [:is_admin])
    create_if_not_exists index(:users, [:two_factor_enabled])
    create_if_not_exists index(:users, [:email_verification_token])
    create_if_not_exists index(:users, [:password_reset_token])
    create_if_not_exists index(:users, [:locked_until])
    create_if_not_exists index(:users, [:email_verified_at])
    create_if_not_exists index(:users, [:stripe_customer_id])
    create_if_not_exists index(:users, [:subscription_tier])

    # ============================================================================
    # USER TOKENS
    # ============================================================================

    create_if_not_exists table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false, type: :utc_datetime)
    end

    create_if_not_exists index(:users_tokens, [:user_id])
    create_if_not_exists unique_index(:users_tokens, [:context, :token])

    # ============================================================================
    # SECURITY TRACKING TABLES
    # ============================================================================
    
    # Login attempts tracking
    create_if_not_exists table(:login_attempts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false
      add :identifier_type, :string, null: false
      add :attempt_count, :integer, default: 0
      add :last_attempt_at, :utc_datetime
      add :ip_address, :string
      add :user_agent, :text
      add :successful, :boolean, default: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:login_attempts, [:identifier])
    create_if_not_exists index(:login_attempts, [:identifier_type])
    create_if_not_exists index(:login_attempts, [:ip_address])
    create_if_not_exists index(:login_attempts, [:last_attempt_at])
    create_if_not_exists index(:login_attempts, [:user_id])

    # Blocked identifiers (IP/fingerprint blocklist)
    create_if_not_exists table(:blocked_identifiers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false
      add :identifier_type, :string, null: false
      add :reason, :text
      add :blocked_at, :utc_datetime, null: false
      add :blocked_by_user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      add :expires_at, :utc_datetime
      add :auto_blocked, :boolean, default: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:blocked_identifiers, [:identifier, :identifier_type])
    create_if_not_exists index(:blocked_identifiers, [:blocked_at])
    create_if_not_exists index(:blocked_identifiers, [:expires_at])
    create_if_not_exists index(:blocked_identifiers, [:auto_blocked])

    # Device fingerprints
    create_if_not_exists table(:device_fingerprints, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :fingerprint_hash, :string, null: false
      add :user_agent, :text
      add :platform, :string
      add :first_seen_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      add :trusted, :boolean, default: false
      add :metadata, :map
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:device_fingerprints, [:fingerprint_hash])
    create_if_not_exists index(:device_fingerprints, [:user_id])
    create_if_not_exists index(:device_fingerprints, [:first_seen_at])
    create_if_not_exists index(:device_fingerprints, [:last_seen_at])
    create_if_not_exists index(:device_fingerprints, [:trusted])

    # Behavioral analysis data
    create_if_not_exists table(:behavioral_data, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :session_id, :string
      add :device_fingerprint_id, references(:device_fingerprints, on_delete: :delete_all, type: :uuid)
      add :mouse_movements, :integer, default: 0
      add :keystrokes, :integer, default: 0
      add :form_focus_time, :integer
      add :time_to_submit, :integer
      add :seems_human, :boolean, default: false
      add :timestamp, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:behavioral_data, [:device_fingerprint_id])
    create_if_not_exists index(:behavioral_data, [:session_id])
    create_if_not_exists index(:behavioral_data, [:timestamp])
    create_if_not_exists index(:behavioral_data, [:seems_human])

    # Allowlist for trusted identifiers
    create_if_not_exists table(:allowed_identifiers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false
      add :identifier_type, :string, null: false
      add :reason, :text
      add :added_at, :utc_datetime, null: false
      add :added_by_user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:allowed_identifiers, [:identifier, :identifier_type])
    create_if_not_exists index(:allowed_identifiers, [:added_at])

    # ============================================================================
    # AUDIT LOGS
    # ============================================================================

    create_if_not_exists table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, :binary_id
      add :action, :string, null: false
      add :target_type, :string
      add :target_id, :binary_id
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:audit_logs, [:actor_id])
    create_if_not_exists index(:audit_logs, [:target_type, :target_id])
  end

  def down do
    drop_if_exists table(:audit_logs)
    drop_if_exists table(:allowed_identifiers)
    drop_if_exists table(:behavioral_data)
    drop_if_exists table(:device_fingerprints)
    drop_if_exists table(:blocked_identifiers)
    drop_if_exists table(:login_attempts)
    drop_if_exists table(:users_tokens)
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS users_approved_by_id_fkey"
    drop_if_exists table(:users)
  end
end
