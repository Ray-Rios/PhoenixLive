defmodule PhoenixApp.Repo.Migrations.DesktopAndSettings do
  @moduledoc """
  ============================================================================
  DESKTOP & SETTINGS TABLES
  ============================================================================
  Window layouts, calendar notes, and CMS options for the desktop environment.
  """
  use Ecto.Migration

  def change do
    # ============================================================================
    # WINDOW LAYOUTS (Desktop Environment)
    # ============================================================================

    create_if_not_exists table(:window_layouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :layout_name, :string, null: false
      add :windows_config, :map, default: %{}
      add :is_default, :boolean, default: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create_if_not_exists index(:window_layouts, [:user_id])
    create_if_not_exists index(:window_layouts, [:is_default])
    create_if_not_exists unique_index(:window_layouts, [:user_id, :layout_name])

    # ============================================================================
    # CALENDAR NOTES
    # ============================================================================

    create_if_not_exists table(:calendar_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :content, :text
      add :is_all_day, :boolean, default: true
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :color, :string, default: "#3b82f6"
      add :reminder, :boolean, default: false
      add :reminder_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create_if_not_exists index(:calendar_notes, [:user_id])
    create_if_not_exists index(:calendar_notes, [:date])
    create_if_not_exists index(:calendar_notes, [:user_id, :date])
    create_if_not_exists index(:calendar_notes, [:reminder, :reminder_at])

    # ============================================================================
    # CMS OPTIONS (Site-wide Settings)
    # ============================================================================

    create_if_not_exists table(:cms_options, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :text
      add :autoload, :boolean, default: true
      add :category, :string, default: "general"
      timestamps()
    end

    create_if_not_exists unique_index(:cms_options, [:key])
    create_if_not_exists index(:cms_options, [:autoload])
    create_if_not_exists index(:cms_options, [:category])

    # ============================================================================
    # USER SESSIONS (for desktop state persistence)
    # ============================================================================
    # Note: user sessions for authentication are handled via users_tokens
    # This is specifically for desktop environment state

    create_if_not_exists table(:user_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_data, :map, default: %{}
      add :desktop_state, :map, default: %{}
      add :last_activity_at, :utc_datetime
      add :user_agent, :string
      add :ip_address, :string
      add :device_type, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:user_sessions, [:user_id])
    create_if_not_exists index(:user_sessions, [:last_activity_at])

    # ============================================================================
    # NOTIFICATION PREFERENCES
    # ============================================================================

    create_if_not_exists table(:notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email_notifications, :boolean, default: true
      add :push_notifications, :boolean, default: true
      add :desktop_notifications, :boolean, default: true
      add :chat_mentions, :boolean, default: true
      add :chat_direct_messages, :boolean, default: true
      add :order_updates, :boolean, default: true
      add :marketing_emails, :boolean, default: false
      add :digest_frequency, :string, default: "daily"  # none, daily, weekly
      add :quiet_hours_start, :time
      add :quiet_hours_end, :time
      add :timezone, :string, default: "UTC"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create_if_not_exists unique_index(:notification_preferences, [:user_id])

    # ============================================================================
    # SITE ANNOUNCEMENTS
    # ============================================================================

    create_if_not_exists table(:announcements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :content, :text, null: false
      add :announcement_type, :string, default: "info"  # info, warning, error, success
      add :is_active, :boolean, default: true
      add :is_dismissible, :boolean, default: true
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :target_audience, :string, default: "all"  # all, authenticated, guests, premium
      add :display_location, {:array, :string}, default: ["all"]  # all, home, dashboard, shop
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:announcements, [:is_active])
    create_if_not_exists index(:announcements, [:starts_at])
    create_if_not_exists index(:announcements, [:ends_at])
    create_if_not_exists index(:announcements, [:announcement_type])
    create_if_not_exists index(:announcements, [:target_audience])
    create_if_not_exists index(:announcements, [:created_by_id])

    # ============================================================================
    # DISMISSED ANNOUNCEMENTS (User tracking)
    # ============================================================================

    create_if_not_exists table(:dismissed_announcements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :announcement_id, references(:announcements, type: :binary_id, on_delete: :delete_all), null: false
      add :dismissed_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:dismissed_announcements, [:user_id, :announcement_id])
    create_if_not_exists index(:dismissed_announcements, [:announcement_id])
  end
end
